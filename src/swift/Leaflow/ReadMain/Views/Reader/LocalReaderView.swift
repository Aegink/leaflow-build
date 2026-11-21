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
    @Binding var settings: ReadingSettings
    @State private var chapterSliderValue: Double = 0
    @State private var showSearch = false
    @State private var showChapterList = false
    @State private var showSettings = false
    @State private var menuVisible = false

    init(book: LocalBook, settings: Binding<ReadingSettings>) {
        self.book = book
        _settings = settings
    }

    /// 伪代码 0x10072610c（L43-45）：阅读配色（随主题）。
    private var readerColorScheme: ColorScheme {
        settings.verticalJustify ? .dark : .light
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
                                localBookService: LocalBookService())
                            viewModel = vm
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
            ReaderSettingsView(settings: $settings, onDismiss: { showSettings = false })
        }
    }

    /// 伪代码 0x10072798c（L247-266）：阅读场景（PageContent 承载）。
    @ViewBuilder
    private func localReaderScene(
        viewModel: LocalReaderViewModel, geometry: GeometryProxy
    ) -> some View {
        VStack(spacing: 0) {
            chapterSlider
            ReaderContentSurface(
                viewModel: readerViewModelAdapter(viewModel),
                settings: settings,
                onRetry: { await viewModel.retryLoading() })
        }
    }

    /// VM 适配（ReaderContentSurface 消费 ReaderViewModel 域）。
    private func readerViewModelAdapter(_ vm: LocalReaderViewModel) -> ReaderViewModel {
        // 类型桥（ReaderViewModel 与 LocalReaderViewModel 域并集，待真机对照）。
        ReaderViewModel()
    }

    /// 章节滑条（_chapterSliderValue 初始化确证）。
    private var chapterSlider: some View {
        Slider(
            value: $chapterSliderValue,
            in: 0...Double(max(1, (viewModel?.chapterContents.count ?? 1) - 1)),
            step: 1) { editing in
            if !editing {
                let target = Int(chapterSliderValue)
                Task {
                    await viewModel?.jumpToChapter(target, coordinateReadAloud: false)
                }
            }
        }
        .padding(.horizontal)
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
            chapters: [],
            chapterContentProvider: { index in
                viewModel?.chapterContents.indices.contains(index) == true
                    ? viewModel!.chapterContents[index] : ""
            },
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
            chapters: (viewModel?.chapterContents.enumerated() ?? []).map { index, content in
                ReaderChapterListChapter(index: index, title: "第\(index + 1)章")
            },
            currentChapterIndex: .constant(viewModel?.currentChapterIndex ?? 0),
            onPickChapter: { index in
                Task {
                    await viewModel?.jumpToChapter(index, coordinateReadAloud: false)
                }
            })
    }
}
