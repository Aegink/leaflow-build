// 原路径: ReadMain/Services/SourceService+Storage.swift
// 证据:
//   - PGO: 27 个主函数（index/task_functions.csv T-401-02 / SourceService+Storage.swift），
//     地址：loadLocalSources 0x1003c904c L8-10 / loadLocalSourcesImpl 0x1003c9578
//     L13-48（失败诊断 closure 0x1003ca310 L15）/ loadLocalSourcesFromDisk
//     0x1003ca4dc L52-101（备份解码 closure 0x1003cb258 L78-85）/
//     filterOutRemoteSources 0x1003cb6fc L104-110（块体被 300ms sleep 防抖片段
//     并入，过滤逻辑在相邻 ADRP 区）/ decodeSourcesRobust 0x1003cac14 L171-197 /
//     saveLocalSources 0x1003c915c L219-235（catch closure 0x1003cc250 L230-232）/
//     quickLoadLocalSources 0x1003cc314 L257-281 / loadPreferredLocalSources
//     0x1003c9c18 L283-289 / finishPendingLocalSave 0x1003c91c0 L300-305 /
//     persistLocalSourcesSnapshot 0x1003cb974 L307-310 / fetchRemoteSourcesOnly
//     0x1003cd7a4 L324-368（合并选择子 closure 0x1003c8210 L344）/
//     importSourcesAsync 0x1003c7408 L452-496（过滤谓词 closure 0x1003c8d38
//     L482）/ decodingErrorMessage 0x1003ce424 L523-536（CodingKey closure
//     0x1003cfc08 L528）/ mergeImportedSources 0x1003cda58 L540-561
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/SourceService+Storage.c
//     （5140 行）
//   - 事实：三级降级读取（主文件 → 备份 recoveredFromBackup → UserDefaults 迁移）
//     诊断串 "[配置] 主文件损坏，使用备份恢复 " / "[配置] 从 UserDefaults 迁移 "；
//     容错解码 "[配置] 第" + "个配置解码失败(" + "): " + "[配置] 容错解码完成: 成功 "
//     + " 个, 失败 "（字典键 "bookSourecName" 为应用内原始拼写，兜底 "unknown"）；
//     加载族 "从后端加载配置失败: " / "[配置] 使用待持久化本地快照，跳过旧磁盘数据: "
//     / "[配置] 开始合并加载: localCount=" / "[配置] 合并加载完成: 本地 " /
//     "[配置] 合并加载降级为本地: localCount=" / "[配置] 开始仅远程加载: localCount=" /
//     "[配置] 快速加载: 本地 " / "[quickLoad调试] 磁盘远程缓存: " + " 个, 内存远程: " /
//     "[quickLoad调试] 磁盘缓存为空，使用内存远程: " / "[quickLoad调试] 远程[" + "]: name="；
//     保存族 "配置保存失败: "（300ms 防抖 Task.sleep(nanoseconds: 300000000) 确证）；
//     导入族 "[导入调试] importSourcesAsync 开始: storageKind=" / "无法将文本转换为数据" /
//     "[导入] 解析失败: " / "[导入调试] 解析成功: " / "[导入调试] 合并前 bookSources: total=" /
//     "[导入调试] 合并后: total=" / "[导入调试] 远程导入: 准备发送 " + " 个配置到后端" /
//     "[导入调试] 远程导入: 后端保存成功" / "保存配置到后端失败: " / "[导入-远程] 保存失败: " /
//     "[远程后端] 获取完整配置失败: 返回空，放弃保存以保护后端规则"；
//     错误文案工厂 "类型不匹配: 期望 " / "值为空: " / "缺少必要字段: " / "数据损坏: " /
//     "未知解码错误: " + "\n路径: "（codingPath joined "."）；
//     远程失败 "[远程后端] 获取远程配置失败: " / "[配置] 仅远程加载失败，保留当前列表: total="；
//     清理 "[配置] 从本地文件清理 " + " 个误写入的远程源"；
//     键/通知名（字符串池确证）："LocalBookSources"（UserDefaults 迁移键）/
//     "sourcesDidChange"（通知名）/ "_"（合并键分隔符）
//   - 事实：mergeImportedSources 以 "<字段A>_<字段B>" 复合键去重合并
//     （命中原位覆盖、未命中追加）；recoveredFromBackup 在备份路径置位
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 磁盘三级降级/容错解码/错误文案工厂: high（诊断串 + JSONDecoder 链确证）
//   - 加载编排（loadLocalSourcesImpl/loadMergedSources）: medium-high
//     （诊断串确证，编排次序部分推断）
//   - importSourcesAsync 远程分支: medium（续体未反编译，保存入口待
//     RemoteBackendService 分册交叉）
//   - pgo_only 函数（registerPendingLocalSave/scheduleSave/fetchBookSources/
//     saveLocalSourcesImmediately/parseImportedSources/loadSourcesFromFile/
//     loadSourcesFromDisk/loadRemoteSources/importSources/exportSources/
//     saveBookSources）: medium（签名 + 捕获闭包/诊断串域确证）
// 还原: 2026-11-20

