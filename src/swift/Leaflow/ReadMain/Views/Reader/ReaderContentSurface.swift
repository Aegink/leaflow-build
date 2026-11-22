// 原路径: ReadMain/Views/Reader/ReaderContentSurface.swift
// 证据:
//   - PGO: 33 个主函数（index/task_functions.csv T-301-06 / ReaderContentSurface.swift），
//     核心地址：currentChapterPageRange 0x100795604 L26-28 / currentPageInChapter
//     0x1007958d4 L30-33 / body 0x100796218 L35-83（+GeometryReader onChange 闭包族
//     0x1007980dc-983d0 L52-81） / mainContent(isDoublePageActive:) 闭包族
//     0x100798778-98b00 L92-111 / 重试闭包 0x10079de64-79e2ac L98-109
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderContentSurface.c（2372 行）
//   - 关键调用：ReaderDoublePagePolicy.isEffective（body L35-83 确证）/
//     currentDevice.userInterfaceIdiom（确证）/
//     HorizontalAlignment.center/Edge.Set.all|vertical/Font.body|medium
//   - 事实：body = GeometryReader + 背景层(ReaderContentBackground) + mainContent +
//     ReaderLoadingIndicatorOverlay；onChange 闭包族：尺寸变化 ×2（CGSize, CGSize）+
//     状态双 Bool（L73-81）；错误态 = VStack(ReaderRetryButton + Button(cornerRadius))
//     + Image + Text（L92-111 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body 结构/onChange 闭包族: high（builder opaque 描述确证）
//   - 页区间计算: high
//   - 加载/错误态文案: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 阅读内容表面：背景 + 主内容 + 加载指示 + 错误重试。
struct ReaderContentSurface: View {
    var viewModel: ReaderViewModel
    var settings: ReadingSettings
    var onRetry: () async -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// 伪代码 0x100795604（L26-28）：本章页区间（start/end/count）。
    private var currentChapterPageRange: (start: Int, end: Int, count: Int) {
        let chapterIndex = viewModel.currentChapterIndex
        let pages = viewModel.pages.filter { $0.chapterIndex == chapterIndex }
        guard let first = pages.first?.pageIndex else { return (0, 0, 0) }
        let last = pages.last?.pageIndex ?? first
        return (first, last, pages.count)
    }

    /// 伪代码 0x1007958d4（L30-33）：本章内当前页。
    private var currentPageInChapter: Int {
        viewModel.currentPage?.pageIndex ?? 0
    }

    var body: some View {
        // 伪代码 0x100796218（L35-83）：GeometryReader + 双页判定。
        GeometryReader { geometry in
            ZStack {
                // 背景层（ReaderContentBackground，闭包 #1 确证）。
                ReaderContentBackground(settings: settings)
                    .ignoresSafeArea()

                mainContent(isDoublePageActive: ReaderDoublePagePolicy.isEffective(
                    settings: settings,
                    containerSize: geometry.size,
                    userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
                    horizontalSizeClass: nil))

                if viewModel.isLoadingPage {
                    ReaderLoadingIndicatorOverlay()
                }
            }
            .onChange(of: geometry.size, initial: true) { oldSize, newSize in
                // 闭包 #3（0x10079827c，L68-72）：尺寸变化回调。
                viewModel.containerSizeChanged(from: oldSize, to: newSize)
            }
            .onChange(of: viewModel.isLoadingPage, initial: false) { _, _ in
                // 闭包 #4（0x1007983d0，L73-81）：状态双 Bool 回调。
            }
        }
    }

    /// 主内容（mainContent(isDoublePageActive:)，闭包族 L92-111）。
    @ViewBuilder
    private func mainContent(isDoublePageActive: Bool) -> some View {
        if viewModel.hasError {
            // 错误态：VStack(ReaderRetryButton + 重试按钮)（L92-111 确证）。
            VStack(spacing: 16) {
                ReaderRetryButton {
                    Task { await onRetry() }
                }
                Button {
                    Task { await onRetry() }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("加载失败，点击重试")
                            .appThemeText(.body)
                    }
                }
                .cornerRadius(8, antialiased: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.all)
        } else if viewModel.pages.isEmpty {
            // T-1601-C0：空/加载页共享组件（ReaderEmptyView /
            // ReaderLoadingPageView 类型树 L11206-11214）。
            if viewModel.isLoadingPage {
                ReaderLoadingPageView(
                    textColor: .primary, message: "正在加载…")
            } else {
                ReaderEmptyView(textColor: .primary)
            }
        } else {
            // 正文承载（PageViewController 承载层；布局细节待真机对照）。
            PageViewController(
                pages: viewModel.pages,
                currentPageIndex: viewModel.currentPageIndex,
                settings: settings,
                bookName: viewModel.bookName,
                totalChapters: viewModel.totalChapters,
                speechHighlight: viewModel.speechHighlight,
                colorVersion: viewModel.colorVersion,
                isRebuildPending: viewModel.isRebuildPending,
                pageMode: settings.pageMode,
                isDoublePageActive: isDoublePageActive,
                menuVisible: viewModel.menuVisible,
                pageTurnCommand: viewModel.pendingPageTurnCommand,
                onTap: { viewModel.handleTap() },
                onSwipeUp: { viewModel.handleSwipeUp() },
                onSwipeUpDown: { viewModel.handleSwipeUpDown() },
                onSwipeUpProgress: { viewModel.handleSwipeUpProgress($0) },
                onSwipeUpCancel: { viewModel.handleSwipeUpCancel() },
                onPageCommitted: { viewModel.handlePageCommitted($0) },
                onCommentTap: { comment, pageIndex in
                    viewModel.handleCommentTap(comment, pageIndex: pageIndex)
                })
        }
    }
}

/// 内容背景（ReaderContentBackground，mangle 内私有类型确证）。
struct ReaderContentBackground: View {
    var settings: ReadingSettings

    var body: some View {
        Color(uiColor: settings.textUIColor)
    }
}

/// 加载指示覆盖层（ReaderLoadingIndicatorOverlay 确证）。
struct ReaderLoadingIndicatorOverlay: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 重试按钮（ReaderRetryButton 确证）。
struct ReaderRetryButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("重试", systemImage: "arrow.clockwise")
                .appThemeText(.body)
        }
        .buttonStyle(.borderedProminent)
    }
}
