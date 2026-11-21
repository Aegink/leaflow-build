// 原路径: ReadMain/Core/HighlightGradientTextRenderer.swift
// 证据:
//   - PGO: 204 条记录（index/task_functions.csv T-303-02 /
//     HighlightGradientTextRenderer.swift；79 函数，伪代码域 2227 行）
//   - CovMap: 上述 L 区段（paint L17-859 / renderer L943-1962 /
//     overlay L1955-2127 / textview L2132-2165 / ext L2187-2227）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/
//     HighlightGradientTextRenderer.c（8118 行，79 块索引
//     0x1001c0b08-0x1001cd644）
//   - 块体确证（地址+行号域）：
//     HighlightResolvedColor.init(uiColor:) 0x1001c0b08 L17-28（RGBA 链 +
//     clearColor 兜底）/ HighlightLinearGradientPaint.draw 0x1001c0b98
//     L49-73（宽高/停点数守卫 + CGGradientCreateWithColors +
//     CGContextDrawLinearGradient options=3）/ normalizedLocations
//     0x1001c112c L75-81（min/max 钳制）/ Layout.init(from:)
//     0x1001c1a1c L161-176（decodeIfPresent 默认 1.0/0.0 链）/
//     centeredStretchRegion 0x1001c1f10 L178-200（0.1..4.0 比例钳制）/
//     clampedHorizontalScale 0x100a02b24 L206-208（0...1）/
//     clampedForNineSlice 0x1001c2124 L525-545 / Paint.init 六参
//     0x10018cc2c L599-606 / draw 0x1001c05f0 L612-633 /
//     resolvedTileSize 0x1001c2c9c L635-653 / drawImage 0x1001c2e2c
//     L655-667（CGImage 分派 drawNineSlice 否则 drawInRect）/
//     drawNineSlice 0x1001c2f58+0x1001c36f8 L669-721（3x3 切片循环）/
//     drawImageSlice 0x1001c3b0c L754-802（CGImageCreateWithImageInRect
//     + 切片缓存 + mode 分派）/ drawTiledImage 0x1001c4174 L834-859
//     （ClipToRect + 双层平铺循环）/ hasForegroundAttributes
//     0x1001d0474 L947-954 / backgroundSnapshotValueSignature
//     0x1001c4c3c L1046-1108（UIColor/UIFont/NSParagraphStyle/NSNumber/
//     NSString/attachment 分派域）/ imageSignature 0x1001c5ae0
//     L1110-1124 / colorSignature 0x1001c599c L1126-1147（宽/高/scale/
//     orientation + CGImage 五元组）/ renderBackgroundSnapshot
//     0x1001c5d5c L1154-1182（NSTextContentStorage+Layout+Container 链）/
//     drawBackgroundGradients 0x1001c60e4 L1230-1279 + closure
//     0x1001c6e24 L1244-1278（圆角半径 = min(w,h)*0.5 与配置钳制 +
//     UIBezierPath beizerPathWithRoundedRect + fill/gradient/paint 三态）/
//     drawForegroundGradients 0x1001c6630 L1287-1310（注释附件透明占位 +
//     enumerateAttributesInRange）/ drawTextKit2MaskText 0x1001c7f98
//     L1410-1465（mask 串构造：removeAttribute NSBackgroundColor +
//     clearColor/whiteColor + SourceIn 渐变）/ textRangesIntersect
//     0x1001c8e08 L1471-1484 / matchingFragment 0x1001c905c L1491-1507 /
//     makeTextKit2Layout 0x1001c5ea8 L1541-1563 / rects(for:layout:)
//     0x1001c93ac L1565-1582（NSIntersectionRange + floor/ceil 取整）/
//     rects(for:textLayoutManager:) 0x1001c7700 L1612-1674（typographic
//     bounds 域内收（高>4 时 (h-2)/2 与 h*0.12 钳制 3.0））/
//     lineVisualMetrics 0x1001ca130 L1680-1704（0.2*font ≥4 +
//     1.15*font 下限）/ referenceGlyphBounds 0x1001c9ca4 L1706-1717
//     （CTLineGetBoundsWithOptions(8) + descender/ascender 兜底）/
//     textRange 0x1001c8b28 L1734-1753 / clipBackgroundRect 0x1001c75c0
//     L1808-1816 / ranges(in:excluding:) 0x1001c7d78 L1822-1841（交集
//     前后两段）/ hasAttribute 0x1001c44f8 L1847-1856 /
//     SnapshotService.renderSnapshot 0x1001cac30 L1926-1945（Task 链 +
//     MainActor 回调）/ OverlayView.didset 五件 0x1001cb07c-0x1001cb6f8
//     L1955-1986 / draw 0x1001cc064 L2023-2037（前景模式渐变域 +
//     背景快照 drawInRect）/ invalidateBackgroundSnapshot 0x1001cb16c
//     L2049-2058（hidden = 无渐变属性）/ updateBackgroundSnapshotIfNeeded
//     0x1001cb854 L2060-2127（lastSnapshotBounds/cachedTextSignature/
//     量化键五元组（w*scale、h*scale、scale*1000）+ 快照命中或 Task）/
//     AttributedTextView.didset 0x1001cc79c L2132-2135（clearColor）/
//     init(frame:) 0x1001ccb30 L2144-2149（usedRect + ceil）/
//     draw 0x1001ccb00 L2158-2165 / ext removingNativeFallbacksForGradient
//     Ranges 0x1001cd398+0x1001cd528 L2187-2202 / ext ranges
//     0x1001cd644 L2206-2227
//   - 事实：渲染域无用户字符串（诊断串仅
//     "Leaflow/CardBackgroundSettingsView.swift" L206 域 /
//     "Leaflow/AppThemeManager.swift" L599 域执行器报告）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（paint/layout 域块体确证；rects/metrics 域
//   参数链按伪代码域还原）
// 还原: 2026-11-20

import UIKit

// MARK: - 颜色解析（0x1001c0b08 L17-28）

/// 高亮渲染的 RGBA 中间色（init(uiColor:) 0x1001c0b08 L17-28 域确证）。
struct HighlightResolvedColor {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    /// init(red:green:blue:alpha:)（签名确证）。
    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// init(uiColor:)（0x1001c0b08 L17-28）：getRed:green:blue:alpha: 成功
    /// 走四分量构造；否则 clearColor 兜底。
    init(uiColor: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            let clear = UIColor.clear.cgColor.components ?? [0, 0, 0, 0]
            self.init(
                red: clear.count > 0 ? clear[0] : 0,
                green: clear.count > 1 ? clear[1] : 0,
                blue: clear.count > 2 ? clear[2] : 0,
                alpha: clear.count > 3 ? clear[3] : 0)
        }
    }

    /// uiColor getter（签名确证；closure #1 in fallbackColor 同链）。
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - 线性渐变（0x1001c0b98 L49-73 / 0x1001c112c L75-81）

/// 渐变停点（closure #1 in fallbackColor L46 域确证：location 缺省按
/// index/count 均分）。
struct HighlightGradientStop {
    var color: UIColor
    var location: CGFloat?
}

/// 线性渐变画刷（startPoint/endPoint 为 0...1 归一化坐标，
/// draw 0x1001c0b98 L49-73 域确证）。
struct HighlightLinearGradientPaint {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var stops: [HighlightGradientStop]

    /// fallbackColor getter（closure #1 0x1001c0e38 L46 域确证：
    /// 遍历停点，缺 location 的按 i/(count-1) 补齐后合成颜色）。
    var fallbackColor: UIColor {
        let clamped: [UIColor] = stops.enumerated().map { index, stop in
            let resolved = stop.location ?? CGFloat(index) /
                CGFloat(max(stops.count - 1, 1))
            return HighlightResolvedColor(uiColor: stop.color).uiColor
                .withAlphaComponent(1.0)
                .blend(withAlpha: resolved)
        }
        return clamped.last ?? .clear
    }

    /// normalizedLocations getter（0x1001c112c L75-81 域确证：
    /// 非空停点 + 首尾钳制）。
    var normalizedLocations: [CGFloat]? {
        let known = stops.compactMap(\.location)
        guard known.count == stops.count, !known.isEmpty else { return nil }
        return known.map { min(max($0, 0), 1) }
    }

    /// draw(in:context:)（0x1001c0b98 L49-73 域确证：宽高>0 且停点数
    /// >=2 守卫；逐停点 UIColor(red:green:blue:alpha:) → CGColor 数组；
    /// DeviceRGB + CGGradientCreateWithColors；起止点按矩形乘算；
    /// CGContextDrawLinearGradient options=3（前后延伸）。
    func draw(in rect: CGRect, context: CGContext) {
        guard rect.width > 0, rect.height > 0, stops.count >= 2 else {
            return
        }
        let colors = stops.map { stop in
            HighlightResolvedColor(uiColor: stop.color).uiColor.cgColor
        }
        // 归一化 locations 转数组（?? 桥后非可选，wave-16）。
        let locations: [CGFloat] = normalizedLocations ??
            stops.indices.map {
                CGFloat($0) / CGFloat(max(stops.count - 1, 1))
            }
        let space = CGColorSpace(
            name: CGColorSpace.sRGB
        ) ?? CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorsSpace: space, colors: colors as CFArray,
            locations: locations
        ) else {
            return
        }
        let start = CGPoint(
            x: rect.minX + startPoint.x * rect.width,
            y: rect.minY + startPoint.y * rect.height)
        let end = CGPoint(
            x: rect.minX + endPoint.x * rect.width,
            y: rect.minY + endPoint.y * rect.height)
        context.drawLinearGradient(
            gradient, start: start, end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

private extension UIColor {
    /// 占位混合（fallbackColor 域的 alpha 归一化还原桥）。
    /// alpha 经 getRed 提取（作用域无 alpha 变量，wave-16）。
    func blend(withAlpha fraction: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(
            red: red, green: green, blue: blue,
            alpha: alpha * fraction)
    }
}

// MARK: - 背景图内边距（0x1001c2124 L525-545）

/// 九宫格切片内边距（horizontal/vertical getter + edgeInsets 签名确证）。
struct HighlightBackgroundImageInsets: Codable, Hashable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    init(
        top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    var horizontal: CGFloat { leading + trailing }
    var vertical: CGFloat { top + bottom }
    var edgeInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: leading, bottom: bottom,
                     right: trailing)
    }

    /// clamped(minimum:maximum:)（签名确证：每边钳制）。
    func clamped(minimum: CGFloat, maximum: CGFloat) -> Self {
        .init(
            top: min(max(top, minimum), maximum),
            leading: min(max(leading, minimum), maximum),
            bottom: min(max(bottom, minimum), maximum),
            trailing: min(max(trailing, minimum), maximum))
    }

