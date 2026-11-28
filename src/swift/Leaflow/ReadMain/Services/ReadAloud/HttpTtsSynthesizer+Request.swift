// 原路径: ReadMain/Services/ReadAloud/HttpTtsSynthesizer.swift。
// 0x100280650：AnalyzeUrl接收speakText/speakSpeed/HttpTts/runtimeStore后构造请求。
import Foundation
import JavaScriptCore

extension HttpTtsSynthesizer {
    static func makeRequest(source: HttpTts, text: String, speed: Int,
                            store: HttpTtsRuntimeStore) throws -> URLRequest {
        let analyzer = AnalyzeUrl(ruleUrl: "", key: nil, page: 1, baseUrl: "", isolatedJavaScript: true)
        defer { analyzer.releaseOwnedJSContext() }
        let context = analyzer.jsContext()
        context.exception = nil
        context.setObject(text, forKeyedSubscript: "speakText" as NSString)
        context.setObject(speed, forKeyedSubscript: "speakSpeed" as NSString)
        context.objectForKeyedSubscript("java")?.setValue(text, forProperty: "speakText")
        context.objectForKeyedSubscript("java")?.setValue(speed, forProperty: "speakSpeed")
        let sourceObject = JSValue(newObjectIn: context)!
        sourceObject.setValue(source.id, forProperty: "id")
        sourceObject.setValue(source.name, forProperty: "name")
        sourceObject.setValue(source.url, forProperty: "url")
        let loginInfo: @convention(block) () -> String = { store.loginInfo(sourceID: source.id) ?? "" }
        let loginMap: @convention(block) () -> [String: String] = { store.loginInfoMap(sourceID: source.id) }
        sourceObject.setValue(loginInfo, forProperty: "getLoginInfo")
        sourceObject.setValue(loginMap, forProperty: "getLoginInfoMap")
        context.setObject(sourceObject, forKeyedSubscript: "source" as NSString)
        if let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
            guard context.exception == nil else { throw AppError.parsing("朗读源脚本库执行失败") }
        }
        var sourceHeaders: [String: String] = [:]
        if let header = source.header, !header.isEmpty {
            let raw: String
            if header.lowercased().hasPrefix("@js:") || header.lowercased().hasPrefix("<js>") {
                context.exception = nil
                let value = context.evaluateScript(AnalyzeUrl.processJsPrefix(header))
                guard context.exception == nil else { throw AppError.parsing("朗读请求头脚本执行失败") }
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
        guard analyzer.urlParseError == nil else {
            throw AppError.parsing(analyzer.urlParseError ?? "朗读请求规则解析失败")
        }
        guard var request = analyzer.buildRequest(), let url = request.url,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.isEmpty == false else {
            throw URLRequestError.invalidUrl
        }
        if source.enabledCookieJar == false {
            request.httpShouldHandleCookies = false
            if LoginService.headerValue(in: analyzer.headers, named: "Cookie") == nil {
                request.setValue(nil, forHTTPHeaderField: "Cookie")
            }
        }
        return request
    }
}
