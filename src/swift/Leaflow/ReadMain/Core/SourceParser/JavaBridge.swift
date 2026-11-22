// 原路径: ReadMain/Core/SourceParser/JavaBridge.swift
// 证据:
//   - PGO: JSImportScriptResolver（50 函数：sandboxRoots/md5Hex/md5Encode16/legacyFolderName/chapterIndex/isRemotePath/directSandboxFileURL/normalizedPathComponents/relativePathVariants 等）
//   - CovMap: sandboxRoots L26-42 @0x1000e8bf0；md5Hex L44-48 @0x1000e915c；md5Encode16 L50-55 @0x1000e95ac；legacyFolderName L57-65 @0x1000e96fc；chapterIndex L78-91 @0x1000e9d04；directSandboxFileURL L103-123 @0x1000ea4d8；normalizedPathComponents L125-151 @0x1000ea9c0；relativePathVariants L153-165 @0x1000eae78
//   - IDA: 上述地址
//   - 诊断：[JSImportScript] local miss|unreadable|hit path=；沙箱非法字符集 [\\/:*?"<>|]；Illegal hexadecimal character in '；qireader.blocking-lane.worker 线程名
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（解析器链确证；路径变体集合见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// 本地 JS 脚本解析器（`<jslib>` 沙箱路径解析）。
enum JSImportScriptResolver {

