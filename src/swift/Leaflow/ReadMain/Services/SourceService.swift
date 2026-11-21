// 原路径: ReadMain/Services/SourceService.swift
// 证据:
//   - PGO: 55 个主函数（index/task_functions.csv T-401-02 / SourceService.swift），
//     地址：NetworkMonitor.isConnected 0x1003aab00 L17-19 / monitor 队列初值
//     0x1003aa7e0 L13 / 路径回调 closure 0x1003aad50 L22-25 /
//     ParserConcurrencyLimiter.updateMaxConcurrent 0x1003aae98 L57-59 /
//     acquirePermit 0x1003aaeb4 L61-63 / reportError 0x1003ac1b8 L132-139 /
//     sourcesBackupURL 0x1003accc4 L161-164 / bookSources 初值 0x1003acd54 L79 /
//     init 0x1003bcb1c L191-204（装配体在 0x1003ac788，注释互换确证）/
//     观察者 closure2 0x1003acf0c L197-203 + closure1 0x1003ad05c L198-202 /
//     remoteBackend 初值 0x1003bcba8 L221 / isRemoteMode 0x1003ad080 L212-214 /
//     deleteSource 0x1003ad6bc L224-241 / deleteBookSource 0x1003add78 L244-264 /
//     clearAllSources 0x1003af2b0 L267-286 / toggleBookSource 0x1003af580
//     L289-309 / batchToggleSources 0x1003afbc0 L312-346（MainActor 收尾
//     closure 0x1003b0410 L328-339）/ batchToggleAllSources 0x1003b0520 L349-381 /
//     batchDeleteSources 0x1003b1a80 L384-412（asm_only，汇编兜底）/
//     deleteDisabledSources 0x1003b2808 L412-429 / getSource(byUrl:) 0x1003b2ecc
//     L472-483（匹配谓词 closure 0x1003b6c6c 复用）/ resolveRemoteSourceMetadata
//     0x1003b37bc L500-524 / cacheResolvedRemoteSource 0x1003b5114 L526-532 /
//     mergeRemoteSummaryWithFull 0x1003b4ae8 L534-548 / updateSource 0x1003b5370
//     L553-601（收尾 closure 0x1003b5ce4 L583-596）/ mergeSourceEdits 0x1003b5e30
//     L604-626 / addSource 0x1003b6868 L634-650 / batchUpdateSourceGroup
//     0x1003b6e14 L687-724（收尾 closure 0x1003b7b9c L707-717）/ renameGroup
//     0x1003b7f74 L727-759（远程收尾 closure 0x1003b8538 L746-752）/ mergeGroups
//     0x1003b86d0 L762-797（收尾 closure 0x1003b91ec L781-790 + implicit closure3
//     0x1003bbc88 L771）/ noteRequestedRevision 闭包 0x1001577a4 L808-812 /
//     SaveSerializer.save 0x1003b9880 L828-868
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/SourceService.c（9256 行）
//   - 事实：诊断串 "[配置] 未找到配置: "（toggleBookSource）/
//     "[远程后端] 删除禁用配置失败: "（deleteDisabledSources）/
//     " → storageKind="（getSource 调试行）/ "[配置] 已保存 " + " 字节到文件"
//     （SaveSerializer.save）/ "未分组"（renameGroup 内联小串位确证）/
//     init 装配体字符串池确证四常量："BookSources.json" / "booksources.json" /
//     "LocalBookSources" / "BackupActiveDestination"（二进制 0x12627D0 邻区）/
//     选择子 fileExistsAtPath: / copyItemAtURL:toURL:error: /
//     addObserverForName:object:queue:usingBlock:（NSUserDefaultsDidChangeNotification）
//   - 事实：批量开关跳过 storageKind 字节 == 2（thirdParty）且已同态源；
//     updateSource oldUrl 先 trimmingCharacters(in:) 归一化；
//     SaveSerializer 门禁为"存在更新的请求修订号则跳过本次保存"
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 增删改/分组主链: high（诊断串 + ObservationRegistrar/COW 链确证）
//   - SaveSerializer.save: high（选择子 + 双诊断串确证）
//   - NetworkMonitor/ParserConcurrencyLimiter: medium-high（域确证，队列 label 推断）
//   - batchDeleteSources: medium（asm_only 汇编兜底，依 closure #5/#6 + 签名）
//   - getSource 调试行 75 字节前缀 / mergeRemoteSummaryWithFull 与
//     mergeSourceEdits 字段集: medium（部分字面量未内联，字段集按判定分支推断）
// 还原: 2026-11-20

