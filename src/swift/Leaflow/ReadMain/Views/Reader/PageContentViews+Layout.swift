// 原始归属: ReadMain/Views/Reader/PageContentViews.swift；拆分不改变336文件统计。
import UIKit

extension PageContentViewController {
    /// 布局帧更新（伪代码 0x100757e1c L460-539）。返回是否完成排版布局。
    /// - 守卫：pageData 无效 / storedContentStyleSignature 与当前签名不一致 → false；
    /// - ReaderInlineImageContext 装配 + BackgroundWork.runAsync 图片预取；
    /// - view 尺寸 <= 1.0 → false；
    /// - settings.applyLayoutTemplate；
    /// - chapterTitleView frame/hidden（L2421-2423）；
    /// - contentTextView/fullLineUnderlineView frame = bounds；
    /// - textContainerInset ≠ (0,8,0,8) → 重设（L2436-2442 精确比较）；
    /// - chapterTitleView.frame = (contentMinX-8, minY, width+16, height)（L2444-2461）；
    /// - textContainer.size = (contentWidth, boundsHeight + max(lineHeight*3, 100))（L2463-2483）；
    /// - applyEggChapterContentInsetsIfNeeded + updateHighlightGradientOverlays(attributedText:)；
    /// - lastLoggedContentFrame 跟踪 + trace。
    @discardableResult
    func updateFrames() -> Bool {
        guard pageData != nil,
              storedContentStyleSignature == nil || storedContentStyleSignature == contentStyleSignature
        else { return false }

        // 图片上下文预取（BackgroundWork.fireAndForget + ReaderInlineImageContext
        // 真实 init 域确证；闭包体未恢复，待真机对照）。contentWidth 经
        // view.bounds（本类型无 containerSize 属性，wave-16）。
        if let page = pageData, let settings {
            let context = ReaderInlineImageContext(
                sourceUrl: page.imageSourceUrl,
                storageKind: page.imageSourceStorageKind,
                contentWidth: view.bounds.width,
                font: settings.widgetFont(size: settings.fontSize),
                scale: UIScreen.main.scale)
            if context.sourceUrl != nil {
                BackgroundWork.fireAndForget(priority: nil) {
                    // 预取闭包体：伪代码未展开（sub_100752D1C），待真机对照。
                }
            }
        }

        let bounds = view.bounds
        guard bounds.width > 1.0, bounds.height > 1.0 else { return false }
        settings?.applyLayoutTemplate(.single)

        guard let settings, let page = pageData else { return false }
        // 原版updateFrames消费布局结果；全屏bounds会把首行放到导航栏后方。
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let layout = ReaderLayoutCalculator.calculateLayout(isFirstPage: page.pageIndex == 0,
            chapterTitleConfig: page.pageIndex == 0 && !page.chapterTitle.isEmpty ? settings.activeChapterTitleConfig : nil,
            leftPageMargin: settings.leftPageMargin, rightPageMargin: settings.rightPageMargin,
            topInsetExtra: settings.topInsetExtra, bottomInsetExtra: settings.bottomInsetExtra,
            screenBounds: bounds, safeAreaFrame: safeFrame.width > 0 && safeFrame.height > 0
                ? safeFrame : bounds.inset(by: view.safeAreaInsets))
        chapterTitleView.frame = CGRect(x: layout.contentRect.minX, y: layout.topInset,
            width: layout.contentRect.width, height: layout.titleHeight)
        chapterTitleView.isHidden = layout.titleHeight <= 0
        fullLineUnderlineView.frame = bounds

        // textContainerInset 常量 (0, 8, 0, 8)（伪代码 L2436-2442 精确比较）。
        let inset = contentTextView.textContainerInset
        if !(inset.top == 0 && inset.left == 8 && inset.bottom == 0 && inset.right == 8) {
            contentTextView.textContainerInset =
                UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        }

        // 0x10075d750返回正文视图；8pt内边距与外扩16pt相抵。
        let contentFrame = layout.contentRect
        contentTextView.frame = contentFrame.insetBy(dx: -8, dy: 0)

        // 正文容器高度 = 容器高 + max(lineHeight * 3, 100)（L2463-2483）。
        let lineHeight = contentTextView.font?.lineHeight ?? 0
        let containerHeight = contentFrame.height + max(lineHeight * 3, 100)
        let container = contentTextView.textContainer
        if container.size.width != contentFrame.width || container.size.height != containerHeight {
            container.size = CGSize(width: contentFrame.width, height: containerHeight)
        }

        applyEggChapterContentInsetsIfNeeded()
        updateHighlightGradientOverlays(attributedText: contentTextView.attributedText)

        if contentTextView.frame != lastLoggedContentFrame {
            lastLoggedContentFrame = contentTextView.frame
        }
        return true
    }

