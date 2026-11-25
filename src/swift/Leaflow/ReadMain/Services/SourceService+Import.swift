// 原始归属: ReadMain/Services/SourceService+Storage.swift
// 导入/导出、解码错误与合并，0x1003c7408 L452-496 / 0x1003cda58 L540-561。
import Foundation

extension SourceService {
    // MARK: 导入导出族

    /// 伪代码 0x1003c7408（L452-496；过滤谓词 closure 0x1003c8d38）：
    /// 导入编排——文本 → Data（失败 "无法将文本转换为数据" 返回 -1）→
    /// 解析（失败 "[导入] 解析失败: " 返回 -1）→ 复合键合并 →
    /// remote 域发送后端保存（"[导入调试] 远程导入: 准备发送 N 个配置到后端"；
    /// 成功 "[导入调试] 远程导入: 后端保存成功"，失败 "保存配置到后端失败: " /
    /// "[导入-远程] 保存失败: "）；返回导入数。
    @MainActor
    func importSourcesAsync(
        from text: String, storageKind kind: StorageKind
    ) async -> Int {
        guard !isImportingSources else {
            lastImportError = "正在导入配置，请稍后重试"
            return -1
        }
        isImportingSources = true
        lastImportError = nil
        defer { isImportingSources = false }
        guard let data = text.data(using: .utf8) else {
            lastImportError = "无法将文本转换为数据"
            return -1
        }
        let parsed = Self.parseImportedSources(from: data)
        guard let sources = parsed.sources, !sources.isEmpty else {
            lastImportError = parsed.errorMessage ?? "没有可导入的配置"
            return -1
        }
        let imported = sources.map { source in
            var copy = source
            copy.storageKind = kind
            return copy
        }
        // 冷启动的外部文件/URL导入也要先合并磁盘书源，不能覆盖已有配置。
        if !hasLoadedOnce && bookSources.isEmpty {
            bookSources = loadSourcesFromDisk()
            hasLoadedOnce = true
        }
        do {
            if kind == .remote {
                try await saveRemoteSources(imported)
                // 网络等待期间列表可能变化，必须合并到最新内存，而不是旧快照。
                let result = mergeImportedSources(imported)
                bookSources = result.merged
                NotificationCenter.default.post(name: Self.sourcesDidChangeNotification, object: nil)
                return result.importedCount
            }
            while true {
                let before = bookSources
                let result = mergeImportedSources(imported)
                let local = result.merged.filter { $0.storageKind != .remote }
                try await persistLocalSourcesSnapshot(
                    local, revision: localSaveRequestedRevision,
                    fileURL: sourcesFileURL, backupURL: sourcesBackupURL)
                // 写盘期间有其他编辑时重算，不能用导入前的列表覆盖其他修改。
                guard before == bookSources else { continue }
                bookSources = result.merged
                NotificationCenter.default.post(name: Self.sourcesDidChangeNotification, object: nil)
                return result.importedCount
            }
        } catch {
            lastImportError = "导入失败：\(error.localizedDescription)"
            Logger.log(lastImportError ?? "导入失败", level: .error)
            return -1
        }
    }

