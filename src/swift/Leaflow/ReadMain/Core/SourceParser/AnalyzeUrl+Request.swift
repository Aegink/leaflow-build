// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl+Request.swift
// 证据:
//   - PGO: buildRequest / smartPercentEncode(LL) / formPercentEncodedComponent(LL) /
//     isAlreadyFormEncoded(LL) / isHexDigit / stringEncoding(forFormCharset:)(LL) / jsEscape(LL) /
//     debugCookieSummary(LL) / collectSourceVariableHosts(LL) / buildMultipartBody(LL) 及闭包
//   - CovMap: smartPercentEncode L26-62 @0x1000bba7c（closure#3 L40 @0x1000bbfd4）；
//     formPercentEncodedComponent L76-96 @0x1000bc404；isAlreadyFormEncoded L98-116 @0x1000bc85c
//     （closure L104 @0x1000bcf50）；isHexDigit L118-120 @0x1000bd000；stringEncoding L122-131
//     @0x1000bcd8c；jsEscape L133-147 @0x1000bca44；debugCookieSummary L149-165 @0x1000bd544；
//     collectSourceVariableHosts L180-204 @0x1000bd7e4；buildRequest L220-343 @0x1000b9da8；
//     buildMultipartBody L346-365 @0x1000bdfc8（closure L355 @0x1000bf240）
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - 诊断串：[buildRequest] 无效的 URL: / [HTTP-COOKIE-DIAG] stateKey= /
//     [HTTP] legado cookie host= / [HTTP] 自定义Headers( / finalLen= / merged= / names=[
//   - 头常量：User-Agent(0x6567412D72657355)、Cookie(0x65696B6F6F43)、content-type、
//     Cache-Control/Pragma: no-cache、charset=gbk(7037543)/gb2312(0x323133326267)、
//     Boundary(0x797261646E756F42)、name="file..."(0x6966223D656D616E)
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - buildRequest: high（编码/UA/Headers/Cookie/Content-Type/缓存策略链逐段确证）
//   - smartPercentEncode / isAlreadyFormEncoded / stringEncoding: medium-high
//   - buildMultipartBody / collectSourceVariableHosts: medium（边界与字段确证，细节未逐行）
// 还原: 2026-11-19

import Foundation

extension AnalyzeUrl {

    // MARK: - 编码