    // MARK: 内容渲染

    /// 内容更新主链（伪代码 0x10075846c L541-782，1700+ 行）。
    /// 流程骨架（选择子/字面量确证）：
    /// 1. 守卫 pageData 有效（sub_100211858 校验）→ 失败直接返回；
    /// 2. trace mark(reason)；
    /// 3. ReaderPageDebug.visibleTextLength(in:) 检查；
    /// 4. view.backgroundColor = 阅读背景色；
    /// 5. 背景图：settings.backgroundUIImage nil → 移除 backgroundImageView；
    ///    否则创建/复用（contentMode 2，frame = bounds，insertSubview atIndex 0，unhide）；
    /// 6. updateFrames() false → trace PageSample(page:reason:role:previous:) + return；
    /// 7. trace beginPage("frames", reason)；
    /// 8. shouldApplyReaderPageLayoutUpdate(stored:current:)；
    /// 9. 章节标题快照（L3196-3307）：key 匹配 → "[TitleSnapshot] SKIP (key matches)"；
    ///    ChapterTitleSnapshotService.cachedSnapshot(for:width:) 命中 →
    ///    ReaderChapterTitleView.configureWithSnapshot(image:animated:false) + CACHE HIT；
    ///    未命中 → CACHE MISS + 异步渲染（true/false 后缀 + resolvedUIFont）；
    /// 10. 正文安装（trace "textInstall"）：settings.preferredReaderSystemUIFont →
    ///     contentTextView.setScrollEnabled:false / textContainer.setLineBreakMode:0 →
    ///     bodyCache.attributedText(for:...) { makeBodyAttributedText(...) } →
    ///     contentTextView.setAttributedText:；
    /// 11. 段落对齐规范化（closure #4 @MainActor：enumerateAttribute NSParagraphStyle）；
    /// 12. applyEggChapterContentInsetsIfNeeded + 覆盖层更新（trace "underline"）；
    /// 13. widget 标签刷新（widgetLabels 迭代）。
    func updateContent(reason: String) {
        guard pageData != nil else { return }
        _ = reason
        _ = ReaderPageDebug.visibleTextLength(in: pageData!)

        guard let settings else { return }
        view.backgroundColor = useTransparentBackground ? .clear : settings.readerBackgroundUIColor

        if let background = settings.backgroundUIImage {
            if let existing = backgroundImageView {
                existing.image = background
            } else {
                let imageView = UIImageView(image: background)
                imageView.contentMode = .scaleAspectFill
                imageView.frame = view.bounds
                view.insertSubview(imageView, at: 0)
                backgroundImageView = imageView
            }
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.removeFromSuperview()
            backgroundImageView = nil
        }

        guard updateFrames() else { return }

        // 章节标题快照缓存链（L3196-3307）。
        if let page = pageData, !page.chapterTitle.isEmpty {
            let width = chapterTitleView.frame.width
            let key = (width, page.chapterTitle)
            // 元组不持 Equatable——先解包可选键再比较（wave-16）。
            if let cached = lastTitleSnapshotKey, cached == key {
                ReaderPerformanceTrace.log(
                    "[TitleSnapshot] SKIP (key matches): \(page.chapterTitle)")
            } else if let snapshot = ChapterTitleSnapshotService.shared.cachedSnapshot(
                for: page.chapterTitle, width: width) {
                chapterTitleView.configureWithSnapshot(image: snapshot, animated: false)
                lastTitleSnapshotKey = key
                ReaderPerformanceTrace.log(
                    "[TitleSnapshot] CACHE HIT: \(page.chapterTitle)")
            } else {
                lastTitleSnapshotKey = nil
                ReaderPerformanceTrace.log(
                    "[TitleSnapshot] CACHE MISS: \(page.chapterTitle)")
            }
        }

        // 正文安装（trace "textInstall" 字面量确证）。
        let font = ReadingSettings.preferredReaderSystemUIFont(
            ofSize: settings.fontSize, weight: .regular, prefersSimplifiedChinese: false)
        contentTextView.font = font
        contentTextView.isScrollEnabled = false
        contentTextView.textContainer.lineBreakMode = .byWordWrapping
        if let page = pageData {
            let attributed = bodyCache.attributedText(
                for: page,
                settings: settings,
                contentStyle: contentStyleSignature,
                width: bodyContentWidth,
                displayScale: view.traitCollection.displayScale
            ) {
                self.makeBodyAttributedText(
                    text: page.content,
                    settings: settings,
                    highlightRange: nil,
                    comments: page.comments,
                    forcePreserveTrailingJustification: false)
            }
            contentTextView.attributedText = paragraphAlignedAttributedText(
                attributed, alignment: settings.textAlignment)
        }

        applyEggChapterContentInsetsIfNeeded()
        updateHighlightGradientOverlays(attributedText: contentTextView.attributedText)
        updateFullLineUnderlineOverlay()
        refreshWidgetLabels(
            context: makeWidgetContext(for: pageData!),
            settings: settings,
            event: .content)
    }