import Foundation
import Network

/// 网络可达性监控（PGO 成员：monitor/queue/isConnectedState/isConnected）。
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    /// 伪代码 0x1003aa7e0（L13）：utility 优先级队列（label 推断）。
    private let queue = DispatchQueue(
        label: "Leaflow.NetworkMonitor.monitor", qos: .utility)

    private let monitor = NWPathMonitor()

    /// LockedState<Bool>（PGO isConnectedState 变量确证）。
    private let isConnectedState = LockedState(true)

    /// 伪代码 0x1003aab00（L17-19）：弱取 monitor 后比对
    /// NWPath.status == .satisfied。
    var isConnected: Bool {
        monitor.currentPath.status == .satisfied
    }

    /// 伪代码 0x1003ac788（L21-27）：启动监控；路径回调
    ///（0x1003aad50 L22-25）把 satisfied 写入 isConnectedState。
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            self?.isConnectedState.value = satisfied
        }
        monitor.start(queue: queue)
    }
}

/// 解析并发限制器（updateMaxConcurrent/acquirePermit 域确证）。
final class ParserConcurrencyLimiter {

    static let shared = ParserConcurrencyLimiter()

    private let gate = AsyncPermitGate(maxConcurrent: 4)
    private var maxConcurrent = 4

    /// 伪代码 0x1003aae98（L57-59）：转发闸门更新。
    func updateMaxConcurrent(_ value: Int) async {
        maxConcurrent = max(1, value)
    }

    /// 伪代码 0x1003aaeb4（L61-63）：AsyncPermitGate 域获取许可。
    func acquirePermit() async throws -> AsyncPermitGate.Permit {
        gate.acquire()
    }

    /// pgo_only（签名确证）：快照。AsyncPermitGate.Snapshot 随 T-208 分册交叉。
    func snapshot() async -> AsyncPermitGate.Snapshot {
        gate.snapshot()
    }
}

/// 书源服务（增删改/分组/远程摘要主链；存储域在 +Storage 扩展）。
final class SourceService: SourceServiceProtocol, ObservableObject {

    /// 伪代码 0x1003acd54（L79）：初值表达式（ObservationRegistrar 域确证）。
    @Published private(set) var bookSources: [BookSource] = []

    /// PGO rssSources 变量确证。
    @Published private(set) var rssSources: [RssSource] = []

    /// PGO isLoading / isLoadingSources / hasLoadedOnce 变量确证。
    private(set) var isLoading = false
    private(set) var isLoadingSources = false
    private var hasLoadedOnce = false

    /// 本地保存版本对（PGO 变量确证；registerPendingLocalSave/
    /// finishPendingLocalSave 消费，实现见 +Storage 扩展）。
    private(set) var localSaveRequestedRevision = 0
    private var localSaveCompletedRevision = 0

    /// 待持久化快照（registerPendingLocalSave 登记、finishPendingLocalSave 消费）。
    var pendingLocalSaveSnapshot: (sources: [BookSource], revision: Int)?

    /// 防抖保存任务（scheduleSave 持有；300ms 睡眠块体确证）。
    var pendingSaveTask: Task<Void, Never>?

    /// 解析器族（PGO 变量确证）。
    let parserLimiter = ParserConcurrencyLimiter()
    let localParser = LocalSourceParser()
    let saveSerializer = SaveSerializer()

