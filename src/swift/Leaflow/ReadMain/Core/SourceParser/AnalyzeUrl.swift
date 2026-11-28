// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl.swift
// 证据:
//   - PGO: batchSearchMode / 静态会话与清理族 / jsPool 初始化闭包 / init(ruleUrl:...) /
//     applyResponseOptions / cleanBaseUrl / parseUrl / setJavaScriptResultVariable / Snapshot /
//     executeJsUrl / evaluateTtsWebSocketMessage / processJsPrefix / replacePagePatterns /
//     evaluatePageExpressions / removeUrlSuffix / evaluateJsExpressions / safeEvaluateScript /
//     keyEncoded / resolveRelativeUrl / parseJsonConfig / loadInitialHeaders / parseHeaders /
//     requestContext 家族 / setExtraHeaders / jsContext / releaseOwnedJSContext / endJSContextScope
//   - CovMap: batchSearchMode L22-23 @0x100080218/0x10047e0a8；batchSearchSession 闭包 L290-308
//     @0x10008185c / L312-325 @0x100081994；batchSearchConnectionsPerHost L343-348 @0x100081a44；
//     clearSearchCaches L365-418 @0x100081ffc；clearIdleRuntimeCaches L420-456 @0x100082658；
//     cancelAllBatchRequests 闭包 L461-467 @0x10008288c；drainJSContextPool L471-476 @0x10008214c；
//     clearBatchRefreshCaches L484-513 @0x100082c5c；jsPool 闭包#2 L521-599 @0x100097124；
//     init L634-668 @0x100083c54；applyResponseOptions L670-677 @0x100084860；cleanBaseUrl
//     L680-697 @0x10008461c；parseUrl L712-939 @0x100084b88；setJavaScriptResultVariable
//     L941-981 @0x100086734；Snapshot L1024-1062 @0x1000876d8；executeJsUrl L1124-1192
//     @0x100087b2c；evaluateTtsWebSocketMessage L1198-1321 @0x10008861c；processJsPrefix
//     L1324-1353 @0x10008a050；replacePagePatterns L1358-1394 @0x10008a42c；
//     evaluatePageExpressions L1400-1437 @0x10008a9b4；removeUrlSuffix L1440-1471 @0x10008b060；
//     evaluateJsExpressions L1475-1594 @0x10008b37c；safeEvaluateScript L1597-1609 @0x10008cb8c；
//     keyEncoded L1622-1636 @0x10008cc68；resolveRelativeUrl L1639-1695 @0x10008d1f0；
//     parseJsonConfig L1698-1828 @0x10008d854；loadInitialHeaders L1831-1870 @0x10008e698；
//     parseHeaders L1873-1913 @0x10008eb40；requestContextJSONString L61-68 @0x100080490；
//     requestContextStringValue L70-84 @0x100080600；updateRequestContextVariables L86-107
//     @0x1000807ac；setExtraHeaders L110-112 @0x100080d5c；jsContext L197-230 @0x1000811c0；
//     releaseOwnedJSContext L253-270 @0x1000814d0；endJSContextScope L272-275 @0x100081518
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 139 条字符串常量
//   - java 作用域键：__nativeHttpRequest/cookie/_nativeSym*/_nativeBase64Encode/base64*/decode/
//     __qireaderEncodeURI*/encodeURIComponent/encodeURI/_cacheMemory*/_cachePersistent*/cache/
//     speakText/speakSpeed/message/webSocketState/_ws* 族
//   - TTS 模板：{{source.bookSourceUrl}}/{{source.bookSourceName}}/{{java.speakText}}/{{java.speakSpeed}}
//   - 诊断串：[AnalyzeUrlTrace] init-start/[AnalyzeUrl] 清缓存|批量刷新|idle 清理 + checkedOut/
//     [evaluateJsExpr] … replacing with empty / nil (JS exception?)/<analyze-url-page-expr>/
//     请求头解析失败: /[parseHeaders] JS => /JSON 解析失败: /onMessage 返回了无效的音频 Base64
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 静态缓存/清理族 + 实例字段 + 上下文家族: high
//   - parseUrl: medium（822 行体，主干顺序按推断 1 还原）
//   - evaluateTtsWebSocketMessage: medium-high（_ws* 桥确证，帧偏移待 T-801 交叉）
//   - evaluateJsExpressions/parseJsonConfig/parseHeaders: medium-high
// 还原: 2026-11-19

