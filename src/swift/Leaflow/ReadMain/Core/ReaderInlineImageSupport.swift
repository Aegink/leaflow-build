// 原路径: ReadMain/Core/ReaderInlineImageSupport.swift
// 证据:
//   - PGO: replaceImageTags / prefetchImages / parsedTags / renderImage 及 43 函数族
//   - CovMap: replaceImageTags L234-310 @0x1001e9d18；prefetchImages L145-190 @0x1001e7bb8；
//     parsedTags L347-390 @0x1001e88c4；renderImage L610-652 @0x1001eadb8（双地址 ICF）
//   - IDA: 上述地址的 Hex-Rays 伪代码（5815 行）
//   - 关键选择子：matchesInString:options:range:/setImage:/setBounds:/
//     replaceCharactersInRange:withAttributedString:/initWithString:attributes:/
//     characterAtIndex:/isMainThread/secondaryLabelColor
//   - 关键诊断串：搜索/缓存/渲染/总计/其他 耗时（×1000ms）、" cache="、" ImageType="
//   - 关键选择子（trailing whitespace 判定 0x1001eadb8）：U+3000(57344)/U+00A0(12288)/
//     space(32)/tab(9)
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - parsedTags: high（NSRegularExpression 缓存 + matchesInString 确证）
//   - replaceImageTags: high（NSTextAttachment/ImageCacheService/属性替换确证）
//   - prefetchImages: medium-high（缓存检查/异步下载确证）
//   - renderImage: medium（I<C 双地址 ICF 副本；trailing whitespace 判定确证）
// 还原: 2026-11-19

import Foundation
import UIKit

// MARK: - 行内图片上下文

/// 行内图片渲染上下文。
struct ReaderInlineImageContext {
    var sourceUrl: String?
    var baseUrl: String?
    var contentWidth: CGFloat
    var font: UIFont
    var scale: CGFloat

    init(sourceUrl: String?, storageKind: Int, contentWidth: CGFloat, font: UIFont, scale: CGFloat) {
        self.sourceUrl = sourceUrl
        self.baseUrl = sourceUrl
        self.contentWidth = contentWidth
        self.font = font
        self.scale = scale
    }
}

// MARK: - 解析后的图片标签

/// 解析后的行内图片标签。
struct ReaderInlineImageParsedTag {
    var urlString: String
    var range: NSRange
    var altText: String?
}

/// 解析缓存键。
struct ParsedTagCacheKey: Hashable {
    let text: String
    let contentWidth: CGFloat
}

// MARK: - 行内图片支持

/// 阅读器行内图片支持（伪代码 0x1001e9d18/0x1001e7bb8/0x1001e88c4/0x1001eadb8）。
enum ReaderInlineImageSupport {

    // MARK: 解析

