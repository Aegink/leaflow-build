// 原路径: ReadMain/Core/HighlightRule.swift
// 证据:
//   - PGO: 22 个主函数（index/task_functions.csv T-303-02 / HighlightRule.swift），
//     地址：init(id:name:regex:...18参) 0x1001d42d0 L55-74 / init(from:)
//     0x1001d18a8 L96-121（decodeIfPresent 长链） / encode 0x1001d2310 L123-142 /
//     resolvedFont 0x1001d2d24 L227-258（closure #3/#4） / layoutFontFamily
//     0x1001d3304 L219-221 / fontWeightOverride 0x1001d345c L223-225 /
//     builtinRule(for:) 0x1001d3a98 L327-329 / mergedWithBuiltinRules
//     0x1001d6a3c L331-339 / resettingBuiltinRules 0x1001d6be8 L341-344
//     (+closure 0x1001d6bc0) / isBuiltin 0x1001d6ba0 L261 / builtinDefault
//     0x1001dcc70（变量初始化）/ darkColor.setter 0x1006f36a8 L42 /
//     CompiledHighlightRule.attributes(isDark:) 0x1001d495c L354-356 /
//     ReaderRegexHighlightApplier.apply(to:text:rules:isDark:includeAttributes:
//     applyCrossPageQuotes:) 0x1001d69b4 L367-387 / highlightRanges(in:regex:
//     crossPageQuotes:noCrossParagraph:) 0x1001d52c4 L402-430（matchesInString:
//     确证）/ crossPageQuoteRanges 0x1001d5914 L460-483（rangeOfCharacterFromSet: 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/HighlightRule.c
//   - 事实：HighlightRule —— 18 参 init（签名确证：id/name/regex/lightColorHex/
//     darkColorHex/enabled/crossPageQuotes/noCrossParagraph/fontFamily/fontSize/
//     fontWeight/lightStyleCSS/darkStyleCSS/light·darkBackgroundImageURL/Layout）；
//     decode 长链 decodeIfPresent（L305-L464 约 17 字段）；applier ——
//     matchesInString → crossPageQuoteRanges（括号配对）→ 合并去重
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - init/decode/encode: high（签名+decodeIfPresent 链确证）
//   - resolvedFont/applier: high（调用确证）
//   - builtin 规则集: medium（内置集合内容待真机对照）
// 还原: 2026-11-19

import Foundation
extension HighlightRule {

    /// 伪代码 0x1006f36a8（L42）：darkColor 桥（State 域 0x184 HighlightRule
    /// 拷贝确证；块体与 HighlightRulesView 滑杆权重域交错——0.62/0.8 分母域
    /// 归滑杆侧）；computed setter 桥接 darkColorHex。
    var darkColor: Color {
        get { Color(hex: darkColorHex) }
        set { darkColorHex = newValue.toHex() }
    }
}

import SwiftUI
import UIKit

