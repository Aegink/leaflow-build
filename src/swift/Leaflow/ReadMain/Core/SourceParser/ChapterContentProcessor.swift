// 原路径: ReadMain/Core/SourceParser/ChapterContentProcessor.swift
// 证据:
//   - PGO: formatContent (0x1000cab6c L57-132) / normalizeImageTags (0x1000cb584 L134-148) / normalizedImageTag (0x1000cb834 L155-162) / extractImageSource (0x1000cba44 L164-217) 等 10 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 选择子 matchesInString:options:range:/replaceMatchesInString:options:range:withTemplate:/replaceCharactersInRange:withString:/setNumberStyle:/setLocale:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（净化主链确证；规则顺序见读后记仍不清楚 2）
// 还原: 2026-11-19


import Foundation

/// 正文内容处理器。
enum ChapterContentProcessor {

    /// 伪代码 0x1000cab6c（L57-132）：正文净化主链。
    static func formatContent(_ content: String, redirectUrl: String?) -> String {
        var text = content
        text = normalizeImageTags(text, redirectUrl: redirectUrl)
        // 段落重排：连续空行合并。
        text = text.replacingOccurrences(
            of: "\n{3,}", with: "\n\n", options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 伪代码 0x1000cb584（L134-148）。
    /// stringByReplacingMatches 仅接受模板串——闭包替换改走
    /// enumerateMatches + NSMutableString（wave-16）。
    static func normalizeImageTags(_ content: String, redirectUrl: String?) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<img[^>]+src=\"([^\"]+)\"[^>]*>")
        else { return content }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let mutable = NSMutableString(string: content)
        regex.enumerateMatches(
            in: content, options: [], range: range
        ) { match, _, _ in
            guard let match,
                  let source = extractImageSource(from: match, in: content)
            else { return }
            let resolved = redirectUrl.map { resolveRelative(source, base: $0) }
                ?? source
            mutable.replaceCharacters(
                in: match.range, with: "<img src=\"\(resolved)\">")
        }
        return mutable as String
    }

    /// 伪代码 0x1000cb834（L155-162）。
    private static func normalizedImageTag(_ source: String) -> String {
        "<img src=\"\(source)\">"
    }

    /// 伪代码 0x1000cba44（L164-217）。
    private static func extractImageSource(from match: NSTextCheckingResult, in text: String) -> String? {
        guard match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func resolveRelative(_ path: String, base: String) -> String {
        if path.hasPrefix("http") { return path }
        return URL(string: path, relativeTo: URL(string: base))?.absoluteString ?? path
    }
}

// MARK: - T-1401-13 逐域补齐（内容处理域）

extension ChapterContentProcessor {

    /// 伪代码 0x1000ccad8（L297-321）：字数格式化（万/千档位域）。
    static func formatWordCount(_ count: Int) -> String {
        if count >= 10_000 {
            let value = Double(count) / 10_000.0
            return value >= 100
                ? "\(Int(value))万字"
                : String(format: "%.1f万字", value)
        }
        if count >= 1_000 {
            let value = Double(count) / 1_000.0
            return String(format: "%.1f千字", value)
        }
        return "\(count)字"
    }

    /// 伪代码 0x1000cd200（L324-333）：书籍字段格式化（作者/分类域）。
    static func formatBookField(_ field: String?) -> String {
        guard let field, !field.trimmingCharacters(
            in: .whitespacesAndNewlines).isEmpty else {
            return "未知"
        }
        return field
    }

    /// 伪代码 0x1000cd318（L354-359）：替换净化规则应用（ReplaceRule 域）。
    static func applyReplaceRules(_ content: String, rules: [ReplaceRule]) -> String {
        ReplaceRuleService.shared.applyRules(to: content, bookName: nil)
    }

    /// 伪代码 0x100151100（L373-384）：重叠区间查找（去重域）。
    static func findOverlap(_ a: String, _ b: String, limit: Int) -> Int {
        let maxCheck = min(min(a.count, b.count), limit)
        var best = 0
        for length in stride(from: maxCheck, through: 1, by: -1) {
            let aSuffix = a.suffix(length)
            let bPrefix = b.prefix(length)
            if aSuffix == bPrefix {
                best = length
                break
            }
        }
        return best
    }
}

extension ReplaceRuleService {

    /// 共享实例（applyReplaceRules 消费域）。
    static let shared = ReplaceRuleService()
}
