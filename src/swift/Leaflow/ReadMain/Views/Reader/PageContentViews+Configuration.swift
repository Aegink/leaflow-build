// 原始归属: ReadMain/Views/Reader/PageContentViews.swift；拆分不改变336文件统计。
import UIKit

extension PageContentViewController {
    // MARK: 配置

    /// 伪代码 0x10075bf60 L992-1044。
    /// needsFrameUpdate = bookName/totalChapters 变化；
    /// 内容变化 = 新旧 pageData 渲染状态不等（hasSameRenderableState 域）；
    /// settings 存回；pageData/bookName/totalChapters/originalText 更新；
    /// widget 字体（settings.widgetFont(size:).fontName）与上次比较，变化 → 刷新 widget；
    /// 内容或评论变化 → updateContent(reason: "configure")
    /// （小串 0x72756769666E6F63 = "configur…" 确证）；否则仅 needsFrameUpdate 时 updateFrames()。
    func configure(
        pageData newPage: PageData,
        settings newSettings: ReadingSettings,
        bookName newBookName: String,
        totalChapters newTotalChapters: Int
    ) {
        let needsFrameUpdate = bookName != newBookName || totalChapters != newTotalChapters
        let contentChanged = pageData.map { !newPage.hasSameRenderableState(as: $0) } ?? true

        settings = newSettings
        pageData = newPage
        bookName = newBookName
        totalChapters = newTotalChapters
        originalText = newPage.content
        if isViewLoaded, widgetInstances.map(\.widget) != newSettings.layoutWidgets {
            setupWidgetLabels(settings: newSettings)
            refreshAllWidgetContent()
        }

        // widget 字体变化检测（L5844-5896：fontName 桥接比较；widgetFont
        // 非可选——直取，wave-16）。
        let widgetFont = newSettings.widgetFont(size: newSettings.fontSize)
        let fontName = widgetFont.fontName
        if lastWidgetFontName != fontName {
            lastWidgetFontName = fontName
            refreshAllWidgetContent()
        }

        guard contentChanged else {
            if needsFrameUpdate {
                updateFrames()
            }
            return
        }
        _ = ReaderPageDebug.visibleTextLength(in: newPage)
        updateContent(reason: "configure")
    }

    // MARK: TTS 高亮

    /// 伪代码 0x10075c4c0 L1093-1130。
    /// 归一化（location == NSNotFound → (NSNotFound, 0)）；
    /// 与当前状态一致（chapterTitle 标志 + range）→ no-op；
    /// 置 isChapterTitleHighlighted；settings.ttsHighlightUIColor 用于章节标题高亮；
    /// location == NSNotFound → highlightRange=(NSNotFound,0) + restorePreviousHighlight()；
    /// 否则 highlightRange = 新值 + applyForegroundHighlight(for:)。
    func updateHighlight(range: NSRange, highlightChapterTitle: Bool) {
        var location = range.location
        var length = range.length
        if location == NSNotFound {
            length = 0
        }
        if highlightChapterTitle == isChapterTitleHighlighted,
           highlightRange.location == location, highlightRange.length == length {
            return
        }
        isChapterTitleHighlighted = highlightChapterTitle
        // 章节 title 高亮：伪代码以 (highlightChapterTitle, ttsHighlightUIColor)
        // 两参传入 ReaderChapterTitleView 配置闭包（closure #1 in configureWithSnapshot），
        // 具体 API 名待 T-303 分册落地。
        let _highlightColor = settings?.ttsHighlightUIColor
        _ = _highlightColor

        highlightRange = NSRange(location: location, length: length)
        if location == NSNotFound {
            restorePreviousHighlight()
        } else {
            applyForegroundHighlight(for: NSRange(location: location, length: length))
        }
    }

    /// 伪代码 0x10075c64c L1133-1238。
    /// textStorage = contentTextView.textStorage；先 restorePreviousHighlight()；
    /// 守卫：location == NSNotFound / pageData 校验失败 /
    ///   location < 0 || length < 1 || 文本长 < location+length → return；
    /// 夹取到 storage.length（sub_10075C9B8）；beginEditing → 跳过段首 U+FFFC（65532）
    /// → 逐段 addAttribute(NSForegroundColorAttributeName,
    ///   settings.ttsHighlightUIColor) → endEditing；
    /// previousHighlightedRange 记录 + updateHighlightGradientOverlayFrames()。
    func applyForegroundHighlight(for range: NSRange) {
        // UITextView.textStorage 非可选（NSTextStorage 域确证）——直取。
        let textStorage = contentTextView.textStorage
        restorePreviousHighlight()
        guard range.location != NSNotFound, pageData != nil else { return }
        guard range.location >= 0, range.length >= 1 else { return }

        let storage = textStorage
        guard let color = settings?.ttsHighlightUIColor else { return }
        let clampedLength = min(range.length, max(0, storage.length - range.location))
        guard clampedLength >= 1, range.location + clampedLength <= storage.length else { return }

        storage.beginEditing()
        let string = storage.string as NSString
        var cursor = range.location
        let end = range.location + clampedLength
        while cursor < end {
            // 跳过段首评论标记（U+FFFC = 65532，伪代码 L6177 精确比较）。
            if string.character(at: cursor) == 0xFFFC {
                cursor += 1
                continue
            }
            var segmentEnd = cursor + 1
            while segmentEnd < end, string.character(at: segmentEnd) != 0xFFFC {
                segmentEnd += 1
            }
            storage.addAttribute(
                .foregroundColor, value: color,
                range: NSRange(location: cursor, length: segmentEnd - cursor))
            cursor = segmentEnd
        }
        storage.endEditing()

        previousHighlightedRange = NSRange(location: range.location, length: clampedLength)
        updateHighlightGradientOverlayFrames()
    }