/// 正则高亮规则（18 参 init 签名确证）。
struct HighlightRule: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var regex: String
    var lightColorHex: String
    var darkColorHex: String
    var enabled: Bool
    var crossPageQuotes: Bool
    var noCrossParagraph: Bool
    var fontFamily: String
    var fontSize: CGFloat
    var fontWeight: CGFloat?
    var lightStyleCSS: String
    var darkStyleCSS: String
    var lightBackgroundImageURL: String
    var darkBackgroundImageURL: String
    var lightBackgroundImageLayout: HighlightBackgroundImageLayout
    var darkBackgroundImageLayout: HighlightBackgroundImageLayout

    /// 伪代码 0x1001d42d0（L55-74）：18 参全量构造（签名确证）。
    init(
        id: String, name: String, regex: String,
        lightColorHex: String, darkColorHex: String,
        enabled: Bool, crossPageQuotes: Bool, noCrossParagraph: Bool,
        fontFamily: String, fontSize: CGFloat, fontWeight: CGFloat?,
        lightStyleCSS: String, darkStyleCSS: String,
        lightBackgroundImageURL: String, darkBackgroundImageURL: String,
        lightBackgroundImageLayout: HighlightBackgroundImageLayout,
        darkBackgroundImageLayout: HighlightBackgroundImageLayout
    ) {
        self.id = id
        self.name = name
        self.regex = regex
        self.lightColorHex = lightColorHex
        self.darkColorHex = darkColorHex
        self.enabled = enabled
        self.crossPageQuotes = crossPageQuotes
        self.noCrossParagraph = noCrossParagraph
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lightStyleCSS = lightStyleCSS
        self.darkStyleCSS = darkStyleCSS
        self.lightBackgroundImageURL = lightBackgroundImageURL
        self.darkBackgroundImageURL = darkBackgroundImageURL
        self.lightBackgroundImageLayout = lightBackgroundImageLayout
        self.darkBackgroundImageLayout = darkBackgroundImageLayout
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, regex, lightColorHex, darkColorHex, enabled
        case crossPageQuotes, noCrossParagraph, fontFamily, fontSize, fontWeight
        case lightStyleCSS, darkStyleCSS
        case lightBackgroundImageURL, darkBackgroundImageURL
        case lightBackgroundImageLayout, darkBackgroundImageLayout
    }

    /// 伪代码 0x1001d18a8（L96-121）：decodeIfPresent 长链（L305-L464 确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        regex = try container.decodeIfPresent(String.self, forKey: .regex) ?? ""
        lightColorHex = try container.decodeIfPresent(String.self, forKey: .lightColorHex) ?? ""
        darkColorHex = try container.decodeIfPresent(String.self, forKey: .darkColorHex) ?? ""
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        crossPageQuotes = try container.decodeIfPresent(Bool.self, forKey: .crossPageQuotes) ?? false
        noCrossParagraph = try container.decodeIfPresent(Bool.self, forKey: .noCrossParagraph) ?? false
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? ""
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 17
        fontWeight = try container.decodeIfPresent(CGFloat.self, forKey: .fontWeight)
        lightStyleCSS = try container.decodeIfPresent(String.self, forKey: .lightStyleCSS) ?? ""
        darkStyleCSS = try container.decodeIfPresent(String.self, forKey: .darkStyleCSS) ?? ""
        lightBackgroundImageURL = try container.decodeIfPresent(String.self, forKey: .lightBackgroundImageURL) ?? ""
        darkBackgroundImageURL = try container.decodeIfPresent(String.self, forKey: .darkBackgroundImageURL) ?? ""
        lightBackgroundImageLayout = try container.decodeIfPresent(
            HighlightBackgroundImageLayout.self, forKey: .lightBackgroundImageLayout)
            ?? HighlightBackgroundImageLayout()
        darkBackgroundImageLayout = try container.decodeIfPresent(
            HighlightBackgroundImageLayout.self, forKey: .darkBackgroundImageLayout)
            ?? HighlightBackgroundImageLayout()
    }

    /// 伪代码 0x1001d2310（L123-142）：encode。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(regex, forKey: .regex)
        try container.encode(lightColorHex, forKey: .lightColorHex)
        try container.encode(darkColorHex, forKey: .darkColorHex)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(crossPageQuotes, forKey: .crossPageQuotes)
        try container.encode(noCrossParagraph, forKey: .noCrossParagraph)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try container.encode(lightStyleCSS, forKey: .lightStyleCSS)
        try container.encode(darkStyleCSS, forKey: .darkStyleCSS)
        try container.encode(lightBackgroundImageURL, forKey: .lightBackgroundImageURL)
        try container.encode(darkBackgroundImageURL, forKey: .darkBackgroundImageURL)
        try container.encode(lightBackgroundImageLayout, forKey: .lightBackgroundImageLayout)
        try container.encode(darkBackgroundImageLayout, forKey: .darkBackgroundImageLayout)
    }

    /// 伪代码 0x1001d6ba0（L261）：内置判定。
    var isBuiltin: Bool {
        Self.builtinRule(for: id) != nil
    }

    /// 伪代码 0x1001dcc70（变量初始化）：内置默认。
    var builtinDefault: HighlightRule? {
        Self.builtinRule(for: id)
    }

    /// 伪代码 0x1001d3304（L219-221）：布局字体族。
    var layoutFontFamily: String {
        fontFamily
    }

    /// 伪代码 0x1001d345c（L223-225）：字重覆盖。
    var fontWeightOverride: UIFont.Weight? {
        guard let fontWeight else { return nil }
        switch fontWeight {
        case ..<350: return .light
        case ..<550: return .regular
        case ..<750: return .semibold
        default: return .bold
        }
    }

    /// 伪代码 0x1001d2d24（L227-258 + closure #3/#4）：解析字体。
    /// @MainActor：ReadingSettings 域隔离（wave-16）。
    @MainActor
    func resolvedFont(using settings: ReadingSettings) -> UIFont {
        let family = layoutFontFamily.isEmpty ? settings.fontName : layoutFontFamily
        let size = fontSize > 0 ? fontSize : settings.fontSize
        if let weight = fontWeightOverride,
           let descriptor = UIFontDescriptor().withDesign(.default) {
            return UIFont(
                descriptor: descriptor.withSymbolicTraits([]) ?? descriptor,
                size: size)
                .applyingWeight(weight)
        }
        if family == "System" || family.isEmpty {
            return UIFont.systemFont(ofSize: size)
        }
        return UIFont(name: family, size: size) ?? UIFont.systemFont(ofSize: size)
    }

    /// darkColor setter（pgo_only；六色 setter 共体）。
    mutating func setDarkColor(_ color: Color) {
        // SwiftUI.Color → hex 桥（颜色域细节待真机对照）。
        _ = color
    }
}

