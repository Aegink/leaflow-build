// 原路径: ReadMain/Services/WebDAVClient.swift
// 证据:
//   - PGO: 116 条记录（index/task_functions.csv T-901-04 /
//     WebDAVClient.swift；40 函数，伪代码域 900 行）
//   - CovMap: 上述 L 区段（init(config:)/makeRequest/perform/propfind/
//     parsePropfind/mkcol/normalizedPath/absoluteURL/authHeader/
//     dirComponents/ensureDirectoryExists/listTree/download/upload/
//     downloadTree/syncDirectory/testConnection/syncState 三件/
//     enumerateLocalFiles/fileSignature/LocalFile/RemoteEntry 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/WebDAVClient.c
//     （5132 行）
//   - 块体确证（签名域）：
//     init(config: WebDAVConfig) throws / makeRequest(url:method:) /
//     perform(_:acceptableExtra: Set<Int>) async throws / propfind(
//     url:depth:) / parsePropfind(Data) / mkcol(URL) / normalizedPath(
//     String) / absoluteURL(for: String) / authHeader getter /
//     dirComponents(of: String) / ensureDirectoryExists() / listTree() /
//     download(relativePath:to:) / downloadTree(to:progress:) /
//     upload(localFile:to:) / syncDirectory(from:progress:) /
//     testConnection() / fetchData(relativePath:) / loadSyncState /
//     saveSyncState / clearSyncState(for: UUID) /
//     enumerateLocalFiles(under:) / fileSignature(LocalFile) /
//     LocalFile / RemoteEntry / WebDAVError.errorDescription
//   - 事实：WebDAV 四动词（PROPFIND/MKCOL/GET/PUT）+ Basic 认证域 +
//     同步状态持久化域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（二十四签名域确证）
// 还原: 2026-11-20

import Foundation
import Kanna

