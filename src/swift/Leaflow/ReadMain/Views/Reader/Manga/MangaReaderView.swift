// 原路径: ReadMain/Views/Reader/Manga/MangaReaderView.swift
// 证据:
//   - PGO: 93 个主函数（index/task_functions.csv T-304-04 / MangaReaderView.swift），
//     地址：init(book:) 0x100616df8 L22-24 / body 0x100617658 L26-28 /
//     mangaRoot 0x100617738 L30-52 / resetMenuOverlayTransientState 0x100617818
//     L190-197 / loadingStatusOverlay 0x10061857c L77-98 / readerContent
//     0x100618650 L110-135 / menuOverlay 0x10062bc84 L179-188 / handleDismiss
//     0x10061ce94 L493-500 / topMoreDetails 0x10061d94c L308-343 /
//     topMoreActions 0x10061dd84 L345-402 / showsTopMenuCover 0x10062a040
//     L404-409 / topBar 0x10061a8fc L199-283 / loadingView 0x10072e554
//     L139-148 / MangaReaderSystemChromeModifier.body 0x10062266c L507-518 /
//     MangaReaderLoadLifecycleModifier.body 0x1006226c4 L528-538 /
//     beginReadingSession 0x1006229a4 L540-546 / handleMenuChange L553-557 /
//     MangaReaderPresentationsModifier.body 0x10062f798 L570-593 /
//     isRemoteMode 0x10062384c L595-597 / MangaReaderAppLifecycleModifier.body
//     0x100624080 L609-623 / MangaChapterListSheet.body 0x10062458c L630-641 /
//     refreshChapterList 0x1006247dc L643-645 / MangaChangeSourceSheet.body
//     0x100624aa4 L652-655 / MangaBookDetailSheet.body 0x1006169d4 L670-677
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/MangaReaderView.c
//   - 事实：漫画阅读根视图 —— body（root → chrome 修饰器 → sheet 组）+
//     分页/webtoon 双模式 + 菜单覆盖 + 章节列表/换源/详情 sheet
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 根结构/修饰器/sheet 组: high（函数名确证）
//   - 深层布局（93 函数）: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 漫画阅读根视图。
struct MangaReaderView: View {

    var book: Book

    @State private var viewModel: MangaReaderViewModel?
    @State private var showChapterList = false
    @State private var showChangeSource = false
    @State private var showBookDetail = false
    @State private var menuVisible = false

    /// 伪代码 0x100616df8（L22-24）。
    init(book: Book) {
        self.book = book
    }

    var body: some View {
        // 伪代码 0x100617658（L26-28）。
        Group {
            if let viewModel {
                mangaRoot(viewModel: viewModel)
                    .modifier(MangaReaderSystemChromeModifier(menuVisible: menuVisible))
                    .modifier(MangaReaderLoadLifecycleModifier(
                        isLoading: viewModel.isLoading, menuVisible: menuVisible,
                        viewModel: viewModel))
                    .modifier(MangaReaderPresentationsModifier(
                        showChapterList: $showChapterList,
                        showChangeSource: $showChangeSource,
                        showBookDetail: $showBookDetail,
                        viewModel: viewModel))
                    .modifier(MangaReaderAppLifecycleModifier(viewModel: viewModel))
            } else {
                loadingView
            }
        }
        .task {
            let vm = MangaReaderViewModel(
                book: book, bookService: BookService(),
                sourceService: SourceService())
            viewModel = vm
            await vm.initialLoad()
        }
    }

    /// 伪代码 0x100617738（L30-52）：根结构。
    @ViewBuilder
    private func mangaRoot(viewModel: MangaReaderViewModel) -> some View {
        GeometryReader { geometry in
            ZStack {
                readerContent(viewModel: viewModel)
                if viewModel.isLoading {
                    loadingStatusOverlay(safeAreaTop: geometry.safeAreaInsets.top)
                }
                if menuVisible {
                    menuOverlay(geometry: geometry)
                }
            }
        }
    }

