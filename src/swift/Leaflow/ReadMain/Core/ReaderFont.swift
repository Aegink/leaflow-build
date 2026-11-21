// 原路径: ReadMain/Core/ReaderFont.swift
// 证据:
//   - PGO: Font.themed(size:weight:design:) / Font.readerUI(size:weight:design:) /
//     Font.readerUI(TextStyle) / Font.TextStyle.defaultPointSize.getter
//   - CovMap: themed L7-12 @0x1001e5be8；readerUI(size:) L25-35 @0x1001e6008；
//     readerUI(TextStyle) L38-48 @0x1001e61bc；defaultPointSize L52-67 @0x1001e5d20
//   - IDA: 上述地址的 Hex-Rays 伪代码（613 行）
//   - 证据串："System"(0x6D6574737953, count 6) —— 系统字体判定
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - defaultPointSize: high（11 个 TextStyle case 逐条对应，返回值逐一可见）
//   - themed/readerUI: high（System 判定 + custom 降级链确证）
// 还原: 2026-11-19

import SwiftUI
import UIKit

// MARK: - Font.TextStyle 默认字号

extension Font.TextStyle {

    /// 伪代码 0x1001e5d20（L52-67）：逐 TextStyle case 返回默认磅值。
    /// 证据：11 个 enum case 逐一比较（largeTitle=34, title=28, title2=22,
    /// title3=20, headline=17, body=17, callout=16, subheadline=15,
    /// footnote=13, caption=12, caption2=11），default=17。
    var defaultPointSize: CGFloat {
        switch self {
        case .largeTitle: return 34.0
        case .title: return 28.0
        case .title2: return 22.0
        case .title3: return 20.0
        case .headline: return 17.0
        case .body: return 17.0
        case .callout: return 16.0
        case .subheadline: return 15.0
        case .footnote: return 13.0
        case .caption: return 12.0
        case .caption2: return 11.0
        @unknown default: return 17.0
        }
    }
}

// MARK: - SwiftUI.Font 阅读器扩展

extension Font {

    /// 伪代码 0x1001e5be8（L7-12）：主题化字体。
    /// 逻辑：获取自定义字体名 → 非空且非 "System" → Font.custom(name, size)
    ///       → 否则 Font.system(size, weight, design)。
    /// "System" 判定证据：常量 0x6D6574737953 = "System" (count 6)。
    static func themed(size: CGFloat, weight: Font.Weight, design: Font.Design?) -> Font {
        let customName = ReaderTheme.currentCustomFontName
        if let name = customName, !name.isEmpty, name != "System" {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: design)
    }

    /// 伪代码 0x1001e6008（L25-35）：阅读器 UI 字体。
    /// 逻辑：自定义字体名非 "System" → Font.custom(name, size) + .weight(weight)
    ///       → 否则 .system(size, weight, design)。
    static func readerUI(size: CGFloat, weight: Font.Weight, design: Font.Design?) -> Font {
        let customName = ReaderTheme.currentCustomFontName
        if let name = customName, !name.isEmpty, name != "System" {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: design)
    }

    /// 伪代码 0x1001e61bc（L38-48）：阅读器 UI 字体（TextStyle 变体）。
    static func readerUI(_ style: Font.TextStyle) -> Font {
        let customName = ReaderTheme.currentCustomFontName
        if let name = customName, !name.isEmpty, name != "System" {
            return .custom(name, size: style.defaultPointSize, relativeTo: style)
        }
        return .system(style, design: .default)
    }
}
