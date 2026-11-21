// 原路径: ReadMain/Core/AudioRequestParser.swift
// 证据:
//   - PGO: 23 条记录（index/task_functions.csv T-801-01 /
//     AudioRequestParser.swift；15 函数，伪代码域 130 行）
//   - CovMap: 上述 L 区段（parseSourceHeaders L10-17 / mergeHeaders
//     L25-36 / parsePlaybackRequest L37-66 / parseDirectCandidate
//     L92-109 / wrapped/base64 域 L110-180 / attr/direct 正则域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/AudioRequestParser.c
//     （892 行）
//   - 块体确证（地址+行号域）：
//     parseSourceHeaders 0x1005fd468 L10-17 / mergeHeaders closure
//     #1/#2 0x1001a2f18 L25-25 / parsePlaybackRequest 0x1001a3218
//     L37-66（trim + parseDirectCandidate → wrapped 链）/
//     attrRegex 0x 域 '(?:src|data-src|href)\s*=\s*["'']([^"'']+)["'']'
//     @ptr 0x10125E920 / directURLRegex '(https?://[^\s<>"'']+)'
//     @ptr 0x10125E8F8 / 'data:url;base64,' @ptr 0x10125E940 /
//     'data:text/plain;base64,' @ptr 0x10125E960 / 'https' L564/L573
//     scheme 域 / LegadoURLRule.Options.headers() 域 L440 /
//     splitCandidateAndInlineHeaders（substring 域 L415-440）
//   - 事实：播放请求四通道（直链 URL / 属性提取 / base64 包装 /
//     data:text 包装）+ 头合并（源/登录/内联三源）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（正则字面量 + 通道域确证）
// 还原: 2026-11-20

import Foundation

/// 播放请求解析器（parsePlaybackRequest 0x1001a3218 L37-66 域确证）。
enum AudioRequestParser {