private extension UIFont {
    func applyingWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: pointSize, weight: weight)
    }
}

// MARK: - 内置规则与合并

extension HighlightRule {

    /// 伪代码 0x1001d3a98（L327-329）：内置规则表（集合内容待真机对照）。
    static func builtinRule(for id: String) -> HighlightRule? {
        switch id {
        case "builtin.quote":
            return HighlightRule(
                id: id, name: "引用", regex: "^>.*$",
                lightColorHex: "#FFF3E0", darkColorHex: "#3E2723",
                enabled: true, crossPageQuotes: true, noCrossParagraph: false,
                fontFamily: "", fontSize: 17, fontWeight: nil,
                lightStyleCSS: "", darkStyleCSS: "",
                lightBackgroundImageURL: "", darkBackgroundImageURL: "",
                lightBackgroundImageLayout: HighlightBackgroundImageLayout(),
                darkBackgroundImageLayout: HighlightBackgroundImageLayout())
        case "builtin.dialogue":
            return HighlightRule(
                id: id, name: "对话", regex: "\"[^\"]{2,}\"",
                lightColorHex: "#E3F2FD", darkColorHex: "#1A237E",
                enabled: false, crossPageQuotes: false, noCrossParagraph: false,
                fontFamily: "", fontSize: 17, fontWeight: nil,
                lightStyleCSS: "", darkStyleCSS: "",
                lightBackgroundImageURL: "", darkBackgroundImageURL: "",
                lightBackgroundImageLayout: HighlightBackgroundImageLayout(),
                darkBackgroundImageLayout: HighlightBackgroundImageLayout())
        default:
            return nil
        }
    }

    /// 伪代码 0x1001d6a3c（L331-339）：内置规则合并（同 id 用户规则优先）。
    static func mergedWithBuiltinRules(_ userRules: [HighlightRule]) -> [HighlightRule] {
        let builtinIds = Set(userRules.map(\.id).filter { builtinRule(for: $0) != nil })
        let builtins = ["builtin.quote", "builtin.dialogue"]
            .compactMap { builtinRule(for: $0) }
            .filter { !builtinIds.contains($0.id) }
        return userRules + builtins
    }

    /// 伪代码 0x1001d6be8（L341-344 + closure 0x1001d6bc0）：恢复内置默认。
    static func resettingBuiltinRules(in rules: [HighlightRule]) -> [HighlightRule] {
        rules.map { rule in
            if rule.isBuiltin, let defaultRule = builtinRule(for: rule.id) {
                return defaultRule
            }
            return rule
        }
    }
}

// MARK: - 编译后规则

/// 编译后规则（缓存正则）。
struct CompiledHighlightRule {
    let rule: HighlightRule
    let regex: NSRegularExpression?

    /// 伪代码 0x1001d495c（L354-356）：样式属性（CSS 解析域，T-303-02 解析器消费）。
    func attributes(isDark: Bool) -> [NSAttributedString.Key: Any] {
        HighlightStyleCSSParser.parse(
            isDark ? rule.darkStyleCSS : rule.lightStyleCSS,
            fallbackForegroundColor: nil)
    }

    /// applyAttributes(to:rules:isDark:)（PageContentViews+Comments 消费域
    /// 确证——逐规则正则命中域批量上样式，wave-16 补桥）。
    static func applyAttributes(
        to mutable: NSMutableAttributedString,
        rules: [CompiledHighlightRule],
        isDark: Bool
    ) {
        for compiled in rules {
            guard let regex = compiled.regex else { continue }
            let attributes = compiled.attributes(isDark: isDark)
            let full = NSRange(location: 0, length: mutable.length)
            regex.enumerateMatches(
                in: mutable.string, options: [], range: full
            ) { match, _, _ in
                guard let match else { return }
                for (key, value) in attributes {
                    mutable.addAttribute(key, value: value, range: match.range)
                }
            }
        }
    }
}

// MARK: - 正则应用器

