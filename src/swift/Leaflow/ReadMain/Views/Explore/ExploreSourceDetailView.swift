// 原路径: ReadMain/Views/Explore/ExploreSourceDetailView.swift
// 类型表7953-8015/34015：选书详情sheet、待阅读载荷及全屏阅读器；规则和加载分册同归本文件。
import SwiftUI

/// 发现源详情页（分类 + 筛选 + 列表）。
struct ExploreSourceDetailView: View {

    let source: BookSource

    // 分类态（getter 签名确证）。
    @State var categoryGroups: [ExploreCategoryGroup] = []
    @State var actionControls: [ExploreCategory] = []
    @State var selectedCategory: ExploreCategory?
    @State var filterValues: [String: String] = [:]
    @State var pendingFilterRefresh = false

    // 列表态。
    @State var books: [Book] = []
    @State var isLoading = false
    @State var hasMore = true
    @State var currentPage = 1
    @State var errorMessage: String?

    // 引擎与任务门（ensureFilterEngine/loadTaskActive/parseTaskActive 域）。
    @State var filterEngine: ExploreFilterEngine?
    @State var parseTaskActive = false
    @State var loadTaskActive = false
    @State var traceCounter = 0
    @State var showFilterSheet = false
    @State var showBrowser = false
    @State var browserRequest: RemoteBrowserRequest?
    @State var openRoute: ExploreOpenRoute?
    @State var searchRoute: ExploreSearchRoute?

    let sourceService = SourceService.shared

    @State var selectedBook: ExploreSelectedBook?
    @State var pendingReadBook: Book?

    var body: some View {
        // body（签名域）：分类选择 + 列表 + 筛选面板 + 弹层。
        VStack(spacing: 0) {
            if categoryGroups.isEmpty && actionControls.isEmpty {
                emptyState
            } else {
                ExploreFilterBar(engine: ensureFilterEngine())
                bookList
            }
        }
        .navigationTitle(source.bookSourceName)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(
            ExploreSourceDetailLifecycleModifier(
                onAppear: { handleViewAppear() },
                onDisappear: { handleViewDisappear() }))
        .exploreSourceDetailPresentations(
                selectedBook: $selectedBook,
                pendingReadBook: $pendingReadBook,
                onReadBookFromDetail: handleReadBookFromDetail,
                filterSheet: $showFilterSheet,
                browserRequest: $browserRequest,
                openRoute: $openRoute,
                searchRoute: $searchRoute,
                source: source)
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("notification.refreshExplore"))
        ) { _ in
            handleRefreshExploreNotification()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("browser.present.now"))
        ) { notification in
            handleStartBrowserNotification(notification)
        }
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 8.0) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("选择分类")
                .appThemeText(.body)
            Text("使用上方操作")
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 书籍列表（"该分类下暂无书籍" @ptr L4940/"暂无内容"/"没有更多了"/
    /// "点击重试"/"contentSection.retry" 域确证）。
    @ViewBuilder
    private var bookList: some View {
        if let errorMessage {
            VStack(spacing: 8.0) {
                Text(errorMessage)
                    .appThemeText(.caption, opacity: 0.7)
                Button("点击重试") {
                    logExploreTrace("contentSection.retry", "retry.initial")
                    Task {
                        await parseCategories(
                            forceRefresh: true, reparseCategories: false)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32.0)
        } else if books.isEmpty && !isLoading {
            Text("该分类下暂无书籍")
                .appThemeText(.caption, opacity: 0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32.0)
        } else {
            List {
                ForEach(books, id: \.bookUrl) { book in
                    Button {
                        selectedBook = ExploreSelectedBook(book: book)
                    } label: {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(book.name).lineLimit(1)
                            if let author = book.author {
                                Text(author)
                                    .appThemeText(.caption, opacity: 0.6)
                            }
                        }
                    }
                }
                if hasMore {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("没有更多了")
                                .appThemeText(.caption, opacity: 0.5)
                        }
                        Spacer()
                    }
                    .onAppear {
                        loadMore()
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                logExploreTrace("pullToRefresh", "")
                await parseCategories(
                    forceRefresh: true, reparseCategories: true)
                await loadBooks(reset: true)
            }
        }
    }
}

