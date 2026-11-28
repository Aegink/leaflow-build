// 原路径: ReadMain/Core/ReadingSettings.swift
// 分册只改变边界，函数、规模与桩仍计入原始文件。
import SwiftUI
import UIKit

extension ReadingSettings {
    /// 正文排版输入签名，不包括页面呈现修订，避免重排提交再次触发自身。
    var paginationSettingsSignature: String {
        let dimensions: [CGFloat] = [fontSize, lineSpacing, paragraphSpacing, letterSpacing,
            fontWeight.rawValue, leftPageMargin, rightPageMargin, topInsetExtra, bottomInsetExtra]
        var fields: [String] = dimensions.map { String(Double($0)) }
        fields.append(String(textIndent))
        fields.append(String(textAlignment.rawValue))
        fields.append(String(verticalJustify))
        fields.append(String(paragraphSeparatorLines))
        fields.append(fontName)
        fields.append(String(isBold))
        fields.append(pageMode.rawValue)
        fields.append(doublePageMode.rawValue)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let title = try? encoder.encode(activeChapterTitleConfig) {
            fields.append(title.base64EncodedString())
        }
        return fields.joined(separator: "|")
    }
    // MARK: 布局域

    /// 伪代码 0x100221ef8（L1555-1565）：模板写入（sub_100227F80 域）→
    /// ReaderLayoutCalculator.calculateLayout 全参链重排并缓存结果
    ///（0xA8 LayoutResult memcpy 域确证）。
    func applyLayoutTemplate(_ template: ReaderLayoutTemplate) {
        layoutTemplate = template
        let bounds = ReaderLayoutCalculator.resolveWindowMetrics()?.bounds
            ?? UIScreen.main.bounds
        cachedLayout = try? getLayout(
            isFirstPage: true, screenBounds: bounds, chapterTitle: "")
    }

    /// 最近一次布局结果缓存（applyLayoutTemplate/getLayout 写入域）。

    /// 伪代码 0x100222014（L1568-1580）：canWritePersistentDefaults 为真 →
    /// 用窗口度量缓存；否则走 getContentAreaSize 摘要链。
    func getLayout(
        isFirstPage: Bool, screenBounds: CGRect?, chapterTitle: String
    ) throws -> ReaderLayoutResult {
        let resolvedBounds = screenBounds ?? ReaderLayoutCalculator.resolveWindowMetrics()?.bounds
        guard let bounds = resolvedBounds else {
            throw CocoaError(.fileReadUnknown)
        }
        return ReaderLayoutCalculator.calculateLayout(
            isFirstPage: isFirstPage,
            chapterTitleConfig: activeChapterTitleConfig,
            leftPageMargin: leftPageMargin,
            rightPageMargin: rightPageMargin,
            topInsetExtra: topInsetExtra,
            bottomInsetExtra: bottomInsetExtra,
            screenBounds: bounds,
            safeAreaFrame: screenBounds ?? ReaderLayoutCalculator.resolveWindowMetrics()?.safeArea ?? bounds,
            chapterTitle: chapterTitle)
    }

    /// 伪代码 0x100222130（L1583-1594）：getLayout 链 → contentRect 尺寸。
    func getContentAreaSize(
        isFirstPage: Bool, chapterTitle: String
    ) throws -> CGSize {
        let layout = try getLayout(
            isFirstPage: isFirstPage,
            screenBounds: ReaderLayoutCalculator.resolveWindowMetrics()?.bounds,
            chapterTitle: chapterTitle)
        return layout.contentRect.size
    }

    /// 伪代码 0x100221e18（L1546-1552）：ReaderWidgetLayoutMetrics
    ///（pageBounds:windowSafeAreaFrame:userInterfaceIdiom: 确证）构建缓存
    ///（offsets 1056-1081）；未变化 / pad 档（offset 1081 == 4 分支）→ false；
    /// 变化 → 触发布局刷新（sub_100221EA0）→ true。
    @discardableResult
    func updateWidgetLayoutMetrics(from view: UIView) -> Bool {
        guard let window = view.window else { return false }
        let metrics = ReaderWidgetLayoutMetrics(
            pageBounds: view.bounds,
            windowSafeAreaFrame: window.safeAreaLayoutGuide.layoutFrame,
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom)
        guard metrics.pageBounds != widgetMetrics.pageBounds
            || metrics.safeAreaFrame != widgetMetrics.safeAreaFrame else {
            return false
        }
        if metrics.isPad { return false }
        widgetMetrics = metrics
        return true
    }

    // MARK: 主题应用域

    /// 伪代码 0x100206dc4（L1521-1533）：Color.init(hex:) 双 hex 域（亮/暗）→
    /// ThemeManager.normalizedDarkChapterTitleConfig(from:) +
    /// ThemeManager.applyInterfaceSettings(from:to:) 链。
    func performReaderThemeApplication(
        forceRepagination: Bool, _ completion: () -> Void
    ) {
        ThemeManager.shared.normalizedDarkChapterTitleConfig(from: self)
        ThemeManager.shared.applyInterfaceSettings(
            from: self, to: self, forceRepagination: forceRepagination)
        completion()
    }

}
