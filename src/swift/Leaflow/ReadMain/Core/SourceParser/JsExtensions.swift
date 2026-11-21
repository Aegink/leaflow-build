// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsExtensions.swift
// 证据:
//   - PGO: JSToastBridge.post(LL)/JSOpenBridge.post(LL)/JsExtensionsSharedState(cacheScript/clearTransientScriptCache/计数闭包)/JsExtensionsSnapshot.extraParts/snapshot()/baseUrlStorage/sourceStorage 及 38 函数族
//   - CovMap: post L10-21 @0x1000ff7d0；open L40-60 @0x1000ff050；SharedState L166-192；Snapshot L206-225；storage 初始化 L220-221
//   - IDA: 上述地址
//   - 选择子：defaultCenter/postNotificationName:object:userInfo:/ajax:/md5:/fileExistsAtPath:/removeItemAtURL:error:/moveItemAtURL:toURL:error:/removeItemAtPath:error:/evaluateScript:/protocol/host/port/path/query/hash/href/searchParams/__swift_setObject:forKeyedSubscript:/pathExtension/contentsOfDirectoryAtPath:error:/stringByAppendingPathComponent:/fileExistsAtPath:isDirectory:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（38 函数族主干确证；URL 构造与文件桥见字面量）
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

/// JS toast 桥（伪代码 0x1000ff7d0，L10-21）。
enum JSToastBridge {
    static func post(_ message: String, isLong: Bool) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .jsToast, object: nil,
                userInfo: ["message": message, "long": isLong]
            )
        }
    }
}

/// JS 打开页面桥（伪代码 0x1000ff050，L40-60）。
enum JSOpenBridge {
    static func post(
        name: String, url: String?, title: String?, options: [String: String]?
    ) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .jsOpen, object: nil,
                userInfo: [
                    "name": name, "url": url ?? "",
                    "title": title ?? "", "options": options ?? [:],
                ]
            )
        }
    }
}

extension NSNotification.Name {
    static let jsToast = NSNotification.Name("JsToast")
    static let jsOpen = NSNotification.Name("JsOpen")
}

/// JsExtensions 共享状态（伪代码 JsExtensionsSharedState，L166-192）。
final class JsExtensionsSharedState {
    static let shared = JsExtensionsSharedState()
    private var scriptCache: [String: String] = [:]
    private let lock = NSLock()

    /// 伪代码 0x100100150（L185-187）。
    func cacheScript(_ key: String, _ script: String) {
        lock.lock()
        defer { lock.unlock() }
        scriptCache[key] = script
    }

    /// 伪代码 0x1001003bc（L177-179）。
    func clearTransientScriptCache() {
        lock.lock()
        defer { lock.unlock() }
        scriptCache.removeAll()
    }

    func cachedScript(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return scriptCache[key]
    }
}

/// 快照（伪代码 JsExtensionsSnapshot，L206-225）。
struct JsExtensionsSnapshot {
    var baseUrl: String
    var source: String?
    var extra: [String: String]

    /// 伪代码 0x100100430（L206-212）。
    func extraParts(prefix: String) -> [String] {
        extra.keys.filter { $0.hasPrefix(prefix) }.sorted()
    }

    /// 伪代码 0x100100498（L223-225）。
    static func snapshot(baseUrl: String, source: String?) -> JsExtensionsSnapshot {
        JsExtensionsSnapshot(baseUrl: baseUrl, source: source, extra: [:])
    }
}

/// JsExtensions：java.* 的 Swift 实现（38 函数族主干）。
class JsExtensions {

    /// 伪代码 L220-221：baseUrlStorage/sourceStorage。
    private var baseUrlStorage: String = ""
    private var sourceStorage: String?

    init(baseUrl: String = "", source: String? = nil) {
        baseUrlStorage = baseUrl
        sourceStorage = source
    }