    /// 伪代码 0x1000bba7c（L26-62）：URL 智能百分号编码。
    /// 已编码段不动，未编码的保留字符合法字符。
    static func smartPercentEncode(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        if isAlreadyFormEncoded(value) {
            return value
        }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~") // 常量 45('-')/46('.')(95('_'))/126('~')
        allowed.insert(charactersIn: ":/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// 伪代码 0x1000bc404（L76-96）：表单组件编码（& , - = 为分隔保留，常量 38/44/45/61）。
    static func formPercentEncodedComponent(_ value: String, charset: String.Encoding) -> String? {
        guard let data = value.data(using: charset) else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._")
        return String(data: data, encoding: charset)?
            .addingPercentEncoding(withAllowedCharacters: allowed)
    }

    /// 伪代码 0x1000bc85c（L98-116）：是否已是编码形态（% + 两个 hex，closure @L104）。
    static func isAlreadyFormEncoded(_ value: String) -> Bool {
        var index = value.startIndex
        while let percentIndex = value[index...].firstIndex(of: "%") {
            let next = value.index(after: percentIndex)
            guard next < value.endIndex,
                  isHexDigit(value.utf8[value.utf8.index(value.utf8.startIndex, offsetBy: value.distance(from: value.startIndex, to: next))])
            else {
                return false
            }
            let after = value.index(after: next)
            guard after < value.endIndex,
                  isHexDigit(value.utf8[value.utf8.index(value.utf8.startIndex, offsetBy: value.distance(from: value.startIndex, to: after))])
            else {
                return false
            }
            index = value.index(after: after)
        }
        return value.contains("%")
    }

    /// 伪代码 0x1000bd000（L118-120）。
    static func isHexDigit(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x46)
            || (byte >= 0x61 && byte <= 0x66)
    }

    /// 伪代码 0x1000bcd8c（L122-131）：表单 charset → String.Encoding。
    static func stringEncoding(forFormCharset charset: String) -> String.Encoding {
        let lowered = charset.lowercased()
        if lowered == "gbk" || lowered == "gb2312" {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            ))
        }
        return .utf8
    }

    /// 伪代码 0x1000bca44（L133-147）：JS 风格转义。
    static func jsEscape(_ value: String) -> String {
        var result = ""
        for character in value {
            switch character {
            case "\\", "\"", "'":
                result.append("\\")
                result.append(character)
            case "\n":
                result.append("\\n")
            case "\r":
                result.append("\\r")
            case "\t":
                result.append("\\t")
            default:
                result.append(character)
            }
        }
        return result
    }

    /// 伪代码 0x1000bd544（L149-165）：cookie 调试摘要。
    static func debugCookieSummary(_ cookie: String?) -> String {
        guard let cookie, !cookie.isEmpty else { return "len=0" }
        return "len=\(cookie.count)"
    }

    // MARK: - 变量宿主收集

    /// 伪代码 0x1000bd7e4（L180-204）：从书源/变量收集宿主集合（sourceVariable_ 前缀）。
    static func collectSourceVariableHosts(from value: Any, into hosts: inout Set<String>) {
        if let dictionary = value as? [String: Any] {
            for key in dictionary.keys where key.hasPrefix("sourceVariable_") {
                hosts.insert(key)
            }
        }
    }

    // MARK: - 请求构建

    /// 伪代码 0x1000b9da8（L220-343）：请求构建主链。
    func buildRequest() -> URLRequest? {
        // 事实 1：两段编码 + URL 构造。
        let encoded = Self.smartPercentEncode(url)
        guard let target = URL(string: encoded) else {
            Logger.log("[buildRequest] 无效的 URL: \(url)", level: Self.requestLogLevel, anchor: 233)
            return nil
        }

        var request = URLRequest(url: target, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.httpMethod = method
        request.timeoutInterval = Self.userTimeout
        request.setValue(Self.defaultUserAgent, forHTTPHeaderField: "User-Agent")

        // 事实 1：自定义 Headers。
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if !headers.isEmpty {
            Logger.log(
                "[HTTP] 自定义Headers(\(headers.count)) names=[\(headers.keys.joined(separator: ","))]",
                level: Self.requestLogLevel,
                anchor: 260
            )
        }

        // 事实 2：Cookie 登记与诊断。
        if let cookie = request.value(forHTTPHeaderField: "Cookie") {
            Self.cookieSummaryCache.put(target.host ?? "", value: Self.debugCookieSummary(cookie))
            Logger.log(
                "[HTTP-COOKIE-DIAG] stateKey=\(target.host ?? "") [HTTP] legado cookie host=\(target.host ?? "") "
                    + "finalLen=\(cookie.count)",
                level: Self.requestLogLevel,
                anchor: 287
            )
        }

        // 事实 3：Content-Type 分支。
        let contentType = (headers["content-type"] ?? headers["Content-Type"] ?? "").lowercased()
        if let body {
            if contentType.contains("multipart/form-data") {
                let boundary = UUID().uuidString
                let multipart = Self.buildMultipartBody(body: body, boundary: boundary)
                request.setValue(
                    "multipart/form-data; boundary=\(boundary)",
                    forHTTPHeaderField: "Content-Type"
                )
                request.httpBody = multipart
            } else if body.hasPrefix("{") || body.hasPrefix("[") {
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = body.data(using: .utf8)
            } else {
                let charsetName = Self.charsetName(from: contentType)
                let encoding = Self.stringEncoding(forFormCharset: charsetName)
                if charsetName == "gbk" || charsetName == "gb2312" {
                    request.setValue(
                        "application/x-www-form-urlencoded; charset=\(charsetName)",
                        forHTTPHeaderField: "Content-Type"
                    )
                } else {
                    request.setValue(
                        "application/x-www-form-urlencoded; charset=utf-8",
                        forHTTPHeaderField: "Content-Type"
                    )
                }
                request.httpBody = body.data(using: encoding)
            }
        }

        // 事实 4：强刷分支。
        if forceRefreshRequest {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        }
        return request
    }

    /// 伪代码 0x1000bdfc8（L346-365）：multipart 体组装（name="file..." 字段）。
    static func buildMultipartBody(body: String, boundary: String) -> Data {
        var data = Data()
        for part in body.split(separator: "\n", omittingEmptySubsequences: false) {
            data.append(Data("--\(boundary)\r\n".utf8))
            data.append(Data(part.utf8))
            data.append(Data("\r\n".utf8))
        }
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }

    /// buildRequest 的 charset 名抽取。
    private static func charsetName(from contentType: String) -> String {
        guard let range = contentType.range(of: "charset=") else { return "utf-8" }
        return String(contentType[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 静态支撑

extension AnalyzeUrl {

    static let requestLogLevel: Int = 2
    /// 伪代码：NetworkConstants.userTimeout（URLRequest.timeoutInterval setter 输入）。
    static let userTimeout: TimeInterval = 60.0
    static let defaultUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    /// 事实 2 的 Cookie 摘要缓存（LRUCache.put）。
    static let cookieSummaryCache = LRUCache<String, String>(maxSize: 32)
}