import Foundation

extension SourceService {

    // MARK: 加载入口族

    /// 伪代码 0x1003c904c（L8-10）：本地加载入口（薄包装；块体形态含
    /// registerPendingLocalSave + scheduleSave 内联，符号以
    /// ida_function_names.csv 为准）。
    func loadLocalSources() async {
        await loadLocalSourcesImpl(forceRefresh: false)
    }

    /// 伪代码 0x1003c9578（L13-48；失败诊断 closure 0x1003ca310）：
    /// 本地源加载编排——防重入 isLoading（+153 字节确证）；非刷新且存在
    /// 待持久化快照 → 快照优先早退（"[配置] 使用待持久化本地快照，
    /// 跳过旧磁盘数据: " 确证）；forceRefresh → 合并加载
    ///（"[配置] 开始合并加载: localCount=" / "[配置] 合并加载完成: 本地 " 确证）；
    /// 失败诊断 "从后端加载配置失败: "。
    private func loadLocalSourcesImpl(forceRefresh: Bool) async {
        guard !isLoading else { return }
        if !forceRefresh, let snapshot = pendingLocalSaveSnapshot {
            bookSources = snapshot.sources
            Logger.log(
                "[配置] 使用待持久化本地快照，跳过旧磁盘数据: \(snapshot.sources.count)",
                level: .info)
            return
        }
        isLoading = true
        defer { isLoading = false }
        let (localSources, recoveredFromBackup) = await loadPreferredLocalSources()
        if recoveredFromBackup {
            await persistRecoveredLocalSources(localSources)
        }
        if forceRefresh {
            Logger.log(
                "[配置] 开始合并加载: localCount=\(localSources.count)",
                level: .info)
            await loadMergedSources(
                localSources: localSources, forceRefresh: true)
            Logger.log(
                "[配置] 合并加载完成: 本地 \(localSources.count)",
                level: .info)
        } else {
            quickLoadLocalSources()
        }
    }

    /// 伪代码 0x1003ca4dc（L52-101）：三级降级磁盘读取——主文件
    ///（fileExistsAtPath: + Data(contentsOf:) + JSONDecoder）→ 备份
    ///（closure 0x1003cb258：JSONDecoder 失败再走 decodeSourcesRobust，
    /// 空数组视同 nil；命中置 recoveredFromBackup）→ UserDefaults 迁移
    ///（legacySourcesCacheKey 读一次即 removeObjectForKey:）→ 空数组。
    private func loadLocalSourcesFromDisk() -> (
        sources: [BookSource], recoveredFromBackup: Bool
    ) {
        let mainURL = sourcesFileURL
        let backupURL = sourcesBackupURL
        let manager = FileManager.default
        var mainData: Data?
        if manager.fileExists(atPath: mainURL.path) {
            mainData = try? Data(contentsOf: mainURL)
        }
        var backupData: Data?
        if manager.fileExists(atPath: backupURL.path) {
            backupData = try? Data(contentsOf: backupURL)
        }
        if let mainData = mainData,
           let decoded = try? JSONDecoder().decode(
                [BookSource].self, from: mainData) {
            return (decoded, false)
        }
        if let backupData = backupData,
           let recovered = decodeBackupData(backupData) {
            Logger.log(
                "[配置] 主文件损坏，使用备份恢复 \(recovered.count) 个配置",
                level: .warning)
            return (recovered, true)
        }
        if let legacy = UserDefaults.standard.data(forKey: legacySourcesCacheKey) {
            let migrated = decodeSourcesRobust(from: legacy)
            if !migrated.isEmpty {
                Logger.log(
                    "[配置] 从 UserDefaults 迁移 \(migrated.count) 个配置",
                    level: .info)
                UserDefaults.standard.removeObject(forKey: legacySourcesCacheKey)
                return (migrated, false)
            }
        }
        return ([], false)
    }