    /// clampedForNineSlice(imageSize:)（0x1001c2124 L525-545 域确证：
    /// 横/纵和不超过图尺寸，溢出时按比例收缩到 0/正半区）。
    func clampedForNineSlice(imageSize: CGSize) -> Self {
        var result = self
        let maxH = max(0, imageSize.width)
        let maxV = max(0, imageSize.height)
        let h = result.horizontal
        let v = result.vertical
        if h > maxH && h > 0 {
            let factor = maxH / h
            result = .init(
                top: result.top * factor,
                leading: result.leading * factor,
                bottom: result.bottom * factor,
                trailing: result.trailing * factor)
        }
        if result.vertical > maxV && result.vertical > 0 {
            let factor = maxV / result.vertical
            result = .init(
                top: result.top * factor,
                leading: result.leading * factor,
                bottom: result.bottom * factor,
                trailing: result.trailing * factor)
        }
        return result
    }
}

// MARK: - 切片保护边（签名族确证）

enum HighlightBackgroundImageSliceProtectionEdge: String, Codable, CaseIterable {
    case top, leading, bottom, trailing
}

struct HighlightBackgroundImageSliceProtectionControlCenters {
    var top: CGPoint
    var leading: CGPoint
    var bottom: CGPoint
    var trailing: CGPoint

    /// center(for:)（签名确证）。
    func center(for edge: HighlightBackgroundImageSliceProtectionEdge)
        -> CGPoint {
        switch edge {
        case .top: return top
        case .leading: return leading
        case .bottom: return bottom
        case .trailing: return trailing
        }
    }
}

enum HighlightBackgroundImagePreviewResizeHandle: String, Codable {
    case topLeft, top, topRight, leading, trailing,
         bottomLeft, bottom, bottomRight
}

// MARK: - 背景图布局（0x1001c1a1c L161-176 / 0x1001c1f10 L178-200）

/// 背景图九宫格布局（init(from:) 0x1001c1a1c L161-176 域确证：
/// decodeIfPresent 长链，slices 默认 0、scale 默认 1.0、offset 默认 0、
/// opacity 默认 1.0）。
struct HighlightBackgroundImageLayout: Codable, Hashable {
    var sliceInsets: HighlightBackgroundImageInsets
    var contentInsets: HighlightBackgroundImageInsets
    var horizontalScale: CGFloat
    var verticalScale: CGFloat
    var horizontalOffset: CGFloat
    var verticalOffset: CGFloat
    var opacity: CGFloat

    init(
        sliceInsets: HighlightBackgroundImageInsets =
            HighlightBackgroundImageInsets(),
        contentInsets: HighlightBackgroundImageInsets =
            HighlightBackgroundImageInsets(),
        horizontalScale: CGFloat = 1.0,
        verticalScale: CGFloat = 1.0,
        horizontalOffset: CGFloat = 0.0,
        verticalOffset: CGFloat = 0.0,
        opacity: CGFloat = 1.0
    ) {
        self.sliceInsets = sliceInsets
        self.contentInsets = contentInsets
        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.opacity = opacity
    }

    enum CodingKeys: String, CodingKey {
        case sliceInsets, contentInsets
        case horizontalScale, verticalScale
        case horizontalOffset, verticalOffset, opacity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sliceInsets = try c.decodeIfPresent(
            HighlightBackgroundImageInsets.self, forKey: .sliceInsets)
            ?? HighlightBackgroundImageInsets()
        contentInsets = try c.decodeIfPresent(
            HighlightBackgroundImageInsets.self, forKey: .contentInsets)
            ?? HighlightBackgroundImageInsets()
        horizontalScale = try c.decodeIfPresent(
            CGFloat.self, forKey: .horizontalScale) ?? 1.0
        verticalScale = try c.decodeIfPresent(
            CGFloat.self, forKey: .verticalScale) ?? 1.0
        horizontalOffset = try c.decodeIfPresent(
            CGFloat.self, forKey: .horizontalOffset) ?? 0.0
        verticalOffset = try c.decodeIfPresent(
            CGFloat.self, forKey: .verticalOffset) ?? 0.0
        opacity = try c.decodeIfPresent(
            CGFloat.self, forKey: .opacity) ?? 1.0
    }

    /// centeredStretchRegion(for:)（0x1001c1f10 L178-200 域确证：
    /// 拉伸比例钳制 0.1...4.0，预览区以内容区居中）。
    static func centeredStretchRegion(for image: UIImage?)
        -> HighlightBackgroundImageLayout {
        let width = image?.size.width ?? 0
        let height = image?.size.height ?? 0
        let scale = min(max(4.0, 0.1), 4.0)
        let slice = min(width * scale, max(1.0, width * scale))
        let centered = HighlightBackgroundImageLayout(
            sliceInsets: HighlightBackgroundImageInsets(
                top: height * 0.5 - slice * 0.5,
                leading: width * 0.5 - slice * 0.5,
                bottom: height * 0.5 - slice * 0.5,
                trailing: width * 0.5 - slice * 0.5))
        return centered
    }

    /// clampedHorizontalScale getter（0x100a02b24 L206-208 域确证：0...1）。
    var clampedHorizontalScale: CGFloat {
        min(max(horizontalScale, 0), 1)
    }
    var clampedVerticalScale: CGFloat { min(max(verticalScale, 0), 1) }
    var clampedOpacity: CGFloat { min(max(opacity, 0), 1) }

    /// backgroundPreviewRect(around:)（0x1001d09ac L214-231 签名域）。
    func backgroundPreviewRect(around bounds: CGRect) -> CGRect {
        bounds.insetBy(
            dx: contentInsets.horizontal * clampedHorizontalScale,
            dy: contentInsets.vertical * clampedVerticalScale)
    }

    /// normalizedSliceInsets(forImageSize:)（0x1001d0828 L233-249 签名域）。
    func normalizedSliceInsets(forImageSize imageSize: CGSize)
        -> HighlightBackgroundImageInsets {
        sliceInsets.clampedForNineSlice(imageSize: imageSize)
    }

    /// destinationSliceScale(forImageSize:destinationSize:)
    /// （0x1001c2388 L271-285 域确证：源 < 目标 → 前向分支，>0 再分支）。
    func destinationSliceScale(
        forImageSize imageSize: CGSize, destinationSize: CGSize
    ) -> CGFloat {
        guard destinationSize.width > 0, destinationSize.height > 0 else {
            return 1.0
        }
        let sourceHorizontal = normalizedSliceInsets(
            forImageSize: imageSize).horizontal
        let destinationHorizontal = destinationSliceInsets(
            forImageSize: imageSize,
            destinationSize: destinationSize).horizontal
        let horizontal = destinationHorizontal > 0
            ? destinationHorizontal / max(sourceHorizontal, 0.001) : 1.0
        let sourceVertical = normalizedSliceInsets(
            forImageSize: imageSize).vertical
        let destinationVertical = destinationSliceInsets(
            forImageSize: imageSize,
            destinationSize: destinationSize).vertical
        let vertical = destinationVertical > 0
            ? destinationVertical / max(sourceVertical, 0.001) : 1.0
        return max(min(horizontal, vertical), 0.001)
    }

    /// destinationSliceInsets(forImageSize:destinationSize:)（签名确证）。
    func destinationSliceInsets(
        forImageSize imageSize: CGSize, destinationSize: CGSize
    ) -> HighlightBackgroundImageInsets {
        let normalized = normalizedSliceInsets(forImageSize: imageSize)
        let scaleX = destinationSize.width / max(imageSize.width, 0.001)
        let scaleY = destinationSize.height / max(imageSize.height, 0.001)
        return HighlightBackgroundImageInsets(
            top: normalized.top * scaleY,
            leading: normalized.leading * scaleX,
            bottom: normalized.bottom * scaleY,
            trailing: normalized.trailing * scaleX)
    }

    /// movingBackgroundPreview(by:)（签名确证：偏移累加）。
    func movingBackgroundPreview(by offset: CGPoint)
        -> HighlightBackgroundImageLayout {
        var copy = self
        copy.horizontalOffset += offset.x
        copy.verticalOffset += offset.y
        return copy
    }

    /// fittingBackgroundPreview(to:around:)（签名确证：预览贴合目标框）。
    func fittingBackgroundPreview(
        to rect: CGRect, around bounds: CGRect
    ) -> HighlightBackgroundImageLayout {
        var copy = self
        let target = backgroundPreviewRect(around: bounds)
        guard target.width > 0, target.height > 0 else { return copy }
        copy.horizontalScale = min(
            max(rect.width / target.width, 0), 1)
        copy.verticalScale = min(max(rect.height / target.height, 0), 1)
        return copy
    }

    /// resizingBackgroundPreview(handle:by:around:)（签名确证）。
    func resizingBackgroundPreview(
        handle: HighlightBackgroundImagePreviewResizeHandle,
        by translation: CGSize, around bounds: CGRect
    ) -> HighlightBackgroundImageLayout {
        var copy = self
        switch handle {
        case .top, .topLeft, .topRight:
            copy.verticalScale = min(
                max(copy.verticalScale + translation.height / 200.0, 0), 1)
        case .bottom, .bottomLeft, .bottomRight:
            copy.verticalScale = min(
                max(copy.verticalScale - translation.height / 200.0, 0), 1)
        case .leading, .trailing:
            copy.horizontalScale = min(
                max(copy.horizontalScale + translation.width / 200.0, 0), 1)
        }
        return copy
    }

    /// updatingSliceProtection(edge:translation:imageSize:imageRect:)
    /// （签名确证）。
    func updatingSliceProtection(
        edge: HighlightBackgroundImageSliceProtectionEdge,
        translation: CGSize, imageSize: CGSize, imageRect: CGRect
    ) -> HighlightBackgroundImageLayout {
        updatingSliceProtection(
            edge: edge, translation: translation, imageSize: imageSize,
            scale: imageRect.width / max(imageSize.width, 0.001))
    }

    /// updatingRenderedSliceProtection(edge:translation:imageSize:
    /// destinationSize:)（签名确证）。
    func updatingRenderedSliceProtection(
        edge: HighlightBackgroundImageSliceProtectionEdge,
        translation: CGSize, imageSize: CGSize, destinationSize: CGSize
    ) -> HighlightBackgroundImageLayout {
        updatingSliceProtection(
            edge: edge, translation: translation, imageSize: imageSize,
            scale: destinationSliceScale(
                forImageSize: imageSize, destinationSize: destinationSize))
    }

    private func updatingSliceProtection(
        edge: HighlightBackgroundImageSliceProtectionEdge,
        translation: CGSize, imageSize: CGSize, scale: CGFloat
    ) -> HighlightBackgroundImageLayout {
        var slices = sliceInsets
        let delta = translation.width / max(scale, 0.001)
        let deltaV = translation.height / max(scale, 0.001)
        switch edge {
        case .top: slices.top = max(slices.top + deltaV, 0)
        case .leading: slices.leading = max(slices.leading + delta, 0)
        case .bottom: slices.bottom = max(slices.bottom - deltaV, 0)
        case .trailing: slices.trailing = max(slices.trailing - delta, 0)
        }
        var copy = self
        copy.sliceInsets = slices.clampedForNineSlice(imageSize: imageSize)
        return copy
    }