    /// pgo_only（"[导入] 数组解析失败: " 池内确证）：Data → [BookSource]
    /// 解析结果（错误文案由 decodingErrorMessage 工厂产出）。
    static func parseImportedSources(
        from data: Data
    ) -> (sources: [BookSource]?, errorMessage: String?) {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let decoder = JSONDecoder()
            let decoded: [BookSource]
            if object is [String: Any] {
                decoded = [try decoder.decode(BookSource.self, from: data)]
            } else {
                decoded = try decoder.decode([BookSource].self, from: data)
            }
            guard !decoded.isEmpty else {
                return (nil, "没有可导入的配置")
            }
            guard decoded.allSatisfy({
                !$0.bookSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else {
                return (nil, "配置缺少名称或 URL")
            }
            return (decoded, nil)
        } catch let error as DecodingError {
            return (nil, decodingErrorMessage(error))
        } catch {
            return (
                nil,
                "[导入] 数组解析失败: \(error.localizedDescription)"
            )
        }
    }

    /// 0x1003cda58 L540-561：命中原位覆盖，未命中追加。
    /// 字段首字节的存储域描述 + "_" + URL（伪代码 __dst[0...2]）作为复合键。
    func mergeImportedSources(
        _ imported: [BookSource]
    ) -> (merged: [BookSource], importedCount: Int) {
        var indexByKey: [String: Int] = [:]
        for (index, source) in bookSources.enumerated() {
            indexByKey[importMergeKey(source)] = index
        }
        var merged = bookSources
        var importedCount = 0
        for source in imported {
            let key = importMergeKey(source)
            if let index = indexByKey[key] {
                merged[index] = source
            } else {
                indexByKey[key] = merged.count
                merged.append(source)
                importedCount += 1
            }
        }
        return (merged, importedCount)
    }

    /// 合并身份：与 getSource(byUrl:storageKind:) 的查找域一致。
    private func importMergeKey(_ source: BookSource) -> String {
        source.storageKind.rawValue + "_" + source.bookSourceUrl
    }

    /// 伪代码 0x1003ce424（L523-536）：DecodingError 五分支 → 中文诊断串
    ///（"类型不匹配: 期望 " / "值为空: " / "缺少必要字段: " / "数据损坏: " /
    /// "未知解码错误: " + "\n路径: " + codingPath joined "." 确证）。
    private static func decodingErrorMessage(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "类型不匹配: 期望 \(typeName(type))\n路径: \(pathText(context))"
        case .valueNotFound(_, let context):
            return "值为空: \(typeName(context))\n路径: \(pathText(context))"
        case .keyNotFound(let key, let context):
            return "缺少必要字段: \(key.stringValue)\n路径: \(pathText(context))"
        case .dataCorrupted(let context):
            return "数据损坏: \(context.debugDescription)"
        @unknown default:
            return "未知解码错误: \(error.localizedDescription)"
        }
    }

    /// typeMismatch/valueNotFound 的实体名（_typeName(qualified: false) 域）。
    private static func typeName(_ type: Any.Type) -> String {
        String(describing: type)
    }

    /// valueNotFound 实体名重载（Context 无类型载荷，取 debugDescription 域）。
    private static func typeName(_ context: DecodingError.Context) -> String {
        context.debugDescription
    }

    /// "\n路径: " + codingPath joined "."（分隔符 "." 确证）。
    private static func pathText(_ context: DecodingError.Context) -> String {
        context.codingPath.map { $0.stringValue }.joined(separator: ".")
    }

    /// pgo_only（3 个 CodingKey 闭包与 decodingErrorMessage 同域确证）：
    /// 同步导入（解析 + 合并 + 保存收尾），返回导入数，失败 -1。
    func importSources(from text: String) -> Int {
        guard let data = text.data(using: .utf8) else { return -1 }
        let parse = Self.parseImportedSources(from: data)
        guard let imported = parse.sources else { return -1 }
        let local = imported.map { source in
            var copy = source
            copy.storageKind = .local
            return copy
        }
        let (merged, importedCount) = mergeImportedSources(local)
        bookSources = merged
        scheduleSave()
        return importedCount
    }

    /// pgo_only：文件读取解析封装（Data(contentsOf:) + parseImportedSources）。
    func loadSourcesFromFile(url: URL) -> [BookSource]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Self.parseImportedSources(from: data).sources
    }

    /// pgo_only：同步便捷封装（磁盘三级降级首段）。
    func loadSourcesFromDisk() -> [BookSource] {
        loadLocalSourcesFromDisk().sources
    }

    /// pgo_only：编码导出（sortedKeys 同域推断）。
    func exportSources() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(bookSources) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 批量保存按存储域分发，远程错误不能报告为本地保存成功。
    func saveBookSources(_ sources: [BookSource]) async -> Bool {
        let remote = sources.filter { $0.storageKind == .remote }
        let (merged, _) = mergeImportedSources(sources.filter {
            $0.storageKind != .remote
        })
        if !remote.isEmpty {
            Logger.log(
                "[导入调试] 远程导入: 准备发送 \(remote.count) 个配置到后端",
                level: .info)
        }
        do {
            if !remote.isEmpty {
                try await saveRemoteSources(remote)
            }
            try await saveSerializer.save(
                revision: localSaveRequestedRevision,
                sources: merged.filter { $0.storageKind != .remote },
                fileURL: sourcesFileURL,
                backupURL: sourcesBackupURL)
            bookSources = mergeImportedSources(sources).merged
            NotificationCenter.default.post(name: Self.sourcesDidChangeNotification, object: nil)
            return true
        } catch {
            Logger.log(
                "配置保存失败: \(error.localizedDescription)",
                level: .error)
            return false
        }
    }
}
