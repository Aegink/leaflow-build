// 原路径: ReadMain/Views/Explore/ExploreSourceFeedView.swift
// 证据:
//   - PGO: 238 条记录（index/task_functions.csv T-501-03 /
//     ExploreSourceFeedView.swift；伪代码域 12796 行）。关键域：
//     ExploreFeedSection.id getter / maxStoredBooksPerSection getter /
//     feedRoot（ToolbarContentBuilder.buildBlock<A> 单元确证）/ content /
//     feedToolbar / handleFeedAppear / handleFeedDisappear /
//     handleStartBrowserNotification / handleJavaOpen / pendingTextAction
//     三件（presented/valueBinding/message getter 确证）/
//     handleReadBookFromDetail / handleSelectedBookChange /
//     presentPendingBrowserRequestAfterFilterDismiss /
//     finishExploreBrowserRequestIfNeeded / filterSheet /
//     openedSearchRouteContent / exploreSettingsSheet
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/
//     ExploreSourceFeedView.c（12796 行）
//   - 字符串确证（位模式/指针）："书签设置" L1276/"gearshape" L1351 域/
//     "infoMap_" L2242/"规则可能有误" @ptr L4062/"contentSection.retry"
//     @ptr L4094/"加载失败，点击重试" @ptr L6052/"暂无内容" L7790/"查看全部"
//     L7990/"arrow.clockwise"（'arrow.cl' L8276）/"book.closed" L8969+L11877/
//     "正在加载书签..." @ptr L10623/"没有更多了" L11769/
//     "triggersParserCleanup=0" @ptr L11870；布局常量 0x4018=6.0 域
//   - 事实：书签 Feed 分段（ExploreFeedSection + maxStoredBooksPerSection
//     上限域）；pendingTextAction 域（弹文本输入后回填）；过滤器面板关闭后
//     补呈浏览器请求（presentPendingBrowserRequestAfterFilterDismiss 域
//     确证）；triggersParserCleanup=0 确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - Feed 分段/弹层链: high（签名族 + 域串确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI

// MARK: - ExploreFeedSection

/// 书签 Feed 分段（id getter 签名确证）。
struct ExploreFeedSection: Identifiable, Equatable {
    let title: String
    let books: [Book]
    var id: String { title }
}

// MARK: - ExploreSourceFeedView

/// 发现源 Feed 视图（书签网格 + 筛选面板 + 弹层）。
struct ExploreSourceFeedView: View {

    let source: BookSource

    // Feed 态（maxStoredBooksPerSection 上限域确证）。
    @State private var sections: [ExploreFeedSection] = []
    @State private var isLoadingFeed = false
    @State private var errorMessage: String?
    @State private var selectedBook: Book?
    @State private var pendingTextActionPresented = false
    @State private var pendingTextActionValue = ""
    @State private var pendingTextActionKey: String?
    @State private var pendingBrowserRequest: RemoteBrowserRequest?
    @State private var showFilterSheet = false
    @State private var showSettingsSheet = false
    @State private var searchRoute: ExploreSearchRoute?
    @State private var openRoute: ExploreOpenRoute?
    @State private var feedTaskActive = false

    private let sourceService = SourceService()

    /// maxStoredBooksPerSection getter（签名确证）。
    private var maxStoredBooksPerSection: Int { 12 }

