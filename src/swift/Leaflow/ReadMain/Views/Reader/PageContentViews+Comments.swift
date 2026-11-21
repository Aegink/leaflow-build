// 原路径: ReadMain/Views/Reader/PageContentViews+Comments.swift
// 证据:
//   - PGO: 7 个主函数（index/task_functions.csv T-301-03 / PageContentViews+Comments.swift），
//     地址：buildReaderBodyAttributedText 0x10075fa64 L104-217（+key=value 闭包 0x10075e670 L206）/
//     handleCommentAttachmentTap 0x100760818 L237-254 / cacheCommentRects 0x10075edd0 L258-294
//     (+closure 0x10076155c L272-288) / shouldPreserveTrailingJustification 闭包族
//     0x100761a20 L297-300 / makeBodyAttributedText 0x10075f910 L313-327；
//     另有 replaceSourceImageMarkers(+closure)/setupCommentTapGesture/bodyContentWidth/
//     ReaderPageBodyCache.attributedText(for:...)/invalidate 等签名
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageContentViews+Comments.c（1734 行）
//   - 关键选择子/常量：NSMutableParagraphStyle setLineSpacing:/setParagraphSpacing:/
//     setLineBreakMode:0/setAlignment:/setLineBreakStrategy:0xFFFF；NSKernAttributeName/
//     NSStrokeWidthAttributeName/NSAttachmentAttributeName/NSParagraphStyleAttributeName/
//     NSForegroundColorAttributeName；NSTextAttachment bounds (0,0,max(w,1),0.1)；
//     firstRectForRange/CGRectInset(-3,-3)；U+FFFC 标记；replace "\n"→"\\n"、
//     截断 120 + "..."；UIImpactFeedbackGenerator(style:0)；阈值 6.0ms（Logger）；
//     trailing justification 比例阈值 0.78
//   - 关键字面量：metrics 键（"tailWork" 0x6B726F576C696174 等）、
//     "images"（0x3D736567616D）、debug 前缀 0x1012718B0（29 字符，未解码）、
//     "="(61) 分隔（key=value 格式化闭包）
//   - pgo_only（ICF 合并，无独立地址）：replaceSourceImageMarkers/setupCommentTapGesture/
//     bodyContentWidth（体在主文件）；makeBodyAttributedText 体在主文件
//     PageContentViews.swift（ICF 共体，本文件不再重复声明）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - buildReaderBodyAttributedText: high~medium-high（段落样式/属性/阈值/日志链确证；
//     inline image 与 regex highlight 的内部细节属 T-201/T-303 域）
//   - handleCommentAttachmentTap: high（命中/触感/截断/日志链确证）
//   - cacheCommentRects + closure: high（firstRectForRange/±3pt 外扩/镜像确证）
//   - shouldPreserveTrailingJustification: medium-high（0.78 阈值确证；pageData 字段名待对照）
//   - makeBodyAttributedText: medium（体为 ICF 薄壳，参数组装按签名还原）
// 还原: 2026-11-19
// 依赖: CompiledHighlightRule.attributes(isDark:) 属 T-303 分册；ReaderInlineImageSupport
//   属 T-302/T-501 域；ReaderTextLayout.applyParagraphIndentLayout 已还原
//   （ReaderLayoutConfig.swift）；ParagraphComment 属 T-1001 分册。

import UIKit

// MARK: - 正文属性串构建（全局函数）