import Foundation
import JavaScriptCore

final class AnalyzeUrl {

    // MARK: - 静态状态

    /// 伪代码 L22-23。
    static var batchSearchMode = false

    /// 伪代码 L290-325/L343-348：批量搜索会话（ephemeral + 连接数）。
    static var batchSearchSession: URLSession?
    static let batchSearchConnectionsPerHost = 8

    /// 伪代码 L521-599（closure #2）：AnalyzeUrl 作用域 jsPool 初始化键集（事实 3）。
    static let jsScopeNativeKeys: [String] = [
        "__nativeHttpRequest", "cookie", "log",
        "_nativeSymDecrypt", "_nativeSymEncryptBase64", "_nativeSymEncryptHex",
        "_nativeBase64Encode", "base64Encode", "base64Decode", "base64", "decode",
        "__qireaderEncodeURIUtf8", "__qireaderEncodeURIWithCharset",
        "encodeURIComponent", "encodeURI",
        "_cacheMemoryPut", "_cacheMemoryGet", "_cacheMemoryDelete",
        "_cachePersistentPut", "_cachePersistentGet", "_cachePersistentDelete",
        "cache", "speakText", "speakSpeed", "message", "webSocketState",
        "_wsMessageType", "_wsMessageText", "_wsMessageCount", "_wsByteAt",
        "_wsUInt16BE", "_wsUtf8", "_wsBase64", "_wsStateJSON", "_wsAction",
        "__javaNative", "book", "chapter",
    ]

    // MARK: - 实例字段（伪代码初始化表达式 L35-L184）

    var url: String = ""
    var baseUrl: String = ""
    var ruleUrl: String
    let source: BookSource?
    var sourceKey: String
    var sourceName: String
    var page: Int = 1
    var method: String = "GET"
    var headers: [String: String] = [:]
    var body: String?
    var charset: String = "utf-8"
    var useWebView = false
    var retry = 0
    var webViewDelayTime = 0
    var forceRefreshRequest = false
    var variableMap: [String: String] = [:]
    var requestContextVariables: [String: String] = [:]
    var suppressRequestWhenResolvedUrlIsEmpty = false
    var webJs: String?
    var sourceRegex: String?

    /// 伪代码 L197-230：实例 JS 上下文。
    private var ownedJSContext: JSContext?
    private let contextLock = NSLock()

    init(
        ruleUrl: String,
        key: String?,
        page: Int,
        baseUrl: String,
        source: BookSource? = nil
    ) {
        // 伪代码 0x100083c54（L634-668）。
        self.ruleUrl = ruleUrl
        self.source = source
        self.sourceKey = key ?? ""
        self.sourceName = key ?? ""
        self.page = page
        self.baseUrl = Self.cleanBaseUrl(baseUrl)
        self.url = ruleUrl
        parseUrl()
    }

    /// 伪代码 0x100084860（L670-677）。
    func applyResponseOptions(webJs: String?, sourceRegex: String?) {
        self.webJs = webJs
        self.sourceRegex = sourceRegex
    }

    /// 伪代码 0x10008461c（L680-697）：baseUrl 清洗。
    static func cleanBaseUrl(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("//") {
            return "https:" + trimmed
        }
        return trimmed
    }

    // MARK: - 请求上下文