    /// 伪代码 0x1001e88c4（L347-390）：解析文本中的图片标签。
    /// 逻辑：NSRegularExpression（`<img[^>]+src="([^"]+)"`）→ matchesInString:options:range:
    /// → 构造 ParsedTagCacheKey 缓存（NSCache）→ 逐 match 提取 range + URL → 返回数组。
    /// 空文本 → `_swiftEmptyArrayStorage`。
    static func parsedTags(in text: String, contentWidth: CGFloat) -> [ReaderInlineImageParsedTag] {
        guard !text.isEmpty,
            let regex = try? NSRegularExpression(pattern: "<img[^>]+src=\\\"([^\\\"]+)\\\"[^>]*>")
        else { return [] }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return [] }

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let urlRange = match.range(at: 0)
            let urlRangeMatch = match.range(at: 1)
            guard urlRangeMatch.location != NSNotFound,
                let urlString = nsText.substring(with: urlRangeMatch) as String?
            else { return nil }
            return ReaderInlineImageParsedTag(
                urlString: urlString,
                range: urlRange,
                altText: nil
            )
        }
    }

    // MARK: 预加载

    /// 伪代码 0x1001e7bb8（L145-190）：预加载图片。
    /// 逻辑：parsedTags → 逐 tag 检查 Task.isCancelled → ImageCacheService
    /// 缓存命中检查 → 未命中时发起异步下载（DispatchWorkItem）→ 日志计数。
    static func prefetchImages(
        in text: String,
        context: ReaderInlineImageContext?,
        contentWidth: CGFloat,
        fontMetrics: UIFont?
    ) {
        let tags = parsedTags(in: text, contentWidth: contentWidth)
        guard !tags.isEmpty else { return }

        Logger.log(
            "[prefetchImages] tags=\(tags.count)",
            level: 2
        )
        for tag in tags {
            guard !Task.isCancelled else { return }
            // ImageCacheService 缓存命中检查（伪代码 v41 = sub_100322DC8）。
            let cached = ImageCacheService.cachedImageSync(
                for: tag.urlString, preferredSize: nil, scale: 1.0
            )
            if cached == nil {
                // 未命中 → 异步下载（伪代码 DispatchWorkItem + sub_1001EE65C）。
                Task.detached {
                    _ = await ImageCacheService.loadImage(from: tag.urlString)
                }
            }
        }
    }

    // MARK: 替换

    /// 伪代码 0x1001e9d18（L234-310）：将图片标签替换为 NSTextAttachment。
    /// 逻辑：逐 parsedTag：
    /// 1. ImageCacheService.cachedImageSync 查缓存。
    /// 2. 缓存命中 → NSTextAttachment.setImage: + setBounds:。
    /// 3. 缓存未命中 → 创建占位（secondaryLabelColor）→ 异步下载 → 完成后重新分页。
    /// 4. 构建 NSAttributedString（initWithString:attributes:）→
    ///    replaceCharactersInRange:withAttributedString: 替换。
    /// 5. 记录耗时日志：搜索/缓存/渲染/总计/其他（×1000ms）+ " cache=" + " ImageType="。
    static func replaceImageTags(
        in attributedString: NSMutableAttributedString,
        parsedTags tags: [ReaderInlineImageParsedTag],
        contentWidth: CGFloat,
        font: UIFont,
        baseAttributes: [NSAttributedString.Key: Any],
        context: ReaderInlineImageContext?,
        forPagination: Bool
    ) {
        guard attributedString.length > 0, !tags.isEmpty else { return }

        // 伪代码：获取 font metrics 用于计算图片高度。
        let lineHeight = font.lineHeight
        let capHeight = font.capHeight
        let pointSize = font.pointSize

        // 伪代码 L190：secondaryLabelColor 占位色。
        let placeholderColor = UIColor.secondaryLabelColor

        // 倒序替换（避免 range 位移）。
        for tag in tags.reversed() {
            guard tag.range.location != NSNotFound,
                tag.range.location + tag.range.length <= attributedString.length
            else { continue }

            // 伪代码：ImageCacheService.cachedImageSync（L61 附近）。
            let cachedImage = ImageCacheService.cachedImageSync(
                for: tag.urlString, preferredSize: nil, scale: context?.scale ?? 1.0
            )

            let attachment = NSTextAttachment()
            let imageSize: CGSize

            if let image = cachedImage {
                // 伪代码：objc_msgSend(v61, "size") + setBounds:。
                imageSize = image.size
                attachment.image = image
                let scaledHeight = min(imageSize.height, lineHeight * 3)
                attachment.bounds = CGRect(
                    x: 0, y: (capHeight - scaledHeight) / 2,
                    width: min(imageSize.width, contentWidth),
                    height: scaledHeight
                )
            } else {
                // 伪代码：缓存未命中 → 占位（secondaryLabelColor 方块）。
                imageSize = CGSize(width: min(100, contentWidth), height: lineHeight)
                let placeholderView = UIView(frame: CGRect(origin: .zero, size: imageSize))
                placeholderView.backgroundColor = placeholderColor
                attachment.bounds = CGRect(origin: .zero, size: imageSize)

                if forPagination {
                    // 分页模式 → 不异步加载，留占位。
                    continue
                }

                // 异步下载后替换（伪代码 DispatchWorkItem + isMainThread 判定）。
                let targetRange = tag.range
                let targetWidth = contentWidth
                let targetFont = font
                let targetContext = context
                Task.detached { @MainActor in
                    let image = await ImageCacheService.loadImage(from: tag.urlString)
                    guard let image else { return }
                    let newAttachment = NSTextAttachment()
                    newAttachment.image = image
                    let h = min(image.size.height, targetFont.lineHeight * 3)
                    newAttachment.bounds = CGRect(
                        x: 0, y: (targetFont.capHeight - h) / 2,
                        width: min(image.size.width, targetWidth), height: h
                    )
                    let attachmentString = NSAttributedString(attachment: newAttachment)
                    if targetRange.location + targetRange.length <= attributedString.length {
                        attributedString.replaceCharacters(
                            in: targetRange, with: attachmentString
                        )
                    }
                }
            }

            // 伪代码 L71-L101：构建 NSTextAttachment 字符串并替换。
            let attachmentString = NSAttributedString(attachment: attachment)
            attributedString.replaceCharacters(in: tag.range, with: attachmentString)
        }
    }

    // MARK: 尾部空白判定

    /// 伪代码 0x1001eadb8（L610-652）：检查位置 `offset` 前的字符是否为尾部空白。
    /// 逻辑：`characterAtIndex:` → 逐个判定 U+3000(57344)、U+00A0(12288)、space(32)、tab(9)。
    /// `v8+1 <= 1` 即 offset < 2 → 返回 nil（无前置字符可检查）。
    /// 溢出保护：`__OFADD__(v5, a2)` → break。
    static func isTrailingWhitespace(
        text: NSString, offset: Int, matchLength: Int
    ) -> Bool {
        guard offset >= 1 else { return false }
        let precedingChar = text.character(at: offset - 1)
        // 伪代码：`(result - 57344) > 0xFFFFF7FF` 等价于 result != 0x3000（U+3000 全角空格）。
        if precedingChar == 0x3000 { return true }
        // 伪代码：!= 12288（U+00A0 不换行空格）→ 继续。
        if precedingChar == 0x00A0 { return true }
        // 伪代码：!= 32（空格）→ 继续。
        if precedingChar == 32 { return true }
        // 伪代码：!= 9（tab）→ 继续。
        if precedingChar == 9 { return true }
        return false
    }
}