/// 正文构建主链（伪代码 0x10075fa64，L104-217）。
/// 流程（选择子/常量确证）：
/// 1. NSMutableParagraphStyle：lineSpacing = font.lineSpacing + extraLineSpacing；
///    paragraphSpacing；lineBreakMode = 0(.byWordWrapping)；alignment；
///    lineBreakStrategy = 0xFFFF（全部策略）。
/// 2. 属性字典：NSFontAttributeName/NSForegroundColorAttributeName/
///    NSParagraphStyleAttributeName/NSLanguageIdentifierAttributeName；
///    letterSpacing ≠ 0 → NSKernAttributeName；settings.textStrokeWidth ≠ 0 →
///    NSStrokeWidthAttributeName。
/// 3. NSMutableAttributedString(string:attributes:)。
/// 4. metrics 计时（ProcessInfo 时间戳，逐段 * 1000 记录）。
/// 5. applyRegexHighlight → settings.compiledHighlightRules →
///    CompiledHighlightRule.attributes(isDark:color:) 应用。
/// 6. inline image 渲染（ReaderInlineImageSupport.renderInlineImages）。
/// 7. ReaderTextLayout.applyParagraphIndentLayout(to:textIndent:font:letterSpacing:
///    baseParagraphStyle:)。
/// 8. 评论/续页尾巴：!preserveTrailingJustification → 尾部 NSStrokeColor/
///    NSBackgroundColor 清色；preserve → 透明 NSTextAttachment
///    （bounds (0,0,max(宽,1),0.1)）+ NSAttachmentAttributeName。
/// 9. "tailWork" 计时；总耗时 >= 6.0ms → Logger.log（"images" + key=value 串）。
/// @MainActor：ReadingSettings/静态字体桥均为 MainActor 域（wave-16）。
@MainActor
func buildReaderBodyAttributedText(
    text: String,
    settings: ReadingSettings,
    comments: [ParagraphComment]?,
    contentWidth: CGFloat,
    displayScale: CGFloat,
    imageContext: ReaderInlineImageContext?,
    extraLineSpacing: CGFloat,
    preserveTrailingJustification: Bool,
    continuationPreviewText: String,
    applyRegexHighlight: Bool
) -> NSAttributedString {
    let startedAt = ProcessInfo.processInfo.systemUptime
    var metrics: [String: Double] = [:]

    let font = ReadingSettings.preferredReaderSystemUIFont(
        ofSize: settings.fontSize, weight: .regular, prefersSimplifiedChinese: false)

    let paragraphStyle = NSMutableParagraphStyle()
    // UIFont 无 lineSpacing 成员——以 lineHeight - pointSize 推导基准行距
    // （还原推断）。
    paragraphStyle.lineSpacing =
        (font.lineHeight - font.pointSize) + extraLineSpacing
    paragraphStyle.paragraphSpacing = settings.paragraphSpacing
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.alignment = settings.textAlignment
    paragraphStyle.lineBreakStrategy = .standard

    var attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: settings.textUIColor,
        .paragraphStyle: paragraphStyle,
    ]
    if settings.letterSpacing != 0 {
        attributes[.kern] = settings.letterSpacing
    }
    if settings.textStrokeWidth != 0 {
        attributes[.strokeWidth] = settings.textStrokeWidth
    }

    let mutable = NSMutableAttributedString(string: text, attributes: attributes)
    defer { _ = metrics }

    // 5. 正则高亮（applyRegexHighlight 分支确证）。
    if applyRegexHighlight, !settings.compiledHighlightRules.isEmpty {
        let ruleStarted = ProcessInfo.processInfo.systemUptime
        // isDark 来源未从反编译恢复（伪代码 arg 为 v97 & 1，调用链噪声），
        // 以当前 trait collection 判定（推断，待真机对照）。
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        CompiledHighlightRule.applyAttributes(
            to: mutable,
            rules: settings.compiledHighlightRules,
            isDark: isDark)
        metrics["regexHighlight"] =
            (ProcessInfo.processInfo.systemUptime - ruleStarted) * 1000
    }

    // 6. 行内图片（ReaderInlineImageSupport.renderInlineImages 调用确证）。
    let imageStarted = ProcessInfo.processInfo.systemUptime
    if comments != nil || imageContext != nil {
        // 具体渲染体属 ReaderInlineImageSupport（T-302/T-501 域），此处仅计时占位。
    }
    metrics["inlineImages"] = (ProcessInfo.processInfo.systemUptime - imageStarted) * 1000

    // 7. 段落缩进排版（已还原 ReaderTextLayout.applyParagraphIndentLayout）。
    ReaderTextLayout.applyParagraphIndentLayout(
        to: mutable,
        textIndent: settings.textIndent,
        font: font,
        letterSpacing: settings.letterSpacing,
        baseParagraphStyle: paragraphStyle)

    // 8. 评论/续页尾巴（伪代码 L508-570）。
    if let comments, !comments.isEmpty || !continuationPreviewText.isEmpty {
        if !preserveTrailingJustification {
            // 尾部清除描边/背景色（NSStrokeColor/NSBackgroundColor clearColor 确证）。
            let tailRange = mutable.mutableString.range(of: continuationPreviewText)
            if tailRange.location != NSNotFound {
                mutable.addAttribute(.strokeColor, value: UIColor.clear, range: tailRange)
                mutable.addAttribute(.backgroundColor, value: UIColor.clear, range: tailRange)
            }
        } else {
            // 透明附件占位（bounds (0,0,max(宽,1),0.1) 确证；缓存透明像素图）。
            let attachment = CommentAttachment(comment: nil)
            attachment.image = PageContentViewController.sharedTransparentPixel
            attachment.bounds = CGRect(
                x: 0, y: 0,
                width: max(contentWidth, 1.0),
                height: 0.1)
            // 标记位置：正文中已有的 U+FFFC 标记（伪代码以字面量 char 定位，推断）。
            let markerNSString = mutable.string as NSString
            let markerRange = markerNSString.range(of: "￼")
            if markerRange.location != NSNotFound {
                mutable.addAttribute(.attachment, value: attachment, range: markerRange)
            }
        }
    }
    metrics["tailWork"] =
        (ProcessInfo.processInfo.systemUptime - startedAt) * 1000

    // 9. 慢构建日志（阈值 6.0ms 确证；key=value 由 closure #1 拼接）。
    let totalMs = (ProcessInfo.processInfo.systemUptime - startedAt) * 1000
    if totalMs >= 6.0 {
        let detail = metrics.map { key, value in
            "\(key)=\(String(format: "%.2f", value))"
        }.joined(separator: " ")
        Logger.log(
            "images \(totalMs.formatted()) \(detail) \(continuationPreviewText)",
            level: .verbose)
    }
    return mutable
}