    /// 伪代码 0x100618650（L110-135）：内容区
    ///（分页/webtoon 双模式，MangaPagedView/MangaReaderView 确证）。
    @ViewBuilder
    private func readerContent(viewModel: MangaReaderViewModel) -> some View {
        if viewModel.isWebtoonMode {
            // webtoon 竖排模式（滚动列表）。
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.chapterImageURLs[viewModel.currentChapterIndex] ?? [], id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                ProgressView().frame(height: 300)
                            }
                        }
                    }
                }
            }
        } else {
            MangaPagedView(
                pages: mangaPages(viewModel),
                startIndex: 0,
                onCenterTap: { menuVisible.toggle() },
                onPageChange: { index in
                    viewModel.preloadCurrentChapterImages(around: index)
                })
        }
    }

    /// MangaPage 域装配（extractImageURLs 消费确证）。
    private func mangaPages(_ viewModel: MangaReaderViewModel) -> [MangaPage] {
        (viewModel.chapterImageURLs[viewModel.currentChapterIndex] ?? [])
            .enumerated()
            .map { offset, url in
                MangaPage(
                    chapterIndex: viewModel.currentChapterIndex,
                    pageIndex: offset, imageURL: url,
                    imageRequestContext: nil,
                    chapterTitle: viewModel.chapters.indices.contains(viewModel.currentChapterIndex)
                        ? viewModel.chapters[viewModel.currentChapterIndex].title : "",
                    content: "")
            }
    }

    /// 伪代码 0x10072e554（L139-148）：加载视图。
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中")
                .font(.caption)
        }
    }

    /// 伪代码 0x10061857c（L77-98）：加载状态覆盖。
    @ViewBuilder
    private func loadingStatusOverlay(safeAreaTop: CGFloat) -> some View {
        VStack {
            Text("加载中…")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, safeAreaTop + 8)
            Spacer()
        }
    }

    /// 伪代码 0x10062bc84（L179-188）：菜单覆盖层。
    @ViewBuilder
    private func menuOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            topBar(safeAreaTop: geometry.safeAreaInsets.top)
            Spacer()
        }
    }

    /// 伪代码 0x10061a8fc（L199-283）：顶部栏。
    @ViewBuilder
    private func topBar(safeAreaTop: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    handleDismiss()
                } label: {
                    Image(systemName: "chevron.down")
                }
                Text(book.name)
                    .appThemeText(.headline)
                Spacer()
            }
            ForEach(topMoreDetails, id: \.self) { detail in
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                ForEach(topMoreActions, id: \.title) { action in
                    Button {
                        action.run()
                    } label: {
                        Label(action.title, systemImage: action.icon)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.top, safeAreaTop)
        .padding()
        .background(.ultraThinMaterial)
    }

    /// 伪代码 0x10061d94c（L308-343）：详情项。
    private var topMoreDetails: [String] {
        [
            "第 \(viewModel?.currentChapterIndex ?? 0) 章",
            "共 \(viewModel?.chapters.count ?? 0) 章",
        ]
    }

    /// 伪代码 0x10061dd84（L345-402）：动作项（title/icon/run 三元组）。
    private var topMoreActions: [(title: String, icon: String, run: () -> Void)] {
        [
            ("章节列表", "list.bullet", { showChapterList = true }),
            ("换源", "arrow.triangle.2.circlepath", { showChangeSource = true }),
            ("详情", "info.circle", { showBookDetail = true }),
            ("加入书架", "plus.square.on.square", { viewModel?.addBookToBookshelf() }),
        ]
    }

    /// 伪代码 0x10062a040（L404-409）：顶部菜单覆盖判定。
    private var showsTopMenuCover: Bool {
        menuVisible
    }

    /// 伪代码 0x10061ce94（L493-500）：退出。
    private func handleDismiss() {
        menuVisible = false
    }

    /// 伪代码 0x100617818（L190-197）：菜单瞬时态复位。
    private func resetMenuOverlayTransientState() {
        menuVisible = false
    }
}

// MARK: - 修饰器

/// 系统状态栏修饰（0x10062266c，L507-518 确证）。
struct MangaReaderSystemChromeModifier: ViewModifier {

    var menuVisible: Bool

    func body(content: Content) -> some View {
        content.statusBarHidden(!menuVisible)
    }
}

/// 加载生命周期修饰（0x1006226c4，L528-538 + beginReadingSession 0x1006229a4
/// L540-546 + handleMenuChange L553-557 确证）。
struct MangaReaderLoadLifecycleModifier: ViewModifier {

    var isLoading: Bool
    var menuVisible: Bool
    var viewModel: MangaReaderViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: menuVisible, initial: false) { _, visible in
                handleMenuChange(visible)
            }
            .onAppear {
                beginReadingSession()
            }
    }

    private func beginReadingSession() {
        viewModel.saveProgress()
    }

    private func handleMenuChange(_ visible: Bool) {
        if !visible {
            resetMenuOverlayTransientState(viewModel)
        }
    }

    private func resetMenuOverlayTransientState(_ viewModel: MangaReaderViewModel) {
        viewModel.saveProgress()
    }
}

/// 呈现组修饰（0x10062f798，L570-593 + isRemoteMode 0x10062384c，L595-597 确证）。
struct MangaReaderPresentationsModifier: ViewModifier {

    @Binding var showChapterList: Bool
    @Binding var showChangeSource: Bool
    @Binding var showBookDetail: Bool
    var viewModel: MangaReaderViewModel

    private var isRemoteMode: Bool {
        true
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showChapterList) {
                MangaChapterListSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showChangeSource) {
                MangaChangeSourceSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showBookDetail) {
                MangaBookDetailSheet(viewModel: viewModel)
            }
    }
}

/// 应用生命周期修饰（0x100624080，L609-623 确证）。
struct MangaReaderAppLifecycleModifier: ViewModifier {

    var viewModel: MangaReaderViewModel

    func body(content: Content) -> some View {
        content.onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willTerminateNotification)) { _ in
            viewModel.saveProgress()
        }
    }
}

// MARK: - Sheet

/// 章节列表 sheet（0x10062458c，L630-641 + refreshChapterList 0x1006247dc 确证）。
struct MangaChapterListSheet: View {

    var viewModel: MangaReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.chapters) { chapter in
                Button {
                    Task {
                        await viewModel.jumpToChapter(viewModel.chapters.firstIndex(where: { $0.id == chapter.id }) ?? 0)
                    }
                    dismiss()
                } label: {
                    Text(chapter.title)
                        .appThemeText(.body)
                }
            }
            .navigationTitle("章节")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        Task { await viewModel.refreshChapterList() }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// 换源 sheet（0x100624aa4，L652-655 确证）。
struct MangaChangeSourceSheet: View {

    var viewModel: MangaReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView("换源", systemImage: "arrow.triangle.2.circlepath")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { dismiss() }
                    }
                }
        }
    }
}

/// 详情 sheet（0x1006169d4，L670-677 确证）。
struct MangaBookDetailSheet: View {

    var viewModel: MangaReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("书籍") {
                    Text(viewModel.book.name)
                    Text(viewModel.book.author ?? "-")
                }
                Section {
                    Button("加入书架") {
                        viewModel.addBookToBookshelf()
                    }
                }
            }
            .navigationTitle("详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
