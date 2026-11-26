// 原始归属: ReadMain/Views/Reader/PageContentViews.swift；拆分不改变336文件统计。
import UIKit

// MARK: - 全行下划线段计算（顶层全局函数）

/// 全行下划线是否含可见文本（伪代码 0x100754f38，L5-21）。
/// 逐字符检查：带附件（NSAttachmentAttributeName）跳过；0xD000-0xDFFF 代理区跳过
/// （伪代码以 57344=0xE000 为基准的 unsigned 减法判定）；空白
/// （CharacterSet.whitespacesAndNewlines）与零宽类字符（含 U+200B=8203）跳过；
/// 首个可见字符返回 true，全部不可见返回 false。
func readerFullLineUnderlineHasVisibleText(_ attributed: NSAttributedString) -> Bool {
    guard attributed.length > 0 else { return false }
    let string = attributed.string
    // 伪代码 L108：显式排除 U+200B；另有两个 Character 字面量（零宽类，值未解码）。
    let excludedZeroWidth: Set<UInt32> = [0x200B]
    let scalars = Array(string.unicodeScalars)
    var range = NSRange()
    for index in 0..<attributed.length {
        if attributed.attribute(.attachment, at: index, effectiveRange: &range) != nil {
            continue
        }
        let scalar = scalars.indices.contains(index) ? scalars[index].value : 0
        if (0xD000...0xDFFF).contains(scalar) { continue }
        if let unicode = Unicode.Scalar(scalar),
           CharacterSet.whitespacesAndNewlines.contains(unicode) {
            continue
        }
        if excludedZeroWidth.contains(scalar) { continue }
        return true
    }
    return false
}

/// 区间相减（伪代码 0x100755310，L39-60；@MainActor，executor 检查在 L30）。
/// 对每个 range 扣除 removing（签名按 PGO demangle：removing 是单个 ClosedRange）：
/// - 无交集（removing.upper <= range.lower || range.upper <= removing.lower）→ 原样保留；
/// - 左段 (range.lower ..< removing.lower) 仅当宽度 > 1.0pt 保留（伪代码 L276-294）；
/// - 右段 (removing.upper ..< range.upper) 仅当宽度 > 1.0pt 保留（伪代码 L296-318）。
/// 顶层函数为 ranges.flatMap(closure#1)；closure#1 体即上述逻辑。
@MainActor
func readerFullLineUnderlineSubtractingSegments(
    _ ranges: [ClosedRange<CGFloat>], removing: ClosedRange<CGFloat>
) -> [ClosedRange<CGFloat>] {
    ranges.flatMap { range -> [ClosedRange<CGFloat>] in
        if removing.upperBound <= range.lowerBound || range.upperBound <= removing.lowerBound {
            return [range]
        }
        var segments: [ClosedRange<CGFloat>] = []
        if range.lowerBound < removing.lowerBound {
            let clippedLower = min(removing.lowerBound, range.upperBound)
            if clippedLower - range.lowerBound > 1.0 {
                segments.append(range.lowerBound...clippedLower)
            }
        }
        if removing.upperBound < range.upperBound {
            if range.upperBound - removing.upperBound > 1.0 {
                segments.append(removing.upperBound...range.upperBound)
            }
        }
        return segments
    }
}

/// 区间裁剪（伪代码 0x100755c2c，L82-89；closure #1 0x10075dac0 L83-88）。
/// 每段与窗口求交，宽度 <= 1.0pt 丢弃（阈值 closure 内确证）。
/// 注意：0x100755c2c 块体实际是 pageRenderSignature 复位逻辑（ICF 误标），
/// 裁剪语义取自 closure #1 + implicit closure #2（L15，同样 1.0 阈值）。
@MainActor
func readerFullLineUnderlineClippedSegments(
    _ ranges: [ClosedRange<CGFloat>], to limit: ClosedRange<CGFloat>
) -> [ClosedRange<CGFloat>] {
    ranges.compactMap { range -> ClosedRange<CGFloat>? in
        let lower = max(limit.lowerBound, range.lowerBound)
        let upper = min(limit.upperBound, range.upperBound)
        guard upper - lower > 1.0 else { return nil }
        return lower...upper
    }
}

// MARK: - 下划线辅助（pgo_only：无独立地址，内联进 updateFullLineUnderlineOverlay，按签名还原）

/// 排除段集合（PGO：readerFullLineUnderlineSegments(fullWidth:excludedRects:lineTop:
/// lineBottom:horizontalPadding:)）。行带与每个排除矩形求交（水平外扩 ±2pt，
/// 截断到 [0, fullWidth]），输出 x 区间。
@MainActor
func readerFullLineUnderlineSegments(
    fullWidth: CGFloat,
    excludedRects: [CGRect],
    lineTop: CGFloat,
    lineBottom: CGFloat,
    horizontalPadding: CGFloat
) -> [ClosedRange<CGFloat>] {
    var segments: [ClosedRange<CGFloat>] = [0...fullWidth]
    for rect in excludedRects {
        guard rect.maxY >= lineTop, rect.minY <= lineBottom else { continue }
        let minX = max(0, rect.minX - horizontalPadding)
        let maxX = min(fullWidth, rect.maxX + horizontalPadding)
        guard minX <= maxX else { continue }
        segments = readerFullLineUnderlineSubtractingSegments(segments, removing: minX...maxX)
    }
    return segments
}

/// 下划线 y 坐标（PGO：readerFullLineUnderlineY(lineBottom:strokeWidth:offset:scale:)）。
/// 伪代码 closure#3 L5571：round((lineBottom - strokeWidth + offset) * scale) / scale。
func readerFullLineUnderlineY(
    lineBottom: CGFloat, strokeWidth: CGFloat, offset: CGFloat, scale: CGFloat
) -> CGFloat {
    ((lineBottom - strokeWidth + offset) * scale).rounded() / scale
}

/// 像素对齐（PGO：readerFullLineUnderlinePixelAligned(_:scale:)）。
func readerFullLineUnderlinePixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
    (value * scale).rounded() / scale
}

/// 文本裁剪区间（PGO：readerFullLineUnderlineTextClipRange(minX:maxX:fullWidth:)）。
/// clamp 到 [0, fullWidth]，宽度 <= 1.0pt 返回 nil。
func readerFullLineUnderlineTextClipRange(
    minX: CGFloat, maxX: CGFloat, fullWidth: CGFloat
) -> ClosedRange<CGFloat>? {
    let lower = max(0, minX)
    let upper = min(fullWidth, maxX)
    guard upper - lower > 1.0 else { return nil }
    return lower...upper
}

/// 段落评论是否排除下划线（PGO：readerFullLineUnderlineShouldExcludeComment）。
/// 判定字段未从反编译恢复 —— 待真机对照（推断：带图/带脚本的评论排除）。
func readerFullLineUnderlineShouldExcludeComment(_ comment: ParagraphComment) -> Bool {
    _ = comment
    return false
}