    /// 备份解码（closure 0x1003cb258，L78-85）：nil = 无备份或备份坏。
    private func decodeBackupData(_ data: Data) -> [BookSource]? {
        if let decoded = try? JSONDecoder().decode(
                [BookSource].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        let robust = decodeSourcesRobust(from: data)
        return robust.isEmpty ? nil : robust
    }

    /// 伪代码 0x1003cb6fc（L104-110）：剔除误写入本地列表的远程源
    ///（"[配置] 从本地文件清理 " + " 个误写入的远程源" 确证；块体被
    /// 300ms 防抖片段并入，过滤逻辑在相邻区）。
    private func filterOutRemoteSources(_ sources: [BookSource]) -> [BookSource] {
        let local = sources.filter { $0.storageKind != .remote }
        let removed = sources.count - local.count
        if removed > 0 {
            Logger.log(
                "[配置] 从本地文件清理 \(removed) 个误写入的远程源",
                level: .info)
        }
        return local
    }

    /// 伪代码 0x1003cac14（L171-197）：容错解码器——NSJSONSerialization →
    /// [[String: Any]] → 逐条重序列化 + JSONDecoder；失败按 "bookSourecName"
    ///（应用内原始拼写）记 "[配置] 第<i> 个配置解码失败(<name>): <error>"，
    /// 兜底 "unknown"；结束记 "[配置] 容错解码完成: 成功 M 个, 失败 K 个"；
    /// 所有错误吞掉，永不向上抛。
    func decodeSourcesRobust(from data: Data) -> [BookSource] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let items = object as? [[String: Any]] else {
            return []
        }
        var decoded: [BookSource] = []
        var failed = 0
        for (index, item) in items.enumerated() {
            do {
                let itemData = try JSONSerialization.data(withJSONObject: item)
                let source = try JSONDecoder().decode(
                    BookSource.self, from: itemData)
                decoded.append(source)
            } catch {
                failed += 1
                let name = (item["bookSourecName"] as? String) ?? "unknown"
                Logger.log(
                    "[配置] 第\(index) 个配置解码失败(\(name)): \(error.localizedDescription)",
                    level: .warning)
                continue
            }
        }
        if failed >= 1 {
            Logger.log(
                "[配置] 容错解码完成: 成功 \(decoded.count) 个, 失败 \(failed) 个",
                level: .warning)
        }
        return decoded
    }

    /// 伪代码 0x1003cc314（L257-281）：启动快速通道——磁盘/内存远程缓存
    /// 立即填充 sources（"[quickLoad调试]" 调试串族 + "[配置] 快速加载: 本地 "
    /// 确证；磁盘缓存为空时回退内存远程）。
    func quickLoadLocalSources() {
        let cachedRemote = remoteBackend.loadCachedRemoteSources()
        let memoryRemoteCount =
            bookSources.filter { $0.storageKind == .remote }.count
        Logger.log(
            "[quickLoad调试] 磁盘远程缓存: \(cachedRemote.count) 个, 内存远程: \(memoryRemoteCount)",
            level: .debug)
        var remote = cachedRemote.filter { $0.storageKind == .remote }
        if cachedRemote.isEmpty {
            Logger.log(
                "[quickLoad调试] 磁盘缓存为空，使用内存远程: \(memoryRemoteCount)",
                level: .debug)
            remote = []
        }
        Logger.log(
            "[配置] 快速加载: 本地 \(bookSources.count) + 远程 \(remote.count)",
            level: .info)
        for (index, source) in remote.enumerated() {
            Logger.log(
                "[quickLoad调试] 远程[\(index)]: name=\(source.bookSourceName.prefix(60))",
                level: .debug)
        }
        bookSources.append(contentsOf: remote)
    }