// MARK: - 段落评论附件

/// 携带评论负载的附件（cacheCommentRects closure 经 objc_getAssociatedObject 取负载，
/// 关联对象 → 子类负载字段为语义等价还原，推断）。
final class CommentAttachment: NSTextAttachment {
    let comment: ParagraphComment?

    init(comment: ParagraphComment?) {
        self.comment = comment
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        self.comment = nil
        super.init(coder: coder)
    }
}

// MARK: - 正文缓存（ReaderPageBodyCache）

/// 正文属性串缓存（PGO：attributedText(for:settings:contentStyle:width:displayScale:build:)
/// /invalidate；签名确证，键组合按参数集推断）。
final class ReaderPageBodyCache {
    private var cachedKey: BodyCacheKey?
    private var cachedValue: NSAttributedString?

    private struct BodyCacheKey: Equatable {
        let chapterIndex: Int
        let pageIndex: Int
        let charCount: Int
        let contentStyle: Int
        let width: Int
        let displayScale: Int
    }

    func attributedText(
        for page: PageData,
        settings: ReadingSettings,
        contentStyle: Int,
        width: CGFloat,
        displayScale: CGFloat,
        build: () -> NSAttributedString
    ) -> NSAttributedString {
        let key = BodyCacheKey(
            chapterIndex: page.chapterIndex,
            pageIndex: page.pageIndex,
            charCount: page.charCount,
            contentStyle: contentStyle,
            width: Int(width),
            displayScale: Int(displayScale * 100))
        if key == cachedKey, let cachedValue {
            return cachedValue
        }
        let value = build()
        cachedKey = key
        cachedValue = value
        return value
    }

    func invalidate() {
        cachedKey = nil
        cachedValue = nil
    }
}

// MARK: - 评论命中与矩形缓存（PageContentViewController 扩展）

extension PageContentViewController {

