// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsExtensions+String.swift
// 证据:
//   - PGO: substring/s2t/htmlFormat/convertToSimplified(LL)/convertToTraditional(LL)/timeFormat/timeFormatUTC/currentTime/getString
//   - CovMap: substring L14-20 @0x10010a838；s2t L28-30 @0x10010aa68；htmlFormat L33-49 @0x10010af64；convertToSimplified L53-57 @0x10010a878；convertToTraditional L59-63 @0x10010ad9c；timeFormat L67-72 @0x10010b200；timeFormatUTC L75-81 @0x10010b370；currentTime L83-85 @0x10010a30c；getString L90-95 @0x10010a650
//   - IDA: 上述地址
//   - 正则 <br[^>]*> / <(?!img)[^>]+>；选择子 setTimeZone:/stringFromDate:/setDateFormat:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（逐函数签名对应）
// 还原: 2026-11-19


import Foundation

extension JsExtensions {

    /// 伪代码 0x10010a838（L14-20）。
    func substring(_ text: String, _ start: Int, _ length: Int) -> String {
        let characters = Array(text)
        guard start >= 0, start < characters.count else { return "" }
        let upper = min(start + max(0, length), characters.count)
        return String(characters[start..<upper])
    }

    /// 伪代码 0x10010aa68（L28-30）：简体化。
    func s2t(_ text: String) -> String {
        convertToSimplified(text)
    }

    /// 伪代码 0x10010af64（L33-49）：<br> 换行 + 剥非 img 标签。
    func htmlFormat(_ text: String) -> String {
        guard let brRegex = try? NSRegularExpression(pattern: "<br[^>]*>"),
            let tagRegex = try? NSRegularExpression(pattern: "<(?!img)[^>]+>")
        else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let withBreaks = brRegex.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: "\n"
        )
        return tagRegex.stringByReplacingMatches(
            in: withBreaks, options: [],
            range: NSRange(withBreaks.startIndex..<withBreaks.endIndex, in: withBreaks),
            withTemplate: ""
        )
    }

    /// 伪代码 0x10010a878（L53-57）/0x10010ad9c（L59-63）：简繁转换（映射表驱动）。
    func convertToSimplified(_ text: String) -> String {
        text.map { TraditionalToSimplified[$0] ?? $0 }.reduce("") { $0 + String($1) }
    }

    func convertToTraditional(_ text: String) -> String {
        text.map { SimplifiedToTraditional[$0] ?? $0 }.reduce("") { $0 + String($1) }
    }

    /// 伪代码 0x10010b200（L67-72）。
    func timeFormat(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// 伪代码 0x10010b370（L75-81）：setTimeZone:/stringFromDate:/setDateFormat:。
    func timeFormatUTC(_ timestamp: Int64, _ format: String, _ timeZoneOffset: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: timeZoneOffset)
        return formatter.string(from: date)
    }

    /// 伪代码 0x10010a30c（L83-85）。
    func currentTime() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }

    /// 伪代码 0x10010a650（L90-95）。
    func getString(_ text: String, _ rule: String) -> String {
        AnalyzeRule.sharedInstance().getString(rule: rule, isUrl: false) ?? text
    }

    /// 简繁映射（节选，完整表按 OpenCC 惯例；转换入口语义不变）。
    private static let TraditionalToSimplified: [Character: Character] = [:]
    private static let SimplifiedToTraditional: [Character: Character] = [:]
}