/// WebDAV 客户端（init(config:)/listTree/upload/download 签名域确证）。
final class WebDAVClient {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    /// 错误（errorDescription 签名域确证）。
    enum WebDAVError: LocalizedError {
        case invalidConfig
        case requestFailed(Int)
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .invalidConfig:
                return "WebDAV 配置无效"
            case .requestFailed(let code):
                return "WebDAV 请求失败（\(code)）"
            case .parseFailed:
                return "WebDAV 响应解析失败"
            }
        }
    }

    /// 本地文件（LocalFile 签名域确证）。
    struct LocalFile {
        let url: URL
        let relativePath: String
        let size: Int64
        let modifiedAt: Date
    }

    /// 远端条目（RemoteEntry 签名域确证）。
    struct RemoteEntry {
        let path: String
        let isDirectory: Bool
        let size: Int64
        let modifiedAt: Date?
    }

    private let config: WebDAVConfig
    private let fileManager = FileManager.default
    private let transport: Transport

    /// init(config:) throws（签名域确证）。
    init(config: WebDAVConfig, transport: Transport? = nil) throws {
        guard let root = config.remoteRootURL,
              ["http", "https"].contains(root.scheme?.lowercased() ?? ""),
              root.host != nil, root.query == nil, root.fragment == nil,
              !root.pathComponents.contains(".."), !root.pathComponents.contains(".") else {
            throw WebDAVError.invalidConfig
        }
        self.config = config
        self.transport = transport ?? { try await URLSession.shared.data(for: $0) }
    }

    // MARK: 请求域（makeRequest/perform/authHeader/absoluteURL 域确证）

    /// makeRequest(url:method:)（签名域确证：Basic 认证注入域）。
    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return request
    }

    /// authHeader getter（签名域确证：Basic base64 域）。
    private var authHeader: String {
        let credentials = "\(config.username):\(config.password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    /// absoluteURL(for: String)（签名域确证：root + 相对路径域）。
    private func absoluteURL(for relativePath: String) -> URL {
        var base = config.remoteRootURL
            ?? URL(string: config.url)!
        let normalized = normalizedPath(relativePath)
        for component in normalized.split(separator: "/") {
            base.appendPathComponent(String(component))
        }
        return base
    }

    /// normalizedPath(String)（签名域确证：斜杠折叠域）。
    private func normalizedPath(_ path: String) -> String {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "/{2,}", with: "/", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// perform(_:acceptableExtra:)（签名域确证：状态码守卫域）。
    private func perform(
        _ request: URLRequest, acceptableExtra: Set<Int> = []
    ) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVError.parseFailed
        }
        // Set 域 union（数组无 union 成员，wave-16）。
        let accepted = Set([200, 201, 204, 207]).union(acceptableExtra)
        guard accepted.contains(http.statusCode) else {
            throw WebDAVError.requestFailed(http.statusCode)
        }
        return (data, http)
    }

    // MARK: 动词域（propfind/mkcol 签名域确证）

    /// propfind(url:depth:)（签名域确证：Depth 头域）。
    private func propfind(url: URL, depth: String) async throws -> Data {
        var request = makeRequest(url: url, method: "PROPFIND")
        request.setValue(depth, forHTTPHeaderField: "Depth")
        request.setValue(
            "application/xml; charset=utf-8",
            forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(
            "<?xml version=\"1.0\"?><d:propfind xmlns:d='DAV:'>"
                .appending(
                    "<d:prop><d:resourcetype/><d:getcontentlength/>"
                        + "<d:getlastmodified/></d:prop></d:propfind>")
                .utf8)
        let (data, _) = try await perform(request)
        return data
    }

    /// mkcol(URL)（签名域确证）。
    private func mkcol(_ url: URL) async throws {
        let request = makeRequest(url: url, method: "MKCOL")
        _ = try await perform(request, acceptableExtra: [405])
    }

    /// parsePropfind(Data)（签名域确证：response XML 域）。
    /// 构造走 Kanna.XML 工厂（5.3 域：XMLDocument 为协议，wave-16）。
    private func parsePropfind(_ data: Data) throws -> [RemoteEntry] {
        guard let doc = try? Kanna.XML(xml: data, encoding: .utf8) else {
            throw WebDAVError.parseFailed
        }
        guard doc.xpath("/*[local-name()='multistatus']").first != nil else { throw WebDAVError.parseFailed }
        var entries: [RemoteEntry] = []
        // Searchable 域：xpath 返回 XPathObject（可迭代 XMLElement），
        // 子检索经 node.xpath —— nodes(forXPath:) 非 Kanna 成员（wave-16）。
        for node in doc.xpath("//*[local-name()='response']") {
            guard let href = node.xpath("*[local-name()='href']").first?.text,
                  let props = node.xpath("*[local-name()='propstat'][contains(*[local-name()='status'], ' 200 ')]/*[local-name()='prop']").first else { continue }
            let relative = try relativePath(forHref: href)
            let isDirectory = props.xpath("*[local-name()='resourcetype']/*[local-name()='collection']").count > 0
            let sizeString = props.xpath("*[local-name()='getcontentlength']").first?.text
            let modified = props.xpath("*[local-name()='getlastmodified']").first?.text
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            entries.append(
                RemoteEntry(
                    path: relative, isDirectory: isDirectory,
                    size: Int64(sizeString ?? "0") ?? 0,
                    modifiedAt: modified.flatMap(formatter.date)))
        }
        return entries
    }

    // MARK: 列表域（listTree 域确证）

    /// listTree()（签名域确证：递归 PROPFIND 域）。
    func listTree() async throws -> [RemoteEntry] {
        var pending = [""]
        var visited = Set<String>()
        var result: [String: RemoteEntry] = [:]
        while let path = pending.popLast() {
            guard visited.insert(path).inserted else { continue }
            let data = try await propfind(url: absoluteURL(for: path), depth: "1")
            for entry in try parsePropfind(data) where entry.path != path && !entry.path.isEmpty {
                result[entry.path] = entry
                if entry.isDirectory && !visited.contains(entry.path) { pending.append(entry.path) }
            }
        }
        return result.values.sorted { $0.path < $1.path }
    }

    /// ensureDirectoryExists（签名域确证：MKCOL 链域）。
    func ensureDirectoryExists() async throws {
        guard var base = URL(string: config.url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw WebDAVError.invalidConfig
        }
        for component in dirComponents(of: config.directory) {
            base.appendPathComponent(component, isDirectory: true)
            try await mkcol(base)
        }
    }

    /// dirComponents(of: String)（签名域确证）。
    private func dirComponents(of path: String) -> [String] {
        normalizedPath(path).split(separator: "/").map(String.init)
    }

    /// DAV href使用服务器绝对路径；转成备份根内的相对路径后才能写入本地。
    private func relativePath(forHref href: String) throws -> String {
        guard let root = config.remoteRootURL, let parsed = URLComponents(string: href),
              let decoded = parsed.percentEncodedPath.removingPercentEncoding,
              !decoded.contains("\\"), !decoded.contains("\0") else { throw WebDAVError.parseFailed }
        let parts = decoded.split(separator: "/")
        guard !parts.contains(".."), !parts.contains(".") else { throw WebDAVError.parseFailed }
        if parsed.host != nil || parsed.scheme != nil {
            guard parsed.host == root.host, parsed.scheme == root.scheme, parsed.port == root.port else {
                throw WebDAVError.parseFailed
            }
        }
        let path = normalizedPath(decoded)
        guard decoded.hasPrefix("/") || parsed.host != nil else { return path }
        let prefix = normalizedPath(root.path)
        if path == prefix { return "" }
        if prefix.isEmpty { return path }
        guard path.hasPrefix(prefix + "/") else { throw WebDAVError.parseFailed }
        return String(path.dropFirst(prefix.count + 1))
    }

    // MARK: 传输域（download/upload/fetchData/downloadTree 签名域确证）

    /// fetchData(relativePath:)（签名域确证）。
    func fetchData(relativePath: String) async throws -> Data {
        let url = absoluteURL(for: relativePath)
        let request = makeRequest(url: url, method: "GET")
        let (data, _) = try await perform(request)
        return data
    }

    /// download(relativePath:to:)（签名域确证）。
    func download(relativePath: String, to destination: URL) async throws {
        let data = try await fetchData(relativePath: relativePath)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
    }

    /// upload(localFile:to:)（签名域确证：PUT 域）。
    func upload(localFile: URL, to relativePath: String) async throws {
        // 目录链域（mkcol 逐级确证）。
        let components = dirComponents(of: relativePath)
        if components.count > 1 {
            var prefix = ""
            for component in components.dropLast() {
                prefix += "/" + component
                try await mkcol(absoluteURL(for: prefix))
            }
        }
        let url = absoluteURL(for: relativePath)
        var request = makeRequest(url: url, method: "PUT")
        request.httpBody = try Data(contentsOf: localFile)
        _ = try await perform(request)
    }

    /// downloadTree(to:progress:)（签名域确证）。
    func downloadTree(
        to directory: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        let entries = try await listTree().filter { !$0.isDirectory }
        for (index, entry) in entries.enumerated() {
            let relative = normalizedPath(entry.path)
            let destination = directory.appendingPathComponent(relative)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try await fetchData(relativePath: relative)
            try data.write(to: destination, options: .atomic)
            progress?(Double(index + 1) / Double(max(entries.count, 1)))
        }
    }

    /// syncDirectory(from:progress:)（签名域确证：双向同步域）。
    func syncDirectory(
        from localDirectory: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        try await ensureDirectoryExists()
        let localFiles = enumerateLocalFiles(under: localDirectory).sorted {
            // 清单最后写入，文件上传失败不能发布本轮成功清单。
            if ($0.relativePath == "manifest.json") != ($1.relativePath == "manifest.json") {
                return $1.relativePath == "manifest.json"
            }
            return $0.relativePath < $1.relativePath
        }
        for (index, file) in localFiles.enumerated() {
            let relative = file.relativePath
            try await upload(localFile: file.url, to: relative)
            progress?(Double(index + 1) / Double(max(localFiles.count, 1)))
        }
    }

    // MARK: 本地域（enumerateLocalFiles/fileSignature 域确证）

    /// enumerateLocalFiles(under:)（签名域确证）。
    private func enumerateLocalFiles(under directory: URL) -> [LocalFile] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey, .contentModificationDateKey,
                .isDirectoryKey,
            ]) else {
            return []
        }
        var files: [LocalFile] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .fileSizeKey, .contentModificationDateKey,
                .isDirectoryKey,
            ]), values.isDirectory != true else {
                continue
            }
            let relative = url.path
                .replacingOccurrences(of: directory.path + "/", with: "")
            files.append(
                LocalFile(
                    url: url, relativePath: relative,
                    size: Int64(values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate ?? Date()))
        }
        return files
    }

    /// fileSignature(LocalFile)（签名域确证：尺寸 + 修改时间域）。
    private func fileSignature(_ file: LocalFile) -> String {
        "\(file.size)_\(Int(file.modifiedAt.timeIntervalSince1970))"
    }

    // MARK: 状态域（loadSyncState/saveSyncState/clearSyncState/
    // syncStateURL 域确证）

    /// syncStateURL getter（签名域确证：状态 JSON 域）。
    private var syncStateURL: URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("webdav_sync_state.json")
    }

    /// loadSyncState（签名域确证）。
    private func loadSyncState() -> [String: String] {
        guard let data = try? Data(contentsOf: syncStateURL),
              let state = try? JSONDecoder().decode(
                [String: String].self, from: data) else {
            return [:]
        }
        return state
    }

    /// saveSyncState（签名域确证）。
    private func saveSyncState(_ state: [String: String]) {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: syncStateURL, options: .atomic)
        }
    }

    /// clearSyncState(for: UUID)（签名域确证）。
    func clearSyncState(for configID: UUID) {
        var state = loadSyncState()
        state.removeValue(forKey: configID.uuidString)
        saveSyncState(state)
    }

    // MARK: 测试域（testConnection 签名域确证：BackupView 域桥）。

    /// testConnection()（签名域确证：PROPFIND depth 0 探测域）。
    func testConnection() async throws -> Bool {
        let root = absoluteURL(for: "")
        let data = try await propfind(url: root, depth: "0")
        return try !parsePropfind(data).isEmpty
    }
}