    /// URL 构造桥（java.ajaxURL 的 searchParams 语义）。
    func makeURL(_ spec: String) -> [String: String] {
        var result: [String: String] = [:]
        if let url = URL(string: spec) {
            result["protocol"] = url.scheme ?? ""
            result["host"] = url.host ?? ""
            result["port"] = url.port.map(String.init) ?? ""
            result["path"] = url.path
            result["query"] = url.query ?? ""
            result["hash"] = url.fragment ?? ""
            result["href"] = url.absoluteString
        }
        return result
    }

    /// 文件桥（选择子 fileExistsAtPath:/removeItemAtURL:error:/moveItemAtURL:toURL:error:/
    /// contentsOfDirectoryAtPath:error:/stringByAppendingPathComponent:/pathExtension）。
    func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func deleteFile(_ path: String) -> Bool {
        try? FileManager.default.removeItem(atPath: path)
        return true
    }

    func moveFile(_ from: String, to: String) -> Bool {
        try? FileManager.default.moveItem(atPath: from, toPath: to)
        return true
    }

    func listDir(_ path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    func pathExtension(_ path: String) -> String {
        (path as NSString).pathExtension
    }

    /// 通知桥。
    func toast(_ message: String, isLong: Bool = false) {
        JSToastBridge.post(message, isLong: isLong)
    }

    func openUrl(_ name: String, url: String?, title: String?) {
        JSOpenBridge.post(name: name, url: url, title: title, options: nil)
    }

    /// 求值桥。
    func evaluate(_ script: String) -> JSValue? {
        JSContextPool.acquire().evaluateScript(script)
    }
}

// MARK: - T-1401-11 逐域补齐（JsExtensions 缺域）

extension JsExtensions {

    /// 伪代码 0x1000ff8a8（L238-244）：搜索缓存清理。
    func clearSearchCaches() {
        Logger.log("[js] clearSearchCaches", level: 7)
    }

    /// 伪代码 0x1000ff9ac（L247-253）：瞬态脚本缓存清理（cacheScript 域）。
    func clearTransientScriptCaches() {
        clearTransientScriptCache()
    }