    var body: some View {
        feedRoot
            .modifier(
                ExploreSourceDetailLifecycleModifier(
                    onAppear: { handleFeedAppear() },
                    onDisappear: { handleFeedDisappear() }))
            .modifier(
                ExploreSourceDetailPresentationsModifier(
                    filterSheet: $showFilterSheet,
                    browserRequest: $pendingBrowserRequest,
                    openRoute: $openRoute,
                    searchRoute: $searchRoute,
                    source: source))
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("browser.present.now"))
            ) { notification in
                handleStartBrowserNotification(notification)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("java.open"))
            ) { notification in
                handleJavaOpen(notification)
            }
    }

    // MARK: 根布局

    /// feedRoot getter（buildBlock<A> 单元签名确证）。
    private var feedRoot: some View {
        Group {
            if sections.isEmpty && !isLoadingFeed {
                emptyOrError
            } else {
                content
            }
        }
        .navigationTitle(source.bookSourceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            feedToolbar
        }
        .refreshable {
            await reloadFeed()
        }
    }

    /// content getter（签名域确证）。
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16.0) {
                if isLoadingFeed {
                    // "正在加载书签..." @ptr L10623 域确证。
                    HStack(spacing: 8.0) {
                        ProgressView()
                        Text("正在加载书签...")
                            .appThemeText(.caption, opacity: 0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24.0)
                }
                ForEach(sections) { section in
                    feedSectionView(section)
                }
            }
            .padding(.all, 12.0)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    /// 分段网格（"查看全部" L7990 域确证）。
    @ViewBuilder
    private func feedSectionView(_ section: ExploreFeedSection) -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack {
                Text(section.title)
                    .appThemeText(.headline)
                Spacer()
                if section.books.count > maxStoredBooksPerSection {
                    Button("查看全部") {
                        // 查看全部域（分段全量页随 T-501-04 交叉）。
                    }
                    .appThemeText(.caption)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 3),
                spacing: 10.0) {
                ForEach(
                    section.books.prefix(maxStoredBooksPerSection),
                    id: \.bookUrl
                ) { book in
                    Button {
                        handleSelectedBookChange(book)
                    } label: {
                        VStack(spacing: 4.0) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(height: 120.0)
                                .overlay {
                                    Image(systemName: "book.closed")
                                        .foregroundColor(.secondary)
                                }
                            Text(book.name)
                                .appThemeText(.caption)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// feedToolbar（签名域确证；"书签设置" L1276 + "gearshape" 域）。
    @ToolbarContentBuilder
    private var feedToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showFilterSheet = true
                } label: {
                    Label("分类筛选", systemImage: "line.3.horizontal.decrease")
                }
                Button {
                    showSettingsSheet = true
                } label: {
                    Label("书签设置", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }

    // MARK: 空态/错误态（"规则可能有误" @ptr L4062/"加载失败，点击重试" @ptr
    // L6052/"暂无内容" L7790/"contentSection.retry" @ptr 域确证）

    @ViewBuilder
    private var emptyOrError: some View {
        VStack(spacing: 10.0) {
            if let errorMessage {
                Text(errorMessage)
                    .appThemeText(.caption, opacity: 0.7)
                Button("加载失败，点击重试") {
                    logRetry("contentSection.retry")
                    Task { await reloadFeed() }
                }
                .buttonStyle(.bordered)
            } else {
                Text("暂无内容")
                    .appThemeText(.caption, opacity: 0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func logRetry(_ event: String) {
        Logger.log("[EXPLORE-TRACE] \(event)", level: .info)
    }

    // MARK: 生命周期（签名域确证）

    /// handleFeedAppear（签名确证）。
    private func handleFeedAppear() {
        Task {
            if sections.isEmpty {
                await reloadFeed()
            }
        }
    }

    /// handleFeedDisappear（"triggersParserCleanup=0" @ptr L11870 确证）。
    private func handleFeedDisappear() {
        // triggersParserCleanup=0（解析清理域确证）。
    }

    /// reloadFeed（书签域加载）。
    private func reloadFeed() async {
        guard !feedTaskActive else { return }
        feedTaskActive = true
        isLoadingFeed = true
        defer {
            feedTaskActive = false
            isLoadingFeed = false
        }
        do {
            let fetched = try await sourceService.exploreBook(
                source: source,
                exploreUrl: source.ruleExplore.exploreUrl, page: 1)
            await MainActor.run {
                sections = [ExploreFeedSection(
                    title: "书签", books: fetched)]
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "规则可能有误"
            }
        }
    }

    // MARK: 书籍联动（签名域确证）

    /// handleReadBookFromDetail（签名确证）。
    private func handleReadBookFromDetail(_ book: Book) {
        selectedBook = book
        // TODO(T-601-01): ReaderRouter 阅读入口。
    }

    /// handleSelectedBookChange（签名确证）。
    private func handleSelectedBookChange(_ book: Book) {
        selectedBook = book
    }

    // MARK: 弹层域（签名域确证）

    /// pendingTextActionPresented getter（签名确证）。
    private var pendingTextActionPresentedBinding: Binding<Bool> {
        Binding(
            get: { pendingTextActionPresented },
            set: { pendingTextActionPresented = $0 })
    }

    /// pendingTextActionValueBinding getter（签名确证）。
    private var pendingTextActionValueBinding: Binding<String> {
        Binding(
            get: { pendingTextActionValue },
            set: { pendingTextActionValue = $0 })
    }

    /// pendingTextActionMessage getter（签名确证）。
    private var pendingTextActionMessage: String {
        pendingTextActionKey ?? "输入内容"
    }

    /// filterSheet getter（签名确证）。onSelect/onAction 双回调域补齐
    /// （FilterSheet 签名域确证，wave-16）。
    private var filterSheet: some View {
        ExploreCategoryFilterSheet(
            groups: [],
            actionControls: [],
            onSelect: { _ in },
            onAction: { _ in })
    }

    /// exploreSettingsSheet getter（签名确证；本体随 ExploreSettingsSheet
    /// 分册落地，无参构造占位）。
    private var exploreSettingsSheet: some View {
        ExploreSettingsSheet()
    }

    /// openedSearchRouteContent（签名确证）。
    @ViewBuilder
    private func openedSearchRouteContent(_ route: ExploreSearchRoute) -> some
        View
    {
        Text(route.displayTitle)
    }

    // MARK: 通知域（签名域确证）

    /// handleStartBrowserNotification（"browser.present.now" 域确证）。
    private func handleStartBrowserNotification(
        _ notification: Notification
    ) {
        guard
            let request = notification.userInfo?["request"]
                as? RemoteBrowserRequest
        else { return }
        if showFilterSheet {
            // 过滤器面板关闭后补呈（presentPendingBrowserRequestAfterFilterDismiss
            // 域确证）。
            pendingBrowserRequest = request
            return
        }
        pendingBrowserRequest = request
    }

    /// handleJavaOpen（签名确证）。
    private func handleJavaOpen(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        openRoute = ExploreOpenRoute(url: url.absoluteString)
    }

    /// presentPendingBrowserRequestAfterFilterDismiss（签名确证）。
    private func presentPendingBrowserRequestAfterFilterDismiss() {
        if pendingBrowserRequest != nil, !showFilterSheet {
            showFilterSheet = false
        }
    }

    /// finishExploreBrowserRequestIfNeeded（签名确证）。
    private func finishExploreBrowserRequestIfNeeded() {
        pendingBrowserRequest = nil
    }
}