    /// 伪代码 0x100080490（L61-68）/0x100080600（L70-84）。
    static func requestContextJSONString(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func requestContextStringValue(_ value: Any) -> String? {
        if let string = value as? String {
            return string
        }
        return requestContextJSONString(value)
    }

    /// 伪代码 0x1000807ac（L86-107）。
    func updateRequestContextVariables(from updates: [String: String]) {
        for (key, value) in updates {
            requestContextVariables[key] = value
        }
    }

    /// 伪代码 0x100080d5c（L110-112）。
    func setExtraHeaders(_ extra: [String: String]) {
        for (key, value) in extra {
            headers[key] = value
        }
    }

    // MARK: - JS 上下文

    /// 伪代码 0x1000811c0（L197-230）。
    func jsContext() -> JSContext {
        contextLock.lock()
        defer { contextLock.unlock() }
        if let owned = ownedJSContext {
            return owned
        }
        let context = JSContextPool.acquire()
        setupJSContext(context)
        ownedJSContext = context
        return context
    }

    /// 伪代码 0x1000814d0（L253-270）/0x100081518（L272-275）。
    func releaseOwnedJSContext() {
        contextLock.lock()
        defer { contextLock.unlock() }
        guard let owned = ownedJSContext else { return }
        JSContextPool.release(owned)
        ownedJSContext = nil
    }

    func endJSContextScope() {
        releaseOwnedJSContext()
    }

    deinit { releaseOwnedJSContext() }

    // MARK: - URL 解析

    /// 伪代码 0x100084b88（L712-939）：URL 规则解析主入口（主干顺序见读后记推断 1）。
    func parseUrl() {
        var working = ruleUrl

        // 事实 9：JS 前缀剥离。
        working = Self.processJsPrefix(working)

        // T-1601-B4：搜索关键字替换（legado `{{key}}` → URL 编码关键字）。
        // 必须在 `{{...}}` JS 表达式求值之前完成；否则 key 会按未定义
        // JS 变量求值为空，搜索 URL 丢失关键字。
        if working.contains("{{key}}") || working.contains("{{Key}}") {
            let encoded = keyEncoded()
            working = working
                .replacingOccurrences(of: "{{key}}", with: encoded)
                .replacingOccurrences(of: "{{Key}}", with: encoded)
        }

        // 事实 9：`{{...}}` 表达式求值。
        working = evaluateJsExpressions(working) ?? working

        // 事实 9：page 替换。
        working = Self.replacePagePatterns(working, page: page)
        working = evaluatePageExpressions(working) ?? working

        // 事实 10：JSON 配置段。
        parseJsonConfig(working)

        // 事实 10：初始头。
        loadInitialHeaders()
        parseHeaders(headersJson)

        // 事实 9：相对 URL 解析。
        url = working
        resolvedUrl = ""
        resolveRelativeUrl()
        url = resolvedUrl.isEmpty ? working : resolvedUrl
        if url.isEmpty, suppressRequestWhenResolvedUrlIsEmpty {
            Logger.log(
                "[AnalyzeUrlTrace] init-start resolved empty, suppressed",
                level: Self.analyzeUrlLogLevel
            )
        }
    }

    private var headersJson: String = ""
    private var resolvedUrl: String = ""

    /// 伪代码 0x10008a050（L1324-1353）：JS 前缀剥离。
    static func processJsPrefix(_ rule: String) -> String {
        let lowered = rule.lowercased()
        if lowered.hasPrefix("@js:") {
            return String(rule.dropFirst("@js:".count))
        }
        if lowered.hasPrefix("<js>") {
            var body = rule.dropFirst("<js>".count)
            if body.lowercased().hasSuffix("</js>") {
                body = body.dropLast("</js>".count)
            }
            return String(body)
        }
        return rule
    }

    /// 伪代码 0x10008a42c（L1358-1394）：`{{page}}`/`searchPage` 页码替换。
    static func replacePagePatterns(_ rule: String, page: Int) -> String {
        var result = rule
        let patterns = ["{{page}}", "$page", "searchPage"]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: String(page))
        }
        return result
    }

    /// 伪代码 0x10008a9b4（L1400-1437）：`<analyze-url-page-expr>` 求值。
    func evaluatePageExpressions(_ rule: String) -> String? {
        guard rule.contains("<analyze-url-page-expr>") else { return rule }
        let expression = rule.replacingOccurrences(
            of: "<analyze-url-page-expr>", with: String(page)
        )
        return evaluateJsExpressions(expression) ?? expression
    }

    /// 伪代码 0x10008b060（L1440-1471）：`##` 后缀剥离（URL 侧）。
    static func removeUrlSuffix(_ rule: String) -> String {
        guard let range = rule.range(of: "##") else { return rule }
        return String(rule[rule.startIndex..<range.lowerBound])
    }

    /// 伪代码 0x10008b37c（L1475-1594）：`{{...}}` 表达式逐段求值。
    func evaluateJsExpressions(_ rule: String) -> String? {
        var result = ""
        var searchStart = rule.startIndex
        while let openRange = rule.range(of: "{{", range: searchStart..<rule.endIndex) {
            result += String(rule[searchStart..<openRange.lowerBound])
            guard let closeRange = rule.range(
                of: "}}", range: openRange.upperBound..<rule.endIndex
            ) else {
                result += String(rule[openRange.lowerBound...])
                searchStart = rule.endIndex
                break
            }
            let expression = String(rule[openRange.upperBound..<closeRange.lowerBound])
            let context = jsContext()
            let evaluated = safeEvaluateScript(expression, in: context)
            if let evaluated, !evaluated.isUndefined, !evaluated.isNull,
               let text = evaluated.toString(), text != "undefined" {
                result += text
            } else {
                Logger.log(
                    "[evaluateJsExpr] \(expression) replacing with empty (nil, JS exception?)",
                    level: Self.analyzeUrlLogLevel
                )
            }
            searchStart = closeRange.upperBound
        }
        if searchStart < rule.endIndex {
            result += String(rule[searchStart...])
        }
        return result
    }

    /// 伪代码 0x10008cb8c（L1597-1609）。
    private func safeEvaluateScript(_ script: String, in context: JSContext) -> JSValue? {
        context.exception = nil
        let value = context.evaluateScript(script)
        if let exception = context.exception {
            Logger.log(
                "[evaluateJsExpr] exception: \(exception)",
                level: Self.analyzeUrlLogLevel
            )
        }
        return value
    }

    /// 伪代码 0x100087b2c（L1124-1192）：JS URL 求值（`@js:` 全段）。
    func executeJsUrl(_ script: String, withResult: Any?) -> String? {
        let context = jsContext()
        if let withResult {
            setJavaScriptResultVariable(withResult, in: context)
        }
        let evaluated = context.evaluateScript(script)
        guard let evaluated, let text = evaluated.toString(), text != "undefined" else {
            return nil
        }
        return text
    }

    /// 伪代码 0x100086734（L941-981）。
    func setJavaScriptResultVariable(_ value: Any?, in context: JSContext) {
        context.setObject(value ?? NSNull(), forKeyedSubscript: "result" as NSString)
    }

    // MARK: - TTS WebSocket

    /// 伪代码 0x10008861c（L1198-1321）：TTS WS 帧消息求值（事实 8）。
    /// `_ws*` 桥（byteAt/uint16BE/utf8/base64/stateJSON/action）+ onMessage 校验。
    func evaluateTtsWebSocketMessage(
        _ frame: HttpTtsWebSocketFrame,
        script: String
    ) -> String? {
        let context = jsContext()
        context.setObject(frame.messageType, forKeyedSubscript: "_wsMessageType" as NSString)
        context.setObject(frame.text ?? "", forKeyedSubscript: "_wsMessageText" as NSString)
        context.setObject(frame.messageCount, forKeyedSubscript: "_wsMessageCount" as NSString)
        context.setObject({ (index: Int) -> Int in
            frame.byteAt(index)
        }, forKeyedSubscript: "_wsByteAt" as NSString)
        context.setObject({ (offset: Int) -> Int in
            frame.uint16BE(at: offset)
        }, forKeyedSubscript: "_wsUInt16BE" as NSString)
        context.setObject({ (offset: Int, count: Int) -> String in
            frame.utf8(at: offset, count: count) ?? ""
        }, forKeyedSubscript: "_wsUtf8" as NSString)
        context.setObject({ (offset: Int, count: Int) -> String in
            frame.base64(at: offset, count: count) ?? ""
        }, forKeyedSubscript: "_wsBase64" as NSString)
        context.setObject(frame.stateJSON, forKeyedSubscript: "_wsStateJSON" as NSString)

        let evaluated = context.evaluateScript(script)
        guard let evaluated else { return nil }
        if evaluated.isNull || evaluated.isUndefined {
            return nil
        }
        guard evaluated.isObject else {
            Logger.log(
                "onMessage 必须返回对象、null 或 undefined",
                level: Self.analyzeUrlLogLevel
            )
            return nil
        }
        guard let audio = evaluated.objectForKeyedSubscript("audio"),
              let base64 = audio.toString(), !base64.isEmpty else {
            Logger.log(
                "onMessage 返回了无效的音频 Base64",
                level: Self.analyzeUrlLogLevel
            )
            return nil
        }
        return base64
    }

    // MARK: - 配置与头

    /// 伪代码 0x10008d854（L1698-1828）：JSON 配置段解析（method/headers/body/charset 等）。
    func parseJsonConfig(_ rule: String) {
        guard let open = rule.firstIndex(of: "{"),
              let close = rule.lastIndex(of: "}"), open < close else { return }
        let jsonText = String(rule[rule.index(after: open)...rule.index(before: close)])
        guard let data = jsonText.data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            Logger.log("JSON 解析失败: \(jsonText)", level: Self.analyzeUrlLogLevel)
            return
        }
        if let method = config["method"] as? String {
            self.method = method.uppercased()
        }
        if let charset = config["charset"] as? String {
            self.charset = charset
        }
        if let body = config["body"] as? String {
            self.body = body
        }
        if let webView = config["webView"] {
            self.useWebView = (webView as? Bool) ?? (webView as? String == "true")
                || (webView as? Int == 1)
        }
        if let retry = config["retry"] as? Int {
            self.retry = retry
        }
        headersJson = config["headers"] as? String ?? ""
    }

    private var headersJsonPlaceholder: String { headersJson }

    /// 伪代码 0x10008e698（L1831-1870）。
    func loadInitialHeaders() {
        if let source {
            var merged = LoginService.mergedHeaderMap(source: source, sourceHeaders: source.headerMap)
            for (key, value) in headers { LoginService.setHeader(key, value: value, in: &merged) }
            headers = merged
        } else if LoginService.headerValue(in: headers, named: "User-Agent") == nil {
            LoginService.setHeader("User-Agent", value: Self.defaultUserAgent, in: &headers)
        }
    }

    /// 伪代码 0x10008eb40（L1873-1913）：headers JSON/JS 解析。
    func parseHeaders(_ text: String) {
        guard !text.isEmpty else { return }
        if let data = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (key, value) in parsed {
                LoginService.setHeader(key, value: value, in: &headers)
            }
            return
        }
        Logger.log("请求头解析失败: \(text)", level: Self.analyzeUrlLogLevel)
    }

    /// 伪代码 0x10008d1f0（L1639-1695）：相对 URL 解析（formatUrl 同族）。
    func resolveRelativeUrl() {
        guard !baseUrl.isEmpty, !url.isEmpty else { return }
        if url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") {
            return
        }
        if url.hasPrefix("//") {
            url = "https:" + url
            return
        }
        guard let reference = URL(string: baseUrl) else { return }
        if url.hasPrefix("/") {
            var components = URLComponents()
            components.scheme = reference.scheme ?? "https"
            components.host = reference.host
            components.path = url
            resolvedUrl = components.url?.absoluteString ?? url
        } else {
            resolvedUrl = URL(string: url, relativeTo: reference)?.absoluteString ?? url
        }
    }

    /// 伪代码 0x10008cc68（L1622-1636）。
    func keyEncoded() -> String {
        Self.smartPercentEncode(sourceKey)
    }

}