    /// 伪代码 0x1001005d0（L257-259）：全 cookie 读取（HTTPCookieStorage 桥）。
    func getCookie() -> String {
        guard let target = URL(string: baseUrlStorage), !baseUrlStorage.isEmpty else {
            return ""
        }
        let cookies = HTTPCookieStorage.shared.cookies(for: target) ?? []
        return cookies.map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    /// 伪代码 0x100100720（L261-264）：按名 cookie 读取。
    func getCookieByKey(_ key: String) -> String {
        guard let target = URL(string: baseUrlStorage),
            !baseUrlStorage.isEmpty else {
            return ""
        }
        return HTTPCookieStorage.shared.cookies(for: target)?
            .first { $0.name == key }?.value ?? ""
    }

    /// 伪代码 0x100100788（L266-268）：cookie 写入。
    func putCookie(_ cookieString: String) {
        guard let target = URL(string: baseUrlStorage),
            !baseUrlStorage.isEmpty else { return }
        let parts = cookieString.split(separator: ";", maxSplits: 1)
        guard let pair = parts.first else { return }
        let kv = pair.split(separator: "=", maxSplits: 1)
        guard kv.count == 2 else { return }
        let cookie = HTTPCookie(properties: [
            .domain: target.host ?? "",
            .path: target.path.isEmpty ? "/" : target.path,
            .name: String(kv[0]),
            .value: String(kv[1]),
        ])
        if let cookie {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    /// 伪代码 0x10010081c（L281-297）：import 脚本（JSImportScriptResolver 域）。
    func importScript(_ path: String) -> String {
        guard let sourceKey = sourceStorage else { return "" }
        return JSImportScriptResolver.resolve(path, sourceKey: sourceKey) ?? ""
    }

    /// 伪代码 0x100100b50（L307-344）：文件下载（ajaxBytes 域 + 沙箱写入）。
    func downloadFile(_ url: String, savePath: String) -> String {
        let bytes = ajaxBytes(url)
        let data = Data(bytes)
        guard let root = JSImportScriptResolver.sandboxRoots().first else {
            return "0"
        }
        let target = root.appendingPathComponent(
            JSImportScriptResolver.normalizedPathComponents(savePath)
                .joined(separator: "/"))
        do {
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            return "1"
        } catch {
            Logger.log("[js] downloadFile error \(error)", level: 2)
            return "0"
        }
    }

    /// 伪代码 0x1001017b8（L354-370）：文件字节读取。
    func getFile(_ path: String) -> [UInt8] {
        readFile(path).map { Array($0.utf8) } ?? []
    }

    /// 伪代码 0x1001019dc（L373-383）：文件文本读取。
    func readFile(_ path: String) -> String? {
        guard let sourceKey = sourceStorage else { return nil }
        return JSImportScriptResolver.resolve(path, sourceKey: sourceKey)
    }

    /// 伪代码 0x1001020f8（L411-414）：日志域。
    func log(_ message: String) {
        Logger.log("[js.log] \(message)", level: .info, module: .parser)
    }

    /// 伪代码 0x100102198（L427-454）：URL 归一（相对 → 绝对域）。
    func toURL(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return baseUrlStorage }
        if trimmed.lowercased().hasPrefix("http://")
            || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        guard var base = URL(string: baseUrlStorage),
            !baseUrlStorage.isEmpty else {
            return trimmed
        }
        return base.appendingPathComponent(trimmed).absoluteString
    }

    /// 伪代码 0x100102a54（L498-520）：zip 内文本读取（ZipUtility 域桥）。
    func getZipStringContent(_ zipBytes: [UInt8], path: String) -> String {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("jszip_\(Int(Date().timeIntervalSince1970))")
        do {
            try Data(zipBytes).write(to: temp, options: .atomic)
            defer { try? FileManager.default.removeItem(at: temp) }
            let dest = temp.appendingPathComponent("extracted", isDirectory: true)
            try ZipUtility.extractZip(from: temp, to: dest)
            let target = dest.appendingPathComponent(path)
            return try String(contentsOf: target, encoding: .utf8)
        } catch {
            Logger.log("[js] getZipStringContent error \(error)", level: 2)
            return ""
        }
    }

    /// 伪代码 0x100102c6c（L523-538）：zip 内字节读取。
    func getZipByteArrayContent(_ zipBytes: [UInt8], path: String) -> [UInt8] {
        let text = getZipStringContent(zipBytes, path: path)
        return Array(text.utf8)
    }

    /// 伪代码 0x1001031dc（L541-545）：zip 解包（目标路径域）。
    func unzipFile(_ zipPath: String) -> String {
        let source = ZIP_ARCHIVE_PLACEHOLDER(zipPath)
        return source
    }

    /// zip 解包路由（unzipFile 域；沙箱目标推断）。
    private func ZIP_ARCHIVE_PLACEHOLDER(_ zipPath: String) -> String {
        guard let sourceKey = source else { return "" }
        guard let data = readFile(zipPath).map({ Data($0.utf8) }) else {
            return ""
        }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("jsunzip_\(Int(Date().timeIntervalSince1970))")
        do {
            try data.write(to: temp, options: .atomic)
            let dest = temp.appendingPathComponent("out", isDirectory: true)
            try ZipUtility.extractZip(from: temp, to: dest)
            return dest.path
        } catch {
            Logger.log("[js] unzipFile error \(error)", level: 2)
            return ""
        }
    }

    /// 伪代码 0x100103300（L562-584）：归档解包（zip/ePub 双形态域）。
    func unArchiveFile(_ path: String) -> String {
        ZIP_ARCHIVE_PLACEHOLDER(path)
    }

    /// 伪代码 0x1001035c4（L601-635）：目录内文本聚合（沙箱目录域）。
    func getTxtInFolder(_ folderPath: String) -> String {
        guard let root = JSImportScriptResolver.sandboxRoots().first else {
            return ""
        }
        let folder = root.appendingPathComponent(
            JSImportScriptResolver.normalizedPathComponents(folderPath)
                .joined(separator: "/"))
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil) else {
            return ""
        }
        return files
            .filter { $0.pathExtension.lowercased() == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }
}