    /// sliceProtectionControlCenters(imageSize:backgroundRect:canvasSize:)
    /// （签名确证）。
    func sliceProtectionControlCenters(
        imageSize: CGSize, backgroundRect: CGRect, canvasSize: CGSize
    ) -> HighlightBackgroundImageSliceProtectionControlCenters {
        let destination = destinationSliceInsets(
            forImageSize: imageSize, destinationSize: backgroundRect.size)
        return HighlightBackgroundImageSliceProtectionControlCenters(
            top: CGPoint(
                x: backgroundRect.midX,
                y: backgroundRect.minY + destination.top),
            leading: CGPoint(
                x: backgroundRect.minX + destination.leading,
                y: backgroundRect.midY),
            bottom: CGPoint(
                x: backgroundRect.midX,
                y: backgroundRect.maxY - destination.bottom),
            trailing: CGPoint(
                x: backgroundRect.maxX - destination.trailing,
                y: backgroundRect.midY))
    }
}

// MARK: - 切片缓存（0x1001c2bfc L563）

struct HighlightImageSliceCacheKey: Hashable {
    var cacheIdentifier: String
    var sourceRect: CGRect
    var scale: CGFloat
}

/// 九宫格切片缓存（init(maxEntries:) 0x1001c2bfc L563 域确证：
/// maxEntries 上限的字典缓存，put 淘汰最旧键）。
final class HighlightImageSliceCache {
    private let maxEntries: Int
    private var storage: [HighlightImageSliceCacheKey: UIImage] = [:]
    private var order: [HighlightImageSliceCacheKey] = []

    init(maxEntries: Int) {
        self.maxEntries = max(1, maxEntries)
    }

    func get(_ key: HighlightImageSliceCacheKey) -> UIImage? {
        storage[key]
    }

    func put(_ key: HighlightImageSliceCacheKey, value: UIImage) {
        if storage[key] == nil {
            order.append(key)
            while order.count > maxEntries {
                let evicted = order.removeFirst()
                storage.removeValue(forKey: evicted)
            }
        }
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
        order.removeAll()
    }
}

// MARK: - 背景图画刷（0x10018cc2c L599-606 → 0x1001c4174 L834-859）

/// 背景图画刷（init 六参 0x10018cc2c L599-606 域确证）。
struct HighlightBackgroundImagePaint {
    enum Size: String, Codable {
        case original, stretch, tile
    }

    enum RepeatMode: String, Codable {
        case none, repeatX, repeatY, repeatBoth
    }

    /// drawImageSlice 的三档切片模式（sliceDrawMode(row:column:)
    /// 0x1001c2f58 域内联确证：0=stretch / 1=tileY / 2=tileX）。
    enum SliceDrawMode {
        case stretch, tileVertically, tileHorizontally
    }

    var image: UIImage
    var size: Size
    var repeatMode: RepeatMode
    var position: CGPoint
    var layout: HighlightBackgroundImageLayout
    var cacheIdentifier: String?

    private static let sliceCache = HighlightImageSliceCache(
        maxEntries: 64)

    /// clamped(_:)（签名确证：0...1）。
    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    /// drawingRect(for:)（签名确证：内容内边距 + 偏移）。
    func drawingRect(for rect: CGRect) -> CGRect {
        let insets = layout.contentInsets.edgeInsets
        let scaled = rect.insetBy(
            dx: insets.left * layout.clampedHorizontalScale,
            dy: insets.top * layout.clampedVerticalScale)
        return scaled.offsetBy(
            dx: layout.horizontalOffset, dy: layout.verticalOffset)
    }

    /// draw(in:context:)（0x1001c05f0 L612-633 域确证：宽高>0 +
    /// resolvedTileSize>0 守卫；分派 drawImage/drawNineSlice/drawTiledImage）。
    func draw(in rect: CGRect, context: CGContext) {
        let target = drawingRect(for: rect)
        guard target.width > 0, target.height > 0 else { return }
        switch repeatMode {
        case .none, .repeatBoth:
            if layout.sliceInsets.horizontal > 0
                || layout.sliceInsets.vertical > 0 {
                drawNineSlice(in: target)
            } else {
                drawImage(in: target)
            }
        case .repeatX, .repeatY:
            drawRepeated(
                target, repeatX: repeatMode == .repeatX,
                repeatY: repeatMode == .repeatY, clippedTo: target)
        }
    }

    /// resolvedTileSize(in:)（0x1001c2c9c L635-653 域确证：图像尺寸，
    /// 空 → .zero）。
    private func resolvedTileSize(in rect: CGRect) -> CGSize {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return .zero }
        return size
    }

    /// drawImage(in:)（0x1001c2e2c L655-667 域确证：CGImage 存在且
    /// 切片域非空 → drawNineSlice；否则 drawInRect alpha 钳制）。
    private func drawImage(in rect: CGRect) {
        if image.cgImage != nil
            && (layout.sliceInsets.horizontal > 0
                || layout.sliceInsets.vertical > 0) {
            drawNineSlice(in: rect)
            return
        }
        image.draw(
            in: rect, blendMode: .normal,
            alpha: clamped(layout.clampedOpacity))
    }

    /// drawNineSlice(in:)（0x1001c2f58/0x1001c36f8 L669-721 域确证：
    /// 3x3 切片网格，rows/cols 各三段，sliceDrawMode(row:column:) 分派）。
    private func drawNineSlice(in rect: CGRect) {
        guard let cgImage = image.cgImage,
              image.size.width > 0, image.size.height > 0 else {
            image.draw(
                in: rect, blendMode: .normal,
                alpha: clamped(layout.clampedOpacity))
            return
        }
        let imageSize = image.size
        let slices = normalizedSliceInsets(imageSize: imageSize)
        let destination = destinationSliceInsets(
            forImageSize: imageSize, destinationSize: rect.size)
        let columns = [
            (0, slices.leading, destination.leading),
            (slices.leading, imageSize.width - slices.horizontal,
             rect.width - destination.horizontal),
            (imageSize.width - slices.trailing, slices.trailing,
             destination.trailing),
        ]
        let rows = [
            (0, slices.top, destination.top),
            (slices.top, imageSize.height - slices.vertical,
             rect.height - destination.vertical),
            (imageSize.height - slices.bottom, slices.bottom,
             destination.bottom),
        ]
        var y = rect.minY
        for (index, row) in rows.enumerated() {
            var x = rect.minX
            for (columnIndex, column) in columns.enumerated() {
                let sourceRect = CGRect(
                    x: column.0, y: row.0, width: column.1, height: row.1)
                let targetRect = CGRect(
                    x: x, y: y, width: max(column.2, 0),
                    height: max(row.2, 0))
                let mode = sliceDrawMode(row: index, column: columnIndex)
                drawImageSlice(
                    from: sourceRect, in: targetRect, mode: mode)
                x += max(column.2, 0)
            }
            y += max(row.2, 0)
        }
    }

    /// sliceDrawMode(row:column:)（0x1001c2f58 内联域确证：
    /// 中行/中列 → 平铺，其余 stretch）。
    private func sliceDrawMode(row: Int, column: Int) -> SliceDrawMode {
        switch (row, column) {
        case (1, 1): return .stretch
        case (_, 1): return .tileVertically
        case (1, _): return .tileHorizontally
        default: return .stretch
        }
    }

    /// drawImageSlice(from:in:mode:)（0x1001c3b0c L754-802 域确证：
    /// 源图矩形按 CGImage 尺寸反算；缓存键命中复用；mode 0 直绘，
    /// 1/2 drawTiledImage 钳制最小 1.0）。
    private func drawImageSlice(
        from sourceRect: CGRect, in targetRect: CGRect,
        mode: SliceDrawMode
    ) {
        guard targetRect.width > 0, targetRect.height > 0,
              let cgImage = image.cgImage else {
            return
        }
        let scale = CGFloat(cgImage.width) / max(image.size.width, 0.001)
        let verticalScale = CGFloat(cgImage.height) / max(image.size.height, 0.001)
        let pixelRect = CGRect(
            x: sourceRect.minX * scale,
            y: sourceRect.minY * verticalScale,
            width: sourceRect.width * scale,
            height: sourceRect.height * verticalScale)
            .integral
        let key = HighlightImageSliceCacheKey(
            cacheIdentifier: cacheIdentifier ?? String(image.hashValue),
            sourceRect: pixelRect, scale: image.scale)
        var slice = Self.sliceCache.get(key)
        if slice == nil, let cropped = cgImage.cropping(to: pixelRect) {
            slice = UIImage(
                cgImage: cropped, scale: image.scale,
                orientation: image.imageOrientation)
            Self.sliceCache.put(key, value: slice!)
        }
        guard let slice else { return }
        switch mode {
        case .stretch:
            slice.draw(
                in: targetRect, blendMode: .normal,
                alpha: clamped(layout.clampedOpacity))
        case .tileHorizontally:
            drawTiledImage(
                slice, in: targetRect,
                tileSize: CGSize(
                    width: max(slice.size.width, 1),
                    height: targetRect.height))
        case .tileVertically:
            drawTiledImage(
                slice, in: targetRect,
                tileSize: CGSize(
                    width: targetRect.width,
                    height: max(slice.size.height, 1)))
        }
    }

    /// drawTiledImage(_:in:tileSize:)（0x1001c4174 L834-859 域确证：
    /// SaveGState + ClipToRect，双层平铺循环）。
    private func drawTiledImage(
        _ image: UIImage, in rect: CGRect, tileSize: CGSize
    ) {
        guard let context = UIGraphicsGetCurrentContext(),
              tileSize.width > 0, tileSize.height > 0 else {
            return
        }
        context.saveGState()
        context.clip(to: rect)
        var y = rect.minY
        let alpha = clamped(layout.clampedOpacity)
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                image.draw(
                    in: CGRect(
                        x: x, y: y, width: tileSize.width,
                        height: tileSize.height),
                    blendMode: .normal, alpha: alpha)
                x += tileSize.width
            }
            y += tileSize.height
        }
        context.restoreGState()
    }

    /// drawRepeated(_:repeatX:repeatY:clippedTo:)（签名确证）。
    private func drawRepeated(
        _ rect: CGRect, repeatX: Bool, repeatY: Bool, clippedTo: CGRect
    ) {
        let tileSize = resolvedTileSize(in: rect)
        guard tileSize.width > 0, tileSize.height > 0 else {
            drawImage(in: rect)
            return
        }
        if repeatX && repeatY {
            drawTiledImage(image, in: rect, tileSize: tileSize)
        } else if repeatX {
            drawTiledImage(
                image, in: rect,
                tileSize: CGSize(width: tileSize.width, height: rect.height))
        } else {
            drawTiledImage(
                image, in: rect,
                tileSize: CGSize(width: rect.width, height: tileSize.height))
        }
    }

    private func normalizedSliceInsets(imageSize: CGSize)
        -> HighlightBackgroundImageInsets {
        layout.normalizedSliceInsets(forImageSize: imageSize)
    }

    private func destinationSliceInsets(
        forImageSize imageSize: CGSize, destinationSize: CGSize
    ) -> HighlightBackgroundImageInsets {
        layout.destinationSliceInsets(
            forImageSize: imageSize, destinationSize: destinationSize)
    }
}

