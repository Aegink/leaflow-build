// 原路径: ReadMain/Views/Reader/ReaderDoublePagePolicy.swift
// 证据:
//   - PGO: 7 个主函数（index/task_functions.csv T-301-06 / ReaderDoublePagePolicy.swift），
//     地址：isSupportedDevice 0x10079f394 L10-13(+closure ×2) / isEffective(mode:...)
//     0x10079f1cc L21-33 / isEffective(settings:...) 0x10079f2c4 L40-48 /
//     renderSizeMatchingContainerOrientation 0x10079f3e8 L145-156 /
//     spreadStartIndex(for:pageCount:) 0x100774a24 L158-162
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderDoublePagePolicy.c（275 行）
//   - 事实：isSupportedDevice = idiom == .pad(2) && horizontalSizeClass != .compact(1)
//     （L22：a3 != 1 && a2 == 2 确证）；isEffective(mode:...) 守卫链：双页模式关 → false /
//     pageMode == 4（卷页）→ false / containerWidth < 700 → false / 设备不支持 → false
//     （L100 确证 700pt 阈值）；renderSizeMatchingContainerOrientation：方向匹配取宽、
//     失配取高（L178-186 确证）；spreadStartIndex：偶对齐（index & ~1），奇数尾页
//     "blank" 跨页（字面量 0x6B6E616C62 + "spread:"(0x3A646165727073) 确证）；
//     逻辑页界/可见页序/目标页（骨架补充签名，pairing 语义自 isEffective(settings:) 块归位）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - isSupportedDevice/isEffective/renderSizeMatchingContainerOrientation/spreadStartIndex:
//     high（常量/阈值/分支确证）
//   - logicalPageBounds/visiblePageIndices/targetIndex: medium（签名确证；pairing 细节待真机）
// 还原: 2026-11-19

import UIKit

/// 双页策略（枚举命名空间）。
enum ReaderDoublePagePolicy {

    /// 伪代码 0x10079f394（L10-13）：idiom == .pad && sizeClass != .compact。
    static func isSupportedDevice(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?
    ) -> Bool {
        userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }

    /// 伪代码 0x10079f1cc（L21-33）：守卫链。
    static func isEffective(
        mode: ReadingSettings.DoublePageMode,
        pageMode: ReadingSettings.PageMode,
        containerSize: CGSize,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?
    ) -> Bool {
        guard mode != .off else { return false }
        guard pageMode != .curl else { return false }
        guard containerSize.width >= 700.0 else { return false }
        return isSupportedDevice(
            userInterfaceIdiom: userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass)
    }

    /// 伪代码 0x10079f2c4（L40-48）：settings 快捷入口（宽度 700 阈值确证）。
    static func isEffective(
        settings: ReadingSettings,
        containerSize: CGSize,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?
    ) -> Bool {
        isEffective(
            mode: settings.doublePageMode,
            pageMode: settings.pageMode,
            containerSize: containerSize,
            userInterfaceIdiom: userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass)
    }

    /// 伪代码 0x10079f3e8（L145-156）：方向匹配的渲染尺寸。
    /// 零/负宽高 → 容器宽；方向匹配（宽比宽/高比高）→ 渲染宽；失配 → 渲染高。
    static func renderSizeMatchingContainerOrientation(
        _ renderSize: CGSize, containerSize: CGSize
    ) -> CGFloat {
        guard renderSize.width > 0, renderSize.height > 0 else {
            return containerSize.width
        }
        let renderIsLandscape = renderSize.height < renderSize.width
        let containerIsLandscape = containerSize.height < containerSize.width
        return renderIsLandscape == containerIsLandscape
            ? renderSize.width
            : renderSize.height
    }

    /// 伪代码 0x100774a24（L158-162）：跨页起始索引（偶对齐；奇数尾页 blank 跨页，
    /// "spread:"/"blank" 字面量确证）。
    static func spreadStartIndex(for index: Int, pageCount: Int) -> Int {
        guard index >= 0, index < pageCount else { return 0 }
        let aligned = index & ~1
        if aligned + 1 >= pageCount {
            // 尾页单独成跨（blank 配对）。
            return aligned
        }
        return aligned
    }

    /// 逻辑页界（骨架签名：settings 快捷入口）。
    static func logicalPageBounds(
        for renderBounds: CGRect,
        renderBounds renderBoundsIn: CGRect,
        settings: ReadingSettings,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        gap: CGFloat
    ) -> CGRect? {
        logicalPageBounds(
            for: renderBoundsIn,
            mode: settings.doublePageMode,
            pageMode: settings.pageMode,
            userInterfaceIdiom: userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass,
            gap: gap)
    }

    /// 逻辑页界（骨架签名：显式模式）。
    static func logicalPageBounds(
        for renderBounds: CGRect,
        renderBounds renderBoundsIn: CGRect,
        mode: ReadingSettings.DoublePageMode,
        pageMode: ReadingSettings.PageMode,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        gap: CGFloat
    ) -> CGRect? {
        guard isEffective(
            mode: mode,
            pageMode: pageMode,
            containerSize: renderBoundsIn.size,
            userInterfaceIdiom: userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass) else { return nil }
        return logicalPageBounds(
            for: renderBounds,
            mode: mode,
            pageMode: pageMode,
            userInterfaceIdiom: userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass,
            gap: gap)
    }

    /// 可见页序（骨架签名：当前跨页的两页索引）。
    static func visiblePageIndices(for index: Int, pageCount: Int) -> [Int] {
        let start = spreadStartIndex(for: index, pageCount: pageCount)
        var indices = [start]
        if start + 1 < pageCount {
            indices.append(start + 1)
        }
        return indices
    }

    /// 逻辑页界（骨架签名：单/双页分配，gap 为中缝）。
    static func logicalPageBounds(
        for renderBounds: CGRect,
        mode: ReadingSettings.DoublePageMode,
        pageMode: ReadingSettings.PageMode,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        gap: CGFloat
    ) -> CGRect {
        _ = mode
        _ = pageMode
        _ = userInterfaceIdiom
        _ = horizontalSizeClass
        let halfWidth = (renderBounds.width - gap) / 2
        let left = CGRect(
            x: renderBounds.minX, y: renderBounds.minY,
            width: halfWidth, height: renderBounds.height)
        let right = CGRect(
            x: renderBounds.minX + halfWidth + gap, y: renderBounds.minY,
            width: halfWidth, height: renderBounds.height)
        _ = left
        return right
    }

    /// 逻辑页界（骨架签名：settings 快捷入口）。
    static func logicalPageBounds(
        for renderBounds: CGRect,
        settings: ReadingSettings,
        userInterfaceIdiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        gap: CGFloat
    ) -> CGRect {
        logicalPageBounds(
            for: renderBounds,
            mode: settings.doublePageMode,
            pageMode: settings.pageMode,
            userInterfaceIdiom: userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass,
            gap: gap)
    }

    /// 双页翻页目标（骨架签名：跨页步进 ±2）。
    static func targetIndex(
        currentIndex: Int, pageCount: Int, direction: ReaderPageTurnDirection
    ) -> Int? {
        let delta = direction == .next ? 2 : -2
        let target = currentIndex + delta
        guard target >= 0, target < pageCount else { return nil }
        return target
    }
}