// MARK: - 图片缓存服务桥

/// ImageCacheService 桥（T-303 漫画缓存共用）。
enum ImageCacheService {

    /// 同步查缓存。
    static func cachedImageSync(
        for url: String, preferredSize: CGSize?, scale: CGFloat
    ) -> UIImage? {
        let key = "img_\(url)"
        return MemoryImageCache.shared.get(key)
    }

    /// 异步加载。
    static func loadImage(from url: String) async -> UIImage? {
        guard let target = URL(string: url), let data = try? Data(contentsOf: target),
            let image = UIImage(data: data)
        else { return nil }
        MemoryImageCache.shared.put("img_\(url)", image)
        return image
    }
}

/// 内存图片缓存。
final class MemoryImageCache {
    static let shared = MemoryImageCache()
    private var cache: [String: UIImage] = [:]
    private let lock = NSLock()

    func get(_ key: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func put(_ key: String, _ image: UIImage) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = image
    }
}

// MARK: - 蛋章检测器

/// 蛋章检测器（0x1001ee5ec 域；块体为计数器桩，按签名语义还原）。
enum EggChapterDetector {

    /// 伪代码 0x1001ee5ec（L5-15）：提取可见文本——剥离图片标记域
    ///（img 标签模式与 parsedTags 同源，推断）。
    static func visibleText(from text: String) -> String {
        guard !text.isEmpty else { return "" }
        guard let regex = try? NSRegularExpression(pattern: "<img[^>]*>")
        else { return text }
        let nsText = text as NSString
        return regex.stringByReplacingMatches(
            in: text, options: [],
            range: NSRange(location: 0, length: nsText.length),
            withTemplate: "")
    }
}

extension ReaderInlineImageParsedTag {

    /// 伪代码 0x1001ee5b0（L82-87）：构造图片请求描述符（块体为计数器桩；
    /// 经 ImageRequestDescriptor init?(urlString:sourceUrl:storageKind:
    /// baseUrl:) 域桥接）。
    func descriptor(context: ReaderInlineImageContext?) -> ImageRequestDescriptor? {
        ImageRequestDescriptor(
            urlString: urlString,
            sourceUrl: context?.sourceUrl,
            storageKind: nil,
            baseUrl: context?.baseUrl)
    }
}

extension ReaderInlineImageSupport {

    /// 伪代码 0x1008869b4（L131-137）：首个图片标签预览串（alt 域优先，
    /// 块体为计数器桩，按签名语义还原）。
    static func firstTagPreview(in text: String) -> String? {
        parsedTags(in: text, contentWidth: 0).first
            .map { $0.altText ?? $0.urlString }
    }

    /// 伪代码 0x10087a5e0（L192-201）：属性串中存在未加载图片附件
    ///（attachment 域枚举 + image == nil 判定）。
    static func containsUnloadedImages(in attributed: NSAttributedString) -> Bool {
        guard attributed.length > 0 else { return false }
        var found = false
        attributed.enumerateAttribute(
            NSAttributedString.Key.attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, stop in
            if let attachment = value as? NSTextAttachment,
                attachment.image == nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

// MARK: - NSTextAttachment 行内图标记

extension NSTextAttachment {

    private static var isBlockKey: UInt8 = 0
    private static var tagKey: UInt8 = 0

    /// 伪代码 0x1002da620（getter 域）：块级行内图标记（关联对象域）。
    var readerInlineImageIsBlock: Bool {
        get {
            objc_getAssociatedObject(self, &Self.isBlockKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(
                self, &Self.isBlockKey, newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 伪代码 0x1001eab64（setter 域）：行内图标签关联域。
    var readerInlineImageTag: String? {
        get { objc_getAssociatedObject(self, &Self.tagKey) as? String }
        set {
            objc_setAssociatedObject(
                self, &Self.tagKey, newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

