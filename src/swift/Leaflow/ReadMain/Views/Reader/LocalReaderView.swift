// 原路径: ReadMain/Views/Reader/LocalReaderView.swift
// 证据:
//   - PGO: 155 个主函数（index/task_functions.csv T-304-03 / LocalReaderView.swift），
//     地址：_chapterSliderValue 初始化 0x100726030 L9 / readerColorScheme
//     0x10072610c L43-45 / body 0x1007273fc L51-53 / localReaderRoot
//     0x1007277e4 L55-152 / localReaderScene 0x10072798c L247-266 /
//     displayedPageInChapter 0x100727b48 L660-667 / searchSheet 0x1007280f4
//     L202-216
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/LocalReaderView.c
//   - 事实：本地书阅读根视图 —— body（root → scene）+ 章节滑条 + 搜索 sheet +
//     菜单覆盖层 + 朗读联动（readerColorScheme 随主题）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 根结构/场景切换: high（函数名确证）
//   - 深层布局（155 函数）: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 本地书阅读根视图。
struct LocalReaderView: View {

    var book: LocalBook

    @State private var viewModel: LocalReaderViewModel?
    @State private var adapter = ReaderViewModel()
    @Binding var settings: ReadingSettings
    @State private var chapterSliderValue: Double = 0
    @State private var isChapterSliderEditing = false
    @State private var showSearch = false
    @State private var showChapterList = false
    @State private var showSettings = false
    @State private var settingsInitialTab = 0
    @State private var menuVisible = false
    @State private var sliderValue: Double = 0
    @State private var sliderDraftValue: Double?
    @State private var isSliderChanging = false
    @State private var showTtsQuickSettings = false
    @State private var showTtsPlayer = false
    @State private var pendingTtsChapterList = false
    @State private var pendingTtsSettings = false
    @State private var ttsSleepTimer = TtsSleepTimer()
    @ObservedObject private var speechCoordinator = ReaderSpeechSupport.sharedCoordinator
    @Environment(\.colorScheme) private var systemColorScheme

    init(book: LocalBook, settings: Binding<ReadingSettings>) {
        self.book = book
        _settings = settings
    }

    /// 伪代码 0x10072610c（L43-45）：阅读配色（随主题）。
    private var readerColorScheme: ColorScheme {
        AppThemeManager.shared.effectiveColorScheme(
            for: systemColorScheme)
    }

    var body: some View {
        // 伪代码 0x1007273fc（L51-53）。
        localReaderRoot
            .preferredColorScheme(readerColorScheme)
    }