    /// 伪代码 0x10075ca30 L1248-1273（closure #1 0x10075ce00 L1263-1269）。
    /// previousHighlightedRange 有效（location != NSNotFound && length >= 1）→
    /// 守卫 storage.length >= location+length → enumerateAttribute(
    /// NSForegroundColorAttributeName, in: previous) 逐段恢复原色
    /// （closure：isChapterTitleHighlighted 复位 + 章节标题高亮复位）；
    /// 完成后 previousHighlightedRange = (NSNotFound, 0)。
    func restorePreviousHighlight() {
        let previous = previousHighlightedRange
        guard previous.location != NSNotFound, previous.length >= 1 else { return }
        // UITextView.textStorage 非可选（NSTextStorage 域确证）——直取。
        let textStorage = contentTextView.textStorage
        guard previous.location + previous.length <= textStorage.length else {
            previousHighlightedRange = NSRange(location: NSNotFound, length: 0)
            return
        }
        guard let originalColor = settings?.textUIColor else { return }
        textStorage.beginEditing()
        textStorage.enumerateAttribute(
            .foregroundColor, in: previous, options: []) { value, subRange, _ in
            // closure #1（0x10075ce00）：TTS 高亮段恢复正文色，其余保持。
            if let color = value as? UIColor,
               color == self.settings?.ttsHighlightUIColor {
                textStorage.addAttribute(
                    .foregroundColor, value: originalColor, range: subRange)
            }
        }
        textStorage.endEditing()
        isChapterTitleHighlighted = false
        // 章节 title 高亮复位（同 updateHighlight 注释）。
        previousHighlightedRange = NSRange(location: NSNotFound, length: 0)
    }

    /// 伪代码 0x10075ce60 L1280-1285。
    /// 块体为 ICF 误标嫌疑（实为评论命中检查路径）；语义按签名还原：
    /// 清除 TTS 高亮 + 待处理高亮队列。
    func clearHighlight() {
        pendingHighlightRange = nil
        pendingChapterTitleHighlight = nil
        updateHighlight(
            range: NSRange(location: NSNotFound, length: 0),
            highlightChapterTitle: false)
    }

    // MARK: 手势

    /// 伪代码 0x10075d0b8 L1289-1295：
    /// UILongPressGestureRecognizer 且其视图是 SelectableReaderTextView → true；否则 false。
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let longPress = gestureRecognizer as? UILongPressGestureRecognizer else {
            return true
        }
        return longPress.view is SelectableReaderTextView
    }

    /// 伪代码 0x10075d4a8 L1299-1306。
    /// 点位转换（convertPoint:toView: 确证）后交给 blocksContainerTap 判定
    /// （pgo_only blocksContainerTap 与本函数共体）。
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let point = gestureRecognizer.location(in: contentTextView)
        return blocksContainerTap(at: point, from: gestureRecognizer.view ?? view)
    }

    /// 容器点击拦截（pgo_only，签名确证）：
    /// 点击落在评论矩形 → 拦截容器点击（交给评论 tap 处理）。
    func blocksContainerTap(at point: CGPoint, from sourceView: UIView) -> Bool {
        let converted = contentTextView.convert(point, from: sourceView)
        return isPointOnComment(converted)
    }

    /// 点击是否落在段落评论矩形上（L182-185；closure #1 0x10075e4e4 为
    /// (comment, rect) 元组过滤闭包）。
    func isPointOnComment(_ point: CGPoint) -> Bool {
        cachedCommentRects.contains { $0.rect.contains(point) }
    }

    /// 保住文本选择的容器点击判定（伪代码 0x1008b4914 L1322-1324）。
    /// 体为候选词循环 contains 检查（7 个候选，命中即 true）；
    /// 候选集合未能从反编译恢复 —— 按最小语义还原，待真机对照。
    func shouldPreserveTextSelectionOnContainerTap(
        at point: CGPoint, from sourceView: UIView
    ) -> Bool {
        let candidates = [
            "selection", "selectionRect", "selectedText",
            "textSelection", "comment", "attachment", "highlight",
        ]
        let description = String(describing: type(of: sourceView))
        return candidates.contains { description.contains($0) }
    }

    // MARK: widget 桥

    /// widget 上下文（pgo_only makeWidgetContext(for:)）。
    /// ReaderDisplayContext 无 page: 参——页身份映射到章节/页索引字段。
    func makeWidgetContext(for page: PageData) -> ReaderDisplayContext {
        ReaderDisplayContext(
            bookName: bookName,
            chapterTitle: page.chapterTitle,
            totalChapters: totalChapters,
            currentChapterIndex: page.chapterIndex,
            currentPageIndex: page.pageIndex,
            totalPages: page.chapterTotalPages,
            timeText: ReaderWidgetDisplayItem.dateFormatter.string(from: Date()))
    }
}
