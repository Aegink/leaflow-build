// 原路径: ReadMain/Views/Reader/ReaderView.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-10 / ReaderView.swift），
//     地址：CommentBrowserSheetPresentationModifier 0x100849cc0 L11-16（Logger.log +
//     "t=" 字面量确证）+ 0x100845f6c L18-24 / body 0x1008477c0 L107-218
//     （closure #2/#3/#4 0x100847a94-847d5c L122-125 / closure #10 0x10084a200
//     L193-195 / closure #11 Button 0x10084a894 L199-203 / closure #13 双 Bool
//     0x10084ac40 L206-211）/ isAnyReaderPresentationVisible 0x10084b8cc L230-249
//     （+closure #16/#17 0x100861438/0x10086145c L247-248）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderView.c（7256 行）
//   - 事实：body = ReaderContentSurface + 菜单层 + 章节列表/搜索/设置多层呈现 +
//     评论浏览 sheet（CommentBrowserSheetPresentationModifier）+ onChange 双 Bool；
//     isAnyReaderPresentationVisible —— 任一呈现层可见判定（closure #16/#17）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body 结构/呈现层: high（builder opaque 描述确证）
//   - 深层交互细节: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 阅读器根视图。
struct ReaderView: View {
    @State private var viewModel = ReaderViewModel()
    @Binding var settings: ReadingSettings
    var bookId: Int

    @State private var showChapterList = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var showCommentBrowser = false

    var body: some View {
        // 伪代码 0x1008477c0（L107-218）。
        Group {
            ReaderContentSurface(
                viewModel: viewModel,
                settings: settings,
                onRetry: {
                    await viewModel.loadBookWithProgress(
                        bookId, needRefresh: true, targetChapterIndex: nil, targetPageOffset: nil)
                })
                .ignoresSafeArea()
                .modifier(CommentBrowserSheetPresentationModifier(isVisible: showCommentBrowser))
                .toolbar(content: readerToolbarContent)
        }
        .onAppear {
            Task {
                await viewModel.loadBookWithProgress(
                    bookId, needRefresh: false, targetChapterIndex: nil, targetPageOffset: nil)
            }
        }
    }

    /// readerToolbarContent（@ToolbarContentBuilder 显式域——
    /// toolbar(content:) 重载歧义消解，wave-16）。
    @ToolbarContentBuilder
    private func readerToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showChapterList = true }) {
                Image(systemName: "list.bullet")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSearch = true }) {
                Image(systemName: "magnifyingglass")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSettings = true }) {
                Image(systemName: "textformat")
            }
        }
    }
        .sheet(isPresented: $showChapterList) {
            ReaderChapterListView(
                chapters: .constant([]),
                currentChapterIndex: .constant(viewModel.currentChapterIndex),
                onPickChapter: { index in
                    viewModel.activateCurrentVisiblePages([index], reason: "chapterPick")
                })
        }
        .sheet(isPresented: $showSearch) {
            FullTextSearchView(
                chapters: .constant([]),
                chapterContentProvider: { _ in "" },
                onPickResult: { _, _ in })
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(settings: $settings, onDismiss: { showSettings = false })
        }
    }

    /// 伪代码 0x10084b8cc（L230-249）：任一呈现层可见判定。
    private var isAnyReaderPresentationVisible: Bool {
        showChapterList || showSearch || showSettings || showCommentBrowser
            || viewModel.menuVisible
    }
}

/// 评论浏览呈现修饰（伪代码 0x100849cc0，L11-16："t=" 字面量确证）。
struct CommentBrowserSheetPresentationModifier: ViewModifier {
    var isVisible: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: .constant(isVisible)) {
                // 评论浏览面板（T-701 域承载）。
                Text("评论")
            }
            .onChange(of: isVisible) { _, newValue in
                Logger.log("commentBrowser t=\\(newValue)", level: .verbose)
            }
    }
}

extension View {

    /// 伪代码 0x10079c9cc（L1070-1092）：常规宽度档玻璃胶囊——size class
    /// 判定域 + GlassCardModifier 链（块体为计数器桩，按签名语义还原）。
    @ViewBuilder
    func ifAvailableRegularGlassCapsule() -> some View {
        if UITraitCollection.current.horizontalSizeClass == .regular {
            self.modifier(GlassCardModifier(style: .regular))
                .clipShape(Capsule())
        } else {
            self
        }
    }
}

