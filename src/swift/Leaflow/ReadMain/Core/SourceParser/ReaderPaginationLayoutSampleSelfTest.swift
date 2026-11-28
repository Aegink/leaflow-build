// T-1602：分页与真实渲染共用字体、边距、章题和安全区；独立偏好域。
import UIKit

@MainActor
enum ReaderPaginationLayoutSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "T1602.PaginationLayout." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ReadingSettings.load(from: defaults)
        let bounds = CGSize(width: 240, height: 320)
        let insets = UIEdgeInsets(top: 20, left: 0, bottom: 30, right: 0)
        let text = String(repeating: "字号与边距改变时正文应完整连续。", count: 100)
        do {
            let plain = try ReaderPaginator.paginate(content: text, chapterIndex: 0,
                settings: settings, pageBounds: bounds)
            settings.leftPageMargin = 42
            settings.rightPageMargin = 38
            settings.topInsetExtra = 12
            settings.bottomInsetExtra = 8
            let sizes = ReaderPaginator.contentSizes(settings: settings, pageBounds: bounds,
                safeAreaInsets: insets, chapterTitle: "")
            emit("pagination_layout_margins_safe_area", ["160", "250", "true"],
                [String(Int(sizes.normal.width)), String(Int(sizes.normal.height)),
                 String(sizes.first == sizes.normal)])
            let narrow = try ReaderPaginator.paginate(content: text, chapterIndex: 0,
                settings: settings, pageBounds: bounds, safeAreaInsets: insets)
            emit("pagination_layout_margins_reflow", ["true", "true", "true"],
                [String(narrow.count > plain.count), String(narrow.map(\.content).joined() == text),
                 String(narrow.allSatisfy { $0.bodyHeight <= sizes.normal.height + 1 })])
            let longTitle = String(repeating: "长章节标题需要多行", count: 4)
            let titleSizes = ReaderPaginator.contentSizes(settings: settings, pageBounds: bounds,
                safeAreaInsets: insets, chapterTitle: longTitle)
            let shortTitle = ReaderPaginator.contentSizes(settings: settings, pageBounds: bounds,
                safeAreaInsets: insets, chapterTitle: "短标题")
            emit("pagination_layout_real_title_height", ["true", "true"],
                [String(titleSizes.first.height < shortTitle.first.height),
                 String(titleSizes.normal == sizes.normal)])
            var config = settings.activeChapterTitleConfig
            config.isEnabled = false
            let hidden = ReaderLayoutCalculator.calculateLayout(isFirstPage: true,
                chapterTitleConfig: config, leftPageMargin: 0, rightPageMargin: 0,
                topInsetExtra: 0, bottomInsetExtra: 0, screenBounds: CGRect(origin: .zero, size: bounds),
                safeAreaFrame: CGRect(origin: .zero, size: bounds), chapterTitle: longTitle)
            emit("pagination_layout_disabled_title", ["0", "320"],
                [String(Int(hidden.titleHeight)), String(Int(hidden.contentRect.height))])
            ReaderLayoutCalculator.updateWindowMetrics(bounds: CGRect(x: 0, y: 0, width: 900, height: 1200),
                safeArea: CGRect(x: 0, y: 44, width: 900, height: 1100))
            let explicit = ReaderPaginator.contentSizes(settings: settings, pageBounds: bounds,
                safeAreaInsets: insets, chapterTitle: "")
            ReaderLayoutCalculator.invalidateLayoutCache()
            emit("pagination_layout_explicit_bounds", ["true"], [String(explicit.normal == sizes.normal)])
            settings.fontName = "Courier"
            settings.fontSize = 22
            settings.letterSpacing = 3
            settings.lineSpacing = 9
            let body = buildReaderBodyAttributedText(text: "Text fixed", settings: settings,
                comments: nil, contentWidth: 160, displayScale: 2, imageContext: nil, extraLineSpacing: 0,
                preserveTrailingJustification: false, continuationPreviewText: "", applyRegexHighlight: false)
            let font = body.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            let style = body.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            emit("pagination_layout_custom_font_render", ["true", "22", "9", "3"],
                [String(font?.familyName == UIFont(name: "Courier", size: 22)?.familyName),
                 String(Int(font?.pointSize ?? 0)), String(Int(style?.lineSpacing ?? 0)),
                 String((body.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber)?.intValue ?? 0)])
            settings.fontName = "NotInstalled-T1602"
            emit("pagination_layout_missing_font_fallback", ["22"], [String(Int(settings.uiFont.pointSize))])
            settings.fontName = "Courier"
            settings.letterSpacing = 0
            let normal = try ReaderPaginator.paginate(content: String(repeating: "fixed body text ", count: 100),
                chapterIndex: 0, settings: settings, pageBounds: bounds)
            settings.letterSpacing = 6
            let spaced = try ReaderPaginator.paginate(content: String(repeating: "fixed body text ", count: 100),
                chapterIndex: 0, settings: settings, pageBounds: bounds)
            emit("pagination_layout_letter_spacing_reflow", ["true"], [String(spaced.count > normal.count)])
            let page = try ReaderPaginator.paginate(content: "短页保持正文", chapterIndex: 0,
                chapterTitle: "实际标题", settings: settings, pageBounds: bounds)[0]
            let controller = PageContentViewController(isInteractive: true)
            controller.configure(pageData: page, settings: settings, bookName: "固定样本", totalChapters: 1)
            controller.loadViewIfNeeded()
            controller.view.frame = CGRect(origin: .zero, size: bounds)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            controller.contentTextView.layoutIfNeeded()
            emit("pagination_layout_text_container_insets", ["160"],
                [String(Int(controller.contentTextView.textContainer.size.width))])
            let layoutManager = controller.contentTextView.layoutManager
            layoutManager.ensureLayout(for: controller.contentTextView.textContainer)
            let used = layoutManager.usedRect(for: controller.contentTextView.textContainer)
            emit("pagination_layout_rendered_width", ["true"],
                [String(used.maxX <= 160.5 && used.minX >= -0.5)])
            settings.fontSize = 28
            controller.configure(pageData: page, settings: settings, bookName: "固定样本", totalChapters: 1)
            let refreshedFont = controller.contentTextView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            emit("pagination_layout_short_page_refresh", ["28", "true"],
                [String(Int(refreshedFont?.pointSize ?? 0)),
                 String(controller.contentTextView.attributedText.string == "短页保持正文")])
            settings.fontName = "System"
            settings.fontSize = 29.5
            settings.letterSpacing = 0
            let longPages = try ReaderPaginator.paginate(content: text, chapterIndex: 0,
                chapterTitle: "实际标题", settings: settings, pageBounds: bounds)
            var heightsFit = true
            var maximumOverflow: CGFloat = 0
            for current in longPages {
                controller.configure(pageData: current, settings: settings, bookName: "固定样本", totalChapters: 1)
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                controller.contentTextView.layoutIfNeeded()
                let manager = controller.contentTextView.layoutManager
                manager.ensureLayout(for: controller.contentTextView.textContainer)
                let height = manager.usedRect(for: controller.contentTextView.textContainer).height
                let overflow = height - controller.contentTextView.bounds.height
                maximumOverflow = max(maximumOverflow, overflow)
                heightsFit = heightsFit && overflow <= 1
            }
            emit("pagination_layout_all_rendered_pages_fit", ["true", "0"],
                [String(heightsFit), String(Int(ceil(maximumOverflow)))])
            emit("pagination_layout_setup", ["成功"], ["成功"])
        } catch {
            ReaderLayoutCalculator.invalidateLayoutCache()
            emit("pagination_layout_setup", ["成功"], [error.localizedDescription])
        }
    }
}
