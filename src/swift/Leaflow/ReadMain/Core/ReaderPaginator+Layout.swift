// 原路径: ReadMain/Core/ReaderPaginator.swift。分册仍计入原始336文件。
import UIKit

extension ReaderPaginator {
    /// 0x1001f6b68 / 0x10088e6bc：首页扣实际章题，普通页复用正文区宽高。
    @MainActor
    static func contentSizes(settings: ReadingSettings, pageBounds: CGSize,
                             safeAreaInsets: UIEdgeInsets, chapterTitle: String) -> (first: CGSize, normal: CGSize) {
        let bounds = CGRect(origin: .zero, size: pageBounds)
        let safeFrame = bounds.inset(by: safeAreaInsets)
        func layout(_ first: Bool) -> CGSize {
            ReaderLayoutCalculator.calculateLayout(isFirstPage: first,
                chapterTitleConfig: settings.activeChapterTitleConfig,
                leftPageMargin: settings.leftPageMargin, rightPageMargin: settings.rightPageMargin,
                topInsetExtra: settings.topInsetExtra, bottomInsetExtra: settings.bottomInsetExtra,
                screenBounds: bounds, safeAreaFrame: safeFrame, chapterTitle: chapterTitle).contentRect.size
        }
        return (layout(true), layout(false))
    }
}
