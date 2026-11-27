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
@MainActor
struct ReaderView: View {
    @State private var viewModel = ReaderViewModel()
    @Binding var settings: ReadingSettings
    var bookId: Int = 0
    var book: Book? = nil
    @State private var showBookmarks = false
    @State private var showReview = false
    var reviewRequest: LocalSourceParser.ReviewRequest? = nil

    @State private var showChapterList = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var settingsInitialTab = 0
    @State private var showCommentBrowser = false
    /// T-1601-C0：顶部“更多操作”面板（ReaderView.Body 类型树确证包含
    /// ReaderTopMoreActionsPanel；此前该面板零引用）。
    @State private var showTopMoreActions = false
    /// 底部工具栏/快捷面板状态（类型树 ReaderBottomToolbar 域）。
    @State private var sliderValue: Double = 0
    @State private var sliderDraftValue: Double?
    @State private var isSliderChanging = false
    @State private var showQuickSettings = false
    @State private var showTtsQuickSettings = false
    @State private var showTtsPlayer = false
    @State private var pendingTtsChapterList = false
    @State private var pendingTtsSettings = false
    @State private var ttsSleepTimer = TtsSleepTimer()
    @ObservedObject private var speechCoordinator = ReaderSpeechSupport.sharedCoordinator

    init(settings: Binding<ReadingSettings>, bookId: Int = 0, book: Book? = nil,
         viewModel: ReaderViewModel? = nil, reviewRequest: LocalSourceParser.ReviewRequest? = nil) {
        _settings = settings
        self.bookId = bookId
        self.book = book
        _viewModel = State(initialValue: viewModel ?? ReaderViewModel())
        self.reviewRequest = reviewRequest
    }

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
                .modifier(ReaderPresentationSheetsModifier(
                    showChapterList: $showChapterList,
                    showSearch: $showSearch,
                    showSettings: $showSettings,
                    settings: $settings,
                    settingsInitialTab: settingsInitialTab,
                    viewModel: viewModel))
        }
        .overlay(alignment: .top) {
            if showTopMoreActions {
                ReaderTopMoreActionsPanel(
                    title: viewModel.bookName.isEmpty
                        ? "更多操作" : viewModel.bookName,
                    subtitle: nil,
                    details: [],
                    actions: [
                        ReaderMoreActionItem(
                            id: "chapterList", title: "目录",
                            systemImage: "list.bullet") {
                            showChapterList = true
                        },
                        ReaderMoreActionItem(
                            id: "search", title: "搜索",
                            systemImage: "magnifyingglass") {
                            showSearch = true
                        },
                        ReaderMoreActionItem(
                            id: "review", title: "评论", systemImage: "text.bubble",
                            isEnabled: viewModel.currentBookSource != nil && viewModel.currentBook != nil) {
                            showReview = true
                        },
                        ReaderMoreActionItem(
                            id: "settings", title: "设置",
                            systemImage: "textformat") {
                            showSettings = true
                        },
                    ],
                    onHeaderTap: { showTopMoreActions = false },
                    onDismiss: { showTopMoreActions = false },
                    cover: { EmptyView() })
                    .accessibilityIdentifier("reader-more-actions")
                    .padding(.top, 8)
                    .transition(
                        .move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.menuVisible || showTopMoreActions {
                VStack(spacing: 0) {
                    if showTtsQuickSettings {
                        ReaderTtsQuickSettingsPanel(vm: viewModel, sleepTimer: ttsSleepTimer,
                            onOpenPlayer: { showTtsQuickSettings = false; showTtsPlayer = true },
                            onSettings: { showTtsQuickSettings = false; settingsInitialTab = 3; showSettings = true },
                            onStop: { showTtsQuickSettings = false }, coordinator: speechCoordinator,
                            preferences: viewModel.readAloudPreferences)
                    } else if showQuickSettings {
                        ReaderQuickSettingsPanel(
                            settings: settings,
                            onDisplay: {
                                showQuickSettings = false
                                showSettings = true
                            },
                            onSpacing: { showQuickSettings = true },
                            onSpeech: {
                                showQuickSettings = false
                                showTtsQuickSettings = true
                            },
                            onHighlight: {
                                showQuickSettings = false
                                showSettings = true
                            },
                            onBrowser: {
                                showQuickSettings = false
                                showSettings = true
                            },
                            onChapterTitle: {
                                showQuickSettings = false
                                showSettings = true
                            },
                            onMore: {
                                showQuickSettings = false
                                showTopMoreActions = true
                            })
                            .padding(.bottom, 4.0)
                    }
                    ReaderBottomToolbar(
                        settings: settings,
                        chapterTitle: viewModel.bookName,
                        displayedPageInChapter:
                            viewModel.currentPageInChapter,
                        chapterPageCount:
                            viewModel.currentChapterPageRange.count,
                        safeAreaBottom: 0,
                        isSpeaking: speechCoordinator.owns(viewModel) && speechCoordinator.isSpeaking,
                        isPreparing: speechCoordinator.owns(viewModel) && speechCoordinator.isPreparing,
                        isPaused: speechCoordinator.owns(viewModel) && speechCoordinator.isPaused,
                        isSettingsActive: showSettings,
                        sliderValue: $sliderValue,
                        sliderDraftValue: $sliderDraftValue,
                        isSliderChanging: $isSliderChanging,
                        onSliderCommit: { pageIndex in
                            viewModel.jumpToChapter(
                                viewModel.currentChapterIndex,
                                pageIndex: pageIndex)
                        },
                        onSliderDragging: { pageIndex in
                            viewModel.jumpToChapter(
                                viewModel.currentChapterIndex,
                                pageIndex: pageIndex)
                        },
                        onPrevChapter: {
                            viewModel.jumpToChapter(
                                max(0, viewModel.currentChapterIndex - 1),
                                pageIndex: nil)
                        },
                        onNextChapter: {
                            viewModel.jumpToChapter(
                                min(max(0, viewModel.totalChapters - 1),
                                    viewModel.currentChapterIndex + 1),
                                pageIndex: nil)
                        },
                        onChapterList: { showChapterList = true },
                        onToggleSpeech: { viewModel.toggleSpeech(); showTtsQuickSettings = true },
                        onStopSpeech: { viewModel.stopSpeech() },
                        onSearch: { showSearch = true },
                        onSettings: { settingsInitialTab = 0; showSettings = true })
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(
            .readerTopMoreActionDismiss, value: showTopMoreActions)
        .animation(
            .easeInOut(duration: 0.2), value: viewModel.menuVisible)
        .onAppear {
            ttsSleepTimer.bind(to: viewModel)
            Task {
                if let book { viewModel.configure(book: book, settings: settings) }
                await viewModel.loadBookWithProgress(
                    bookId, needRefresh: false, targetChapterIndex: nil, targetPageOffset: nil)
            }
        }
        .sheet(isPresented: $showBookmarks) {
            NavigationStack {
                BookmarkListView(bookUrl: viewModel.currentBook?.bookUrl ?? "",
                    onSelect: { bookmark in
                        showBookmarks = false
                        viewModel.jumpToChapter(bookmark.chapterIndex, pageIndex: nil)
                    })
            }
        }
        .fullScreenCover(isPresented: $showTtsPlayer, onDismiss: {
            if pendingTtsChapterList { showChapterList = true }
            if pendingTtsSettings { settingsInitialTab = 3; showSettings = true }
            pendingTtsChapterList = false
            pendingTtsSettings = false
        }) {
            TtsPlayerView(vm: viewModel, isPresented: $showTtsPlayer,
                showChapterList: $pendingTtsChapterList, showSettings: $pendingTtsSettings, sleepTimer: ttsSleepTimer)
        }
        .onDisappear { viewModel.saveProgress() }
        .modifier(ReadingStatisticsLifecycleModifier(
            bookFingerprint: viewModel.currentBook?.contentFingerprint, bookName: viewModel.bookName,
            pageIndex: viewModel.currentPageIndex, chapterIndex: viewModel.currentChapterIndex,
            charCount: viewModel.currentPage?.charCount ?? 0,
            isReady: viewModel.currentPage.map { !$0.isLoadingPlaceholder && !$0.isErrorPlaceholder } ?? false))
        .modifier(ReaderSelectionPresentationModifier(vm: viewModel))
        .modifier(ReaderReviewPresentationModifier(vm: viewModel, showReview: $showReview, request: reviewRequest))
    }

    /// readerToolbarContent（@ToolbarContentBuilder 显式域——
    /// toolbar(content:) 重载歧义消解，wave-16）。
    @ToolbarContentBuilder
    private func readerToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showBookmarks = true }) {
                Image(systemName: "bookmark")
            }
        }
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
        // T-1601-C0：顶部更多操作入口（ReaderTopMoreActionsPanel）。
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showTopMoreActions.toggle()
                Logger.log("阅读更多操作展开状态：\(showTopMoreActions)", level: .info)
            }) {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("更多操作")
            .accessibilityValue(showTopMoreActions ? "已展开" : "已收起")
        }
    }


    /// 伪代码 0x10084b8cc（L230-249）：任一呈现层可见判定。
    private var isAnyReaderPresentationVisible: Bool {
        showChapterList || showSearch || showSettings || showCommentBrowser || showReview
            || showTopMoreActions || showTtsPlayer || showTtsQuickSettings || viewModel.menuVisible
    }
}

