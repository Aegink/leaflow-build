// 原路径: ReadMain/Views/Reader/ReaderPageControllerPool.swift
// 证据:
//   - PGO: 16 个主函数（index/task_functions.csv T-301-07 / ReaderPageControllerPool.swift），
//     地址：init 0x1007be290 L26-32 / update 0x1007bce00 L41-50（+closure 0x1007bcb2c L48）/
//     prepare 0x1007bd5f8 L63-74 / refresh 0x1007bd2f0 L80-94 / hasSameRenderableState
//     0x1007bd074 L100-115 / activeSelectionHandler 0x1007bd670 L117-122 / clear
//     0x1007bd024 L130-137 / detach 0x1007bdeb8 L139-147 / pageController 0x1007bdae4
//     L149-172 / spreadController 0x1007bd7b0 L174-203 / configure 0x1007be7b4 L209-226 /
//     displayStartIndex 0x1007bdf4c L248-251 / trimPagesIfNeeded 0x1007beb34 L263-269
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderPageControllerPool.c（1463 行）
//   - 事实：池管理 PageContentViewController/ReaderSpreadContentViewController 双池；
//     update 全量刷新 + closure 逐 VC 回调；hasSameRenderableState 经
//     PageData.commentRenderSignature（确证）；trimPagesIfNeeded 容量裁剪；
//     detach removeFromSuperview + removeFromParent（确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（池语义确证；容量常量待真机对照）
// 还原: 2026-11-19

import UIKit

/// 页面控制器池：单页/双页双池 + 渲染态校验 + 容量裁剪。
@MainActor
final class ReaderPageControllerPool {
    private var settings: ReadingSettings
    private var bookName: String
    private var totalChapters: Int
    private var speechHighlight: ReaderSpeechHighlight
    private let usesTransparentPageBackground: Bool

    private var pages: [PageData] = []
    private var singlePool: [Int: PageContentViewController] = [:]
    private var singleOrder: [Int] = []
    private var spreadPool: [Int: ReaderSpreadContentViewController] = [:]
    private var spreadOrder: [Int] = []
    private let maxPoolSize = 7

    init(
        settings: ReadingSettings,
        bookName: String,
        totalChapters: Int,
        speechHighlight: ReaderSpeechHighlight,
        usesTransparentPageBackground: Bool
    ) {
        self.settings = settings
        self.bookName = bookName
        self.totalChapters = totalChapters
        self.speechHighlight = speechHighlight
        self.usesTransparentPageBackground = usesTransparentPageBackground
    }

    /// 伪代码 0x1007bce00（L41-50）+ closure（0x1007bcb2c，L48）：
    /// 全量替换页集 + 逐 VC 刷新回调。
    func update(
        pages newPages: [PageData],
        settings newSettings: ReadingSettings,
        bookName newBookName: String,
        totalChapters newTotalChapters: Int,
        speechHighlight newSpeechHighlight: ReaderSpeechHighlight,
        onCommentTap: ((ParagraphComment, Int) -> Void)?
    ) {
        pages = newPages
        settings = newSettings
        bookName = newBookName
        totalChapters = newTotalChapters
        speechHighlight = newSpeechHighlight
        for (index, controller) in singlePool {
            if index < newPages.count {
                configure(controller, for: index, onCommentTap: onCommentTap)
            }
        }
    }

    /// 伪代码 0x1007bd5f8（L63-74）：预取指定页。
    func prepare(index: Int, isDoublePage: Bool, bounds: CGRect) {
        _ = bounds
        if isDoublePage {
            _ = spreadController(for: index)
        } else {
            _ = pageController(for: index)
        }
    }

    /// 伪代码 0x1007bd2f0（L80-94）：刷新显示 VC。
    func refresh(_ viewController: UIViewController, for index: Int, isDoublePage: Bool) {
        guard index < pages.count else { return }
        let page = pages[index]
        if let content = viewController as? PageContentViewController {
            content.configure(
                pageData: page,
                settings: settings,
                bookName: bookName,
                totalChapters: totalChapters)
        } else if let spread = viewController as? ReaderSpreadContentViewController {
            spread.refresh(
                pages: visiblePair(for: index),
                settings: settings,
                bookName: bookName,
                totalChapters: totalChapters)
            _ = spread
        }
    }

