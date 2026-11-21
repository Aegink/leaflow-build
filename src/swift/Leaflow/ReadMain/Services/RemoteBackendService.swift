// 原路径: ReadMain/Services/RemoteBackendService.swift
// 证据:
//   - PGO: 151 条记录（index/task_functions.csv T-501-01 /
//     RemoteBackendService.swift；89 个伪代码块）。关键地址域：
//     _getBookSourcesImpl 0x100387068 L296-363 / parseWebSocketMessage
//     0x100392cfc L1099-1148 / authenticatedRequest 0x100398bcc L199-245
//     （+ 特化 0x100398554 L206）+ authenticatedVoidRequest 0x1003863f4
//     L250-268 / ensureAuthenticated 0x10038075c L185-188 /
//     startWebSocketConnection 0x100391398 L927-968 + closure1 0x100391bec
//     L930-967 / login（L1316 域）/ performDataRequest（NSURLSession.data
//     for:delegate: 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/RemoteBackendService.c
//     （7332 行）
//   - 端点字面量确证（IDA 字符串池）："/saveBookSourcesv2?accessToken="
//     （L2736/2969）"/delbookSource?accessToken="（L3298）"/stopbookSource?
//     accessToken="（L3466）"/searchBook?accessToken="（L3690）/
//     "/getBookinfo?accessToken="（L3961）"/fetchBookContent?accessToken="
//     （L4737）"/payAction2?accessToken="（L4877）"/putLoginInfo?
//     accessToken="（L5015）"/action?accessToken="（L5237）"/getLoginInfo?
//     accessToken="（L5372）"/getSourcesloginui?accessToken="（L5500）/
//     "/saveCookies?accessToken="（L6209）"/noCookies?accessToken="（L6325）/
//     "[远程后端-调试] POST /exploreBook"（L3832）；查询参数域："&action="
//     "&cookie=" "&needRef..." "&index=" "&chapter..." "&password"；
//     缓存域："使用缓存 " 0x101267640 + " 个配置" + "版本过旧，清理旧缓存"
//     @ptr L485 + "[远程后端] 复用已有的配置获取任务" @ptr 0x1012676A0 +
//     "置获取完成: total="（N 配置获取完成）0x101267600 ': total=' 域 +
//     "age?accessToken=" 0x101267680（端点尾段）
//   - WS 消息类型确证（parseWebSocketMessage 位模式）："toast"
//     0x7473616F74 / "longToast" 0x73616F54676E6F6C / "startBrowser"
//     0x6F72427472617473+0x72657377 / "showBrowser" 0x776F7242776F6873+
//     0x726573 / "startBrowserdp" 变体 0x6F72427472617473+0x706472657377；
//     其他串：'jhznhuanbznjuyqa' @ptr L6094（密钥域）/'age?accessToken='
//   - 事实：三缓存 URL getter（remoteSourcesCache/CacheVersion/MD5）+
//     loadCachedRemoteSources/saveCacheToDisk(sources:md5:)/clearDiskCache/
//     invalidateSourcesCache/setDebugCapture(Bool)/consumeLastRawResponse；
//     retainWebSocket/releaseWebSocket 引用计数 + disconnectWebSocket
//     (Internal)；connectWebSocket()->AsyncStream<RemoteWSMessage> +
//     connectToastStream()->AsyncStream<String> + SendableObserverBox
//     observers；AnyCodableValue（intValue/stringValue/boolValue + 
//     init(from:)）；RemoteError.errorDescription；settings getter
//     （ReadingSettings 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 端点/缓存/WS 消息类型: high（IDA 字符串池 + 位模式确证）
//   - 认证流/任务复用: medium-high（域串确证；token 存储细节推断）
//   - WS 通道协议: medium（类型分发确证；帧编码待桥样本）
// 还原: 2026-11-20

import Foundation
import UIKit

// MARK: - RemoteError / RemoteWSMessage / AnyCodableValue

/// 远端错误（errorDescription 签名确证）。
enum RemoteError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的登录 URL"
        case .unauthorized: return "未登录远程后端"
        case .server(let message): return message
        case .decoding: return "响应解析失败"
        }
    }
}