    /// 伪代码 0x1003bcba8（L221）：远程后端初值表达式。
    let remoteBackend = RemoteBackendService()

    /// url 双索引（PGO sourceIndex/sourceUrlIndex 变量确证）。
    private var sourceIndex: [String: BookSource] = [:]
    private var sourceUrlIndex: [String: BookSource] = [:]

    /// 存储文件名（init 装配体字符串池确证："BookSources.json" /
    /// "booksources.json"；键 "LocalBookSources" / "BackupActiveDestination"）。
    private let sourcesFileName = "BookSources.json"
    private let sourcesBackupName = "booksources.json"
    private let legacySourcesCacheKey = "LocalBookSources"

    /// 通知名（字符串池 "sourcesDidChange" 确证；post 点待 +Storage 交叉）。
    static let sourcesDidChangeNotification =
        Notification.Name("sourcesDidChange")

    /// sourcesFileURL（pgo_only）：文档目录 + sourcesFileName。
    var sourcesFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent(sourcesFileName)
    }

    /// 伪代码 0x1003accc4（L161-164）：备份 URL（文档目录 + sourcesBackupName）。
    var sourcesBackupURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent(sourcesBackupName)
    }

    /// 伪代码 0x1003ac1b8（L132-139）：错误分类上报
    ///（classifyNetworkError 消费确证，实现见 +Parsing）。
    @discardableResult
    func reportError(_ error: Error, context: String?) -> AppError {
        let appError = SourceService.classifyNetworkError(error)
        Logger.error(
            appError.errorDescription ?? "未知错误",
            context: context ?? "-")
        return appError
    }

    /// 伪代码 0x1003bcb1c（L191-204）：主块仅剩计数桩；装配体在 0x1003ac788
    ///（注释互换确证）：装配 ParserConcurrencyLimiter/SaveSerializer 依赖并注册
    /// NSUserDefaultsDidChangeNotification 观察者
    ///（addObserverForName:object:queue:usingBlock: 选择子确证）。
    init() {
        NotificationCenter.default.addObserver(
            forName: NSUserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // closure2（0x1003acf0c L197-203）：弱取 self，存活则派发 Task；
            // closure1（0x1003ad05c L198-202）转发内部重载 thunk。
            guard let self = self else { return }
            Task { await self.handleSettingsChange() }
        }
    }

    /// 观察者终点（closure1 0x1003ad05c → 内部 thunk，体未展开）：
    /// 设置变更后的重载/同步入口（推断）。
    private func handleSettingsChange() async {
        guard hasLoadedOnce else { return }
        await loadLocalSources()
    }

    // MARK: 域判定

    /// 伪代码 0x1003ad080（L212-214）：远程模式判定。
    func isRemoteMode(for source: BookSource) -> Bool {
        source.storageKind == .remote
    }

    /// pgo_only（签名确证；字节序 local/remote/thirdParty 推断一致）。
    func isStorageRemote(for source: BookSource) -> Bool {
        source.storageKind == .remote
    }

    // MARK: 删除族

    /// 伪代码 0x1003ad6bc（L224-241）：同步入队待删源；真正移除+保存延迟到
    /// 异步 thunk（sub_1003AD730，与 deleteBookSource(url:) 同路径）。
    func deleteSource(_ source: BookSource) {
        let url = source.bookSourceUrl
        Task { [weak self] in
            _ = await self?.deleteBookSource(url: url)
        }
    }

    /// 伪代码 0x1003add78（L244-264）：按 url 匹配移除（COW + 观察者通知），
    /// 命中后走保存触发器（closure #4 in importSourcesAsync 域确证）；
    /// 返回 true = 已删除，false = 无此 url。
    func deleteBookSource(url: String) async -> Bool {
        let before = bookSources.count
        bookSources.removeAll { $0.bookSourceUrl == url }
        guard bookSources.count != before else { return false }
        scheduleSave()
        return true
    }

    /// 伪代码 0x1003af2b0（L267-286）：取消挂起保存、清空内存数组、
    /// 空数组原子写盘（options=1 即 .atomic）并触发保存收尾。
    func clearAllSources() {
        pendingSaveTask?.cancel()
        bookSources = []
        let data = try? JSONEncoder().encode([BookSource]())
        if let data = data {
            try? data.write(to: sourcesFileURL, options: .atomic)
        }
        scheduleSave()
    }

    /// 伪代码 0x1003af580（L289-309）："[配置] 未找到配置: " 诊断串确证；
    /// 命中改写 enabled，remote 域走 MainActor Task、本地走保存收尾。
    @discardableResult
    func toggleBookSource(url: String, enable: Bool) -> Bool {
        guard let index = bookSources.firstIndex(where: {
            $0.bookSourceUrl == url
        }) else {
            Logger.log("[配置] 未找到配置: \(url)", level: .info)
            return false
        }
        bookSources[index].enabled = enable
        if bookSources[index].storageKind == .remote {
            // MainActor 收尾任务（&unk_10133EC98 域，体未展开；
            // 持久化统一由 finishPendingLocalSave 承接）。
            Task { finishPendingLocalSave(revision: localSaveRequestedRevision) }
        } else {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return true
    }

    /// 伪代码 0x1003afbc0（L312-346；MainActor 收尾 closure 0x1003b0410）：
    /// 命中 urls 集合的源改写 enabled 并计数，有改动即收尾；返回改写数。
    @discardableResult
    func batchToggleSources(urls: Set<String>, enable: Bool) -> Int {
        var changed = 0
        for index in bookSources.indices
        where urls.contains(bookSources[index].bookSourceUrl) {
            bookSources[index].enabled = enable
            changed += 1
        }
        if changed > 0 {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return changed
    }

    /// 伪代码 0x1003b0520（L349-381；收尾 closure 0x1003b0b0c L363-374）：
    /// 全量开关；跳过 storageKind 字节 == 2（thirdParty）与已同态源；
    /// remote 域收集 url（closure #2）异步同步；返回改写数。
    @discardableResult
    func batchToggleAllSources(enable: Bool) -> Int {
        var changed = 0
        var remoteUrls: [String] = []
        for index in bookSources.indices {
            let source = bookSources[index]
            if source.storageKind == .thirdParty { continue }
            if source.enabled == enable { continue }
            bookSources[index].enabled = enable
            changed += 1
            if source.storageKind == .remote {
                remoteUrls.append(source.bookSourceUrl)
            }
        }
        if changed > 0 {
            // MainActor 收尾（&unk_10133EC48 域）+ 有未同步项即 finishPendingLocalSave。
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return changed
    }

    /// 伪代码 0x1003b1a80（L384-412）：主流程 asm_only（汇编兜底，无 Hex-Rays
    /// 块）；语义依签名 + closure #5（url 提取 0x1003bc3b8）+ closure #6
    ///（过滤谓词 0x1003b1f3c，1400B 步长）还原：移除命中 urls 的源并返回删除数。
    func batchDeleteSources(urls: Set<String>) async -> Int {
        let before = bookSources.count
        bookSources.removeAll { urls.contains($0.bookSourceUrl) }
        let removed = before - bookSources.count
        if removed > 0 {
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return removed
    }

    /// 伪代码 0x1003b2808（L412-429）：谓词过滤禁用源并原地压缩，返回删除数；
    /// 远程同步失败 catch 记录 "[远程后端] 删除禁用配置失败: "（诊断串确证）。
    func deleteDisabledSources() async -> Int {
        let before = bookSources.count
        bookSources.removeAll { !$0.enabled }
        let removed = before - bookSources.count
        if removed > 0 {
            do {
                // 远程域同步（伪代码 catch 路径确证；远程调用体未展开，
                // 随 RemoteBackendService 分册交叉）。
                try await syncDisabledSourceRemoval(count: removed)
            } catch {
                Logger.log(
                    "[远程后端] 删除禁用配置失败: \(error.localizedDescription)",
                    level: .error)
            }
            finishPendingLocalSave(revision: localSaveRequestedRevision)
        }
        return removed
    }

    /// 远程同步占位（诊断串确证；调用体未展开，待 RemoteBackendService 分册）。
    private func syncDisabledSourceRemoval(count: Int) async throws {}

    // MARK: 查找族

    /// 伪代码 0x1003b2ecc（L472-483）：内存按 bookSourceUrl 查找；
    /// 未命中走远程缓存摘要回退并打调试行（" → storageKind=" 与
    /// ", has searchUrl=" 小串位确证；75 字节前缀文本未内联，措辞推断）。
    func getSource(byUrl url: String) -> BookSource? {
        if let hit = bookSources.first(where: { $0.bookSourceUrl == url }) {
            return hit
        }
        let cached = remoteBackend.loadCachedRemoteSources()
        if let hit = cached.first(where: { $0.bookSourceUrl == url }) {
            return hit
        }
        let truncated = String(url.prefix(60))
        Logger.log(
            "[配置] 未命中源: \(truncated) → storageKind=-, has searchUrl=false",
            level: .debug)
        return nil
    }

    /// pgo_only（签名确证）：id 即 bookSourceUrl（0x1002332a4 确证）。
    func getSource(byId id: String) -> BookSource? {
        getSource(byUrl: id)
    }

    /// pgo_only（签名确证）：按存储类别过滤查找。
    func getSource(byUrl url: String, storageKind: StorageKind) -> BookSource? {
        bookSources.first(where: {
            $0.bookSourceUrl == url && $0.storageKind == storageKind
        })
    }

    /// 伪代码 0x1003b37bc（L500-524）：复用 getSource 匹配谓词
    ///（closure 0x1003b6c6c 域）定位源并整源克隆，走远程元数据解析。
    func resolveRemoteSourceMetadata(for source: BookSource) async -> BookSource {
        if let hit = bookSources.first(where: {
            $0.bookSourceUrl == source.bookSourceUrl
        }) {
            return hit
        }
        let cached = remoteBackend.loadCachedRemoteSources()
        if let hit = cached.first(where: {
            $0.bookSourceUrl == source.bookSourceUrl
        }) {
            return hit
        }
        return source
    }

    /// 伪代码 0x1003b5114（L526-532）：仅对 .remote 生效——按 url 原地替换
    /// 解析后的完整源，并转发 RemoteBackendService 缓存
    ///（cacheResolvedRemoteSource 调用确证，随其分册落地）。
    func cacheResolvedRemoteSource(_ source: BookSource) {
        guard source.storageKind == .remote else { return }
        if let index = bookSources.firstIndex(where: {
            $0.bookSourceUrl == source.bookSourceUrl
        }) {
            bookSources[index] = source
        }
    }

    /// 伪代码 0x1003b4ae8（L534-548）：full 为底，summary 仅回填其空/nil 字段
    ///（字符串非空判定 + Optional nil 判定确证；字段集按判定分支推断）。
    static func mergeRemoteSummary(
        summary: BookSource, full: BookSource
    ) -> BookSource {
        var merged = full
        if merged.bookSourceName.isEmpty {
            merged.bookSourceName = summary.bookSourceName
        }
        if (merged.bookSourceGroup ?? "").isEmpty {
            merged.bookSourceGroup = summary.bookSourceGroup
        }
        if (merged.loginUrl ?? "").isEmpty {
            merged.loginUrl = summary.loginUrl
        }
        if (merged.coverDecodeUrl ?? "").isEmpty {
            merged.coverDecodeUrl = summary.coverDecodeUrl
        }
        return merged
    }

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
            try manager.copyItem(at: fileURL, to: backupURL)
        }
        try data.write(to: fileURL, options: .atomic)
        Logger.log("[配置] 已保存 \(data.count) 字节到文件", level: .info)
    }
}