    /// 可见页对（双页配对）。
    private func visiblePair(for index: Int) -> [PageData] {
        let start = ReaderDoublePagePolicy.spreadStartIndex(for: index, pageCount: pages.count)
        var pair = [pages[start]]
        if start + 1 < pages.count {
            pair.append(pages[start + 1])
        }
        return pair
    }

    /// 伪代码 0x1007bd074（L100-115）：渲染态一致性
    ///（PageData.commentRenderSignature 确证）。
    func hasSameRenderableState(_ viewController: UIViewController, as page: PageData) -> Bool {
        guard let content = viewController as? PageContentViewController,
              let current = content.pageData else { return false }
        return current.hasSameRenderableState(as: page)
            && PageData.commentRenderSignature(current.comments)
                == PageData.commentRenderSignature(page.comments)
    }

    /// 伪代码 0x1007bd670（L117-122）：VC 内活动选择处理器。
    func activeSelectionHandler(in viewController: UIViewController?) -> ReaderTextSelectionHandling? {
        (viewController as? PageContentViewController)?.contentSelectionHandler
    }

    /// 伪代码 0x1007bd024（L130-137）：清空双池。
    func clear() {
        for (_, controller) in singlePool { detach(controller) }
        for (_, controller) in spreadPool { detach(controller) }
        singlePool.removeAll()
        singleOrder.removeAll()
        spreadPool.removeAll()
        spreadOrder.removeAll()
    }

    /// 伪代码 0x1007bdeb8（L139-147）：脱离父级（确证）。
    private func detach(_ viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }

    /// 伪代码 0x1007bdae4（L149-172）：取/建单页 VC。
    private func pageController(for index: Int) -> PageContentViewController {
        if let cached = singlePool[index] {
            return cached
        }
        let controller = PageContentViewController(isInteractive: true)
        controller.configure(
            pageData: pages[index],
            settings: settings,
            bookName: bookName,
            totalChapters: totalChapters)
        singlePool[index] = controller
        singleOrder.append(index)
        trimPagesIfNeeded()
        return controller
    }

    /// 伪代码 0x1007bd7b0（L174-203）：取/建双页 VC。
    private func spreadController(for index: Int) -> ReaderSpreadContentViewController {
        if let cached = spreadPool[index] {
            return cached
        }
        let controller = ReaderSpreadContentViewController()
        controller.refresh(
            pages: visiblePair(for: index),
            settings: settings,
            bookName: bookName,
            totalChapters: totalChapters)
        spreadPool[index] = controller
        spreadOrder.append(index)
        trimPagesIfNeeded()
        return controller
    }

    /// 伪代码 0x1007be7b4（L209-226）：装配 VC（@MainActor 确证）。
    private func configure(
        _ controller: PageContentViewController,
        for index: Int,
        onCommentTap: ((ParagraphComment, Int) -> Void)?
    ) {
        guard index < pages.count else { return }
        controller.onCommentTap = { comment in onCommentTap?(comment, index) }
        controller.configure(
            pageData: pages[index],
            settings: settings,
            bookName: bookName,
            totalChapters: totalChapters)
    }

    /// 伪代码 0x1007bdf4c（L248-251）：显示起始索引。
    private var displayStartIndex: Int {
        ReaderDoublePagePolicy.spreadStartIndex(for: 0, pageCount: pages.count)
    }

    /// 伪代码 0x1007beb34（L263-269）：容量裁剪。
    private func trimPagesIfNeeded() {
        while singleOrder.count > maxPoolSize {
            let evicted = singleOrder.removeFirst()
            if let controller = singlePool.removeValue(forKey: evicted) {
                detach(controller)
            }
        }
        while spreadOrder.count > maxPoolSize {
            let evicted = spreadOrder.removeFirst()
            if let controller = spreadPool.removeValue(forKey: evicted) {
                detach(controller)
            }
        }
    }
}