    /// 伪代码 0x1007277e4（L55-152）：根结构
    /// （内容 + 章节滑条 + 菜单 + sheet 组）。
    @ViewBuilder
    private var localReaderRoot: some View {
        GeometryReader { geometry in
            ZStack {
                if let viewModel {
                    localReaderScene(viewModel: viewModel, geometry: geometry)
                } else {
                    ProgressView()
                        .task {
                            let vm = LocalReaderViewModel(
                                book: book, settings: settings,
                                localBookService: LocalBookService.shared)
                            vm.updatePaginationBoundsIfNeeded(size: geometry.size)
                            viewModel = vm
                            ttsSleepTimer.bind(to: vm)
                            await vm.loadBook()
                        }
                }
                if menuVisible {
                    menuOverlay
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            searchSheet
        }
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(settings: $settings, onDismiss: { showSettings = false }, initialTab: settingsInitialTab)
        }
        .fullScreenCover(isPresented: $showTtsPlayer, onDismiss: {
            if pendingTtsChapterList { showChapterList = true }
            if pendingTtsSettings { settingsInitialTab = 3; showSettings = true }
            pendingTtsChapterList = false
            pendingTtsSettings = false
        }) {
            if let viewModel {
                TtsPlayerView(vm: viewModel, isPresented: $showTtsPlayer,
                    showChapterList: $pendingTtsChapterList, showSettings: $pendingTtsSettings, sleepTimer: ttsSleepTimer)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if menuVisible, let viewModel {
                VStack(spacing: 0) {
                if showTtsQuickSettings {
                    ReaderTtsQuickSettingsPanel(vm: viewModel, sleepTimer: ttsSleepTimer,
                        onOpenPlayer: { showTtsQuickSettings = false; showTtsPlayer = true },
                        onSettings: { showTtsQuickSettings = false; settingsInitialTab = 3; showSettings = true },
                        onStop: { showTtsQuickSettings = false }, coordinator: speechCoordinator,
                        preferences: viewModel.readAloudPreferences)
                }
                ReaderBottomToolbar(
                    settings: settings,
                    chapterTitle: book.name,
                    displayedPageInChapter:
                        viewModel.currentPageInChapter,
                    chapterPageCount:
                        max(1, viewModel.pages.filter {
                            $0.chapterIndex == viewModel.currentChapterIndex
                        }.count),
                    safeAreaBottom: 0,
                    isSpeaking: speechCoordinator.owns(viewModel) && speechCoordinator.isSpeaking,
                    isPreparing: speechCoordinator.owns(viewModel) && speechCoordinator.isPreparing,
                    isPaused: speechCoordinator.owns(viewModel) && speechCoordinator.isPaused,
                    isSettingsActive: showSettings,
                    sliderValue: $sliderValue,
                    sliderDraftValue: $sliderDraftValue,
                    isSliderChanging: $isSliderChanging,
                    onSliderCommit: { pageIndex in
                        Task {
                            await viewModel.jumpToChapter(
                                viewModel.currentChapterIndex,
                                coordinateReadAloud: false)
                            _ = pageIndex
                        }
                    },
                    onPrevChapter: {
                        Task {
                            await viewModel.jumpToChapter(
                                max(0, viewModel.currentChapterIndex - 1),
                                coordinateReadAloud: false)
                        }
                    },
                    onNextChapter: {
                        Task {
                            await viewModel.jumpToChapter(
                                min(max(0, viewModel.chapterContents.count - 1),
                                    viewModel.currentChapterIndex + 1),
                                coordinateReadAloud: false)
                        }
                    },
                    onChapterList: { showChapterList = true },
                    onToggleSpeech: { viewModel.toggleSpeech(); showTtsQuickSettings = true },
                    onStopSpeech: { viewModel.stopSpeech() },
                    onSearch: { showSearch = true },
                    onSettings: { settingsInitialTab = 0; showSettings = true })
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: menuVisible)
        .onDisappear { viewModel?.saveProgress() }
        .modifier(ReadingStatisticsLifecycleModifier(
            bookFingerprint: book.id.uuidString, bookName: book.name,
            pageIndex: viewModel?.currentPageIndex ?? 0, chapterIndex: viewModel?.currentChapterIndex ?? 0,
            charCount: viewModel?.currentPage?.charCount ?? 0,
            isReady: viewModel?.currentPage.map { !$0.isLoadingPlaceholder && !$0.isErrorPlaceholder } ?? false))
    }

    /// 伪代码 0x10072798c（L247-266）：阅读场景（PageContent 承载）。
    @ViewBuilder
    private func localReaderScene(
        viewModel: LocalReaderViewModel, geometry: GeometryProxy
    ) -> some View {
        // 桥接本地 VM → ReaderContentSurface 消费的 ReaderViewModel。
        syncAdapter(viewModel)
        return VStack(spacing: 0) {
            chapterSlider
            GeometryReader { contentGeometry in
                ReaderContentSurface(
                    viewModel: adapter,
                    settings: settings,
                    onRetry: { await viewModel.retryLoading() })
                    .task(id: contentGeometry.size) {
                        if viewModel.updatePaginationBoundsIfNeeded(size: contentGeometry.size) {
                            await viewModel.rebuildPages(resyncSpeech: true)
                        }
                    }
            }
        }
    }

    /// VM 适配（ReaderContentSurface 消费 ReaderViewModel 域）。
    /// T-1601-C0：此前每次 body 返回全新 ReaderViewModel（页面永远为空）；
    /// 改为常驻 adapter + 状态同步（@Observable 变更驱动 body 重算）。
    private func syncAdapter(_ vm: LocalReaderViewModel) {
        adapter.pages = vm.pages
        adapter.chapterPages = vm.pages
        adapter.chapterContents = vm.chapterContents
        adapter.currentChapterIndex = vm.currentChapterIndex
        adapter.currentPageIndex = vm.currentPageIndex
        adapter.bookName = book.name
        adapter.totalChapters = vm.chapterContents.count
        adapter.isLoadingPage = vm.isLoading
        adapter.hasError = vm.hasError
        adapter.menuVisible = menuVisible
        adapter.containerSize = vm.containerSize
        adapter.settings = settings
        adapter.pageCommitHandler = { [weak vm] commit in vm?.commitPageTurn(commit) }
    }

    /// 章节滑条（_chapterSliderValue 初始化确证）。
    private var chapterSlider: some View {
        Slider(
            value: $chapterSliderValue,
            in: 0...Double(max(1, (viewModel?.chapterContents.count ?? 1) - 1)),
            step: 1) { editing in
            isChapterSliderEditing = editing
            if !editing {
                let target = Int(chapterSliderValue)
                Task {
                    await viewModel?.jumpToChapter(target, coordinateReadAloud: false)
                }
            }
        }
        .padding(.horizontal)
        .disabled((viewModel?.chapterContents.count ?? 0) < 2)
        .accessibilityIdentifier("local-reader-chapter-slider")
        .accessibilityValue("第\(Int(chapterSliderValue) + 1)章")
        .onChange(of: viewModel?.currentChapterIndex, initial: true) { _, index in
            guard !isChapterSliderEditing, let index else { return }
            chapterSliderValue = Double(index)
        }
    }

    /// 伪代码 0x100727b48（L660-667）：本章内页序。
    private var displayedPageInChapter: Int {
        viewModel?.currentPageInChapter ?? 0
    }

    /// 菜单覆盖层（menuVisible 联动）。
    @ViewBuilder
    private var menuOverlay: some View {
        VStack {
            HStack {
                Button {
                    showChapterList = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                Spacer()
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat")
                }
                Spacer()
                Button {
                    showTtsQuickSettings.toggle()
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .accessibilityLabel("朗读")
                Spacer()
                Button {
                    menuVisible = false
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
            .padding()
            Spacer()
        }
        .background(.ultraThinMaterial.opacity(0.001))
    }

    /// 伪代码 0x1007280f4（L202-216）：搜索 sheet（AnyView 确证）。
    @ViewBuilder
    private var searchSheet: some View {
        LocalFullTextSearchView(
            chapterContentProvider: { index in
                viewModel?.chapterContents.indices.contains(index) == true
                    ? viewModel!.chapterContents[index] : ""
            },
            chapterCount: viewModel?.chapterContents.count ?? 0,
            onPickResult: { chapterIndex, _ in
                Task {
                    await viewModel?.jumpToChapter(chapterIndex, coordinateReadAloud: false)
                }
            })
    }

    /// 章节列表 sheet。
    @ViewBuilder
    private var chapterListSheet: some View {
        ReaderChapterListView(
            chapters: .constant(
                (viewModel?.chapterContents ?? []).indices.map { index in
                    ReaderChapterListChapter(index: index, title: viewModel?.ttsChapterName(at: index) ?? "")
                }),
            currentChapterIndex: .constant(viewModel?.currentChapterIndex ?? 0),
            onPickChapter: { index in
                Task {
                    guard let viewModel else { return }
                    showChapterList = false
                    _ = await viewModel.readAloudChangeChapter(by: index - viewModel.currentChapterIndex)
                    viewModel.readAloudCoordinator.seekToCurrentPage(owner: viewModel)
                    viewModel.saveProgress()
                }
            })
    }
}
