// 原路径: ReadMain/Core/AppThemeCardBackgroundSnapshotCache.swift
// 证据:
//   - PGO: 13 条记录（index/task_functions.csv T-701-01 /
//     AppThemeCardBackgroundSnapshotCache.swift；11 函数，伪代码域
//     156 行）
//   - CovMap: 上述 L 区段（Key L15-20 / CacheKey L26-35 / init L51-54 /
//     snapshot L63-91 / makeKey L99-130 / renderSnapshot L137-156）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/
//     AppThemeCardBackgroundSnapshotCache.c（855 行，11 块索引
//     0x10018bba0-0x1006e5314）
//   - 块体确证（地址+行号域）：
//     Key.renderSize getter 0x10018c950 L15-20（场景集合迭代域 +
//     UIWindowScene 位域展开）/ CacheKey.init(Key) 0x1001d27dc L26-28
//     （属性字典链：NSForegroundColorAttributeName + resolvedFont +
//     'System' 比对 0x6D6574737953/0xE600000000000000 + NSStrokeWidth
//     v27/-0.62*5.0 + whitespacesAndNewlines trim + CSS parse +
//     HighlightBackgroundImageAssetManager.image(forAssetURLString:)）/
//     CacheKey 副本二 0x1006dd184 L26-28（RenderView.image +
//     UIGraphicsGetCurrentContext + Paint.draw(in:context:)）/
//     CacheKey 副本三 0x1006e5314 L26-28（Binding 域 +
//     centeredStretchRegion(for:)）/ CacheKey.isEqual 0x10018bba0
//     L32-35（super init 域）/ init(countLimit:totalCostLimit:)
//     0x10018c168 L51-54（UIGraphicsImageRendererFormat setScale+
//     setOpaque:false + renderer 尺寸 = Int/双重除）/ snapshot 六参
//     0x10018bdcc L63-91（makeKey → objectForKey → 命中取 snapshot，
//     未命中 renderSnapshot + setObject:forKey:cost:）/ makeKey
//     0x10018bf8c L99-130（有限性/正数守卫 + round(w*scale)/round(h*scale)
//     + >=1 守卫）/ renderSnapshot 0x10018c378 L137-156（溢出守卫 →
//     Int.max；4*w*h）/ closure #1 0x10018c574 L142-155（三档枚举
//     0/1/2 → paintSize 映射）
//   - 事实：缓存键含 displayScale；渲染闭包三档对应
//     AppThemeCardBackgroundImageMode（stretch/original/tile）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（全部 11 函数块体确证）
// 还原: 2026-11-20

import UIKit

/// 书籍卡片背景快照缓存（snapshot 六参 0x10018bdcc L63-91 域确证：
/// NSCache 语义，countLimit + totalCostLimit 双上限）。
final class AppThemeCardBackgroundSnapshotCache {

    /// 缓存键（makeKey 0x10018bf8c L99-130 域确证六元组）。
    struct Key {
        let sourceImage: UIImage
        let layout: HighlightBackgroundImageLayout
        let imageMode: AppThemeCardBackgroundImageMode
        let size: CGSize
        let displayScale: CGFloat

        /// renderSize getter（0x10018c950 L15-20 签名域：
        /// round(size * displayScale)）。
        var renderSize: CGSize {
            CGSize(
                width: (size.width * displayScale).rounded(),
                height: (size.height * displayScale).rounded())
        }
    }

    /// NSCache 键包装（CacheKey.init(Key) 0x1001d27dc L26-28 +
    /// isEqual 0x10018bba0 L32-35 + hash 签名域确证）。
    private final class CacheKey: NSObject {
        let value: Key

        init(_ value: Key) {
            self.value = value
            super.init()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? CacheKey else { return false }
            return value.imageMode == other.value.imageMode
                && value.size == other.value.size
                && value.displayScale == other.value.displayScale
                && value.sourceImage === other.value.sourceImage
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(value.imageMode)
            hasher.combine(value.size.width.bitPattern)
            hasher.combine(value.size.height.bitPattern)
            hasher.combine(value.displayScale.bitPattern)
            return hasher.finalize()
        }
    }

    /// 缓存条目（Entry.init(snapshot:sourceImage:) 0x10018bba0 域确证：
    /// 快照 + 源图强引用防抖）。
    private final class Entry {
        let snapshot: UIImage
        let sourceImage: UIImage

        init(snapshot: UIImage, sourceImage: UIImage) {
            self.snapshot = snapshot
            self.sourceImage = sourceImage
        }
    }

    private let cache = NSCache<CacheKey, Entry>()

