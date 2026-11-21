// 原路径: ReadMain/Core/SourceParser/ParagraphCommentParser.swift
// 证据:
//   - PGO: sourceImage(from:) (0x100163580 L17-29) / extractComments(from:source:) (0x100162560 L31-78) 等 5 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 选择子 escapedPatternForString:/rangeAtIndex:/replaceCharactersInRange:withString:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// 段落评论解析器（段评图片/文字提取）。
enum ParagraphCommentParser {

    struct ParagraphComment {
        var text: String
        var imageUrls: [String]
    }

    /// 伪代码 0x100163580（L17-29）：段评中的图片 URL。
    static func sourceImage(from comment: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<img[^>]+src=\"([^\"]+)\"")
        else { return nil }
        let range = NSRange(comment.startIndex..<comment.endIndex, in: comment)
        guard let match = regex.firstMatch(in: comment, options: [], range: range),
            match.numberOfRanges > 1,
            let sourceRange = Range(match.range(at: 1), in: comment)
        else { return nil }
        return String(comment[sourceRange])
    }

    /// 伪代码 0x100162560（L31-78）：段评提取。
    static func extractComments(from content: String, source: BookSource?) -> [ParagraphComment] {
        guard let regex = try? NSRegularExpression(
            pattern: "{{(?!.*\b(java|source)\b)[^}]*}}", options: []
        ) else { return [] }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        return matches.compactMap { match -> ParagraphComment? in
            guard match.numberOfRanges > 1,
                let expressionRange = Range(match.range(at: 1), in: content)
            else { return nil }
            let expression = String(content[expressionRange])
            let analyzer = AnalyzeRule.sharedInstance()
            guard let text = analyzer.getString(rule: expression, isUrl: false), !text.isEmpty
            else { return nil }
            return ParagraphComment(
                text: text,
                imageUrls: [sourceImage(from: text)].compactMap { $0 }
            )
        }
    }
}

extension ParagraphCommentParser {

    /// 伪代码 0x100163970（L80-87）：段评属性提取——img 标签内指定属性域。
    static func extractAttr(
        from comment: String, attribute: String
    ) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<img[^>]*\b\(attribute)=\"([^\"]+)\"") else {
            return nil
        }
        let range = NSRange(comment.startIndex..<comment.endIndex, in: comment)
        guard let match = regex.firstMatch(in: comment, options: [], range: range),
            match.numberOfRanges > 1,
            let valueRange = Range(match.range(at: 1), in: comment)
        else { return nil }
        return String(comment[valueRange])
    }
}