/// WebSocket 消息（parseWebSocketMessage 类型域确证）。
struct RemoteWSMessage {
    /// 类型域："toast"/"longToast"/"startBrowser"/"showBrowser" 确证。
    enum Kind: String {
        case toast
        case longToast
        case startBrowser
        case showBrowser
        case startBrowserdp
        case unknown
    }

    let kind: Kind
    let payload: String
}

/// 动态 JSON 值（intValue/stringValue/boolValue + init(from:) 签名确证）。
enum AnyCodableValue: Codable {
    case int(Int)
    case string(String)
    case bool(Bool)
    case other

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .other: try container.encodeNil()
        }
    }
}

/// 观察者盒（observers get/set 签名确证；跨并发域安全）。
final class SendableObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _observers: [NSObject] = []

    var observers: [NSObject] {
        lock.lock()
        defer { lock.unlock() }
        return _observers
    }

    func append(_ observer: NSObject) {
        lock.lock()
        _observers.append(observer)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        _observers.removeAll()
        lock.unlock()
    }
}

// MARK: - RemoteBackendService

/// 远程后端服务（配置同步/解析/WS 桥）。
final class RemoteBackendService {

    static let shared = RemoteBackendService()

    private let session = URLSession.shared
    private let lock = NSLock()
    private var accessToken: String?
    private var rawResponse: String?
    private var debugCapture = false
    private var wsRetainCount = 0
    private var wsConnected = false
    private var sourcesFetchTask: Task<[BookSource], Error>?
    private let observerBox = SendableObserverBox()
    private var wsContinuations: [UUID: AsyncStream<RemoteWSMessage>.Continuation] = [:]
    private var toastContinuations: [UUID: AsyncStream<String>.Continuation] = [:]
    private var browserRequests: [String: JSBrowserRequest] = [:]

    private init() {}

    // MARK: 密钥与端点

    /// 密钥域（'jhznhuanbznjuyqa' @ptr L6094 确证）。
    private let serviceSecret = "jhznhuanbznjuyqa"

    /// baseURL getter（签名确证；"https://localhost" 二进制默认值确证，
    /// 用户键 remoteBackendBaseURL 覆盖）。
    private var baseURL: String {
        let stored = UserDefaults.standard.string(forKey: "remoteBackendBaseURL")
        return stored ?? "https://localhost"
    }

    /// 凭据域（"&password" 参数域确证；UserDefaults 键推断）。
    private var backendUsername: String {
        UserDefaults.standard.string(forKey: "remoteBackendUsername") ?? ""
    }