// MARK: - 渲染器（0x1001c4c3c L1046-1108 → 0x1001c8b28 L1734-1753）

/// 渐变文字渲染器（静态域 0x1001c4c3c-0x1001c8b28 块体族确证）。
enum HighlightGradientTextRenderer {

    /// 渲染配置（renderBackgroundSnapshot 0x1001c5d5c L1154-1182 域确证：
    /// insets 四元组 + lineFragmentPadding + lineBreakMode +
    /// maximumNumberOfLines）。
    struct Configuration: Hashable {
        var textInsetsTop: CGFloat
        var textInsetsLeft: CGFloat
        var textInsetsBottom: CGFloat
        var textInsetsRight: CGFloat
        var lineFragmentPadding: CGFloat
        var lineBreakMode: NSLineBreakMode
        var maximumNumberOfLines: Int

        init(
            textInsetsTop: CGFloat = 0, textInsetsLeft: CGFloat = 0,
            textInsetsBottom: CGFloat = 0, textInsetsRight: CGFloat = 0,
            lineFragmentPadding: CGFloat = 0,
            lineBreakMode: NSLineBreakMode = .byWordWrapping,
            maximumNumberOfLines: Int = 0
        ) {
            self.textInsetsTop = textInsetsTop
            self.textInsetsLeft = textInsetsLeft
            self.textInsetsBottom = textInsetsBottom
            self.textInsetsRight = textInsetsRight
            self.lineFragmentPadding = lineFragmentPadding
            self.lineBreakMode = lineBreakMode
            self.maximumNumberOfLines = maximumNumberOfLines
        }
    }

    /// TextKit1/TextKit2 布局封装（makeLayout/makeTextKit2Layout 签名确证）。
    struct TextLayout {
        let storage: NSTextContentStorage
        let layoutManager: NSTextLayoutManager
        let container: NSTextContainer
    }

    // MARK: 属性检测（0x1001d0474 L947-954 / 0x1001c44f8 L1847-1856）

