// 原路径: ReadMain/Services/ReadAloud/HttpTtsSynthesizer.swift。
// 0x100280650：AnalyzeUrl接收speakText/speakSpeed/HttpTts/runtimeStore后构造请求。
import Foundation
import JavaScriptCore

extension HttpTtsSynthesizer {
    struct PreparedRequest {
        let request: URLRequest
        let webSocket: HttpTtsWebSocketConfiguration?
    }

    static func makeRequest(source: HttpTts, text: String, speed: Int,
                            store: HttpTtsRuntimeStore) throws -> URLRequest {
        try prepareRequest(source: source, text: text, speed: speed, store: store).request
    }

    static func prepareRequest(source: HttpTts, text: String, speed: Int,
                               store: HttpTtsRuntimeStore) throws -> PreparedRequest {
        try HttpTtsLoginConfigurationEvaluator(store: store).prepareDefaultsIfNeeded(for: source, store: store)
        let analyzer = AnalyzeUrl(ruleUrl: "", key: nil, page: 1, baseUrl: "", isolatedJavaScript: true)
        defer { analyzer.releaseOwnedJSContext() }
        let context = analyzer.jsContext()
        context.exception = nil
        var scriptError: String?
        context.exceptionHandler = { _, error in scriptError = error?.toString() ?? "脚本异常" }
        context.setObject(text, forKeyedSubscript: "speakText" as NSString)
        context.setObject(speed, forKeyedSubscript: "speakSpeed" as NSString)
        context.objectForKeyedSubscript("java")?.setValue(text, forProperty: "speakText")
        context.objectForKeyedSubscript("java")?.setValue(speed, forProperty: "speakSpeed")
        JsBridgeTemplates.registerHttpTtsSourceBridge(in: context, source: source, runtimeStore: store)
        var webSocket: HttpTtsWebSocketConfiguration?
        var webSocketError: Error?
        let configure: @convention(block) (JSValue) -> String = { value in
            do {
                let config = try HttpTtsWebSocketConfiguration(javaScriptValue: value)
                webSocket = config
                return config.url.absoluteString
            } catch { webSocketError = error; return "" }
        }
        context.objectForKeyedSubscript("java")?.setValue(configure, forProperty: "webSocket")
        if let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
            guard scriptError == nil, context.exception == nil else { throw AppError.parsing("朗读源脚本库执行失败") }
        }
        var sourceHeaders: [String: String] = [:]
        if let header = source.header, !header.isEmpty {
            let raw: String
            if header.lowercased().hasPrefix("@js:") || header.lowercased().hasPrefix("<js>") {
                context.exception = nil
                let value = context.evaluateScript(AnalyzeUrl.processJsPrefix(header))
                guard scriptError == nil, context.exception == nil else { throw AppError.parsing("朗读请求头脚本执行失败") }
                if let map = value?.toDictionary() as? [String: String] {
                    sourceHeaders = map
                    raw = ""
                } else { raw = value?.toString() ?? "" }
            } else { raw = header }
            if !raw.isEmpty {
                guard let map = LoginService.parseLoginHeaderMap(from: raw) else {
                    throw AppError.parsing("朗读请求头不是有效JSON对象")
                }
                sourceHeaders = map
            }
        }
        for (key, value) in LoginService.parseLoginHeaderMap(from: store.loginHeader(sourceID: source.id)) ?? [:] {
            LoginService.setHeader(key, value: value, in: &sourceHeaders)
        }
        analyzer.headers = sourceHeaders
        analyzer.ruleUrl = source.url
        analyzer.parseUrl()
        if let scriptError { throw AppError.parsing("朗读请求脚本执行失败：\(scriptError)") }
        if let webSocketError { throw webSocketError }
        if let webSocket {
            analyzer.url = webSocket.url.absoluteString
            analyzer.setExtraHeaders(webSocket.headers)
        }
        guard analyzer.urlParseError == nil else {
            throw AppError.parsing(analyzer.urlParseError ?? "朗读请求规则解析失败")
        }
        guard var request = analyzer.buildRequest(), let url = request.url,
              (webSocket == nil ? ["http", "https"] : ["ws", "wss"]).contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false else {
            throw URLRequestError.invalidUrl
        }
        if source.enabledCookieJar == false {
            request.httpShouldHandleCookies = false
            if LoginService.headerValue(in: analyzer.headers, named: "Cookie") == nil {
                request.setValue(nil, forHTTPHeaderField: "Cookie")
            }
        }
        return PreparedRequest(request: request, webSocket: webSocket)
    }
}