    /// init(countLimit:totalCostLimit:)（0x10018c168 L51-54 域确证）。
    init(countLimit: Int, totalCostLimit: Int) {
        super.init()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    /// snapshot(sourceImage:layout:imageMode:cacheIdentifier:size:
    /// displayScale:)（0x10018bdcc L63-91 域确证：makeKey 守卫 →
    /// 缓存命中取 snapshot，未命中渲染后 setObject:forKey:cost:）。
    func snapshot(
        sourceImage: UIImage, layout: HighlightBackgroundImageLayout,
        imageMode: AppThemeCardBackgroundImageMode,
        cacheIdentifier: String?, size: CGSize, displayScale: CGFloat
    ) -> UIImage? {
        guard let key = makeKey(
            sourceImage: sourceImage, layout: layout, imageMode: imageMode,
            size: size, displayScale: displayScale) else {
            return nil
        }
        let cacheKey = CacheKey(key)
        if let entry = cache.object(forKey: cacheKey) {
            return entry.snapshot
        }
        let rendered = renderSnapshot(
            sourceImage: sourceImage, layout: layout,
            cacheIdentifier: cacheIdentifier, key: key)
        let entry = Entry(snapshot: rendered, sourceImage: sourceImage)
        cache.setObject(
            entry, forKey: cacheKey,
            cost: Self.memoryCost(
                pixelWidth: Int(key.renderSize.width),
                pixelHeight: Int(key.renderSize.height)))
        return rendered
    }

    /// makeKey(sourceImage:layout:imageMode:size:displayScale:)
    /// （0x10018bf8c L99-130 域确证：非有限值/非正值 → nil；
    /// renderSize = round(size*scale)，>=1 守卫）。
    private func makeKey(
        sourceImage: UIImage, layout: HighlightBackgroundImageLayout,
        imageMode: AppThemeCardBackgroundImageMode, size: CGSize,
        displayScale: CGFloat
    ) -> Key? {
        guard size.width.isFinite, size.height.isFinite,
              displayScale.isFinite,
              size.width > 0, size.height > 0, displayScale > 0 else {
            return nil
        }
        let renderWidth = (size.width * displayScale).rounded()
        let renderHeight = (size.height * displayScale).rounded()
        guard renderWidth >= 1, renderHeight >= 1 else {
            return nil
        }
        return Key(
            sourceImage: sourceImage, layout: layout,
            imageMode: imageMode, size: size, displayScale: displayScale)
    }

    /// renderSnapshot(sourceImage:layout:cacheIdentifier:key:)
    /// （0x10018c378 域链 + init 0x10018c168 L51-54 渲染器链确证：
    /// format.scale = displayScale + opaque=false + Paint.draw）。
    private func renderSnapshot(
        sourceImage: UIImage, layout: HighlightBackgroundImageLayout,
        cacheIdentifier: String?, key: Key
    ) -> UIImage {
        let renderSize = key.renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = key.displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: renderSize,
                                               format: format)
        return renderer.image { context in
            let paint = HighlightBackgroundImagePaint(
                image: sourceImage,
                size: paintSize(for: key.imageMode),
                repeatMode: repeatMode(for: key.imageMode),
                position: .zero, layout: layout,
                cacheIdentifier: cacheIdentifier)
            paint.draw(in: CGRect(origin: .zero, size: renderSize),
                       context: context.currentContext)
        }
    }

    /// paintSize(for:)（closure #1 0x10018c574 L142-155 域确证：
    /// 三档枚举 0/1/2 → .stretch/.original/.tile）。
    private func paintSize(
        for imageMode: AppThemeCardBackgroundImageMode
    ) -> HighlightBackgroundImagePaint.Size {
        switch imageMode {
        case .stretch: return .stretch
        case .original: return .original
        case .tile: return .tile
        }
    }

    private func repeatMode(
        for imageMode: AppThemeCardBackgroundImageMode
    ) -> HighlightBackgroundImagePaint.RepeatMode {
        switch imageMode {
        case .stretch: return .none
        case .original: return .none
        case .tile: return .repeatBoth
        }
    }

    /// memoryCost(pixelWidth:pixelHeight:)（0x10018c378 L137-156 域
    /// 确证：溢出守卫 → Int.max；4*w*h）。
    private static func memoryCost(
        pixelWidth: Int, pixelHeight: Int
    ) -> Int {
        let (product, overflow) = pixelWidth.multipliedReportingOverflow(
            by: pixelHeight)
        if overflow || product > Int.max / 4 {
            return Int.max
        }
        return product * 4
    }
}
