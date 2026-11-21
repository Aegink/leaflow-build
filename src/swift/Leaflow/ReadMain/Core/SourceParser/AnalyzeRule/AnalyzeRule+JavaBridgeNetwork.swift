// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JavaBridgeNetwork.swift
// 证据:
//   - PGO: resolvedSourceHeaderString(LL) (0x10003912c L26-92) / registerNetworkBridge (0x100038eac L96-424) 及 closure #1/#3
//   - CovMap: L26-92 @0x10003912c；L96-424 @0x100038eac
//   - IDA: 上述地址
//   - 诊断：[getSourceHeaders] resolved / Invalid URL:；选择子 currentThread/threadDictionary/__swift_objectForKeyedSubscript:/__swift_setObject:forKeyedSubscript:/statusCode/allHeaderFields
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（网络桥链确证；closure 键名见读后记仍不清楚）
// 还原: 2026-11-19


import Foundation

extension AnalyzeRule {

    /// 伪代码 0x10003912c（L26-92）：源级请求头解析。
    /// headers 为书源 headerMap（BookSource.headerMap 消费域，wave-16）。
    func resolvedSourceHeaderString() -> String {
        var resolved: [String: String] = [:]
        if let loginHeader = getVariable("loginHeader") {
            resolved["loginHeader"] = loginHeader
        }
        for (key, value) in source?.headerMap ?? [:] {
            resolved[key] = value
        }
        Logger.log(
            "[getSourceHeaders] resolved \(resolved.keys.joined(separator: ","))",
            level: .warning
        )
        if JSONSerialization.isValidJSONObject(resolved),
            let data = try? JSONSerialization.data(withJSONObject: resolved, options: []),
            let text = String(data: data, encoding: .utf8)
        {
            return text
        }
        return "{}"
    }

    /// 伪代码 0x100038eac（L96-424）：java 网络桥。
    func registerNetworkBridge() {
        let context = jsContextHandle()
        let network: [String: Any] = [
            "ajax": { (url: String) -> String in
                JsExtensions().ajax(url)
            },
            "ajaxAll": { (urls: [String]) -> [String] in
                JsExtensions().ajaxAll(urls)
            },
            "post": { (url: String, body: String, headers: [String: String]) -> String in
                JsExtensions().post(url, body, headers).body
            },
            "head": { (url: String, headers: [String: String]) -> String in
                JsExtensions().head(url, headers).body
            },
            "connect": { (url: String) -> String in
                JsExtensions().ajax(url)
            },
            "getWebViewUA": { () -> String in
                AnalyzeUrl.defaultUserAgent
            },
        ]
        for (key, value) in network {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
    }
}
