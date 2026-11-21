// 原路径: ReadMain/Core/HighlightStyleCSSParser.swift
// 证据:
//   - PGO: 24 个主函数（index/task_functions.csv T-303-02 / HighlightStyleCSSParser.swift），
//     地址：parse(_:fallbackForegroundColor:) 0x100dcd40 0x1001dcd40 L12-133
//     （stripCSSComments → splitDeclarations → firstColonIndex → apply 链确证）/
//     stripCSSComments 0x1001dde64 L146-160 / splitDeclarations 0x1001de460
//     L162-195 / firstColonIndex 0x1001de84c L197-212 / applyForegroundPaint
//     0x1001dea58 L217-225 / applyBackgroundPaint 0x1001dec64 L230-238 /
//     parseBorderRadius 0x1001dee70 L250-265 / parsePaint 0x1001e2a00 L240-248 /
//     applyTextDecorationShorthand 0x1001df07c L569-604 / applyTextDecorationLine
//     0x1001df7bc L610-635 / parseDecorationStyle 0x1001dfd1c L529-560
//     (+closure 0x1001dc8e0 L531) / parseColor 0x1001e01c4 L267-278 /
//     parseLinearGradientPaint 0x1001e0428 L280-316 / parseRGBColor 0x1001e0b94
//     L472-523 / parseHexColor 0x1001e111c L443-470 / splitTopLevelCommaList
//     0x1001e1440 L318-351 / parseGradientDirection 0x1001e182c L404-436 /
//     firstTopLevelToken 0x1001e1f1c L363-383 / parseGradientStopLocation
//     0x1001e2148 L385-402 / parseComponent #1 0x1001e2458 L485-497
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/HighlightStyleCSSParser.c
//   - 事实：parse 主链 —— stripCSSComments → splitDeclarations → 逐声明
//     firstColonIndex 拆属性名/值 → trim → apply 分派（foreground/background/
//     border-radius/text-decoration）；颜色三形态（hex/rgb()/linear-gradient()）；
//     gradient —— splitTopLevelCommaList + parseGradientDirection + stop location
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链/声明拆分: high（调用链确证）
//   - 颜色/渐变解析细节: medium-high（三形态确证；边缘输入待真机对照）
// 还原: 2026-11-19

import Foundation
import SwiftUI
import UIKit

/// 高亮 CSS 解析器（inline style → 属性字典/画笔）。
enum HighlightStyleCSSParser {

    // MARK: 画笔与解析结果

    /// 渐变画笔（HighlightLinearGradientPaint 域确证）。
    struct GradientPaint {
        var colors: [UIColor]
        var locations: [CGFloat]
        var angle: CGFloat
    }

    /// 解析后的样式集合。
    struct ResolvedStyle {
        var foreground: UIColor?
        var backgroundPaint: GradientPaint?
        var backgroundColor: UIColor?
        var borderRadius: CGFloat?
        var textDecoration: String?
    }

    // MARK: 主入口