/// 呈现层链修饰（原 readerPresentationSheets 方法域——some View 链上
/// 实例方法不可达，ViewModifier 化，wave-64）。
private struct ReaderPresentationSheetsModifier: ViewModifier {
    @Binding var showChapterList: Bool
    @Binding var showSearch: Bool
    @Binding var showSettings: Bool
    var settings: Binding<ReadingSettings>
    var settingsInitialTab: Int
    let viewModel: ReaderViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showChapterList) {
                ReaderChapterListView(
                    chapters: .constant(viewModel.chapters.enumerated().map {
                        ReaderChapterListChapter(index: $0.offset, title: $0.element.name)
                    }),
                    currentChapterIndex: .constant(viewModel.currentChapterIndex),
                    onPickChapter: { index in
                        showChapterList = false
                        Task { @MainActor in
                            _ = await viewModel.readAloudChangeChapter(by: index - viewModel.currentChapterIndex)
                            viewModel.readAloudCoordinator.seekToCurrentPage(owner: viewModel)
                            viewModel.saveProgress()
                        }
                    })
            }
            .sheet(isPresented: $showSearch) {
                FullTextSearchView(
                    chapters: .constant(viewModel.chapters.enumerated().map {
                        ReaderChapterListChapter(index: $0.offset, title: $0.element.name)
                    }),
                    chapterContentProvider: { index in
                        viewModel.chapterContents.indices.contains(index) ? viewModel.chapterContents[index] : ""
                    },
                    onPickResult: { index, _ in
                        showSearch = false
                        viewModel.jumpToChapter(index, pageIndex: nil)
                    })
            }
            .sheet(isPresented: $showSettings) {
                ReaderSettingsView(settings: settings, onDismiss: { showSettings = false }, initialTab: settingsInitialTab)
            }
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
                Logger.log("commentBrowser t=\(newValue)", level: .verbose)
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

