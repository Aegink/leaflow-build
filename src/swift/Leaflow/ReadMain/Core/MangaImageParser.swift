// 原路径: ReadMain/Core/MangaImageParser.swift
// 证据:
//   - PGO: 4 个主函数（index/task_functions.csv T-304-01 / MangaImageParser.swift），
//     地址：extractImageURLs(from:) 0x1001e4d08 L14-43（matchesInString:options:
//     range: 确证）/ extractSrcValue(from:) 0x1001e51a4 L58-82 / isValidImageURL
//     0x1001e565c L84-93（+closure #5 0x1001e5a88 L89）—— 正则匹配 + trim 链
//     （whitespacesAndNewlines.trimmingCharacters L2419-2460 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/MangaImageParser.c（271 行）
//   - 事实：extractImageURLs —— img 标签正则匹配（matchesInString 确证）→
//     逐 match 提取 src/data-src → trim → isValidImageURL 过滤；
//     extractSrcValue —— 单 match 内 src 属性串；isValidImageURL ——
//     http(s) 前缀判定
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（正则匹配/trim/过滤链确证；正则串待真机对照）
// 还原: 2026-11-19

import Foundation

/// 漫画图片 URL 解析器（img 标签 src 提取）。
enum MangaImageParser {

    /// img 标签正则（matchesInString 调用确证；模式串待真机对照）。
    private static let imageTagRegex = try? NSRegularExpression(
        pattern: "<img[^>]+>",
        options: [.caseInsensitive])

    /// src/data-src 属性正则。
    private static let srcRegex = try? NSRegularExpression(
        pattern: "(?:data-src|src)\\s*=\\s*[\"']([^\"']+)[\"']",
        options: [.caseInsensitive])

    /// 伪代码 0x1001e4d08（L14-43）：从正文提取图片 URL 列表。
    /// matchesInString → 逐 match extractSrcValue → trim → isValidImageURL 过滤。
    static func extractImageURLs(from content: String) -> [String] {
        guard let tagRegex = imageTagRegex else { return [] }
        let nsContent = content as NSString
        let tagMatches = tagRegex.matches(
            in: content, options: [],
            range: NSRange(location: 0, length: nsContent.length))
        var urls: [String] = []
        for match in tagMatches {
            let tag = nsContent.substring(with: match.range)
            guard let src = extractSrcValue(from: tag) else { continue }
            let trimmed = src.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidImageURL(trimmed) else { continue }
            urls.append(trimmed)
        }
        return urls
    }

    /// 伪代码 0x1001e51a4（L58-82）：单标签内 src/data-src 提取。
    static func extractSrcValue(from tag: String) -> String? {
        guard let srcRegex else { return nil }
        let nsTag = tag as NSString
        guard let match = srcRegex.firstMatch(
            in: tag, options: [],
            range: NSRange(location: 0, length: nsTag.length)) else { return nil }
        guard match.numberOfRanges > 1,
              match.range(at: 1).location != NSNotFound else { return nil }
        return nsTag.substring(with: match.range(at: 1))
    }

    /// 伪代码 0x1001e565c（L84-93）：URL 有效性（http 前缀判定）。
    static func isValidImageURL(_ url: String) -> Bool {
        url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://")
    }
}