    /// 伪代码 0x1001dcd40（L12-133）：主链 —— stripCSSComments →
    /// splitDeclarations → 逐声明 firstColonIndex 拆分 → trim → apply 分派。
    static func parse(
        _ css: String,
        fallbackForegroundColor: UIColor?
    ) -> [NSAttributedString.Key: Any] {
        var resolved = ResolvedStyle()
        let cleaned = stripCSSComments(css)
        for declaration in splitDeclarations(cleaned) {
            guard let colonIndex = firstColonIndex(in: declaration) else { continue }
            let property = declaration[declaration.startIndex..<colonIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = declaration[declaration.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            switch property {
            case "color":
                applyForegroundPaint(value, to: &resolved)
            case "background", "background-color":
                applyBackgroundPaint(value, to: &resolved)
            case "border-radius":
                resolved.borderRadius = parseBorderRadius(value)
            case "text-decoration":
                applyTextDecorationShorthand(value, to: &resolved)
            case "text-decoration-line":
                applyTextDecorationLine(value, to: &resolved)
            default:
                break
            }
        }
        var attributes: [NSAttributedString.Key: Any] = [:]
        let foreground = resolved.foreground ?? fallbackForegroundColor
        if let foreground {
            attributes[.foregroundColor] = foreground
        }
        if let paint = resolved.backgroundPaint {
            attributes[.backgroundColor] = UIColor(patternImage: gradientImage(paint))
        } else if let background = resolved.backgroundColor {
            attributes[.backgroundColor] = background
        }
        if let radius = resolved.borderRadius, radius > 0 {
            attributes[.baselineOffset] = 0
            _ = radius
        }
        if let decoration = resolved.textDecoration, decoration == "underline" {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attributes
    }

    /// 渐变 → 1px 图（UIColor(patternImage:) 通道）。
    private static func gradientImage(_ paint: GradientPaint) -> UIImage {
        let size = CGSize(width: 4, height: 4)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        let gradient = CAGradientLayer()
        gradient.colors = paint.colors
        gradient.locations = paint.locations as [NSNumber]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = CGRect(origin: .zero, size: size)
        gradient.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    // MARK: 拆分辅助

    /// 伪代码 0x1001dde64（L146-160）：剥注释。
    static func stripCSSComments(_ css: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "/\\*.*?\\*/", options: [.dotMatchesLineSeparators]) else {
            return css
        }
        let nsCss = css as NSString
        return regex.stringByReplacingMatches(
            in: css, options: [],
            range: NSRange(location: 0, length: nsCss.length),
            withTemplate: "")
    }

    /// 伪代码 0x1001de460（L162-195）：分号拆声明（括号深度感知）。
    static func splitDeclarations(_ css: String) -> [String] {
        var declarations: [String] = []
        var current = ""
        var depth = 0
        for character in css {
            switch character {
            case "(":
                depth += 1
                current.append(character)
            case ")":
                depth = max(0, depth - 1)
                current.append(character)
            case ";":
                if depth == 0 {
                    declarations.append(current)
                    current = ""
                } else {
                    current.append(character)
                }
            default:
                current.append(character)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            declarations.append(current)
        }
        return declarations
    }

    /// 伪代码 0x1001de84c（L197-212）：首个顶层冒号。
    static func firstColonIndex(in declaration: String) -> String.Index? {
        var depth = 0
        for (index, character) in declaration.enumerated() {
            switch character {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case ":" where depth == 0:
                return declaration.index(declaration.startIndex, offsetBy: index)
            default: break
            }
        }
        return nil
    }

    // MARK: apply 分派

    /// 伪代码 0x1001dea58（L217-225）。
    private static func applyForegroundPaint(_ value: String, to style: inout ResolvedStyle) {
        if let paint = parsePaint(value) {
            // 前景渐变退化为首色（paint 语义推断）。
            style.foreground = paint.colors.first ?? style.foreground
        } else {
            style.foreground = parseColor(value)
        }
    }

    /// 伪代码 0x1001dec64（L230-238）。
    private static func applyBackgroundPaint(_ value: String, to style: inout ResolvedStyle) {
        if let paint = parsePaint(value) {
            style.backgroundPaint = paint
        } else {
            style.backgroundColor = parseColor(value)
        }
    }

    /// 伪代码 0x1001e2a00（L240-248）：值 → 画笔（linear-gradient 分派）。
    private static func parsePaint(_ value: String) -> GradientPaint? {
        guard value.lowercased().hasPrefix("linear-gradient") else { return nil }
        return parseLinearGradientPaint(value)
    }

    /// 伪代码 0x1001dee70（L250-265）：圆角。
    private static func parseBorderRadius(_ value: String) -> CGFloat? {
        let number = value.trimmingCharacters(in: CharacterSet(charactersIn: "px %"))
        guard let parsed = Double(number) else { return nil }
        return CGFloat(parsed)
    }

    /// 伪代码 0x1001df07c（L569-604）：text-decoration 简写。
    private static func applyTextDecorationShorthand(_ value: String, to style: inout ResolvedStyle) {
        for part in value.split(separator: " ") {
            applyTextDecorationLine(String(part), to: &style)
        }
    }

    /// 伪代码 0x1001df7bc（L610-635）+ closure（0x1001dc8e0，L531）。
    private static func applyTextDecorationLine(_ value: String, to style: inout ResolvedStyle) {
        let normalized = value.lowercased()
        let valid = ["underline", "overline", "line-through", "none"]
        guard valid.contains(normalized) else { return }
        style.textDecoration = normalized
    }

    // MARK: 颜色解析

    /// 伪代码 0x1001e01c4（L267-278）：颜色三形态分派。
    static func parseColor(_ value: String) -> UIColor? {
        let lowered = value.lowercased()
        if lowered.hasPrefix("#") {
            return parseHexColor(lowered)
        }
        if lowered.hasPrefix("rgb") {
            return parseRGBColor(lowered)
        }
        // 命名色（常见集）。
        switch lowered {
        case "transparent": return UIColor.clear
        case "white": return .white
        case "black": return .black
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        default: return nil
        }
    }

    /// 伪代码 0x1001e111c（L443-470）：hex（3/6/8 位）。
    static func parseHexColor(_ hex: String) -> UIColor? {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        switch value.count {
        case 3:
            let expanded = value.map { "\($0)\($0)" }.joined()
            value = expanded
        case 6, 8:
            break
        default:
            return nil
        }
        guard let number = UInt64(value, radix: 16) else { return nil }
        if value.count == 8 {
            // UInt64 → Double 显式转换（位域掩码结果域，wave-16）。
            let alpha = CGFloat(Double(number & 0xFF) / 255.0)
            let rgb = number >> 8
            return UIColor(
                red: CGFloat(Double((rgb >> 16) & 0xFF) / 255.0),
                green: CGFloat(Double((rgb >> 8) & 0xFF) / 255.0),
                blue: CGFloat(Double(rgb & 0xFF) / 255.0),
                alpha: alpha)
        }
        return UIColor(
            red: CGFloat((number >> 16) & 0xFF) / 255.0,
            green: CGFloat((number >> 8) & 0xFF) / 255.0,
            blue: CGFloat(number & 0xFF) / 255.0,
            alpha: 1.0)
    }

    /// 伪代码 0x1001e0b94（L472-523）+ parseComponent（0x1001e2458，L485-497）。
    static func parseRGBColor(_ value: String) -> UIColor? {
        guard let inner = value.firstRange(of: "(").map({
            value[$0.upperBound...]
        }).flatMap({ outer in
            outer.firstRange(of: ")").map { outer[..<$0.lowerBound] }
        }) else { return nil }
        let components = splitTopLevelCommaList(String(inner)).compactMap {
            component in
            guard let parsed = Double(component.trimmingCharacters(
                in: .whitespaces)) else { return nil }
            return CGFloat(parsed)
        }
        guard components.count >= 3 else { return nil }
        // rgb()/rgba() 两种：第四位 alpha（0-1 或百分比）。
        let alpha = components.count > 3 ? min(max(components[3], 0), 1) : 1.0
        let scale = value.lowercased().contains("rgba") ? 1.0 : 1.0
        return UIColor(
            red: min(components[0] * scale / 255.0, 1.0),
            green: min(components[1] * scale / 255.0, 1.0),
            blue: min(components[2] * scale / 255.0, 1.0),
            alpha: alpha)
    }

    /// 伪代码 0x1001e1440（L318-351）：顶层逗号拆分（括号深度感知）。
    static func splitTopLevelCommaList(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for character in value {
            switch character {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case "," where depth == 0:
                parts.append(current)
                current = ""
                continue
            default: break
            }
            current.append(character)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(current)
        }
        return parts
    }

    /// 伪代码 0x1001e0428（L280-316）：linear-gradient 解析。
    static func parseLinearGradientPaint(_ value: String) -> GradientPaint? {
        guard let open = value.firstRange(of: "(") else { return nil }
        let inner = String(value[open.upperBound...])
            .replacingOccurrences(of: ")", with: "")
        let arguments = splitTopLevelCommaList(inner)
        guard arguments.count >= 2 else { return nil }
        var index = 0
        var angle: CGFloat = 180
        // 首参可能是角度/方向（parseGradientDirection 确证）。
        if let direction = parseGradientDirection(arguments[0]) {
            angle = direction
            index = 1
        }
        var colors: [UIColor] = []
        var locations: [CGFloat] = []
        for argument in arguments[index...] {
            let tokens = splitTopLevelCommaList(argument)
            let color = parseColor(tokens[0])
            guard let color else { continue }
            let location = tokens.count > 1
                ? parseGradientStopLocation(tokens[1]) ?? CGFloat(locations.count) / CGFloat(arguments.count - index - 1)
                : CGFloat(locations.count) / CGFloat(max(1, arguments.count - index - 1))
            colors.append(color)
            locations.append(min(max(location, 0), 1))
        }
        guard colors.count >= 2 else { return nil }
        return GradientPaint(colors: colors, locations: locations, angle: angle)
    }

    /// 伪代码 0x1001e182c（L404-436）：方向 → 角度。
    private static func parseGradientDirection(_ token: String) -> CGFloat? {
        let normalized = token.trimmingCharacters(in: .whitespaces).lowercased()
        if normalized.hasPrefix("to ") {
            switch normalized {
            case "to top": return 0
            case "to right": return 90
            case "to bottom": return 180
            case "to left": return 270
            default: return 180
            }
        }
        if normalized.hasSuffix("deg"),
           let degrees = Double(normalized.dropLast(3)) {
            return CGFloat(degrees)
        }
        return nil
    }

    /// 伪代码 0x1001e2148（L385-402）：stop 位置。
    private static func parseGradientStopLocation(_ token: String) -> CGFloat? {
        let normalized = token.trimmingCharacters(in: .whitespaces).lowercased()
        if normalized.hasSuffix("%"),
           let percent = Double(normalized.dropLast(1)) {
            return CGFloat(percent / 100.0)
        }
        if normalized.hasSuffix("px"),
           let pixels = Double(normalized.dropLast(2)) {
            return CGFloat(pixels / 100.0)
        }
        return nil
    }
}