    /// hasBackgroundAttributes(_:)（0x1001d0474 L947-954 域确证：
    /// 长度>0 且 enumerateAttributesInRange 命中背景属性）。
    static func hasBackgroundAttributes(_ text: NSAttributedString?)
        -> Bool {
        guard let text, text.length > 0 else { return false }
        var found = false
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length))
        { attributes, _, stop in
            if attributes[.backgroundColor] != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    /// hasForegroundAttributes(_:)（0x1001d0474 域确证）。
    static func hasForegroundAttributes(_ text: NSAttributedString?)
        -> Bool {
        guard let text, text.length > 0 else { return false }
        var found = false
        text.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: text.length)
        ) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    /// hasGradientAttributes(_:)（签名确证：背景/前景/描边/附件四查）。
    static func hasGradientAttributes(_ text: NSAttributedString?)
        -> Bool {
        guard let text, text.length > 0 else { return false }
        var found = false
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length))
        { attributes, _, stop in
            if attributes[.backgroundColor] != nil
                || attributes[.foregroundColor] != nil
                || attributes[.strokeColor] != nil
                || attributes[.attachment] != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    /// hasRoundedBackground(in:range:)（0x1001ca808 L1863-1869 签名域）。
    static func hasRoundedBackground(
        in text: NSAttributedString, range: NSRange
    ) -> Bool {
        guard range.location != NSNotFound, range.length > 0 else {
            return false
        }
        var found = false
        text.enumerateAttributes(in: range) { attributes, _, stop in
            if backgroundCornerRadius(from: attributes) > 0 {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    /// backgroundCornerRadius(from:)（签名确证：NSCustomHighlight 钳制）。
    static func backgroundCornerRadius(
        from attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        guard let corner = attributes[
            NSAttributedString.Key("NSCustomHighlightCornerRadius")
        ] as? CGFloat else {
            return 0
        }
        return min(max(corner, 0), 100)
    }

    /// hasAttribute(_:in:range:)（0x1001c44f8 L1847-1856 域确证：
    /// 直接 attribute 链 + enumerate 兜底）。
    static func hasAttribute(
        _ key: NSAttributedString.Key, in text: NSAttributedString,
        range: NSRange
    ) -> Bool {
        if text.attribute(key, at: 0, effectiveRange: nil) != nil {
            return true
        }
        var found = false
        text.enumerateAttribute(key, in: range) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    /// ranges(in:excluding:)（0x1001c7d78 L1822-1841 域确证：
    /// 交集前后两段；排除域无效/零长 → 原域整段返回）。
    static func ranges(
        in range: NSRange, excluding excluded: NSRange?
    ) -> [NSRange] {
        guard let excluded, excluded.location != NSNotFound,
              excluded.length > 0 else {
            return range.location != NSNotFound && range.length > 0
                ? [range] : []
        }
        let intersection = NSIntersectionRange(range, excluded)
        guard intersection.length > 0 else {
            return range.location != NSNotFound && range.length > 0
                ? [range] : []
        }
        var result: [NSRange] = []
        if range.location < intersection.location {
            result.append(
                NSRange(
                    location: range.location,
                    length: intersection.location - range.location))
        }
        let rangeEnd = range.location + range.length
        let intersectionEnd = intersection.location + intersection.length
        if intersectionEnd < rangeEnd {
            result.append(
                NSRange(
                    location: intersectionEnd,
                    length: rangeEnd - intersectionEnd))
        }
        return result
    }

    // MARK: 签名域（0x1001c4a5c L1033-1044 → 0x1001c599c L1126-1147）

    /// quantized(_:multiplier:)（签名确证）。
    private static func quantized(
        _ value: CGFloat, multiplier: CGFloat
    ) -> Int {
        guard multiplier > 0 else { return 0 }
        return Int((value * multiplier).rounded())
    }

    /// configurationSignature(_:)（签名确证）。
    static func configurationSignature(_ configuration: Configuration)
        -> Int {
        var hasher = Hasher()
        hasher.combine(quantized(configuration.textInsetsTop, multiplier: 100))
        hasher.combine(
            quantized(configuration.textInsetsLeft, multiplier: 100))
        hasher.combine(
            quantized(configuration.textInsetsBottom, multiplier: 100))
        hasher.combine(
            quantized(configuration.textInsetsRight, multiplier: 100))
        hasher.combine(quantized(configuration.lineFragmentPadding,
                                  multiplier: 100))
        hasher.combine(configuration.lineBreakMode.rawValue)
        hasher.combine(configuration.maximumNumberOfLines)
        return hasher.finalize()
    }

    /// backgroundSnapshotAttributeSignature(_:)（0x1001c4a5c L1033-1044
    /// 域确证：键名字典序 + 值签名链）。
    static func backgroundSnapshotAttributeSignature(
        _ attributes: [NSAttributedString.Key: Any]
    ) -> Int {
        var hasher = Hasher()
        for key in attributes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            hasher.combine(key.rawValue)
            hasher.combine(backgroundSnapshotValueSignature(attributes[key]))
        }
        return hasher.finalize()
    }

    /// backgroundSnapshotValueSignature(_:)（0x1001c4c3c L1046-1108 域
    /// 确证：UIColor → colorSignature / UIFont → fontName+pointSize+
    /// symbolicTraits / NSParagraphStyle → alignment+行距族+lineBreakMode+
    /// lineBreakStrategy / NSNumber → integerValue+doubleValue /
    /// NSString → String.hash / NSTextAttachment → bounds+description /
    /// paint 结构 → 字段哈希 / 其他 → String(describing:)）。
    static func backgroundSnapshotValueSignature(_ value: Any?) -> Int {
        var hasher = Hasher()
        switch value {
        case let color as UIColor:
            hasher.combine(colorSignature(color))
        case let font as UIFont:
            hasher.combine(font.fontName)
            hasher.combine(quantized(font.pointSize, multiplier: 100))
            hasher.combine(font.fontDescriptor.symbolicTraits.rawValue)
        case let paragraph as NSParagraphStyle:
            hasher.combine(paragraph.alignment.rawValue)
            hasher.combine(quantized(paragraph.lineSpacing, multiplier: 100))
            hasher.combine(
                quantized(paragraph.paragraphSpacing, multiplier: 100))
            hasher.combine(
                quantized(paragraph.paragraphSpacingBefore, multiplier: 100))
            hasher.combine(
                quantized(paragraph.firstLineHeadIndent, multiplier: 100))
            hasher.combine(quantized(paragraph.headIndent, multiplier: 100))
            hasher.combine(quantized(paragraph.tailIndent, multiplier: 100))
            hasher.combine(paragraph.lineBreakMode.rawValue)
            hasher.combine(paragraph.lineBreakStrategy.rawValue)
        case let number as NSNumber:
            hasher.combine(number.intValue)
            hasher.combine(number.doubleValue.bitPattern)
        case let string as NSString:
            hasher.combine(string as String)
        case let attachment as NSTextAttachment:
            hasher.combine(quantized(attachment.bounds.width, multiplier: 100))
            hasher.combine(
                quantized(attachment.bounds.height, multiplier: 100))
            hasher.combine(String(describing: type(of: attachment)))
        case let image as UIImage:
            hasher.combine(imageSignature(image))
        case let someValue:
            hasher.combine(String(describing: someValue))
        case nil:
            hasher.combine(0)
        }
        return hasher.finalize()
    }

    /// backgroundSnapshotAttributedTextSignature(_:)（签名确证：
    /// length + string + 逐段属性签名）。
    static func backgroundSnapshotAttributedTextSignature(
        _ text: NSAttributedString
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(text.length)
        hasher.combine(text.string)
        text.enumerateAttributes(
            in: NSRange(location: 0, length: text.length)
        ) { attributes, _, _ in
            hasher.combine(backgroundSnapshotAttributeSignature(attributes))
        }
        return hasher.finalize()
    }

    /// imageSignature(_:)（0x1001c5ae0 L1110-1124 域确证：宽/高/scale/
    /// orientation + CGImage 五元组哈希）。
    static func imageSignature(_ image: UIImage) -> Int {
        var hasher = Hasher()
        hasher.combine(quantized(image.size.width, multiplier: 100))
        hasher.combine(quantized(image.size.height, multiplier: 100))
        hasher.combine(quantized(image.scale, multiplier: 100))
        hasher.combine(image.imageOrientation.rawValue)
        if let cgImage = image.cgImage {
            hasher.combine(cgImage.width)
            hasher.combine(cgImage.height)
            hasher.combine(cgImage.bitsPerComponent)
            hasher.combine(cgImage.bitsPerPixel)
            hasher.combine(cgImage.bytesPerRow)
        }
        return hasher.finalize()
    }

    /// colorSignature(_:)（0x1001c599c L1126-1147 域确证：RGBA 四分量
    /// hash(into:) 链）。
    static func colorSignature(_ color: UIColor) -> Int {
        var hasher = Hasher()
        let resolved = HighlightResolvedColor(uiColor: color)
        hasher.combine(quantized(resolved.red, multiplier: 100))
        hasher.combine(quantized(resolved.green, multiplier: 100))
        hasher.combine(quantized(resolved.blue, multiplier: 100))
        hasher.combine(quantized(resolved.alpha, multiplier: 100))
        return hasher.finalize()
    }

    // MARK: 缓存键（0x1001cc5f8 L988-999 / 0x1001c495c L1001-1003）

    /// pixelCount(_:scale:)（0x1001c495c L1001-1003 域确证：
    /// 量化宽高 × scale 的像素计数哈希，100 倍量化）。
    static func pixelCount(_ size: CGSize, scale: CGFloat) -> Int {
        var hasher = Hasher()
        hasher.combine(quantized(size.width, multiplier: scale * 100))
        hasher.combine(quantized(size.height, multiplier: scale * 100))
        hasher.combine(quantized(scale, multiplier: 100))
        hasher.combine(quantized(size.width * size.height,
                                 multiplier: scale * 100))
        return hasher.finalize()
    }

    /// backgroundSnapshotCacheKey(in:textSignature:configuration:
    /// renderIdentity:scale:)（0x1001cc5f8 L988-999 域确证：
    /// 空矩形/scale<=0 → nil；否则五元组键）。
    static func backgroundSnapshotCacheKey(
        in bounds: CGRect, textSignature: Int,
        configuration: Configuration, renderIdentity: Int, scale: CGFloat
    ) -> HighlightGradientBackgroundSnapshotCacheKey? {
        guard bounds.width > 0, bounds.height > 0, scale > 0 else {
            return nil
        }
        return HighlightGradientBackgroundSnapshotCacheKey(
            renderIdentity: renderIdentity,
            quantizedWidth: quantized(bounds.width, multiplier: scale * 100),
            quantizedHeight: quantized(bounds.height, multiplier: scale * 100),
            quantizedScale: quantized(scale, multiplier: 1000),
            pixelCount: pixelCount(bounds.size, scale: scale),
            textSignature: textSignature)
    }

    /// backgroundSnapshotCacheKey(for:in:configuration:renderIdentity:
    /// scale:)（签名确证：文本签名由 attributedText 计算）。
    static func backgroundSnapshotCacheKey(
        for attributedText: NSAttributedString?, in bounds: CGRect,
        configuration: Configuration, renderIdentity: Int, scale: CGFloat
    ) -> HighlightGradientBackgroundSnapshotCacheKey? {
        guard let attributedText else { return nil }
        return backgroundSnapshotCacheKey(
            in: bounds,
            textSignature: backgroundSnapshotAttributedTextSignature(
                attributedText),
            configuration: configuration,
            renderIdentity: renderIdentity, scale: scale)
    }

    // MARK: 快照渲染（0x1001c5d5c L1154-1182 / 0x1001c60e4 L1230-1279）

    /// makeTextKit2Layout(for:in:configuration:)（0x1001c5ea8 L1541-1563
    /// 域确证：NSTextContentStorage + LayoutManager + Container 尺寸 =
    /// 宽 - 左右 insets、高 - 上下 insets，padding/mode/maxLines 链）。
    static func makeTextKit2Layout(
        for attributedText: NSAttributedString, in bounds: CGRect,
        configuration: Configuration
    ) -> TextLayout {
        let storage = NSTextContentStorage()
        storage.attributedString = attributedText
        let layoutManager = NSTextLayoutManager()
        storage.addTextLayoutManager(layoutManager)
        let width = max(
            bounds.width - configuration.textInsetsLeft
                - configuration.textInsetsRight, 0)
        let height = max(
            bounds.height - configuration.textInsetsTop
                - configuration.textInsetsBottom, 0)
        let container = NSTextContainer(size: CGSize(width: width,
                                                     height: height))
        container.lineFragmentPadding = configuration.lineFragmentPadding
        container.lineBreakMode = configuration.lineBreakMode
        container.maximumNumberOfLines = configuration.maximumNumberOfLines
        layoutManager.textContainer = container
        return TextLayout(
            storage: storage, layoutManager: layoutManager,
            container: container)
    }

    /// makeLayout(for:in:configuration:)（签名确证：TextKit1 回退）。
    static func makeLayout(
        for attributedText: NSAttributedString, in bounds: CGRect,
        configuration: Configuration
    ) -> (NSLayoutManager, NSTextContainer, NSTextStorage) {
        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let width = max(
            bounds.width - configuration.textInsetsLeft
                - configuration.textInsetsRight, 0)
        let height = max(
            bounds.height - configuration.textInsetsTop
                - configuration.textInsetsBottom, 0)
        let container = NSTextContainer(size: CGSize(width: width,
                                                     height: height))
        container.lineFragmentPadding = configuration.lineFragmentPadding
        container.lineBreakMode = configuration.lineBreakMode
        container.maximumNumberOfLines = configuration.maximumNumberOfLines
        layoutManager.addTextContainer(container)
        return (layoutManager, container, storage)
    }

    /// renderBackgroundSnapshot(_:in:configuration:scale:)
    /// （0x1001c5d5c L1154-1182 域确证：渐变属性守卫 + 渲染器 scale +
    /// drawBackgroundGradients 捕获回调 + UIGraphicsImageRenderer）。
    static func renderBackgroundSnapshot(
        _ attributedText: NSAttributedString, in bounds: CGRect,
        configuration: Configuration, scale: CGFloat
    ) -> UIImage? {
        guard bounds.width > 0, bounds.height > 0, scale > 0 else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(
            size: bounds.size, format: format)
        return renderer.image { rendererContext in
            drawBackgroundGradients(
                attributedText, in: bounds, configuration: configuration,
                textLayoutManager: nil)
        }
    }

    /// drawBackgroundGradients(_:in:configuration:textLayoutManager:)
    /// （0x1001c60e4 L1230-1279 + closure 0x1001c6e24 L1244-1278 域确证：
    /// 长度/上下文/矩形守卫；enumerateAttributesInRange；每段：
    /// 背景色 → fillRect / 渐变 → 圆角裁剪后 draw / 图 → paint.draw；
    /// 圆角半径 = min(w*0.5, h*0.5, 配置钳制)）。
    static func drawBackgroundGradients(
        _ attributedText: NSAttributedString?, in bounds: CGRect,
        configuration: Configuration, textLayoutManager: NSTextLayoutManager?
    ) {
        guard let attributedText, attributedText.length > 0,
              let context = UIGraphicsGetCurrentContext(),
              bounds.width > 0, bounds.height > 0 else {
            return
        }
        // TextLayout 装配壳不可达（嵌套于 HighlightBackgroundImagePaint 域）
        // ——直接在传入的 layoutManager 上确保布局（wave-16）。
        if let textLayoutManager {
            let container = NSTextContainer(size: bounds.size)
            textLayoutManager.textContainer = container
            textLayoutManager.ensureLayout(
                for: textLayoutManager.documentRange)
        }
        attributedText.enumerateAttributes(
            in: NSRange(location: 0, length: attributedText.length)
        ) { attributes, range, _ in
            let rects = backgroundRects(
                for: range, fallbackLayout: nil,
                textLayoutManager: textLayoutManager, bounds: bounds,
                configuration: configuration)
            guard !rects.isEmpty else { return }
            let cornerRadius = backgroundCornerRadius(from: attributes)
            let backgroundColor = attributes[.backgroundColor] as? UIColor
            let gradient = attributes[
                NSAttributedString.Key("LeaflowHighlightGradient")
            ] as? HighlightLinearGradientPaint
            let imagePaint = attributes[
                NSAttributedString.Key("LeaflowHighlightImagePaint")
            ] as? HighlightBackgroundImagePaint
            for rect in rects {
                let drawRect = imagePaint.map {
                    HighlightBackgroundImageLayout
                        .centeredStretchRegion(for: $0.image)
                    .backgroundPreviewRect(around: rect)
                } ?? rect
                context.saveGState()
                let radius = min(
                    min(drawRect.width * 0.5, drawRect.height * 0.5),
                    max(cornerRadius, 0))
                if radius > 0 {
                    let path = UIBezierPath(
                        roundedRect: drawRect, cornerRadius: radius)
                    context.addPath(path.cgPath)
                    context.clip(using: .winding)
                } else {
                    context.clip(to: drawRect)
                }
                if let backgroundColor {
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(drawRect)
                }
                if let gradient {
                    gradient.draw(in: drawRect, context: context)
                }
                if let imagePaint {
                    imagePaint.draw(in: drawRect, context: context)
                }
                context.restoreGState()
            }
        }
    }

    /// drawForegroundGradients(_:in:configuration:excluding:
    /// textLayoutManager:)（0x1001c6630 L1287-1310 + closure 0x1001c7bf0
    /// L1295-1309 域确证：注释附件透明占位替换后 enumerateAttributes，
    /// 渐变段 drawTextKit2MaskText / TextKit1 drawGlyphs）。
    static func drawForegroundGradients(
        _ attributedText: NSAttributedString?, in bounds: CGRect,
        configuration: Configuration, excluding: NSRange?,
        textLayoutManager: NSTextLayoutManager?
    ) {
        guard let attributedText, attributedText.length > 0,
              let context = UIGraphicsGetCurrentContext(),
              bounds.width > 0, bounds.height > 0 else {
            return
        }
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        replaceCommentAttachmentsWithTransparentPlaceholders(in: mutable)
        mutable.enumerateAttributes(
            in: NSRange(location: 0, length: mutable.length)
        ) { attributes, range, _ in
            guard let gradient = attributes[
                NSAttributedString.Key("LeaflowHighlightGradient")
            ] as? HighlightLinearGradientPaint else {
                return
            }
            for segment in ranges(in: range, excluding: excluding) {
                drawForegroundGradient(
                    gradient, attributedText: mutable, range: segment,
                    bounds: bounds, configuration: configuration,
                    textLayoutManager: textLayoutManager, context: context)
            }
        }
    }

    /// drawForegroundGradient(_:attributedText:range:bounds:configuration:
    /// textLayoutManager:context:)（签名确证：mask 域渐变合成）。
    static func drawForegroundGradient(
        _ gradient: HighlightLinearGradientPaint,
        attributedText: NSAttributedString, range: NSRange,
        bounds: CGRect, configuration: Configuration,
        textLayoutManager: NSTextLayoutManager?, context: CGContext
    ) {
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        if let textLayoutManager {
            drawTextKit2MaskText(
                attributedText, range: range, matching: textLayoutManager,
                in: bounds, configuration: configuration, context: context)
        } else {
            drawTextKit1MaskText(
                attributedText, range: range, in: bounds,
                configuration: configuration)
        }
        context.setBlendMode(.sourceIn)
        gradient.draw(in: bounds, context: context)
        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// drawTextKit2MaskText(_:range:matching:in:configuration:context:)
    /// （0x1001c7f98 L1410-1465 + closure 0x1001c8cd8 L1441-1464 域确证：
    /// mask 串去掉背景属性 + clearColor/whiteColor 前景；附件枚举透明
    /// 占位；textRange → enumerateTextSegmentsInRange → 逐段
    /// layoutFragmentFrame 偏移绘制；SourceIn 渐变）。
    static func drawTextKit2MaskText(
        _ attributedText: NSAttributedString, range: NSRange,
        matching textLayoutManager: NSTextLayoutManager, in bounds: CGRect,
        configuration: Configuration, context: CGContext
    ) {
        let mutable = NSMutableAttributedString(
            attributedString: attributedText)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.removeAttribute(.backgroundColor, range: full)
        mutable.removeAttribute(
            NSAttributedString.Key("LeaflowHighlightGradient"), range: full)
        mutable.removeAttribute(
            NSAttributedString.Key("LeaflowHighlightImagePaint"), range: full)
        mutable.addAttribute(
            .foregroundColor, value: UIColor.clear, range: full)
        mutable.addAttribute(
            .foregroundColor, value: UIColor.white, range: range)
        mutable.enumerateAttribute(
            .attachment, in: full
        ) { value, _, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            let placeholder = NSTextAttachment()
            placeholder.bounds = attachment.bounds
            if let transparent = UIGraphicsImageRenderer(size: CGSize(
                width: 1, height: 1
            )).image { _ in }.cgImage {
                placeholder.image = UIImage(cgImage: transparent)
            }
            mutable.addAttribute(
                .attachment, value: placeholder,
                range: NSRange(location: 0, length: mutable.length))
        }
        let layout = makeTextKit2Layout(
            for: mutable, in: bounds, configuration: configuration)
        guard let textRange = textRange(for: range, in: layout.layoutManager)
        else {
            return
        }
        layout.layoutManager.ensureLayout(for: textRange)
        // enumerateTextLayoutFragments 为 NSTextLayoutManager 真实遍历域
        // （textLayoutFragments(for:) 非 SDK 成员，wave-16）。
        var fragments: [NSTextLayoutFragment] = []
        layout.layoutManager.enumerateTextLayoutFragments(
            from: textRange.location, options: [],
            using: { fragment in
                fragments.append(fragment)
                return true
            })
        for fragment in fragments {
            let frame = fragment.layoutFragmentFrame
            fragment.draw(
                at: CGPoint(
                    x: bounds.minX + configuration.textInsetsLeft + frame.minX,
                    y: bounds.minY + configuration.textInsetsTop + frame.minY),
                in: context)
        }
    }

    /// drawTextKit1MaskText(_:range:in:configuration:)（签名确证）。
    static func drawTextKit1MaskText(
        _ attributedText: NSAttributedString, range: NSRange,
        in bounds: CGRect, configuration: Configuration
    ) {
        let mutable = NSMutableAttributedString(
            attributedString: attributedText)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.removeAttribute(.backgroundColor, range: full)
        mutable.addAttribute(
            .foregroundColor, value: UIColor.white, range: range)
        let (layoutManager, container, _) = makeLayout(
            for: mutable, in: bounds, configuration: configuration)
        layoutManager.ensureLayout(for: container)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return }
        layoutManager.drawGlyphs(
            forGlyphRange: glyphRange,
            at: CGPoint(
                x: configuration.textInsetsLeft,
                y: configuration.textInsetsTop))
    }

    /// textRangesIntersect(_:_:contentManager:)（0x1001c8e08 L1471-1484
    /// 域确证：四 offset 全部有效后 min<max）。
    static func textRangesIntersect(
        _ range0: NSTextRange, _ range1: NSTextRange,
        contentManager: NSTextContentManager?
    ) -> Bool {
        guard let contentManager else { return false }
        // documentRange.location 为非可选 any NSTextLocation（wave-16）。
        let documentLocation = contentManager.documentRange.location
        // endpoint 取 KeyPath 直取。
        func offset(
            of range: NSTextRange,
            endpoint: KeyPath<NSTextRange, any NSTextLocation>
        ) -> Int? {
            let location = range[keyPath: endpoint]
            let offset = contentManager.offset(
                from: documentLocation, to: location)
            return offset == NSNotFound ? nil : offset
        }
        guard let start0 = offset(of: range0, endpoint: \.location),
              let end0 = offset(of: range0, endpoint: \.endLocation),
              let start1 = offset(of: range1, endpoint: \.location),
              let end1 = offset(of: range1, endpoint: \.endLocation)
        else {
            return false
        }
        return max(start0, start1) < min(end0, end1)
    }

    /// matchingFragment(for:in:liveContentManager:fallbackContentManager:)
    /// （0x1001c905c L1491-1507 域确证：offset 映射 + ensureLayout +
    /// textLayoutFragmentForLocation）。
    static func matchingFragment(
        for location: NSTextRange, in textLayoutManager: NSTextLayoutManager,
        liveContentManager: NSTextContentManager?,
        fallbackContentManager: NSTextContentManager?
    ) -> NSTextLayoutFragment? {
        // documentRange.location / location.location 均为非可选 any
        // NSTextLocation（NSTextRange 域，wave-16）；fallback→live 偏移
        // 映射域未还原——直接以传入 range 在 live manager 上定位
        // （两管理器同文本域，还原推断；记入仍不清楚）。
        guard let liveContentManager, let fallbackContentManager else {
            return nil
        }
        _ = fallbackContentManager
        textLayoutManager.ensureLayout(for: location)
        var found: NSTextLayoutFragment?
        textLayoutManager.enumerateTextLayoutFragments(
            from: location.location, options: [],
            using: { fragment in
                found = fragment
                return false
            })
        return found
    }

    // MARK: 矩形域（0x1001c93ac L1565-1582 / 0x1001c7700 L1612-1674）

    /// rects(for:layout:)（0x1001c93ac L1565-1582 域确证：
    /// NSIntersectionRange + boundingRectForGlyphRange + insets 平移 +
    /// floor/ceil 取整）。
    static func rects(
        for range: NSRange, layout: TextLayout
    ) -> [CGRect] {
        // TextKit1 glyphRange/boundingRect 域在 NSTextLayoutManager 上不可用
        // ——改走 enumerateTextSegments 域（与 rects(for:textLayoutManager:)
        // 同构，wave-16）。
        guard let textRange = textRange(for: range, in: layout.layoutManager)
        else {
            return []
        }
        layout.layoutManager.ensureLayout(for: textRange)
        var result: [CGRect] = []
        layout.layoutManager.enumerateTextSegments(
            in: textRange, type: .standard, options: []
        ) { _, segmentBounds, _, _ in
            guard segmentBounds.width > 0, segmentBounds.height > 0 else {
                return true
            }
            let originX = (
                segmentBounds.minX + layout.container.lineFragmentPadding)
            let rect = CGRect(
                x: floor(originX), y: floor(segmentBounds.minY),
                width: ceil(segmentBounds.maxX) - floor(originX),
                height: ceil(segmentBounds.height))
            result.append(rect)
            return true
        }
        return result
    }

    /// backgroundRects(for:layout:)（签名确证）。
    static func backgroundRects(
        for range: NSRange, layout: TextLayout
    ) -> [CGRect] {
        rects(for: range, layout: layout)
    }

    /// backgroundRects(for:fallbackLayout:textLayoutManager:bounds:
    /// configuration:)（drawBackgroundGradients 消费域确证——live manager
    /// 直连域；fallbackLayout 未接线记入仍不清楚，wave-16 补桥）。
    static func backgroundRects(
        for range: NSRange, fallbackLayout: TextLayout?,
        textLayoutManager: NSTextLayoutManager?, bounds: CGRect,
        configuration: Configuration
    ) -> [CGRect] {
        guard let textLayoutManager else { return [] }
        return rects(
            for: range, textLayoutManager: textLayoutManager,
            bounds: bounds, configuration: configuration)
    }

    /// rects(for:textLayoutManager:bounds:configuration:)
    /// （0x1001c7700 L1612-1674 + closure 0x1001c9684 L1624-1672 域确证：
    /// enumerateTextSegmentsInRange(type=2) 逐段；行域内收：
    /// 高>4 时 (h-2)/2 与 h*0.12 钳制 ≤3.0；floor/ceil 取整）。
    static func rects(
        for range: NSRange, textLayoutManager: NSTextLayoutManager,
        bounds: CGRect, configuration: Configuration
    ) -> [CGRect] {
        guard let textRange = textRange(for: range, in: textLayoutManager)
        else {
            return []
        }
        textLayoutManager.ensureLayout(for: textRange)
        var result: [CGRect] = []
        textLayoutManager.enumerateTextSegments(
            in: textRange, type: .standard, options: []
        ) { _, segmentBounds, _, _ in
            guard segmentBounds.width > 0, segmentBounds.height > 0 else {
                return true
            }
            var rect = segmentBounds
            if rect.height > 4 {
                let half = max((rect.height - 2) * 0.5, 0)
                let ratio = rect.height * 0.12
                let insetY: CGFloat
                if ratio > 1, half >= ratio {
                    insetY = min(ratio, 3)
                } else if half < ratio {
                    insetY = min(half, 3)
                } else {
                    insetY = min(half, 3)
                }
                rect = rect.insetBy(dx: 0, dy: insetY)
            }
            rect.origin.x += configuration.textInsetsLeft
            rect.origin.y += configuration.textInsetsTop
            result.append(
                CGRect(
                    x: floor(rect.minX), y: floor(rect.minY),
                    width: ceil(rect.maxX) - floor(rect.minX),
                    height: ceil(rect.height)))
            return true
        }
        return result
    }

    /// alignedBackgroundRect(_:) / tightenedBackgroundRect(_:)
    /// （签名确证：整像素对齐）。
    static func alignedBackgroundRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: floor(rect.minX), y: floor(rect.minY),
            width: ceil(rect.maxX) - floor(rect.minX),
            height: ceil(rect.maxY) - floor(rect.minY))
    }

    static func tightenedBackgroundRect(_ rect: CGRect) -> CGRect {
        alignedBackgroundRect(rect).integral
    }

    /// lineVisualMetrics(for:)（0x1001ca130 L1680-1704 域确证：
    /// glyph 上限 = min(lineHeight, max(下限))；下限 = 0.2*font（≥4）
    /// 双侧 + 1.15*font 取大）。
    static func lineVisualMetrics(
        for line: NSTextLineFragment
    ) -> (glyphBounds: CGRect, referenceGlyphBounds: CGRect,
          maxFontPointSize: CGFloat) {
        var maxFontPointSize: CGFloat = 0
        line.attributedString.enumerateAttribute(
            .font, in: NSRange(
                location: 0, length: line.attributedString.length)
        ) { value, _, _ in
            if let font = value as? UIFont, font.pointSize > maxFontPointSize
            {
                maxFontPointSize = font.pointSize
            }
        }
        let reference = referenceGlyphBounds(for: line)
        let padding = max(maxFontPointSize * 0.2, 4)
        var lowerBound = reference.height + padding + padding
        if maxFontPointSize > 0 {
            lowerBound = max(lowerBound, maxFontPointSize * 1.15)
        }
        let glyphHeight = min(
            max(lowerBound, reference.height),
            max(line.typographicBounds.height, reference.height))
        let glyphBounds = CGRect(
            x: reference.minX, y: reference.minY, width: reference.width,
            height: glyphHeight)
        return (glyphBounds, reference, maxFontPointSize)
    }

    /// referenceGlyphBounds(for:)（0x1001c9ca4 L1706-1717 域确证：
    /// CTLineGetBoundsWithOptions(8) 域参考字形；无效时
    /// descender/ascender 差兜底）。
    static func referenceGlyphBounds(for line: NSTextLineFragment)
        -> CGRect {
        let attributed = line.attributedString
        let ctLine = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(ctLine, [])
        if bounds.isNull || bounds.height <= 0 {
            let font = attributed.attribute(
                .font, at: 0, effectiveRange: nil) as? UIFont
            let ascent = font?.ascender ?? 0
            let descent = font?.descender ?? 0
            return CGRect(
                x: 0, y: -descent, width: 0, height: ascent - descent)
        }
        var referenceFont: UIFont?
        attributed.enumerateAttribute(
            .font, in: NSRange(
                location: 0, length: attributed.length)
        ) { value, _, _ in
            if referenceFont == nil { referenceFont = value as? UIFont }
        }
        if let font = referenceFont {
            let reference = NSAttributedString(
                string: "国", attributes: [.font: font])
            let referenceLine = CTLineCreateWithAttributedString(reference)
            let referenceBounds = CTLineGetBoundsWithOptions(
                referenceLine, [])
            if !referenceBounds.isNull, referenceBounds.height > 0 {
                return referenceBounds
            }
            return CGRect(
                x: 0, y: -font.descender, width: 0,
                height: font.ascender - font.descender)
        }
        return bounds
    }

    /// textKit2BackgroundHeight(lineHeight:glyphHeight:fontPointSize:)
    /// （签名确证：视觉行高钳制）。
    static func textKit2BackgroundHeight(
        lineHeight: CGFloat, glyphHeight: CGFloat, fontPointSize: CGFloat
    ) -> CGFloat {
        let padding = max(fontPointSize * 0.2, 4)
        let lower = glyphHeight + padding + padding
        let upper = fontPointSize > 0 ? fontPointSize * 1.15 : lineHeight
        return min(max(lineHeight, lower), max(upper, lineHeight))
    }

    /// textRange(for:in:)（0x1001c8b28 L1734-1753 域确证：
    /// NSNotFound/零长/超界守卫）。NSRange → NSTextRange 桥：经
    /// enumerateTextLayoutFragments 收集 fragment 端点（NSTextElement
    /// elementRange 域）+ NSTextContentManager.offset 定位（fragment
    /// 粒度——字符级定位无公开 API，还原推断；记入仍不清楚，wave-16）。
    static func textRange(
        for range: NSRange, in textLayoutManager: NSTextLayoutManager
    ) -> NSTextRange? {
        guard range.location != NSNotFound, range.length > 0,
              let contentManager = textLayoutManager.textContentManager
        else {
            return nil
        }
        let start = contentManager.documentRange.location
        let documentEnd = contentManager.documentRange.endLocation
        let documentLength = contentManager.offset(
            from: start, to: documentEnd)
        guard range.location >= 0,
              range.location + range.length <= documentLength
        else {
            return nil
        }
        // 端点集：文档起点 + 各 fragment 尾端（文档序）。
        var endpoints: [(offset: Int, location: any NSTextLocation)] = [
            (0, start),
        ]
        textLayoutManager.enumerateTextLayoutFragments(
            from: start, options: []
        ) { fragment in
            guard let elementEnd = fragment.textElements.last?
                .elementRange?.endLocation else {
                return true
            }
            let offset = contentManager.offset(
                from: start, to: elementEnd)
            guard offset < documentLength else { return true }
            endpoints.append((offset, elementEnd))
            return true
        }
        // 目标起点：最后一个 offset ≤ range.location 的端点。
        guard let startLocation = endpoints.last(where: {
            $0.offset <= range.location
        })?.location else {
            return nil
        }
        // 目标终点：首个 offset ≥ range.location + range.length 的端点。
        guard let endLocation = endpoints.first(where: {
            $0.offset >= range.location + range.length
        })?.location else {
            return nil
        }
        return NSTextRange(location: startLocation, end: endLocation)
    }

    /// replaceCommentAttachmentsWithTransparentPlaceholders(in:)
    /// （0x1001ca3ec/0x1001ceadc L1795-1805 域确证：附件枚举 + 1x1
    /// 透明占位替换）。
    static func replaceCommentAttachmentsWithTransparentPlaceholders(
        in mutableText: NSMutableAttributedString
    ) {
        let full = NSRange(
            location: 0, length: mutableText.length)
        let transparent = UIGraphicsImageRenderer(
            size: CGSize(width: 1, height: 1)
        ).image { rendererContext in
            // UIGraphicsImageRendererContext 无 currentContext 成员——
            // 闭包参数即上下文（wave-16）。
            rendererContext.cgContext.clear(
                CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        mutableText.enumerateAttribute(
            .attachment, in: full
        ) { value, range, _ in
            guard let attachment = value as? NSTextAttachment,
                  attachment.bounds.width > 0 else {
                return
            }
            let placeholder = NSTextAttachment()
            placeholder.bounds = attachment.bounds
            placeholder.image = transparent
            mutableText.addAttribute(
                .attachment, value: placeholder, range: range)
        }
    }

    /// clipBackgroundRect(_:cornerRadius:context:)
    /// （0x1001c75c0 L1808-1816 域确证：背景色存在 + 半径>0 才裁剪）。
    static func clipBackgroundRect(
        _ rect: CGRect, cornerRadius: CGFloat, context: CGContext
    ) {
        guard cornerRadius > 0, rect.width > 0, rect.height > 0 else {
            return
        }
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.clip(using: .winding)
    }

    /// measuredSize(for:width:configuration:)（0x1001cd1bc L1316-1331
    /// 签名域：TextKit1 usedRect + 上下 insets）。
    static func measuredSize(
        for attributedText: NSAttributedString, width: CGFloat,
        configuration: Configuration
    ) -> CGSize {
        guard attributedText.length > 0, width > 0 else { return .zero }
        let bounds = CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
        let (layoutManager, container, _) = makeLayout(
            for: attributedText, in: bounds, configuration: configuration)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        return CGSize(
            width: ceil(width),
            height: ceil(used.maxY + configuration.textInsetsTop
                + configuration.textInsetsBottom))
    }

    /// drawFullAttributedText(_:in:configuration:)（签名确证）。
    static func drawFullAttributedText(
        _ attributedText: NSAttributedString, in bounds: CGRect,
        configuration: Configuration
    ) {
        nativeRenderingAttributedText(
            attributedText, preservingForegroundIn: nil
        ).draw(in: bounds)
    }

    /// nativeRenderingAttributedText(_:preservingForegroundIn:)
    /// （签名确证）。
    static func nativeRenderingAttributedText(
        _ attributedText: NSAttributedString,
        preservingForegroundIn: NSRange?
    ) -> NSAttributedString {
        attributedText.removingNativeFallbacksForGradientRanges(
            preservingForegroundIn: preservingForegroundIn)
    }
}

// MARK: - 快照缓存键与服务（0x1001ca8dc L1902-1904 / 0x1001cac30 L1926-1945）

/// 背景快照缓存键（updateBackgroundSnapshotIfNeeded 0x1001cb854
/// L2060-2127 域确证：renderIdentity + 量化宽高 + scale*1000 +
/// pixelCount + textSignature 七元组）。
struct HighlightGradientBackgroundSnapshotCacheKey: Hashable {
    var renderIdentity: Int
    var quantizedWidth: Int
    var quantizedHeight: Int
    var quantizedScale: Int
    var pixelCount: Int
    var textSignature: Int
}

/// 背景快照服务（init(maxEntries:) 0x1001ca8dc L1902-1904 +
/// renderSnapshot 0x1001cac30 L1926-1945 域确证：Task 后台渲染 +
/// MainActor 回调 + LRU 上限）。
final class HighlightGradientBackgroundSnapshotService {
    private let maxEntries: Int
    private var storage:
        [HighlightGradientBackgroundSnapshotCacheKey: UIImage] = [:]
    private var order: [HighlightGradientBackgroundSnapshotCacheKey] = []

    init(maxEntries: Int) {
        self.maxEntries = max(1, maxEntries)
    }

    func cachedSnapshot(
        for key: HighlightGradientBackgroundSnapshotCacheKey
    ) -> UIImage? {
        storage[key]
    }

    func storeSnapshot(
        _ image: UIImage, for key: HighlightGradientBackgroundSnapshotCacheKey
    ) {
        if storage[key] == nil {
            order.append(key)
            while order.count > maxEntries {
                storage.removeValue(forKey: order.removeFirst())
            }
        }
        storage[key] = image
    }

    func clear() {
        storage.removeAll()
        order.removeAll()
    }

    /// renderSnapshot(for:attributedText:bounds:configuration:scale:
    /// completion:)（0x1001cac30 L1926-1945 域确证：isCancelled 守卫 +
    /// imageSignature 捕获 + 后台 Task 渲染 + MainActor 完成回调）。
    @discardableResult
    func renderSnapshot(
        for key: HighlightGradientBackgroundSnapshotCacheKey,
        attributedText: NSAttributedString, bounds: CGRect,
        configuration: HighlightGradientTextRenderer.Configuration,
        scale: CGFloat,
        completion: @MainActor @Sendable (UIImage?) -> Void
    ) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self, !Task.isCancelled else {
                await MainActor.run { completion(nil) }
                return
            }
            let image = HighlightGradientTextRenderer
                .renderBackgroundSnapshot(
                    attributedText, in: bounds,
                    configuration: configuration, scale: scale)
            self.storeSnapshot(image ?? UIImage(), for: key)
            await MainActor.run { completion(image) }
        }
    }
}

// MARK: - 覆盖视图（0x1001cb07c L1955-1960 → 0x1001cc56c L2117-2126）

/// 高亮渐变覆盖视图（didset 五件 + draw + invalidate/
/// updateBackgroundSnapshotIfNeeded 域确证）。
final class HighlightGradientOverlayView: UIView {

    /// 渲染模式（draw 0x1001cc064 L2023-2037 域确证：1=前景直绘渐变，
    /// 0=背景快照）。
    enum RenderMode: Int {
        case backgroundSnapshot = 0
        case foregroundGradient = 1
    }

    var attributedText: NSAttributedString? {
        didSet {
            // attributedText.didset 0x1001cb07c L1955-1960 域确证。
            backgroundSnapshotTask?.cancel()
            backgroundSnapshotTask = nil
            backgroundSnapshotKey = nil
            backgroundSnapshotImage = nil
            cachedTextSignature = nil
            lastSnapshotBounds = nil
            setNeedsDisplay()
            updateBackgroundSnapshotIfNeeded()
        }
    }

    var textConfiguration: HighlightGradientTextRenderer.Configuration {
        didSet {
            // configuration.didset 0x1001cb410 L1963-1970 域确证：
            // 等值短路；前景模式 setNeedsDisplay，背景模式走快照链。
            guard oldValue != textConfiguration else { return }
            if renderMode == .foregroundGradient {
                setNeedsDisplay()
            } else {
                setNeedsDisplay()
            }
        }
    }

    weak var textLayoutManager: NSTextLayoutManager? {
        didSet {
            // textLayoutManager.didset 0x1001cb578 L1973-1977 域确证。
            setNeedsDisplay()
        }
    }

    var excludedForegroundRange: NSRange? {
        didSet {
            // excludedForegroundRange.didset 0x1001cb5a4 L1980-1980 域确证。
            if excludedForegroundRange != oldValue,
               renderMode == .backgroundSnapshot {
                setNeedsDisplay()
            }
        }
    }

    var renderIdentity: Int = 0 {
        didSet {
            // renderIdentity.didset 0x1001cb608/0x1001cb6f8 L1983-1986 域确证。
            guard renderIdentity != oldValue else { return }
            invalidateBackgroundSnapshot()
        }
    }

    var renderMode: RenderMode = .backgroundSnapshot

    private var backgroundSnapshotImage: UIImage?
    private var backgroundSnapshotKey:
        HighlightGradientBackgroundSnapshotCacheKey?
    private var backgroundSnapshotTask: Task<Void, Never>?
    private var cachedTextSignature: Int?
    private var lastSnapshotBounds: CGRect?

    private static let snapshotService =
        HighlightGradientBackgroundSnapshotService(maxEntries: 8)

    /// init(renderMode:)（签名确证）。
    init(renderMode: RenderMode = .backgroundSnapshot) {
        self.renderMode = renderMode
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        invalidateBackgroundSnapshot()
    }

    /// draw(_:)（0x1001cc064 L2023-2037 域确证：前景模式渐变域绘制，
    /// 背景模式快照 drawInRect）。
    override func draw(_ rect: CGRect) {
        if renderMode == .foregroundGradient {
            guard let attributedText, attributedText.length > 0,
                  let context = UIGraphicsGetCurrentContext(),
                  bounds.width > 0, bounds.height > 0 else {
                return
            }
            HighlightGradientTextRenderer.drawForegroundGradients(
                attributedText, in: bounds,
                configuration: textConfiguration,
                excluding: excludedForegroundRange,
                textLayoutManager: textLayoutManager)
        } else {
            updateBackgroundSnapshotIfNeeded()
            backgroundSnapshotImage?.draw(in: bounds)
        }
    }

    /// layoutSubviews（variable initialization 域确证：更新快照链）。
    override func layoutSubviews() {
        super.layoutSubviews()
        if renderMode == .backgroundSnapshot {
            updateBackgroundSnapshotIfNeeded()
        }
    }

    /// invalidateBackgroundSnapshot（0x1001cb16c L2049-2058 域确证：
    /// 前景模式 → 渐变属性检测置 hidden；背景模式 → 文本无渐变属性时
    /// hidden）。
    func invalidateBackgroundSnapshot() {
        let hasGradient: Bool
        if renderMode == .foregroundGradient {
            hasGradient = HighlightGradientTextRenderer
                .hasGradientAttributes(attributedText)
        } else {
            hasGradient = HighlightGradientTextRenderer
                .hasBackgroundAttributes(attributedText)
                || HighlightGradientTextRenderer.hasRoundedBackground(
                    in: attributedText ?? NSAttributedString(),
                    range: NSRange(
                        location: 0,
                        length: attributedText?.length ?? 0))
        }
        isHidden = !hasGradient
        setNeedsDisplay()
    }

    /// refreshVisibility（签名确证：invalidate 同链别名）。
    func refreshVisibility() {
        invalidateBackgroundSnapshot()
    }

    /// updateBackgroundSnapshotIfNeeded（0x1001cb854 L2060-2127 域确证：
    /// 前景模式/hidden/空文本/空 bounds/无 window 守卫；bounds 变更 +
    /// 文本签名计算；量化键五元组；快照命中即用，否则 Task 渲染）。
    private func updateBackgroundSnapshotIfNeeded() {
        guard renderMode == .backgroundSnapshot, !isHidden,
              let attributedText, attributedText.length > 0,
              bounds.width > 0, bounds.height > 0,
              window != nil || superview != nil else {
            return
        }
        if let lastSnapshotBounds,
           lastSnapshotBounds.equalTo(bounds),
           backgroundSnapshotImage != nil {
            return
        }
        lastSnapshotBounds = bounds
        if cachedTextSignature == nil {
            cachedTextSignature = HighlightGradientTextRenderer
                .backgroundSnapshotAttributedTextSignature(attributedText)
        }
        let scale = traitCollection.displayScale
        guard scale > 0,
              let key = HighlightGradientTextRenderer
                  .backgroundSnapshotCacheKey(
                    in: bounds, textSignature: cachedTextSignature ?? 0,
                    configuration: textConfiguration,
                    renderIdentity: renderIdentity, scale: scale)
        else {
            return
        }
        backgroundSnapshotTask?.cancel()
        backgroundSnapshotTask = nil
        backgroundSnapshotImage = nil
        if key != backgroundSnapshotKey {
            backgroundSnapshotKey = key
        }
        if let cached = Self.snapshotService.cachedSnapshot(for: key) {
            backgroundSnapshotImage = cached
            setNeedsDisplay()
            return
        }
        guard backgroundSnapshotTask == nil else { return }
        let text = attributedText
        let configuration = textConfiguration
        let bounds = bounds
        let identity = renderIdentity
        backgroundSnapshotTask = Self.snapshotService.renderSnapshot(
            for: key, attributedText: text, bounds: bounds,
            configuration: textConfiguration, scale: scale
        ) { [weak self] image in
            guard let self, identity == self.renderIdentity else { return }
            self.backgroundSnapshotImage = image
            self.invalidateIntrinsicContentSize()
            self.setNeedsDisplay()
        }
    }
}

// MARK: - 属性文本视图（0x1001cc79c L2132-2135 → 0x1001ccb00 L2158-2165）

/// 渐变属性文本视图（attributedText/configuration didset + init(frame:)
/// + draw + intrinsicContentSize/sizeThatFits 域确证）。
final class HighlightGradientAttributedTextView: UIView {

    var attributedText: NSAttributedString? {
        didSet {
            // attributedText.didset 0x1001cc79c L2132-2135 域确证。
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    var attrConfiguration: HighlightGradientTextRenderer.Configuration {
        didSet {
            // configuration.didset 0x1001cc914 L2138-2141 域确证。
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        attrConfiguration = HighlightGradientTextRenderer.Configuration()
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        attrConfiguration = HighlightGradientTextRenderer.Configuration()
        super.init(coder: coder)
        backgroundColor = .clear
    }

    /// draw(_:)（0x1001ccb00 L2158-2165 域确证）。configuration →
    /// attrConfiguration（本类型属性名域，wave-16）。
    override func draw(_ rect: CGRect) {
        guard let attributedText, attributedText.length > 0 else { return }
        HighlightGradientTextRenderer.drawFullAttributedText(
            attributedText, in: bounds, configuration: attrConfiguration)
    }

    /// intrinsicContentSize（init(frame:) 0x1001ccb30 L2144-2149 域确证：
    /// ceil(maxY + 上下 insets)）。
    override var intrinsicContentSize: CGSize {
        guard let attributedText, attributedText.length > 0,
              bounds.width > 0 else {
            return super.intrinsicContentSize
        }
        return HighlightGradientTextRenderer.measuredSize(
            for: attributedText, width: bounds.width,
            configuration: attrConfiguration)
    }

    /// sizeThatFits(_:)（0x1001ccb30 域确证：宽度 ceil + 高度 maxY +
    /// insets）。
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let attributedText, attributedText.length > 0,
              size.width > 0 else {
            return super.sizeThatFits(size)
        }
        return HighlightGradientTextRenderer.measuredSize(
            for: attributedText, width: ceil(size.width),
            configuration: attrConfiguration)
    }
}

// MARK: - NSAttributedString 扩展（0x1001cd398 L2187-2202 / 0x1001cd644 L2206-2227）

extension NSAttributedString {

    /// ranges(in:excluding:)（0x1001cd644 L2206-2227 域确证：
    /// 与 HighlightGradientTextRenderer.ranges 同语义）。
    func ranges(
        in range: NSRange, excluding excluded: NSRange?
    ) -> [NSRange] {
        HighlightGradientTextRenderer.ranges(
            in: range, excluding: excluded)
    }

    /// removingNativeFallbacksForGradientRanges(preservingForegroundIn:)
    /// （0x1001cd398+0x1001cd528 L2187-2202 域确证：渐变属性段去原生
    /// 前景（clearColor 补前景），preservingForegroundIn 段保留）。
    func removingNativeFallbacksForGradientRanges(
        preservingForegroundIn preserved: NSRange?
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttributes(in: full) { attributes, range, _ in
            let hasGradient = attributes[
                NSAttributedString.Key("LeaflowHighlightGradient")
            ] != nil || attributes[.backgroundColor] is UIColor
            guard hasGradient else { return }
            for segment in HighlightGradientTextRenderer.ranges(
                in: range, excluding: preserved
            ) {
                mutable.addAttribute(
                    .foregroundColor, value: UIColor.clear,
                    range: segment)
            }
        }
        return mutable
    }
}
