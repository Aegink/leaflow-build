// T-1602：实际控制器嵌入、首次正文安装、背景与池刷新，不用自造文字视图代验。
import UIKit

enum ReaderRenderingSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) {
        let settings = ReadingSettings.load()
        settings.backgroundColorHex = ""
        settings.textColorHex = "000000"
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let defaultRGB = settings.readerBackgroundUIColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        emit("reader_background_default", ["true"], [String(defaultRGB
            && abs(red - 1) < 0.001 && abs(green - 1) < 0.001 && abs(blue - 1) < 0.001)])
        settings.backgroundColorHex = "112233"
        let customRGB = settings.readerBackgroundUIColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        emit("reader_background_custom", ["true"], [String(customRGB
            && abs(red - 17.0 / 255) < 0.001
            && abs(green - 34.0 / 255) < 0.001
            && abs(blue - 51.0 / 255) < 0.001)])
        settings.backgroundColorHex = "FFFFFF"
        do {
            let pages = try ReaderPaginator.paginate(content: "固定渲染正文", chapterIndex: 0,
                settings: settings, pageBounds: CGSize(width: 320, height: 480))
            guard var first = pages.first else { throw AppError.emptyContent }
            let pool = ReaderPageControllerPool(settings: settings, bookName: "固定渲染样本",
                totalChapters: 1, speechHighlight: .none, usesTransparentPageBackground: false)
            pool.update(pages: pages, settings: settings, bookName: "固定渲染样本",
                totalChapters: 1, speechHighlight: .none, onCommentTap: nil)
            let host = UIViewController()
            host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
            let renderer = ReaderTwoPageRenderer()
            renderer.install(in: host)
            renderer.install(in: host)
            guard let controller = pool.viewController(for: 0, isDoublePage: false) as? PageContentViewController
            else { throw AppError.emptyContent }
            renderer.setCurrentViewController(controller)
            controller.view.layoutIfNeeded()
            emit("reader_first_body_render", ["true", "true", "true"],
                [String(controller.parent === host),
                 String(controller.contentTextView.attributedText?.string.contains("固定渲染正文") == true),
                 String(controller.view.backgroundColor?.isEqual(settings.readerBackgroundUIColor) == true)])
            first.content = "更新后的正文"
            first.charCount = first.content.utf16.count
            pool.update(pages: [first], settings: settings, bookName: "固定渲染样本",
                totalChapters: 1, speechHighlight: .none, onCommentTap: nil)
            let refreshed = pool.viewController(for: 0, isDoublePage: false)
            emit("reader_pool_content_refresh", ["true", "true", "true"],
                [String(refreshed === controller), String(controller.contentTextView.attributedText.string == first.content),
                 String(pool.viewController(for: -1, isDoublePage: false) == nil
                    && pool.viewController(for: 1, isDoublePage: false) == nil)])
            let incoming = UIViewController()
            let transition = PageTurnTransition(from: PageTurnPageID(chapterIndex: 0, pageIndex: 0),
                to: PageTurnPageID(chapterIndex: 0, pageIndex: 1), direction: .next)
            renderer.prepare(transition: transition, incoming: incoming)
            renderer.render(progress: 0.5)
            _ = renderer.finishSettlement(committed: false)
            let cancelled = renderer.currentViewController === controller && incoming.parent == nil
            renderer.prepare(transition: transition, incoming: incoming)
            _ = renderer.finishSettlement(committed: true)
            let committed = renderer.currentViewController === incoming && controller.parent == nil
            renderer.clear()
            emit("reader_renderer_lifecycle", ["true", "true", "0"],
                [String(cancelled), String(committed), String(host.children.count)])
            emit("reader_render_setup", ["成功"], ["成功"])
        } catch {
            emit("reader_render_setup", ["成功"], [error.localizedDescription])
        }
    }
}