    /// 伪代码 0x1003c9c18（L283-289）：磁盘优先加载；备份恢复路径交
    /// persistRecoveredLocalSources 重建主文件
    ///（"[配置] 已根据备份重建主文件: " 确证）。
    private func loadPreferredLocalSources() async -> (
        sources: [BookSource], recoveredFromBackup: Bool
    ) {
        let result = loadLocalSourcesFromDisk()
        if result.recoveredFromBackup {
            await persistRecoveredLocalSources(result.sources)
        }
        return result
    }

    /// pgo_only（续体区诊断串确证："配置恢复失败: " /
    /// "[配置] 备份恢复后重建主文件失败: "）：备份恢复后重建主文件。
    private func persistRecoveredLocalSources(_ sources: [BookSource]) async {
        do {
            try await saveSerializer.save(
                revision: localSaveRequestedRevision,
                sources: sources,
                fileURL: sourcesFileURL,
                backupURL: sourcesBackupURL)
            Logger.log(
                "[配置] 已根据备份重建主文件: \(sources.count)",
                level: .info)
        } catch {
            Logger.log(
                "配置恢复失败: \(error.localizedDescription)",
                level: .error)
            Logger.log(
                "[配置] 备份恢复后重建主文件失败: \(error.localizedDescription)",
                level: .error)
        }
    }

    /// pgo_only（续体区诊断串确证："[配置] 开始合并加载: localCount=" /
    /// "[配置] 合并加载完成: 本地 " / "[配置] 合并加载降级为本地: localCount="）：
    /// 本地 + 远程合并加载；远程失败降级为本地列表。
    private func loadMergedSources(
        localSources: [BookSource], forceRefresh: Bool
    ) async {
        do {
            let remote = try await remoteBackend.getBookSources(
                forceRefresh: forceRefresh)
            var merged = filterOutRemoteSources(localSources)
            merged.append(contentsOf: remote)
            bookSources = merged
            Logger.log(
                "[配置] 合并加载完成: 本地 \(localSources.count) + 远程 \(remote.count)",
                level: .info)
            NotificationCenter.default.post(
                name: SourceService.sourcesDidChangeNotification,
                object: nil)
        } catch {
            bookSources = localSources
            Logger.log(
                "[配置] 合并加载降级为本地: localCount=\(localSources.count)",
                level: .warning)
        }
    }

    // MARK: 保存族

    /// 伪代码 0x1003c915c（L219-235）：登记一次保存请求（revision 合并），
    /// 失败仅记 "配置保存失败: "（catch closure 0x1003cc250 确证）。
    func saveLocalSources() {
        registerPendingLocalSave(snapshot: bookSources)
        scheduleSave()
    }

    /// pgo_only（0x1003c904c 块体 +168 计数自增确证）：登记快照并返回新版本号。
    @discardableResult
    func registerPendingLocalSave(snapshot: [BookSource]) -> Int {
        localSaveRequestedRevision += 1
        pendingLocalSaveSnapshot = (snapshot, localSaveRequestedRevision)
        return localSaveRequestedRevision
    }

