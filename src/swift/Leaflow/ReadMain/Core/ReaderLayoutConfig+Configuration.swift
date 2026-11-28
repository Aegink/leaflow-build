// 原路径: ReadMain/Core/ReaderLayoutConfig.swift
// 分册只改变边界，函数、规模、桩仍计入原始文件。
import Foundation
import UIKit
import SwiftUI

// MARK: - T-1401-02 逐域补齐（阅读排版域）

extension ChapterTitleConfig {

    enum CodingKeys: String, CodingKey {
        case fontName
        case fontSize
        case textAlignment
        case useBold
        case isEnabled
        case chapterNameFont
        case fontWeightName
    }

    /// Codable 手工实现：NSTextAlignment 非 Codable，rawValue 桥
    ///（T-1401-01 ChapterTitlePreset 双档解码域依赖）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(
            String.self, forKey: .fontName) ?? ""
        fontSize = try container.decodeIfPresent(
            CGFloat.self, forKey: .fontSize) ?? 22
        let alignmentRaw = try container.decodeIfPresent(
            Int.self, forKey: .textAlignment) ?? NSTextAlignment.center.rawValue
        textAlignment = NSTextAlignment(rawValue: alignmentRaw) ?? .center
        useBold = try container.decodeIfPresent(Bool.self, forKey: .useBold) ?? true
        isEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .isEnabled) ?? true
        chapterNameFont = try container.decodeIfPresent(
            String.self, forKey: .chapterNameFont) ?? ""
        fontWeightName = try container.decodeIfPresent(
            String.self, forKey: .fontWeightName) ?? "regular"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(textAlignment.rawValue, forKey: .textAlignment)
        try container.encode(useBold, forKey: .useBold)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(chapterNameFont, forKey: .chapterNameFont)
        try container.encode(fontWeightName, forKey: .fontWeightName)
    }

    /// 伪代码 0x1001f1f4c（L506-514）：权重名 → UIFont.Weight
    ///（"regular" 0x72616C75676572 / "medium" 0x6D756964656D / "semibold"
    /// 0xE8 域 / "bold" 0x646C6F62 字面量确证；未匹配回退 sub_1001FB7FC 链
    /// → regular）。
    var uiFontWeight: UIFont.Weight {
        switch fontWeightName {
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .regular
        }
    }

    /// 伪代码 0x1007bfee8（L525-543）：fontFamily == "System"
    ///（0x6D6574737953 确证）→ systemFontOfSize:weight:(uiFontWeight)；
    /// 否则 UIFont(name:size:)；weight 名 bold → fontDescriptorWithSymbolic
    /// Traits:2(traitBold) 重取（块体与 ReaderChapterTitleView.applyStyle
    /// ICF 合并，题名视图域按桥处理）。
    func resolvedUIFont(fontFamily: String) -> UIFont {
        let base: UIFont
        let weight = useBold ? UIFont.Weight.bold : uiFontWeight
        if fontFamily == "System" {
            base = .systemFont(ofSize: fontSize, weight: weight)
        } else {
            base = UIFont(name: fontFamily, size: fontSize)
                ?? .systemFont(ofSize: fontSize, weight: weight)
        }
        if useBold || fontWeightName == "bold" {
            if let descriptor = base.fontDescriptor
                .withSymbolicTraits(.traitBold) {
                return UIFont(descriptor: descriptor, size: fontSize)
            }
        }
        return base
    }
}

extension LayoutWidget {

    /// 伪代码 0x1001f0d6c（L230-250）：默认 widgets——五段阈值
    ///（0.12/0.37/0.62/0.87 域确证）选对齐档 + "battery." 前缀域
    ///（0x2E797265746162 确证）+ 百分比钳制 0...100（0x4059=100.0 域）；
    /// widget 集推断。
    static func defaultWidgets(
        screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat
    ) -> [LayoutWidget] {
        let usable = max(screenHeight - safeTop - safeBottom, 1)
        let ratio = min(max(safeTop / usable, 0), 1)
        let alignment: WidgetTextAlignment
        switch ratio {
        case 0.0..<0.12: alignment = .leading
        case 0.12..<0.37: alignment = .center
        case 0.37..<0.62: alignment = .trailing
        case 0.62..<0.87: alignment = .leading
        default: alignment = .center
        }
        return [
            LayoutWidget(
                type: "battery", alignment: alignment, showOnFirstPage: true),
            LayoutWidget(
                type: "time", alignment: alignment, showOnFirstPage: true),
            LayoutWidget(
                type: "progress", alignment: alignment, showOnFirstPage: false),
        ]
    }
}