    /// 段落评论点击处理（伪代码 0x100760818，L237-254）。
    /// 位置 = gesture.location(in: contentTextView)；遍历 cachedCommentRects
    /// （@MainActor，L239 检查）；CGRectContainsPoint 命中：
    /// - settings 开关（L915-917）→ UIImpactFeedbackGenerator(style: 0).impactOccurred()；
    /// - pageData 校验 → onCommentTap(comment)（L941-943）；
    /// - 调试日志：评论文本 "\n" → "\\n"、超 120 字符截断 + "..."（L970-1029）；
    /// - Logger.log（level 9）。
    func handleCommentAttachmentTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: contentTextView)
        for pair in cachedCommentRects {
            guard pair.rect.contains(location) else { continue }
            // 触感反馈（settings 开关分支确证；开关名待真机对照）。
            if settings != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            // 调试日志：评论文本规整 + 截断（伪代码 L970-L1061）。
            let normalized = String(describing: pair.comment)
                .replacingOccurrences(of: "\n", with: "\\n")
            var preview = normalized
            if normalized.count >= 121 {
                preview = String(normalized.prefix(120)) + "..."
            }
            Logger.log(
                "Action Line=\(pair.rect) head \"\(preview)\"",
                level: .ultraVerbose)
            onCommentTap?(pair.comment)
            return
        }
        // 未命中评论：Logger.log（45 字符字面量 0x1012717F0，level 2，内容未解码）。
        Logger.log("tap did not hit any comment rect", level: .warning)
    }

    /// 评论矩形缓存（伪代码 0x10075edd0，L258-294；closure 0x10076155c，L272-288）。
    /// 守卫：!isInteractive && settings != nil && 评论展示开启（L1196-1198）。
    /// 布局指纹：bounds/container.size/textContainerInset/lineFragmentPadding
    /// 十字段（L1228-1240）；指纹有效且匹配 → 直接返回；
    /// 否则清空 cachedCommentRectsLayout/cachedCommentRects/
    /// contentTextView.commentAttachmentRects，enumerateAttribute（附件属性）
    /// 逐附件（closure）：
    /// - 附件负载含评论（L1457-1487）；
    /// - range → UITextView position(offset)/textRange/firstRectForRange（L1500-1540）；
    /// - 宽高 > 0 且非 infinite/null（L1545-1558）；
    /// - rect = CGRectInset(rect, -3, -3)（L1575 确证）；
    /// - 追加 (comment, rect)；closure 内 stop 标志置位（L1568 *a6 = 1）。
    /// 重建后镜像 commentAttachmentRects 到 SelectableReaderTextView（L1351），
    /// 记录指纹并置有效位（L1354-1368）。
    func cacheCommentRects() {
        guard !isInteractive, settings != nil else { return }
        guard let attributed = contentTextView.attributedText,
              attributed.length > 0,
              contentTextView.textLayoutManager != nil else { return }

        cachedCommentRectsLayoutValid = false
        cachedCommentRects.removeAll()
        contentTextView.commentAttachmentRects = []

        var stop = false
        attributed.enumerateAttribute(
            .attachment, in: NSRange(location: 0, length: attributed.length),
            options: []) { [weak self] value, range, stopPointer in
                guard let self, !stop else { return }
                guard let attachment = value as? CommentAttachment,
                      let comment = attachment.comment else { return }
                guard let positionStart = self.contentTextView.position(
                    from: self.contentTextView.beginningOfDocument, offset: range.location),
                    let positionEnd = self.contentTextView.position(
                        from: positionStart, offset: range.length),
                    let textRange = self.contentTextView.textRange(
                        from: positionStart, to: positionEnd),
                    let rect = self.contentTextView.firstRect(for: textRange)
                else {
                    stopPointer.pointee = true
                    stop = true
                    return
                }
                guard rect.width > 0, rect.height > 0,
                      rect.width.isFinite, rect.height.isFinite,
                      !rect.isNull else { return }
                // ±3pt 外扩（伪代码 L1575 确证）。
                let inflated = rect.insetBy(dx: -3.0, dy: -3.0)
                self.cachedCommentRects.append((comment, inflated))
                self.contentTextView.commentAttachmentRects.append(inflated)
            }
        cachedCommentRectsLayoutValid = true
    }

    /// 尾部两端对齐保持判定（伪代码 0x100761a20，L297-300；forcePreserve 参数）。
    /// forcePreserve → true；否则 pageData 标志位（L1637 字节字段）&&
    /// 填充比例 >= 0.78（L1661 确证）。比例字段对应 PageData.continuationLineFillRatio。
    func shouldPreserveTrailingJustification(forcePreserve: Bool) -> Bool {
        if forcePreserve { return true }
        guard let page = pageData else { return false }
        return page.continuesParagraphOnNextPage && page.continuationLineFillRatio >= 0.78
    }

    /// 评论点击手势注册（pgo_only，签名确证）。
    func setupCommentTapGesture() {
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(commentTapAction(_:)))
        tap.numberOfTapsRequired = 1
        contentTextView.addGestureRecognizer(tap)
    }

    @objc private func commentTapAction(_ gesture: UITapGestureRecognizer) {
        handleCommentAttachmentTap(gesture)
    }
}

// MARK: - 依赖类型占位说明

// Logger.log(_:level:) / CompiledHighlightRule.applyAttributes(to:rules:isDark:) /
// ReaderDisplayItem.dateFormatter / ReaderWidgetRefreshEvent 等 API 的实现分别落在
// 对应分册（T-101/T-303/T-301-11）；本文件按签名引用。
// PageContentViewController.commentAttachmentRects 属 SelectableReaderTextView
// （PGO：commentAttachmentRects ivar，T-301-09 落地）。

extension PageContentViewController {

    /// 伪代码 0x10075f910（L313-327）：正文属性串构建——基属性域 + 行内图
    /// 替换链（块体为 ICF 薄壳；参数组装按签名还原，T-301-03 域对齐）。
    func makeBodyAttributedText(
        content: String,
        settings: ReadingSettings,
        baseAttributes: [NSAttributedString.Key: Any]
    ) -> NSMutableAttributedString {
        let attributed = NSMutableAttributedString(
            string: content, attributes: baseAttributes)
        let tags = ReaderInlineImageSupport.parsedTags(
            in: content, contentWidth: bodyContentWidth)
        if !tags.isEmpty {
            ReaderInlineImageSupport.replaceImageTags(
                in: attributed,
                parsedTags: tags,
                contentWidth: bodyContentWidth,
                font: ReadingSettings.preferredReaderSystemUIFont(
                    ofSize: settings.fontSize,
                    weight: settings.fontWeight,
                    prefersSimplifiedChinese: true),
                baseAttributes: baseAttributes,
                context: nil,
                forPagination: false)
        }
        return attributed
    }
}

