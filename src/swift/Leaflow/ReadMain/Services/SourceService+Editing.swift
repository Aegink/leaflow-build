// 原始归属: ReadMain/Services/SourceService.swift
// 编辑/分组与保存序列化器，地址和原行区段沿用各成员取证。
import Foundation

extension SourceService {
    // MARK: 编辑族

    /// 伪代码 0x1003b5370（L553-601；收尾 closure 0x1003b5ce4）：
    /// oldUrl 先 trimmingCharacters 归一化；定位失败或新 url 冲突返回 false；
    /// 原地替换（COW + 观察者通知）后 remote 走 MainActor Task、
    /// 本地走 finishPendingLocalSave。
    @discardableResult
    func updateSource(oldUrl: String, source: BookSource) -> Bool {
        let trimmed = oldUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bookSources.isEmpty else { return false }
        guard let index = bookSources.firstIndex(where: {
            $0.bookSourceUrl == trimmed
        }) else {
            return false
        }
        if source.bookSourceUrl != trimmed {
            let conflict = bookSources.enumerated().contains { offset, item in
                offset != index && item.bookSourceUrl == source.bookSourceUrl
            }
            if conflict { return false }
        }
        bookSources[index] = source
        if source.storageKind == .remote {
            Task { finishPendingLocalSave(revision: localSaveRequestedRevision) }
        } else {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return true
    }

    /// 伪代码 0x1003b5e30（L604-626）：edits 非空字段逐个覆盖 base
    ///（非空/非 nil 判定确证；字段集推断）。
    static func mergeSourceEdits(
        base: BookSource, edits: BookSource
    ) -> BookSource {
        var merged = base
        if !edits.bookSourceName.isEmpty {
            merged.bookSourceName = edits.bookSourceName
        }
        if !edits.bookSourceUrl.isEmpty {
            merged.bookSourceUrl = edits.bookSourceUrl
        }
        if let group = edits.bookSourceGroup {
            merged.bookSourceGroup = group
        }
        if let login = edits.loginUrl {
            merged.loginUrl = login
        }
        if let cover = edits.coverDecodeUrl {
            merged.coverDecodeUrl = cover
        }
        return merged
    }

    /// 伪代码 0x1003b6868（L634-650）：空 url 或重复 url 拒绝；否则 COW 追加
    /// 并按 storageKind 分派保存；返回 true = 已加入。
    @discardableResult
    func addSource(_ source: BookSource) -> Bool {
        guard !source.bookSourceUrl.isEmpty else { return false }
        guard !bookSources.contains(where: {
            $0.bookSourceUrl == source.bookSourceUrl
        }) else {
            return false
        }
        bookSources.append(source)
        if source.storageKind == .remote {
            Task { finishPendingLocalSave(revision: localSaveRequestedRevision) }
        } else {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return true
    }

    // MARK: 分组族

    /// pgo_only（签名确证）：收集全部分组名（空分组按 "未分组" 兜底，排序推断）。
    func getAllGroupNames() -> [String] {
        Set(bookSources.map { $0.bookSourceGroup ?? "未分组" }).sorted()
    }

    /// 伪代码 0x1003b6e14（L687-724；收尾 closure 0x1003b7b9c）：命中 urls
    /// 集合的源改写 group 并计数，有改动即收尾；返回修改数。
    @discardableResult
    func batchUpdateSourceGroup(urls: Set<String>, group: String?) -> Int {
        var changed = 0
        for index in bookSources.indices
        where urls.contains(bookSources[index].bookSourceUrl) {
            bookSources[index].bookSourceGroup = group
            changed += 1
        }
        if changed > 0 {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return changed
    }

    /// 伪代码 0x1003b7f74（L727-759；远程收尾 closure 0x1003b8538）：
    /// from==to 返回 0；空分组名按 "未分组" 兜底（内联小串位确证）；
    /// 命中改名并收集 remote url 异步同步；返回重命名数。
    @discardableResult
    func renameGroup(from: String, to: String) -> Int {
        guard from != to, !bookSources.isEmpty else { return 0 }
        let normalizedFrom = from.isEmpty ? "未分组" : from
        var changed = 0
        var remoteUrls: [String] = []
        for index in bookSources.indices {
            let current = bookSources[index].bookSourceGroup ?? "未分组"
            if current == normalizedFrom {
                bookSources[index].bookSourceGroup = to
                changed += 1
                if bookSources[index].storageKind == .remote {
                    remoteUrls.append(bookSources[index].bookSourceUrl)
                }
            }
        }
        if changed > 0 {
            // remoteUrls 非空时另派远程重命名收尾（closure 0x1003b8538 域）。
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return changed
    }

    /// 伪代码 0x1003b86d0（L762-797；收尾 closure 0x1003b91ec + implicit
    /// closure3 0x1003bbc88）：命中 sourceGroups 字典的源 group 改写为 into；
    /// 返回并入数量。
    @discardableResult
    func mergeGroups(sourceGroups: [String], into: String) -> Int {
        guard !bookSources.isEmpty else { return 0 }
        let targets = Set(sourceGroups)
        var changed = 0
        for index in bookSources.indices {
            let current = bookSources[index].bookSourceGroup ?? "未分组"
            if targets.contains(current) {
                bookSources[index].bookSourceGroup = into
                changed += 1
            }
        }
        if changed > 0 {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return changed
    }

    // MARK: 协议实现

    /// SourceServiceProtocol（ServiceProtocols 默认实现指向本分册）：
    /// 函数体在 +Parsing 扩展 0x1003c195c（L440-474，
    /// "[远程后端] getBookInfo 成功" 诊断串确证）。
    func getBookInfo(source: BookSource, book: Book) async -> Book? {
        await getBookInfo(source: source, book: book, canReName: true)
    }
}

/// 保存序列化器（noteRequestedRevision/latestRequestedRevision/save 域确证）。
final class SaveSerializer {

    private static let stateLock = NSLock()
    private static var latestRequestedRevisionStorage = 0

    /// pgo_only（closure 0x1001577a4 L808-812 消费确证）：登记请求修订号。
    static func noteRequestedRevision(_ revision: Int) {
        stateLock.lock()
        latestRequestedRevisionStorage = max(latestRequestedRevisionStorage, revision)
        stateLock.unlock()
    }

    /// pgo_only（签名确证）：当前请求修订号。
    static var latestRequestedRevision: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return latestRequestedRevisionStorage
    }

    /// 伪代码 0x1003b9880（L828-868）：revision 门禁（存在更新的请求修订号
    /// 则跳过）→ JSONEncoder（outputFormatting = [.sortedKeys] 确证）→
    /// fileExistsAtPath: → copyItemAtURL:toURL:error:（fileURL → backupURL）
    /// → Data.write(to:options: .atomic) → "[配置] 已保存 N 字节到文件"。
    func save(
        revision: Int,
        sources: [BookSource],
        fileURL: URL,
        backupURL: URL
    ) async throws {
        guard revision >= Self.latestRequestedRevision else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(sources)
        let manager = FileManager.default
        if manager.fileExists(atPath: fileURL.path) {
            // 已有备份也必须可更新，第三次保存不能因目标已存在而失败。
            try Data(contentsOf: fileURL).write(to: backupURL, options: .atomic)
        }
        try data.write(to: fileURL, options: .atomic)
        Logger.log("[配置] 已保存 \(data.count) 字节到文件", level: .info)
    }
}