extension ReaderLayoutTemplate {

    /// 伪代码 0x1001f7ce0（L1070-1104）：模板预设 4 槽 widgets——槽位域
    ///（tag 1/2/4/4 + 水平比 0x3FB47AE147AE147B=0.08 / 0x3FE0=0.5 + 尺寸
    /// 0x4028=12.0 + 透明度 0x3FD3=0.3 + 首页显隐位确证；tag→类型映射推断）。
    func presetWidgets(
        screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat
    ) -> [LayoutWidget] {
        _ = screenHeight
        _ = safeTop
        _ = safeBottom
        switch self {
        case .standard, .single:
            // .single preset 复用 standard 集（还原推断，随 T-1401-02 核清）。
            return [
                LayoutWidget(
                    type: "progress", alignment: .leading,
                    showOnFirstPage: true),
                LayoutWidget(
                    type: "time", alignment: .leading,
                    showOnFirstPage: false),
                LayoutWidget(
                    type: "battery", alignment: .center,
                    showOnFirstPage: true),
                LayoutWidget(
                    type: "battery", alignment: .trailing,
                    showOnFirstPage: true),
            ]
        case .compact:
            return [
                LayoutWidget(
                    type: "progress", alignment: .leading,
                    showOnFirstPage: true),
            ]
        case .immersive:
            return []
        }
    }
}

extension ReaderLayoutCalculator {

    /// 伪代码 0x1001f5d10（L804-826）：窗口度量缺失 → 轮询等待
    ///（sub_100031A48 睡眠域；50×20ms 上限推断）。
    static func waitForWindowMetrics() async throws {
        for _ in 0..<50 {
            if resolveWindowMetrics() != nil { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// 伪代码 0x100227628（L1032-1045）：calculateLayout 全参链 → 内容区尺寸
    ///（CGRectGetHeight 域确证；chapterTitle/fontFamily 两参在 T-302 形态
    /// 中并入配置域）。
    static func getContentAreaSize(
        isFirstPage: Bool,
        chapterTitleConfig: ChapterTitleConfig,
        leftPageMargin: CGFloat,
        rightPageMargin: CGFloat,
        topInsetExtra: CGFloat,
        bottomInsetExtra: CGFloat,
        screenBounds: CGRect?,
        chapterTitle: String,
        fontFamily: String
    ) throws -> CGSize {
        var config = chapterTitleConfig
        if config.fontName.isEmpty { config.fontName = fontFamily }
        let bounds = screenBounds ?? UIScreen.main.bounds
        let layout = calculateLayout(
            isFirstPage: isFirstPage,
            chapterTitleConfig: config,
            leftPageMargin: leftPageMargin,
            rightPageMargin: rightPageMargin,
            topInsetExtra: topInsetExtra,
            bottomInsetExtra: bottomInsetExtra,
            screenBounds: bounds,
            safeAreaFrame: bounds,
            chapterTitle: chapterTitle)
        return layout.contentRect.size
    }
}

/// 章节标题高度缓存（0x1001f4818/0x1001f4c3c 域；MainActor executor 断言
/// 确证——"Leaflow/ReaderLayoutConfig.swift" L700 域）。
@MainActor
final class ChapterTitleHeightCache {

    static let shared = ChapterTitleHeightCache()
    private var heights: [String: CGFloat] = [:]
    /// 持久化宿主判定（clear 域 swift_weakLoadStrong 确证）。
    private var hasPersistHost: Bool = false

    /// 伪代码 0x1001f4818（L655-663）：0x88 槽位写入域。
    func setMeasuredHeight(_ height: CGFloat, for key: String) {
        heights[key] = height
    }

    /// 伪代码 0x1001f4c3c（L665-672）：宿主存在 → persistToDisk 尾调；
    /// 内存清空。
    func clear() {
        heights.removeAll()
        if hasPersistHost {
            persistToDisk()
        }
    }

    /// 持久化域（0x1001f4c3c 尾调确证；磁盘格式未解码——占位桥不冒充）。
    private func persistToDisk() {
        // 磁盘格式域未解码；格式确证后补齐（记入仍不清楚）。
    }
}

