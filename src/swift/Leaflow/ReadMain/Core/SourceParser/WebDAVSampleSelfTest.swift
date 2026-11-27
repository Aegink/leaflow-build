// T-1602：真实备份导出/传输/恢复链，只替换HTTP传输，所有文件使用隔离目录。
import Foundation

enum WebDAVSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let identifier = "webdav-sample-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        let defaults = UserDefaults(suiteName: identifier)!
        defer {
            defaults.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        let config = WebDAVConfig(id: UUID(), name: "固定DAV", url: "https://sample.invalid/dav/base",
                                  username: "sample", password: "fixture", directory: "backup/one")
        do {
            emit("webdav_root_preserves_service_path", ["/dav/base/backup/one"],
                ["/" + (config.remoteRootURL?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "")])
            let server = FixtureServer()
            let transport: WebDAVClient.Transport = { request in try await server.respond(request) }
            let client = try WebDAVClient(config: config, transport: transport)
            try await client.ensureDirectoryExists()
            emit("webdav_mkcol_parent_sequence", ["MKCOL /dav/base/backup", "MKCOL /dav/base/backup/one"], await server.calls())
            let docs = root.appendingPathComponent("documents")
            try FileManager.default.createDirectory(at: docs.appendingPathComponent("local_books/中文"), withIntermediateDirectories: true)
            let payload = Data([0, 1, 2, 255, 0, 128])
            try payload.write(to: docs.appendingPathComponent("local_books/中文/图 像.bin"))
            let backup = BackupService(documentsDirectory: docs, applicationSupportDirectory: root.appendingPathComponent("support"),
                                       defaults: defaults, webDAVTransport: transport)
            var progress: [Double] = []
            try await backup.backupToWebDAV(config: config, categories: [.localBooks], progress: { progress.append($0) })
            let stored = await server.snapshot()
            emit("webdav_backup_awaits_nested_upload", ["true", "true"],
                [String(stored["/dav/base/backup/one/local_books/中文/图 像.bin"] == payload),
                 String(stored["/dav/base/backup/one/manifest.json"] != nil)])
            emit("webdav_backup_progress_completed", ["1.0", "true"],
                [String(progress.last ?? -1), String(progress == progress.sorted())])
            let puts = await server.calls().filter { $0.hasPrefix("PUT ") }
            emit("webdav_manifest_uploaded_last", ["PUT /dav/base/backup/one/manifest.json"], [puts.last ?? ""])
            emit("webdav_basic_authorization", ["true"], [String(await server.authenticated())])
            let entries = try await client.listTree()
            emit("webdav_propfind_entry_scope", ["local_books:true", "local_books/中文:true", "local_books/中文/图 像.bin:false", "manifest.json:false"],
                entries.map { $0.path + ":" + String($0.isDirectory) })
            emit("webdav_propfind_file_metadata", ["6", "true"],
                [String(entries.first { $0.path.hasSuffix(".bin") }?.size ?? -1),
                 String(entries.first { $0.path.hasSuffix(".bin") }?.modifiedAt != nil)])
            let preview = try await backup.previewWebDAVBackup(config: config)
            emit("webdav_preview_reads_manifest", ["localBooks"], preview["categories"] as? [String] ?? [])
            emit("webdav_last_backup_date", ["true"], [String(await backup.webDAVLastBackupDate(config: config) != nil)])
            let restoredDocs = root.appendingPathComponent("restored-documents")
            let restore = BackupService(documentsDirectory: restoredDocs, applicationSupportDirectory: root.appendingPathComponent("restored-support"),
                                        defaults: defaults, webDAVTransport: transport)
            try await restore.restoreFromWebDAV(config: config, categories: [.localBooks])
            emit("webdav_restore_nested_binary", ["true"], [String(try Data(contentsOf: restoredDocs.appendingPathComponent("local_books/中文/图 像.bin")) == payload)])
            await server.configure(failUploads: true)
            var failed = false
            do { try await backup.backupToWebDAV(config: config, categories: [.localBooks]) } catch { failed = true }
            emit("webdav_upload_error_propagates", ["true"], [String(failed)])
            await server.configure(maliciousHref: "/dav/base/backup/one/%2e%2e/escape.json")
            var traversalRejected = false
            do { try await client.downloadTree(to: root.appendingPathComponent("malicious")) } catch { traversalRejected = true }
            emit("webdav_encoded_parent_rejected", ["true", "false"],
                [String(traversalRejected), String(FileManager.default.fileExists(atPath: root.appendingPathComponent("escape.json").path))])
            await server.configure(maliciousHref: "https://other.invalid/dav/base/backup/one/file.json")
            var originRejected = false
            do { _ = try await client.listTree() } catch { originRejected = true }
            emit("webdav_foreign_origin_rejected", ["true"], [String(originRejected)])
            await server.configure(listStatus: 404)
            var missingRejected = false
            do { _ = try await client.testConnection() } catch { missingRejected = true }
            emit("webdav_missing_root_not_success", ["true"], [String(missingRejected)])
        } catch { emit("webdav_restore_nested_binary", ["通过"], [error.localizedDescription]) }
    }

    private actor FixtureServer {
        private var files: [String: Data] = [:]
        private var requests: [String] = []
        private var authOK = true
        private var failUploads = false
        private var maliciousHref: String?
        private var listStatus = 207

        func calls() -> [String] { requests }
        func snapshot() -> [String: Data] { files }
        func authenticated() -> Bool { authOK }
        func configure(failUploads: Bool = false, maliciousHref: String? = nil, listStatus: Int = 207) {
            self.failUploads = failUploads
            self.maliciousHref = maliciousHref
            self.listStatus = listStatus
        }

        func respond(_ request: URLRequest) async throws -> (Data, URLResponse) {
            let url = request.url!
            let path = "/" + url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let method = request.httpMethod ?? ""
            requests.append(method + " " + path)
            authOK = authOK && request.value(forHTTPHeaderField: "Authorization") == "Basic " + Data("sample:fixture".utf8).base64EncodedString()
            var status = 200
            var data = Data()
            switch method {
            case "MKCOL": status = 201
            case "PUT":
                try await Task.sleep(nanoseconds: 10_000_000)
                status = failUploads ? 503 : 201
                if !failUploads { files[path] = request.httpBody ?? Data() }
            case "GET":
                status = files[path] == nil ? 404 : 200
                data = files[path] ?? Data()
            case "PROPFIND":
                status = listStatus
                var children: [String: Bool] = [path: true]
                for name in files.keys where name.hasPrefix(path + "/") {
                    let rest = name.dropFirst(path.count + 1)
                    let first = String(rest.split(separator: "/")[0])
                    children[path + "/" + first] = rest.contains("/")
                }
                let rows: String
                if let maliciousHref { rows = row(maliciousHref, directory: false, size: 0) }
                else {
                    rows = children.keys.sorted().map { name in
                        row(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!, directory: children[name]!, size: files[name]?.count ?? 0)
                    }.joined()
                }
                data = Data(("<d:multistatus xmlns:d='DAV:'>" + rows + "</d:multistatus>").utf8)
            default: status = 405
            }
            return (data, HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!)
        }

        private func row(_ href: String, directory: Bool, size: Int) -> String {
            "<d:response><d:href>\(href)</d:href><d:propstat><d:prop><d:resourcetype>"
                + (directory ? "<d:collection/>" : "")
                + "</d:resourcetype><d:getcontentlength>\(size)</d:getcontentlength>"
                + "<d:getlastmodified>Wed, 01 Jan 2025 00:00:00 GMT</d:getlastmodified></d:prop>"
                + "<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>"
        }
    }
}