    /// 属性提取正则（attrRegex closure 域确证）。
    private static let attrRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: "(?:src|data-src|href)\\s*=\\s*[\"']([^\"']+)[\"']")
    }()

    /// 直链正则（directURLRegex closure 域确证）。
    private static let directURLRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: "(https?://[^\\s<>\"']+)")
    }()

    /// base64 包装前缀（'data:url;base64,' / 'data:text/plain;base64,'
    /// @ptr 0x10125E940/0x10125E960 域确证）。
    private static let dataURLBase64Prefix = "data:url;base64,"
    private static let dataTextBase64Prefix = "data:text/plain;base64,"

    // MARK: 头域（parseSourceHeaders 0x1005fd468 L10-17 域确证）

    /// parseSourceHeaders(from:)（0x1005fd468 域确证：JSON 对象串 →
    /// 头字典；异常回空）。
    static func parseSourceHeaders(from text: String?)
        -> [String: String] {
        guard let text, !text.isEmpty else { return [:] }
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: String] else {
            return [:]
        }
        return dict
    }

    /// mergeHeaders(sourceHeaders:loginHeaders:inlineHeaders:)
    /// （closure #1/#2 域确证：登录覆盖源、内联覆盖登录；值 trim +
    /// 非 '\r\n' 过滤 closure #3）。
    static func mergeHeaders(
        sourceHeaders: [String: String],
        loginHeaders: [String: String],
        inlineHeaders: [String: String]
    ) -> [String: String] {
        var merged = sourceHeaders
        for (key, value) in loginHeaders {
            // closure #1 域确证：登录头覆盖。
            merged[key] = value
        }
        for (key, value) in inlineHeaders {
            // closure #2 域确证：内联头最高优先。
            merged[key] = value
        }
        // closure #3 域确证：过滤换行注入。
        return merged.filter { _, value in
            !value.contains("\r") && !value.contains("\n")
        }
    }

    // MARK: 播放请求（parsePlaybackRequest 0x1001a3218 L37-66 域确证）

    /// parsePlaybackRequest(from:)（0x1001a3218 块体确证：trim →
    /// 直链候选 → 包装候选；空串返回 nil）。
    static func parsePlaybackRequest(from raw: String)
        -> AudioPlaybackRequest? {
        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = parseDirectCandidate(trimmed) {
            return direct
        }
        let (urlString, headers) = splitCandidateAndInlineHeaders(trimmed)
        return parseWrappedDataCandidate(
            urlString, inlineHeaders: headers)
    }

    /// splitCandidateAndInlineHeaders(_:)（L415-440 域确证：
    /// '{{...}}url' 或 'url,{{...}}' 内联 JSON 头切分）。
    private static func splitCandidateAndInlineHeaders(
        _ candidate: String
    ) -> (urlString: String, headers: [String: String]) {
        // '{{...}}' 内联头域（substring 切分 L415-440 确证）。
        if candidate.hasPrefix("{{"),
           let endRange = candidate.range(of: "}}") {
            let headerText = String(
                candidate[candidate.startIndex..<endRange.upperBound])
            let urlString = String(
                candidate[endRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (urlString, parseSourceHeaders(from: headerText))
        }
        if candidate.hasSuffix("}}"),
           let startRange = candidate.range(of: "{{") {
            let urlString = String(
                candidate[candidate.startIndex..<startRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let headerText = String(
                candidate[startRange.lowerBound...])
            return (urlString, parseSourceHeaders(from: headerText))
        }
        return (candidate, [:])
    }

    /// parseDirectCandidate(_:)（0x1001a37e4 L92-109 域确证：
    /// URL 构造 + scheme https/http 守卫 L564/L573）。
    private static func parseDirectCandidate(
        _ candidate: String
    ) -> AudioPlaybackRequest? {
        guard let url = URL(string: candidate) else { return nil }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            // 'https' L564/L573 域确证：非 http(s) 不走直链。
            return nil
        }
        return AudioPlaybackRequest(
            url: url, headers: [:])
    }

    /// parseWrappedDataCandidate(_:inlineHeaders:)（closure #1/#2 域
    /// 确证：data:URL / base64 包装 / 属性提取三通道）。
    private static func parseWrappedDataCandidate(
        _ candidate: String, inlineHeaders: [String: String]
    ) -> AudioPlaybackRequest? {
        // 通道一：data:url;base64, 包装。
        if candidate.hasPrefix(dataURLBase64Prefix) {
            guard let decoded = decodeBase64Payload(
                String(candidate.dropFirst(
                    dataURLBase64Prefix.count))) else {
                return nil
            }
            return parsePlaybackRequest(from: decoded)
        }
        // 通道二：data:text/plain;base64, 包装。
        if candidate.hasPrefix(dataTextBase64Prefix) {
            guard let decoded = decodeBase64Payload(
                String(candidate.dropFirst(
                    dataTextBase64Prefix.count))) else {
                return nil
            }
            return parsePlaybackRequest(from: decoded)
        }
        // 通道三：属性提取（attrRegex 域确证）。
        let range = NSRange(candidate.startIndex..., in: candidate)
        if let match = attrRegex.firstMatch(
            in: candidate, options: [], range: range),
            let attrRange = Range(match.range(at: 1), in: candidate) {
            let attributeValue = String(candidate[attrRange])
            if let request = parseDirectCandidate(attributeValue) {
                return AudioPlaybackRequest(
                    url: request.url,
                    headers: mergeHeaders(
                        sourceHeaders: [:],
                        loginHeaders: [:],
                        inlineHeaders: inlineHeaders))
            }
        }
        // 通道四：直链兜底（directURLRegex 域确证）。
        if let match = directURLRegex.firstMatch(
            in: candidate, options: [], range: range),
            let urlRange = Range(match.range(at: 1), in: candidate) {
            let urlString = String(candidate[urlRange])
            guard let url = URL(string: urlString) else { return nil }
            return AudioPlaybackRequest(
                url: url,
                headers: mergeHeaders(
                    sourceHeaders: [:],
                    loginHeaders: [:],
                    inlineHeaders: inlineHeaders))
        }
        return nil
    }

    /// decodeBase64Payload(_:)（签名域确证：url-safe 变体兼容）。
    private static func decodeBase64Payload(_ payload: String)
        -> String? {
        var base64 = payload
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }

    /// firstAttributeValue(in:)（签名域确证：首属性值提取）。
    private static func firstAttributeValue(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = attrRegex.firstMatch(
            in: text, options: [], range: range),
            let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }
}