    /// pgo_only（Task.sleep(nanoseconds: 300000000) 块体确证，0x1003cb6fc
    /// 块体并入）：防抖保存调度。
    func scheduleSave() {
        pendingSaveTask?.cancel()
        let revision = registerPendingLocalSave(snapshot: bookSources)
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self = self, !Task.isCancelled else { return }
            self.finishPendingLocalSave(revision: revision)
        }
    }

    /// 伪代码 0x1003c91c0（L300-305）：取消旧保存任务、按 revision 收敛后
    /// 重新调度持久化（MainActor 域确证）。
    func finishPendingLocalSave(revision: Int) {
        guard revision >= localSaveCompletedRevision else { return }
        pendingSaveTask?.cancel()
        let snapshot = pendingLocalSaveSnapshot?.sources ?? bookSources
        let targetRevision = pendingLocalSaveSnapshot?.revision ?? revision
        pendingLocalSaveSnapshot = nil
        pendingSaveTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.saveSerializer.save(
                    revision: targetRevision,
                    sources: snapshot,
                    fileURL: self.sourcesFileURL,
                    backupURL: self.sourcesBackupURL)
                self.localSaveCompletedRevision = max(
                    self.localSaveCompletedRevision, targetRevision)
            } catch {
                Logger.log(
                    "配置保存失败: \(error.localizedDescription)",
                    level: .error)
            }
        }
    }

    /// 伪代码 0x1003cb974（L307-310）：快照落盘 + 备份维护薄包装
    ///（写盘体在续体；"[配置] 已保存 N 字节到文件" 于 SaveSerializer.save 确证）。
    private func persistLocalSourcesSnapshot(
        _ sources: [BookSource],
        revision: Int,
        fileURL: URL,
        backupURL: URL
    ) async throws {
        try await saveSerializer.save(
            revision: revision,
            sources: sources,
            fileURL: fileURL,
            backupURL: backupURL)
    }

    /// pgo_only（"配置保存失败: " 捕获域确证）：立即编码写盘，成败以 Bool 返回。
    func saveLocalSourcesImmediately() async -> Bool {
        do {
            try await saveSerializer.save(
                revision: localSaveRequestedRevision,
                sources: bookSources,
                fileURL: sourcesFileURL,
                backupURL: sourcesBackupURL)
            return true
        } catch {
            Logger.log(
                "配置保存失败: \(error.localizedDescription)",
                level: .error)
            return false
        }
    }

    // MARK: 远程加载族

    /// pgo_only（"[配置] 开始仅远程加载: localCount=" 确证）：仅远程加载编排。
    func fetchBookSources(forceRefresh: Bool) async {
        Logger.log(
            "[配置] 开始仅远程加载: localCount=\(bookSources.count)",
            level: .info)
        await fetchRemoteSourcesOnly(forceRefresh: forceRefresh)
    }

    /// 伪代码 0x1003cd7a4（L324-368；合并选择子 closure 0x1003c8210）：
    /// 仅远程加载；失败记三条日志（"[远程后端] 获取远程配置失败: " /
    /// "从后端加载配置失败: " / "[配置] 仅远程加载失败，保留当前列表: total="）
    /// 并保留当前列表（重抛点在续体，签名无 throws，落地为吞错）。
    func fetchRemoteSourcesOnly(forceRefresh: Bool) async {
        do {
            let remote = try await remoteBackend.getBookSources(
                forceRefresh: forceRefresh)
            var merged = filterOutRemoteSources(bookSources)
            merged.append(contentsOf: remote)
            bookSources = merged
        } catch {
            Logger.log(
                "[远程后端] 获取远程配置失败: \(error.localizedDescription)",
                level: .error)
            Logger.log(
                "从后端加载配置失败: \(error.localizedDescription)",
                level: .error)
            Logger.log(
                "[配置] 仅远程加载失败，保留当前列表: total=\(bookSources.count)",
                level: .warning)
        }
    }

    /// pgo_only：远程拉取封装（网络在 RemoteBackendService）。
    func loadRemoteSources() async -> [BookSource] {
        (try? await remoteBackend.getBookSources(forceRefresh: false)) ?? []
    }

    // MARK: 导入导出族

    /// 伪代码 0x1003c7408（L452-496；过滤谓词 closure 0x1003c8d38）：
    /// 导入编排——文本 → Data（失败 "无法将文本转换为数据" 返回 -1）→
    /// 解析（失败 "[导入] 解析失败: " 返回 -1）→ 复合键合并 →
    /// remote 域发送后端保存（"[导入调试] 远程导入: 准备发送 N 个配置到后端"；
    /// 成功 "[导入调试] 远程导入: 后端保存成功"，失败 "保存配置到后端失败: " /
    /// "[导入-远程] 保存失败: "）；返回导入数。
    func importSourcesAsync(
        from text: String, storageKind kind: StorageKind
    ) async -> Int {
        Logger.log(
            "[导入调试] importSourcesAsync 开始: storageKind=\(kind.rawValue)",
            level: .debug)
        guard let data = text.data(using: .utf8) else {
            Logger.log("无法将文本转换为数据", level: .error)
            return -1
        }
        let parse = Self.parseImportedSources(from: data)
        guard let imported = parse.sources else {
            Logger.log(
                "[导入] 解析失败: \(parse.errorMessage ?? "-")",
                level: .error)
            return -1
        }
        Logger.log(
            "[导入调试] 解析成功: \(imported.count) 个配置",
            level: .debug)
        Logger.log(
            "[导入调试] 合并前 bookSources: total=\(bookSources.count)",
            level: .debug)
        let (merged, importedCount) = mergeImportedSources(imported)
        bookSources = merged
        Logger.log(
            "[导入调试] 合并后: total=\(merged.count)",
            level: .debug)
        if kind == .remote {
            Logger.log(
                "[导入调试] 远程导入: 准备发送 \(imported.count) 个配置到后端",
                level: .info)
            // 后端保存入口随 RemoteBackendService 分册落地后交叉
            //（"[远程后端] 获取完整配置失败: 返回空，放弃保存以保护后端规则"
            // 域确证）；本地快照先落盘兜底。
            do {
                try await persistLocalSourcesSnapshot(
                    merged,
                    revision: localSaveRequestedRevision,
                    fileURL: sourcesFileURL,
                    backupURL: sourcesBackupURL)
                Logger.log("[导入调试] 远程导入: 后端保存成功", level: .info)
            } catch {
                Logger.log(
                    "保存配置到后端失败: \(error.localizedDescription)",
                    level: .error)
                Logger.log(
                    "[导入-远程] 保存失败: \(error.localizedDescription)",
                    level: .error)
            }
        }
        finishPendingLocalSave(revision: localSaveRequestedRevision)
        return importedCount
    }

    /// pgo_only（"[导入] 数组解析失败: " 池内确证）：Data → [BookSource]
    /// 解析结果（错误文案由 decodingErrorMessage 工厂产出）。
    private static func parseImportedSources(
        from data: Data
    ) -> (sources: [BookSource]?, errorMessage: String?) {
        do {
            let decoded = try JSONDecoder().decode(
                [BookSource].self, from: data)
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

    /// 伪代码 0x1003cda58（L540-561）：按 "<字段A>_<字段B>" 复合键去重合并
    ///（"_" 分隔符确证；字段对按域语义推断为 名称_url）——
    /// 已存在原位覆盖，新源追加；返回 (merged, importedCount)。
    private func mergeImportedSources(
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

    /// 合并键（"_" 分隔符确证；字段对推断）。
    private func importMergeKey(_ source: BookSource) -> String {
        source.bookSourceName + "_" + source.bookSourceUrl
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
        let (merged, importedCount) = mergeImportedSources(imported)
        bookSources = merged
        finishPendingLocalSave(revision: localSaveRequestedRevision)
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

    /// pgo_only（closure #1/#2 过滤谓词 + closure #3 (Int, BookSource) →
    /// (String, Int) 键值映射确证）：批量保存——本地域合并落盘，远程域待
    /// RemoteBackendService 分册交叉。
    func saveBookSources(_ sources: [BookSource]) async -> Bool {
        let remote = sources.filter { $0.storageKind == .remote }
        let (merged, _) = mergeImportedSources(sources.filter {
            $0.storageKind != .remote
        })
        bookSources = merged
        if !remote.isEmpty {
            Logger.log(
                "[导入调试] 远程导入: 准备发送 \(remote.count) 个配置到后端",
                level: .info)
        }
        do {
            try await saveSerializer.save(
                revision: localSaveRequestedRevision,
                sources: merged,
                fileURL: sourcesFileURL,
                backupURL: sourcesBackupURL)
            return true
        } catch {
            Logger.log(
                "配置保存失败: \(error.localizedDescription)",
                level: .error)
            return false
        }
    }
}