    /// 伪代码 0x1000e8bf0（L26-42）：沙箱根目录。
    static func sandboxRoots() -> [URL] {
        let manager = FileManager.default
        var roots: [URL] = []
        if let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            roots.append(caches.appendingPathComponent("jslib"))
        }
        if let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first {
            roots.append(documents.appendingPathComponent("jslib"))
        }
        return roots
    }

    /// 伪代码 0x1000e915c（L44-48）/0x1000e95ac（L50-55）。
    static func md5Hex(_ input: String) -> String {
        CryptoBridge.digest(input, mode: "md5")
    }

    static func md5Encode16(_ input: String) -> String {
        String(md5Hex(input).dropFirst(8).dropLast(8))
    }

    /// 伪代码 0x1000e96fc（L57-65）：旧版文件夹名（md5-16）。
    static func legacyFolderName(for sourceKey: String) -> String {
        md5Encode16(sourceKey)
    }

    /// 伪代码 0x1000e9d04（L78-91）。
    static func chapterIndex(from path: String) -> Int? {
        let digits = path.filter { $0.isNumber }
        return Int(String(digits.prefix(6)))
    }

    /// 伪代码 0x1000ea338（L95）：远程路径判定（http/https）。
    static func isRemotePath(_ path: String) -> Bool {
        path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://")
    }

    /// 伪代码 0x1000ea4d8（L103-123）：直接沙箱文件 URL（非法字符清洗后）。
    static func directSandboxFileURL(_ path: String) -> URL? {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = path.components(separatedBy: invalid).joined()
        for root in sandboxRoots() {
            let candidate = root.appendingPathComponent(cleaned)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// 伪代码 0x1000ea9c0（L125-151）：路径分量归一（去 .. 与空段）。
    static func normalizedPathComponents(_ path: String) -> [String] {
        path.split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    /// 伪代码 0x1000eae78（L153-165）：相对路径变体集合（推断 1：含 legacy 前缀形态）。
    static func relativePathVariants(_ path: String, sourceKey: String) -> [String] {
        let components = normalizedPathComponents(path)
        var variants = [components.joined(separator: "/")]
        variants.append(legacyFolderName(for: sourceKey) + "/" + components.joined(separator: "/"))
        return variants
    }

    /// 解析主入口（诊断串事实 1）。
    static func resolve(_ path: String, sourceKey: String) -> String? {
        if isRemotePath(path) {
            return AnalyzeUrl.downloadScript(path)
        }
        for variant in relativePathVariants(path, sourceKey: sourceKey) {
            if let url = directSandboxFileURL(variant),
                let content = try? String(contentsOf: url, encoding: .utf8)
            {
                Logger.log("[JSImportScript] local hit path=\(url.path)", level: .warning)
                return content
            }
        }
        Logger.log("[JSImportScript] local miss path=\(path)", level: .warning)
        return nil
    }
}

// MARK: - T-1401-10 逐域补齐（Java 桥域）

/// Java 桥（ajaxAll 0x1000ec4ac / post 0x1000ecc18 / connect 0x1000ed1f8 /
/// put 0x1000ed3b4 / md5Encode 0x1000ed5ec / log 0x1000ed62c / timeFormat
/// 0x1000ed7cc / timeFormatUTC 0x1000eda28 / base64Encode 0x1000edb18 /
/// hexDecodeToString 0x1000edc00 / aesBase64DecodeToString 0x1000ee6ac /
/// aesEncodeToString 0x1000ee6fc 域；经 JsExtensions/CryptoHelper 模块桥）。
final class JavaBridge {

    /// 伪代码 0x1000ec4ac（L364-385）：批量请求域。
    static func ajaxAll(_ urls: [String]) -> [String] {
        JsExtensions().ajaxAll(urls)
    }

    /// T-1601-B3：`java.ajax(url)` 单请求域（JsExtensions.ajax 同源；
    /// java 对象此前未注册 ajax → 依赖 ajax 的 Legado JS 规则抛错）。
    static func ajax(_ url: String) -> String {
        JsExtensions().ajax(url)
    }

    /// 伪代码 JavaBridge.put(String, String) -> String（inout
    /// [String: String] 闭包确证）：**变量写入**，不是 HTTP PUT。
    static func put(_ key: String, _ value: String) -> String {
        AnalyzeRule.sharedInstance().putVariable(key, value: value)
        return value
    }

    /// 伪代码 JavaBridge.get(String) -> String（inout [String: String]
    /// 闭包确证）：变量读取，缺失返回空串。
    static func get(_ key: String) -> String {
        AnalyzeRule.sharedInstance().getVariable(key) ?? ""
    }

    /// 伪代码 0x1000ecc18（L393-401）：POST 域。
    static func post(_ url: String, body: String, headers: [String: String]) -> String {
        JsExtensions().post(url, body, headers).body
    }

    /// 伪代码 0x1000ed1f8（L406-410）：CONNECT 域。
    static func connect(_ url: String, body: String, headers: [String: String]) -> String {
        JsExtensions().post(url, body, headers).body
    }

    /// 伪代码 0x1000ed3b4（L412-415）：PUT 域。
    static func put(_ url: String, body: String, headers: [String: String]) -> String {
        JsExtensions().post(url, body, headers).body
    }

    /// 伪代码 0x1000ed5ec（L421-425）：MD5 摘要域。
    static func md5Encode(_ input: String) -> String {
        JsExtensions().md5(input)
    }

    /// 伪代码 0x1000ed62c（L427-429）：日志域。
    static func log(_ message: String) {
        Logger.log("[java] \(message)", level: .info, module: .parser)
    }

    /// 伪代码 0x1000ed7cc（L431-437）：时间格式化（本地域）。
    static func timeFormat(_ timestamp: Int64) -> String {
        JsExtensions().timeFormat(timestamp)
    }

    /// 伪代码 0x1000eda28（L439-446）：UTC 时间格式化（时区偏移参数域）。
    static func timeFormatUTC(_ timestamp: Int64, _ format: String, _ timeZoneOffset: Int) -> String {
        JsExtensions().timeFormatUTC(timestamp, format, timeZoneOffset)
    }

    /// 伪代码 0x1000edb18（L448-450）：Base64 编码域。
    static func base64Encode(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
    }

    /// 伪代码 0x1000edc00（L457-481）：hex 解码为串（双字符配对域）。
    static func hexDecodeToString(_ input: String) -> String {
        JsBridgeTemplates.makeHexDecodeToStringBlock()(input)
    }

    /// 伪代码 0x1000ee6ac（L491-493）：AES/Base64 解码域（CryptoHelper
    /// 对称桥）。
    static func aesBase64DecodeToString(_ data: String, key: String, iv: String, transformer: String) -> String {
        CryptoHelper.cipherProcess(data, key: key, iv: iv, transformer: transformer)
    }

    /// 伪代码 0x1000ee6fc（L495-497）：AES/Base64 编码域。
    static func aesEncodeToString(_ data: String, key: String, iv: String, transformer: String) -> String {
        CryptoHelper.symmetricEncryptBase64(
            data: data, key: key, transformer: transformer, iv: iv)
    }
}

/// Cookie 桥（removeCookie 0x1000ee7cc / getCookie 0x1000ee858 /
/// setCookie 0x1000ee91c 域；HTTPCookieStorage 桥）。
enum CookieBridge {

    /// 伪代码 0x1000ee7cc（L513-516）：移除域。
    static func removeCookie(_ url: String, name: String) {
        let storage = HTTPCookieStorage.shared
        guard let target = URL(string: url) else { return }
        for cookie in storage.cookies(for: target) ?? [] where cookie.name == name {
            storage.deleteCookie(cookie)
        }
    }

    /// 伪代码 0x1000ee858（L518-521）：读取域。
    static func getCookie(_ url: String, name: String) -> String {
        let storage = HTTPCookieStorage.shared
        guard let target = URL(string: url) else { return "" }
        return storage.cookies(for: target)?
            .first { $0.name == name }?.value ?? ""
    }

    /// 伪代码 0x1000ee91c（L524-530）：写入域。
    static func setCookie(_ url: String, name: String, value: String) {
        guard let target = URL(string: url) else { return }
        let cookie = HTTPCookie(
            properties: [
                .domain: target.host ?? "",
                .path: target.path.isEmpty ? "/" : target.path,
                .name: name,
                .value: value,
            ])
        if let cookie {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
}

/// import 脚本域扩展（readTxtFile 0x1000e7998 / cacheFile 0x1000e80f4 /
/// importScript 0x1000eca8c 域；既有 JSImportScriptResolver 路径工具复用）。
extension JSImportScriptResolver {

    /// 伪代码 0x1000e7998（L254-276）：沙箱文本读取（路径归一域复用）。
    static func readTxtFile(_ path: String, sourceKey: String) -> String? {
        guard let url = JSImportScriptResolver.directSandboxFileURL(path) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 伪代码 0x1000e80f4（L278-310）：缓存文件读取（缓存目录域）。
    static func cacheFile(_ path: String, sourceKey: String) -> String? {
        guard let root = JSImportScriptResolver.sandboxRoots().first else {
            return nil
        }
        let cacheURL = root.appendingPathComponent("cache")
        let target = cacheURL.appendingPathComponent(
            JSImportScriptResolver.normalizedPathComponents(path)
                .joined(separator: "/"))
        return try? String(contentsOf: target, encoding: .utf8)
    }

    /// 伪代码 0x1000eca8c（L312-320）：import 脚本装配（readTxtFile 链域）。
    static func importScript(_ path: String, sourceKey: String) -> String? {
        readTxtFile(path, sourceKey: sourceKey)
            ?? cacheFile(path, sourceKey: sourceKey)
    }

}