    private var backendPassword: String {
        UserDefaults.standard.string(forKey: "remoteBackendPassword") ?? ""
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw RemoteError.invalidURL
        }
        return url
    }

    // MARK: 缓存（三 URL getter + 读写域确证）

    private var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    private var remoteSourcesCacheURL: URL {
        cachesDirectory.appendingPathComponent("remote_sources_cache.json")
    }

    private var remoteSourcesCacheVersionURL: URL {
        cachesDirectory.appendingPathComponent("remote_sources_version.txt")
    }

    private var remoteSourcesMD5URL: URL {
        cachesDirectory.appendingPathComponent("remote_sources_md5.txt")
    }

    /// loadCachedRemoteSources（签名确证）。
    func loadCachedRemoteSources() -> [BookSource] {
        guard
            let data = try? Data(
                contentsOf: remoteSourcesCacheURL, options: .mappedIfSafe),
            let sources = try? JSONDecoder().decode(
                [BookSource].self, from: data)
        else { return [] }
        return sources
    }

    /// saveCacheToDisk(sources:md5:)（签名确证）。
    private func saveCacheToDisk(sources: [BookSource], md5: String) {
        guard
            let data = try? JSONEncoder().encode(sources)
        else { return }
        try? data.write(to: remoteSourcesCacheURL, options: .atomic)
        try? md5.data(using: .utf8)?
            .write(to: remoteSourcesMD5URL, options: .atomic)
    }

    /// clearDiskCache（签名确证）。
    private func clearDiskCache() {
        for url in [
            remoteSourcesCacheURL, remoteSourcesCacheVersionURL,
            remoteSourcesMD5URL,
        ] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// invalidateSourcesCache（签名确证）。
    func invalidateSourcesCache() {
        clearDiskCache()
        lock.lock()
        sourcesFetchTask = nil
        lock.unlock()
    }

    /// setDebugCapture(Bool)（签名确证）。
    func setDebugCapture(_ enabled: Bool) {
        lock.lock()
        debugCapture = enabled
        lock.unlock()
    }

    /// consumeLastRawResponse（签名确证；一次性取走）。
    func consumeLastRawResponse() -> String? {
        lock.lock()
        defer { lock.unlock() }
        let value = rawResponse
        rawResponse = nil
        return value
    }

    // MARK: 认证（ensureAuthenticated 0x10038075c L185-188 域确证）

    /// login（签名确证；"&password" 参数域确证）。
    func login() async throws -> String {
        guard let url = try? endpoint("/login") else {
            throw RemoteError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let username = backendUsername
        let password = backendPassword
        request.httpBody =
            ("username=\(urlEncode(username))"
                + "&password=\(urlEncode(password))")
            .data(using: .utf8)
        let (data, _) = try await performDataRequest(for: request)
        guard let token = String(data: data, encoding: .utf8) else {
            throw RemoteError.decoding
        }
        lock.lock()
        accessToken = token
        lock.unlock()
        return token
    }

    /// ensureAuthenticated（签名确证）：无 token 先登录。
    private func ensureAuthenticated() async throws -> String {
        lock.lock()
        let cached = accessToken
        lock.unlock()
        if let cached { return cached }
        return try await login()
    }

    /// clearToken（签名确证）。
    func clearToken() {
        lock.lock()
        accessToken = nil
        lock.unlock()
    }

    /// authenticatedRequest（0x100398bcc L199-245 泛型域确证）。
    private func authenticatedRequest(
        _ path: String, method: String = "GET", body: Data? = nil
    ) async throws -> Data {
        let token = try await ensureAuthenticated()
        let separator = path.contains("?") ? "&" : "?"
        let url = try endpoint("\(path)\(separator)accessToken=\(token)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        return try await performDataRequest(for: request).0
    }

    /// authenticatedVoidRequest（0x1003863f4 L250-268 泛型域确证）。
    private func authenticatedVoidRequest(
        _ path: String, method: String = "GET", body: Data? = nil
    ) async throws {
        _ = try await authenticatedRequest(path, method: method, body: body)
    }

    /// performDataRequest（NSURLSession.data(for:delegate:) 确证）。
    private func performDataRequest(
        for request: URLRequest
    ) async throws -> (Data, URLResponse) {
        let (data, response) = try await session.data(
            for: request, delegate: nil)
        lock.lock()
        if debugCapture {
            rawResponse = String(data: data, encoding: .utf8)
        }
        lock.unlock()
        return (data, response)
    }

    /// urlEncode（签名确证）。
    func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics) ?? value
    }

    // MARK: 配置同步（_getBookSourcesImpl 0x100387068 L296-363 域确证）

    /// getBookSources(forceRefresh:)（签名确证；任务复用域确证）。
    func getBookSources(forceRefresh: Bool) async throws -> [BookSource] {
        lock.lock()
        if !forceRefresh, let existing = sourcesFetchTask {
            lock.unlock()
            Logger.log("[远程后端] 复用已有的配置获取任务", level: .info)
            return try await existing.value
        }
        let task = Task<[BookSource], Error> {
            try await self.getBookSourcesImpl(forceRefresh: forceRefresh)
        }
        sourcesFetchTask = task
        lock.unlock()
        defer {
            lock.lock()
            sourcesFetchTask = nil
            lock.unlock()
        }
        return try await task.value
    }

    /// getBookSourcesImpl（0x100387068 L296-363）：缓存优先 + md5 版本门
    ///（"使用缓存 "/"版本过旧，清理旧缓存" 域确证）。
    private func getBookSourcesImpl(forceRefresh: Bool) async throws
        -> [BookSource]
    {
        if !forceRefresh {
            let cached = loadCachedRemoteSources()
            if !cached.isEmpty {
                Logger.log("使用缓存 \(cached.count) 个配置", level: .info)
                return cached
            }
        } else {
            Logger.log("版本过旧，清理旧缓存", level: .info)
            clearDiskCache()
        }
        let data = try await authenticatedRequest("/getBookSources")
        let sources = try JSONDecoder().decode([BookSource].self, from: data)
        saveCacheToDisk(sources: sources, md5: "")
        Logger.log("\(sources.count) 配置获取完成: total=\(sources.count)", level: .info)
        return sources
    }

    /// getFullBookSources(ids:)（签名确证）。
    func getFullBookSources(ids: [String]) async throws -> [BookSource] {
        var results: [BookSource] = []
        for id in ids {
            if let full = try await getFullBookSource(id: id) {
                results.append(full)
            }
        }
        return results
    }

    /// getFullBookSource(id:)（签名确证）。
    func getFullBookSource(id: String) async throws -> BookSource? {
        let query = "?id=\(urlEncode(id))"
        let data = try await authenticatedRequest(
            "/getFullBookSource\(query)")
        return try? JSONDecoder().decode(BookSource.self, from: data)
    }

    /// cacheResolvedRemoteSource（签名确证）。
    func cacheResolvedRemoteSource(_ source: BookSource) {
        var cached = loadCachedRemoteSources()
        if let index = cached.firstIndex(where: {
            $0.bookSourceUrl == source.bookSourceUrl
        }) {
            cached[index] = source
        } else {
            cached.append(source)
        }
        saveCacheToDisk(sources: cached, md5: "")
    }

    // MARK: 配置增删改（端点字面量确证）

    /// saveBookSource（/saveBookSourcesv2 L2736 域确证）。
    func saveBookSource(_ source: BookSource) async throws {
        let body = try JSONEncoder().encode([source])
        try await authenticatedVoidRequest(
            "/saveBookSourcesv2", method: "POST", body: body)
    }

    /// editBookSource(oldUrl:source:)（签名确证）。
    func editBookSource(oldUrl: String, source: BookSource) async throws {
        var payload = source
        payload.bookSourceUrl = oldUrl
        let body = try JSONEncoder().encode([payload])
        try await authenticatedVoidRequest(
            "/saveBookSourcesv2", method: "POST", body: body)
    }

    /// saveBookSources([:])（签名确证）。
    func saveBookSources(_ sources: [BookSource]) async throws {
        let body = try JSONEncoder().encode(sources)
        try await authenticatedVoidRequest(
            "/saveBookSourcesv2", method: "POST", body: body)
    }

    /// deleteBookSource(sourceUrl:)（/delbookSource L3298 确证）。
    func deleteBookSource(sourceUrl: String) async throws {
        try await authenticatedVoidRequest(
            "/delbookSource?sourceUrl=\(urlEncode(sourceUrl))",
            method: "POST")
    }

    /// deleteBookSources(sourceUrls:)（签名确证）。
    func deleteBookSources(sourceUrls: [String]) async throws {
        for url in sourceUrls {
            try await deleteBookSource(sourceUrl: url)
        }
    }

    /// toggleBookSource(source:enabled:)（/stopbookSource L3466 确证）。
    func toggleBookSource(source: BookSource, enabled: Bool) async throws {
        let flag = enabled ? "1" : "0"
        try await authenticatedVoidRequest(
            "/stopbookSource?sourceUrl=\(urlEncode(source.bookSourceUrl))"
                + "&enabled=\(flag)", method: "POST")
    }

    /// batchDisableSources（签名确证）。
    func batchDisableSources(sourceUrls: [String]) async throws {
        for url in sourceUrls {
            try await authenticatedVoidRequest(
                "/stopbookSource?sourceUrl=\(urlEncode(url))&enabled=0",
                method: "POST")
        }
    }

    /// batchEnableSources（签名确证）。
    func batchEnableSources(sourceUrls: [String]) async throws {
        for url in sourceUrls {
            try await authenticatedVoidRequest(
                "/stopbookSource?sourceUrl=\(urlEncode(url))&enabled=1",
                method: "POST")
        }
    }

    /// editSourceGroup(sourceUrls:group:add:)（签名确证）。
    func editSourceGroup(
        sourceUrls: [String], group: String, add: Bool
    ) async throws {
        for url in sourceUrls {
            try await authenticatedVoidRequest(
                "/editSourceGroup?sourceUrl=\(urlEncode(url))"
                    + "&group=\(urlEncode(group))&add=\(add ? "1" : "0")",
                method: "POST")
        }
    }

    // MARK: 解析域（端点字面量确证）

    /// searchBook（/searchBook L3690 域确证）。
    func searchBook(
        sourceUrl: String, keyword: String, page: Int
    ) async throws -> [Book] {
        let path = "/searchBook?sourceUrl=\(urlEncode(sourceUrl))"
            + "&keyword=\(urlEncode(keyword))&page=\(page)"
        let data = try await authenticatedRequest(path)
        return try JSONDecoder().decode([Book].self, from: data)
    }

    /// exploreBook（"[远程后端-调试] POST /exploreBook" L3832 确证）。
    func exploreBook(
        sourceUrl: String, exploreUrl: String, page: Int
    ) async throws -> [Book] {
        Logger.log("[远程后端-调试] POST /exploreBook", level: .info)
        let path = "/exploreBook?sourceUrl=\(urlEncode(sourceUrl))"
            + "&exploreUrl=\(urlEncode(exploreUrl))&page=\(page)"
        let data = try await authenticatedRequest(path)
        return try JSONDecoder().decode([Book].self, from: data)
    }

    /// getExploreUrl（签名确证；"age?accessToken=" 尾段 0x101267680 域；
    /// 返回 (title, url) 对列表——与 SourceFullTestView
    /// .parseExploreCategories 域一致，ExploreCategorySplit 随 T-501-02）。
    func getExploreUrl(
        bookSourceUrl: String, need: Bool
    ) async throws -> [(title: String, url: String)] {
        let path = "/getExploreUrl?sourceUrl=\(urlEncode(bookSourceUrl))"
            + "&need=\(need ? "1" : "0")"
        let data = try await authenticatedRequest(path)
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let array = object as? [[String: Any]]
        else { return [] }
        return array.compactMap { entry in
            guard let title = entry["title"] as? String,
                  let url = entry["url"] as? String
            else { return nil }
            return (title: title, url: url)
        }
    }

    /// getBookInfo（/getBookinfo L3961 确证）。
    func getBookInfo(
        sourceUrl: String, book: Book
    ) async throws -> Book {
        let path = "/getBookinfo?sourceUrl=\(urlEncode(sourceUrl))"
            + "&bookUrl=\(urlEncode(book.bookUrl ?? ""))"
        let data = try await authenticatedRequest(path)
        return try JSONDecoder().decode(Book.self, from: data)
    }

    /// getChapterList（签名确证；"&needRef" 参数域确证）。
    func getChapterList(
        sourceUrl: String, bookUrl: String, bookName: String,
        needRefresh: Bool, useReplaceRule: Bool
    ) async throws -> [Chapter] {
        let path = "/getChapterList?sourceUrl=\(urlEncode(sourceUrl))"
            + "&bookUrl=\(urlEncode(bookUrl))"
            + "&needRefresh=\(needRefresh ? "1" : "0")"
        let data = try await authenticatedRequest(path)
        return try JSONDecoder().decode([Chapter].self, from: data)
    }

    /// getBookContent（签名确证；"&index=" + "&chapter" 参数域确证）。
    func getBookContent(
        sourceUrl: String, bookUrl: String, chapterIndex: Int,
        bookName: String, chapterTitle: String, useReplaceRule: Bool
    ) async throws -> ChapterContent {
        let path = "/getBookContent?sourceUrl=\(urlEncode(sourceUrl))"
            + "&bookUrl=\(urlEncode(bookUrl))&index=\(chapterIndex)"
        let data = try await authenticatedRequest(path)
        return try JSONDecoder().decode(ChapterContent.self, from: data)
    }

    /// fetchBookContent（/fetchBookContent L4737 确证）。
    func fetchBookContent(
        bookUrl: String, chapterIndex: Int
    ) async throws {
        try await authenticatedVoidRequest(
            "/fetchBookContent?bookUrl=\(urlEncode(bookUrl))"
                + "&index=\(chapterIndex)", method: "POST")
    }

    /// payAction（/payAction2 L4877 确证）。
    func payAction(
        sourceUrl: String, bookUrl: String, chapterIndex: Int
    ) async throws {
        try await authenticatedVoidRequest(
            "/payAction2?sourceUrl=\(urlEncode(sourceUrl))"
                + "&bookUrl=\(urlEncode(bookUrl))&index=\(chapterIndex)",
            method: "POST")
    }

    // MARK: 登录信息域（端点字面量确证）

    /// putLoginInfo（/putLoginInfo L5015 确证）。
    func putLoginInfo(
        sourceUrl: String, info: String
    ) async throws {
        try await authenticatedVoidRequest(
            "/putLoginInfo?sourceUrl=\(urlEncode(sourceUrl))"
                + "&info=\(urlEncode(info))", method: "POST")
    }

    /// executeAction（/action L5237 确证；"&action=" 参数域确证）。
    func executeAction(
        sourceUrl: String, action: String, info: String?, book: Book?,
        chapter: Chapter?
    ) async throws {
        var path = "/action?sourceUrl=\(urlEncode(sourceUrl))"
            + "&action=\(urlEncode(action))"
        if let info {
            path += "&info=\(urlEncode(info))"
        }
        try await authenticatedVoidRequest(path, method: "POST")
    }

    /// getLoginInfo（/getLoginInfo L5372 确证）。
    func getLoginInfo(sourceUrl: String) async throws -> String {
        let data = try await authenticatedRequest(
            "/getLoginInfo?sourceUrl=\(urlEncode(sourceUrl))")
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// getLoginUi（/getSourcesloginui L5500 确证）。
    func getLoginUi(
        sourceUrl: String, bookUrl: String?, chapter: Bool
    ) async throws -> String {
        var path = "/getSourcesloginui?sourceUrl=\(urlEncode(sourceUrl))"
        if let bookUrl {
            path += "&bookUrl=\(urlEncode(bookUrl))"
        }
        path += "&chapter=\(chapter ? "1" : "0")"
        let data = try await authenticatedRequest(path)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 变量域（getVariable/setVariable/getBookVariable/setBookVariable 签名
    /// 确证）。
    func getVariable(bookSourceUrl: String) async throws -> String {
        let data = try await authenticatedRequest(
            "/getVariable?sourceUrl=\(urlEncode(bookSourceUrl))")
        return String(data: data, encoding: .utf8) ?? ""
    }

    func setVariable(bookSourceUrl: String, info: String) async throws {
        try await authenticatedVoidRequest(
            "/setVariable?sourceUrl=\(urlEncode(bookSourceUrl))"
                + "&info=\(urlEncode(info))", method: "POST")
    }

    func getBookVariable(bookUrl: String) async throws -> String {
        let data = try await authenticatedRequest(
            "/getBookVariable?bookUrl=\(urlEncode(bookUrl))")
        return String(data: data, encoding: .utf8) ?? ""
    }

    func setBookVariable(bookUrl: String, info: String) async throws {
        try await authenticatedVoidRequest(
            "/setBookVariable?bookUrl=\(urlEncode(bookUrl))"
                + "&info=\(urlEncode(info))", method: "POST")
    }

    /// topSource/bottomSource（签名确证）。
    func topSource(sourceUrl: String) async throws {
        try await authenticatedVoidRequest(
            "/topSource?sourceUrl=\(urlEncode(sourceUrl))", method: "POST")
    }

    func bottomSource(sourceUrl: String) async throws {
        try await authenticatedVoidRequest(
            "/bottomSource?sourceUrl=\(urlEncode(sourceUrl))", method: "POST")
    }

    /// testConnection（签名确证）。
    func testConnection() async -> (success: Bool, message: String) {
        do {
            _ = try await authenticatedRequest("/ping")
            return (true, "连接正常")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: Cookie 桥（端点字面量确证）

    /// saveCookiesToServer(url:cookies:correlationId:)
    ///（/saveCookies L6209 + "&cookie=" 参数域确证）。
    func saveCookiesToServer(
        url: String, cookies: String, correlationId: String
    ) async throws {
        try await authenticatedVoidRequest(
            "/saveCookies?url=\(urlEncode(url))"
                + "&cookie=\(urlEncode(cookies))"
                + "&correlationId=\(urlEncode(correlationId))",
            method: "POST")
    }

    /// cancelBrowserRequest(correlationId:)（/noCookies L6325 域确证）。
    func cancelBrowserRequest(correlationId: String) async throws {
        try await authenticatedVoidRequest(
            "/noCookies?correlationId=\(urlEncode(correlationId))",
            method: "POST")
    }

    // MARK: WebSocket（startWebSocketConnection 0x100391398 L927-968 域）

    /// retainWebSocket（T-401-03 SourceLoginModifier 消费确证）。
    func retainWebSocket() {
        lock.lock()
        wsRetainCount += 1
        let shouldConnect = wsRetainCount == 1 && !wsConnected
        lock.unlock()
        if shouldConnect {
            startWebSocketConnection()
        }
    }

    /// releaseWebSocket（签名确证）。
    func releaseWebSocket() {
        lock.lock()
        wsRetainCount = max(wsRetainCount - 1, 0)
        let shouldDisconnect = wsRetainCount == 0 && wsConnected
        lock.unlock()
        if shouldDisconnect {
            disconnectWebSocketInternal()
        }
    }

    /// startWebSocketConnection（0x100391398 L927-968 + closure1
    /// 0x100391bec L930-967 确证）。
    private func startWebSocketConnection() {
        lock.lock()
        wsConnected = true
        lock.unlock()
        Task {
            let stream = await connectWebSocket()
            for await message in stream {
                await MainActor.run {
                    broadcastWSMessage(message)
                }
            }
        }
    }

    /// broadcastWSMessage（签名确证）：分发到观察者 + 流。
    private func broadcastWSMessage(_ message: RemoteWSMessage) {
        for continuation in wsContinuations.values {
            continuation.yield(message)
        }
        switch message.kind {
        case .toast, .longToast:
            for continuation in toastContinuations.values {
                continuation.yield(message.payload)
            }
        case .startBrowser, .showBrowser, .startBrowserdp:
            break
        case .unknown:
            break
        }
    }

    /// disconnectWebSocket（签名确证）。
    func disconnectWebSocket() {
        releaseWebSocket()
    }

    /// disconnectWebSocketInternal（签名确证）。
    private func disconnectWebSocketInternal() {
        lock.lock()
        wsConnected = false
        let continuations = wsContinuations
        let toastStreams = toastContinuations
        wsContinuations = [:]
        toastContinuations = [:]
        lock.unlock()
        for continuation in continuations.values {
            continuation.finish()
        }
        for continuation in toastStreams.values {
            continuation.finish()
        }
    }

    /// connectWebSocket（签名确证）。
    func connectWebSocket() async -> AsyncStream<RemoteWSMessage> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            wsContinuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.wsContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    /// connectToastStream（签名确证）。
    func connectToastStream() async -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            toastContinuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.toastContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    /// parseWebSocketMessage（0x100392cfc L1099-1148；类型位模式确证）。
    func parseWebSocketMessage(_ text: String) -> RemoteWSMessage {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let map = object as? [String: Any],
            let type = map["type"] as? String
        else {
            return RemoteWSMessage(kind: .unknown, payload: text)
        }
        let payload =
            (map["message"] as? String)
            ?? (map["payload"] as? String)
            ?? text
        return RemoteWSMessage(
            kind: RemoteWSMessage.Kind(rawValue: type) ?? .unknown,
            payload: payload)
    }
}

// MARK: - RemoteBrowserRequest 相等性（== infix 签名确证）

extension RemoteBrowserRequest {
    static func == (lhs: RemoteBrowserRequest, rhs: RemoteBrowserRequest)
        -> Bool
    {
        lhs.url == rhs.url && lhs.sourceStateKey == rhs.sourceStateKey
    }
}