    /// 正文属性串构建入口（伪代码 0x10075f910 L313-327，+Comments 分册）。
    func makeBodyAttributedText(
        text: String,
        settings: ReadingSettings,
        highlightRange: NSRange?,
        comments: [ParagraphComment]?,
        forcePreserveTrailingJustification: Bool
    ) -> NSAttributedString {
        buildReaderBodyAttributedText(
            text: text,
            settings: settings,
            comments: comments,
            contentWidth: bodyContentWidth,
            displayScale: view.traitCollection.displayScale,
            imageContext: nil,
            extraLineSpacing: settings.lineSpacing,
            preserveTrailingJustification: shouldPreserveTrailingJustification(
                forcePreserve: forcePreserveTrailingJustification),
            continuationPreviewText: "",
            applyRegexHighlight: true)
    }

    /// 段落对齐属性规范化（伪代码 0x10075a648 L784-799，@MainActor）。
    /// 取现有 NSParagraphStyle（attribute 查询，无则新建 NSMutableParagraphStyle）→
    /// mutableCopy → setAlignment(alignment) → addAttribute(NSParagraphStyleAttributeName,
    /// 全文 range)。
    func paragraphAlignedAttributedText(
        _ attributed: NSAttributedString, alignment: NSTextAlignment
    ) -> NSAttributedString {
        guard attributed.length > 0 else { return attributed }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let paragraphStyle: NSMutableParagraphStyle
        if let existing = attributed.attribute(
            .paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
            paragraphStyle = existing.mutableCopy() as! NSMutableParagraphStyle
        } else {
            paragraphStyle = NSMutableParagraphStyle()
        }
        paragraphStyle.alignment = alignment
        mutable.addAttribute(
            .paragraphStyle, value: paragraphStyle,
            range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    /// 正文缓存宽度（pgo_only bodyContentWidth getter）。
    var bodyContentWidth: CGFloat {
        contentTextView.textContainer.size.width
    }

    /// 强制重建内容（pgo_only：与 updateContent 共体，按签名声明）。
    func forceRebuildContent(settings: ReadingSettings) {
        bodyCache.invalidate()
        storedContentStyleSignature = nil
        self.settings = settings
        updateContent(reason: "configure")
    }

    /// 可渲染正文区间（pgo_only，按签名声明）：
    /// range 越界或 NSNotFound → nil。
    func renderedTextRange(
        forContentRange range: NSRange, textStorageLength: Int
    ) -> NSRange? {
        guard range.location != NSNotFound,
              range.location + range.length <= textStorageLength else { return nil }
        return range
    }

    // MARK: 章节标题内边距（彩蛋模式）

    /// 伪代码 0x10075a834 L801-855。
    /// 前置：pageData 校验 + shouldApplyReaderPageLayoutUpdate(stored:current:)。
    /// 条件：contentTextView.attributedText length >= 1、textLayoutManager 存在、
    /// bounds.height > 0；enumerateTextLayoutFragments(documentRange.location, options: 4)
    /// 闭包（closure #1，0x10075ac94 L803-811，@MainActor）逐 fragment frame 取
    /// minY/min、maxY/max（空 rect 跳过）；inset = floor((bounds.height - 内容高) * 0.5)
    /// 且 >= 0；与当前 top/bottom 不同 → setTextContainerInset(inset, left, inset, right)。
    func applyEggChapterContentInsetsIfNeeded() {
        let currentInset = contentTextView.textContainerInset
        guard pageData != nil,
              shouldApplyReaderPageLayoutUpdate(
                storedContentStyleSignature: storedContentStyleSignature ?? 0,
                currentContentStyleSignature: contentStyleSignature)
        else { return }
        guard let attributed = contentTextView.attributedText, attributed.length >= 1,
              let layoutManager = contentTextView.textLayoutManager,
              contentTextView.bounds.height > 0
        else { return }

        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var found = false
        layoutManager.enumerateTextLayoutFragments(
            from: layoutManager.documentRange.location,
            options: [.ensuresLayout],
            using: { fragment in
                let frame = fragment.layoutFragmentFrame
                if frame.isEmpty { return true }
                found = true
                minY = min(minY, frame.minY)
                maxY = max(maxY, frame.maxY)
                return true
            })
        guard found else { return }

        let contentHeight = max(0, maxY - minY)
        let inset = max(0, floor((contentTextView.bounds.height - contentHeight) * 0.5))
        if currentInset.top != inset || currentInset.bottom != inset {
            contentTextView.textContainerInset = UIEdgeInsets(
                top: inset, left: currentInset.left, bottom: inset, right: currentInset.right)
        }
        // 彩蛋模式下隐藏全行下划线（closure #2 0x10075ade4 L830-837：
        // setPath(nil) + setHidden(true)）。
        clearFullLineUnderlineOverlay()
    }

    // MARK: 渐变高亮覆盖层

    /// 伪代码 0x10075aeac L862-869：
    /// highlightRange.location == NSNotFound → 覆盖层 textLayoutManager 置 nil；
    /// 否则赋当前 textLayoutManager。
    func updateHighlightGradientOverlayFrames() {
        let manager = contentTextView.textLayoutManager
        if highlightRange.location == NSNotFound {
            highlightGradientBackgroundView.textLayoutManager = nil
            highlightGradientForegroundView.textLayoutManager = nil
        } else {
            highlightGradientBackgroundView.textLayoutManager = manager
            highlightGradientForegroundView.textLayoutManager = manager
        }
    }

    /// 伪代码 0x10075af50 L871-878：
    /// 采集度量（textContainerInset/lineFragmentPadding/lineBreakMode）→
    /// updateHighlightGradientOverlayConfiguration → 覆盖层绑定 textLayoutManager。
    func updateHighlightGradientOverlays(attributedText: NSAttributedString?) {
        _ = attributedText
        let inset = contentTextView.textContainerInset
        let padding = contentTextView.textContainer.lineFragmentPadding
        let breakMode = contentTextView.textContainer.lineBreakMode
        updateHighlightGradientOverlayConfiguration()
        // 覆盖层度量传递：inset/padding/lineBreakMode 按伪代码采集后交给
        // HighlightGradientOverlayView（具体 API 名待 T-303 分册落地）。
        _ = inset
        _ = padding
        _ = breakMode
        highlightGradientBackgroundView.textLayoutManager = contentTextView.textLayoutManager
        highlightGradientForegroundView.textLayoutManager = contentTextView.textLayoutManager
    }

    /// 渲染签名（伪代码 0x10075b08c L880-893）。
    /// pageRenderSignature 未缓存时用 Hasher 组合（pageData 渲染域 + settings 两字段
    /// + 存在标志）并缓存；之后每次组合缓存签名 + settings 字段。
    func updateHighlightGradientOverlayConfiguration() {
        if pageRenderSignature == nil {
            var hasher = Hasher()
            if let page = pageData {
                hasher.combine(page.chapterIndex)
                hasher.combine(page.pageIndex)
                hasher.combine(page.charCount)
            }
            if let settings {
                hasher.combine(settings.fontSize)
                hasher.combine(settings.verticalJustify)
            }
            pageRenderSignature = hasher.finalize()
        }
    }

    /// 渲染身份（pgo_only highlightBackgroundRenderIdentity：签名哈希）。
    var highlightBackgroundRenderIdentity: Int {
        updateHighlightGradientOverlayConfiguration()
        return pageRenderSignature ?? 0
    }

    // MARK: 全行下划线覆盖层

    /// 清除下划线（pgo_only；closure #2 0x10075ade4：setPath(nil) + setHidden(true)）。
    func clearFullLineUnderlineOverlay() {
        fullLineUnderlineLayer.path = nil
        fullLineUnderlineView.isHidden = true
    }

    /// 伪代码 0x10075b230 L910-990（closure #3 0x10075b928 L929-974）。
    /// 守卫：settings 存在、attributedText 非空、textLayoutManager 存在、内容宽度 > 0，
    /// 失败 → clearFullLineUnderlineOverlay。
    /// 排除矩形 ← cachedCommentRects（convertRect:fromCoordinateSpace: 换算到覆盖层坐标）。
    /// enumerateTextLayoutFragments（options: 4 = ensuresLayout）逐 fragment：
    /// - 逐 NSTextLineFragment：readerFullLineUnderlineHasVisibleText(line.attributedString)
    ///   过滤（L5419-5421）；
    /// - lineTop = fragmentFrame.minY + typographicBounds.minY；
    ///   lineBottom = lineTop + typographicBounds.height（L5433-5436）；
    ///   lineBottom < 0 或 lineTop >= 覆盖层高 → 跳过（L5441）；
    /// - 排除段：readerFullLineUnderlineSegments（±2pt 外扩）；
    /// - 文本裁剪：readerFullLineUnderlineTextClipRange（L5539-5553，宽度 <= 1.0pt 跳过）；
    /// - 相减：readerFullLineUnderlineSubtractingSegments；
    /// - y = readerFullLineUnderlineY（L5571：round((lineBottom - strokeWidth + offset)*scale)/scale）；
    /// - moveToPoint/addLineToPoint 逐段画线（L5577-5580）。
    /// 空 path → clearFullLineUnderlineOverlay；
    /// 否则：覆盖层 frame、layer path、fillColor（usesTextColor ? textUIColor :
    ///   textUnderlineUIColor）、strokeColor、lineWidth、lineDashPattern（可选）、
    ///   lineCap（round/butt 按设置）、lineJoin round → setHidden(false)。
    func updateFullLineUnderlineOverlay() {
        guard let settings,
              let attributed = contentTextView.attributedText, attributed.length > 0,
              let layoutManager = contentTextView.textLayoutManager
        else {
            clearFullLineUnderlineOverlay()
            return
        }
        let fullWidth = fullLineUnderlineView.bounds.width
        guard fullWidth > 0 else {
            clearFullLineUnderlineOverlay()
            return
        }

        let excludedRects = cachedCommentRects.map { pair in
            fullLineUnderlineView.convert(pair.rect, from: contentTextView)
        }

        let path = UIBezierPath()
        // strokeWidth 下限 1.0（closure#3 L5399：fmax(a3, 1.0)）；offset 取值待真机对照。
        let strokeWidth: CGFloat = max(1.0, settings.textStrokeWidth)
        let scale = fullLineUnderlineView.traitCollection.displayScale
        let offset: CGFloat = 0

        layoutManager.enumerateTextLayoutFragments(
            from: layoutManager.documentRange.location,
            options: [.ensuresLayout],
            using: { fragment in
                for line in fragment.textLineFragments {
                    guard readerFullLineUnderlineHasVisibleText(line.attributedString) else {
                        continue
                    }
                    let typographic = line.typographicBounds
                    let lineTop = fragment.layoutFragmentFrame.minY + typographic.minY
                    let lineBottom = lineTop + typographic.height
                    if lineBottom < 0 || lineTop >= fullLineUnderlineView.bounds.height {
                        continue
                    }
                    let excluded = readerFullLineUnderlineSegments(
                        fullWidth: fullWidth,
                        excludedRects: excludedRects,
                        lineTop: lineTop,
                        lineBottom: lineBottom,
                        horizontalPadding: 2.0)
                    guard let clip = readerFullLineUnderlineTextClipRange(
                        minX: fragment.layoutFragmentFrame.minX + typographic.minX,
                        maxX: fragment.layoutFragmentFrame.minX + typographic.maxX,
                        fullWidth: fullWidth) else { continue }
                    var segments: [ClosedRange<CGFloat>] = [clip]
                    for range in excluded {
                        segments = readerFullLineUnderlineSubtractingSegments(
                            segments, removing: range)
                    }
                    guard !segments.isEmpty else { continue }
                    let y = readerFullLineUnderlineY(
                        lineBottom: lineBottom, strokeWidth: strokeWidth,
                        offset: offset, scale: scale)
                    for segment in segments {
                        path.move(to: CGPoint(x: segment.lowerBound, y: y))
                        path.addLine(to: CGPoint(x: segment.upperBound, y: y))
                    }
                }
                return true
            })

        if path.isEmpty {
            clearFullLineUnderlineOverlay()
            return
        }

        fullLineUnderlineView.frame = view.bounds
        fullLineUnderlineLayer.path = path.cgPath
        let fillColor = settings.textUnderlineUsesTextColor
            ? settings.textUIColor
            : settings.textUnderlineUIColor
        fullLineUnderlineLayer.fillColor = fillColor.cgColor
        fullLineUnderlineLayer.strokeColor = fillColor.cgColor
        fullLineUnderlineLayer.lineWidth = settings.textStrokeWidth
        fullLineUnderlineLayer.lineCap = .round
        fullLineUnderlineLayer.lineJoin = .round
        fullLineUnderlineView.isHidden = false
    }

}