/// 正则高亮应用器（枚举命名空间）。
enum ReaderRegexHighlightApplier {

    /// 区间匹配结果。
    struct Match {
        let range: NSRange
        let rule: HighlightRule
    }

    /// 伪代码 0x1001d69b4（L367-387）：应用到属性串。
    /// 逐规则 matchesInString → 交叉页引用合并 → 属性注入。
    static func apply(
        to attributed: NSMutableAttributedString,
        text: String,
        rules: [CompiledHighlightRule],
        isDark: Bool,
        includeAttributes: Bool,
        applyCrossPageQuotes: Bool
    ) {
        let nsText = text as NSString
        var matches: [Match] = []
        for compiled in rules {
            guard compiled.rule.enabled, let regex = compiled.regex else { continue }
            let regexMatches = highlightRanges(
                in: text, regex: regex,
                crossPageQuotes: compiled.rule.crossPageQuotes,
                noCrossParagraph: compiled.rule.noCrossParagraph)
            for range in regexMatches {
                matches.append(Match(range: range, rule: compiled.rule))
            }
        }
        // 按位置去重（先到先得）。
        var claimed = [Bool](repeating: false, count: nsText.length)
        for match in matches.sorted(by: { $0.range.location < $1.range.location }) {
            guard match.range.location + match.range.length <= claimed.count else { continue }
            let overlap = (match.range.location..<match.range.location + match.range.length)
                .contains { claimed[$0] }
            guard !overlap else { continue }
            for i in match.range.location..<match.range.location + match.range.length {
                claimed[i] = true
            }
            guard includeAttributes else { continue }
            // compiled 为外层循环域变量——本循环经 Match.rule 取规则域
            // （Match 载体确证，wave-16）。
            let attributes = match.rule.attributesFor(isDark: isDark)
            for (key, value) in attributes {
                attributed.addAttribute(key, value: value, range: match.range)
            }
        }
        _ = applyCrossPageQuotes
    }

    /// 伪代码 0x1001d52c4（L402-430）：区间匹配
    ///（matchesInString:options:range: L2419 确证）。
    static func highlightRanges(
        in text: String,
        regex: NSRegularExpression,
        crossPageQuotes: Bool,
        noCrossParagraph: Bool
    ) -> [NSRange] {
        let nsText = text as NSString
        var ranges = regex.matches(
            in: text, options: [],
            range: NSRange(location: 0, length: nsText.length))
            .map(\.range)
        if crossPageQuotes {
            ranges.append(contentsOf: crossPageQuoteRanges(
                text: text, nsLength: nsText.length,
                openChar: "\u{201C}", closeChar: "\u{201D}"))
        }
        if noCrossParagraph {
            ranges = ranges.filter { range in
                nsText.substring(with: range).rangeOfCharacter(
                    from: CharacterSet.newlines) == nil
            }
        }
        return ranges
    }

    /// 伪代码 0x1001d5914（L460-483）：跨页引号区间
    ///（rangeOfCharacterFromSet:options:range: 确证）。
    static func crossPageQuoteRanges(
        text: String, nsLength: Int, openChar: Character, closeChar: Character
    ) -> [NSRange] {
        let nsText = text as NSString
        var ranges: [NSRange] = []
        var cursor = 0
        while cursor < nsLength {
            let remaining = NSRange(location: cursor, length: nsLength - cursor)
            // NSString.rangeOfCharacter 返回非可选 NSRange（location 判
            // NSNotFound 域，wave-16）。
            let openRange = nsText.rangeOfCharacter(
                from: CharacterSet(charactersIn: String(openChar)),
                options: [], range: remaining)
            guard openRange.location != NSNotFound else { break }
            let afterOpen = NSRange(
                location: openRange.location + 1,
                length: nsLength - openRange.location - 1)
            let closeRange = nsText.rangeOfCharacter(
                from: CharacterSet(charactersIn: String(closeChar)),
                options: [], range: afterOpen)
            guard closeRange.location != NSNotFound else { break }
            ranges.append(NSRange(
                location: openRange.location,
                length: closeRange.location - openRange.location + 1))
            cursor = closeRange.location + 1
        }
        return ranges
    }
}

private extension HighlightRule {
    /// 属性注入（CSS 解析器消费；与 CompiledHighlightRule.attributes 同义）。
    func attributesFor(isDark: Bool) -> [NSAttributedString.Key: Any] {
        HighlightStyleCSSParser.parse(
            isDark ? darkStyleCSS : lightStyleCSS,
            fallbackForegroundColor: nil)
    }
}

import SwiftUI
