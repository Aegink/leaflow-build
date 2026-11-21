// 原路径: ReadMain/Views/Search/SearchView.swift
// 证据:
//   - PGO: 106 条记录（index/task_functions.csv T-501-07 /
//     SearchView.swift；伪代码域 7286 行）。关键地址：
//     bookshelfSearchResults 0x1009022ec L27-40 / body 0x100903d54 L42-140 /
//     searchContent 0x100904b04 L162-196 / submitSourceSearch 0x1009143c8
//     L198-201 / consumePendingSingleSourceIfNeeded 0x100906180 L203-207 /
//     scheduleSourceReload 0x100906364 L142-150 / scheduleSearchFieldReady
//     0x100906520 L152-159 / bookshelfSearchView 0x1009056a8 L403-451 /
//     filterBar 0x1009081b0 L210-311 / searchResultsView 0x10090d654
//     L342-401 / bookshelfSearchRow 0x100910b70 L454-472 /
//     openBookshelfReader 0x100911970 L474-483 / setBookshelfReadingItem
//     0x100911aec L485-494；usesSourceSearch/searchPrompt/searchHistoryView
//     （签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SearchView.c
//     （7286 行）
//   - 字符串确证（位模式/指针）："书名或作者" L904（搜索提示）/'SourceService'
//     L1043/'TabSelection' L1443 域/"搜索失败" L2732/" N 个配置搜索失败"
//     @ptr L2754/"无法打开浏览器" @ptr L2765/"未找到结果" L2808/
//     "magnifyingglass" L2820/"…词或选择更多分组" @ptr L2882/
//     "到匹配结果\n" @ptr L2896/"个分组" L3373/"全部分组" L3394/"选择分组"
//     L3408/"square.g(rid)" L4548 域/"不聚合" L4557/"精确匹配 " L5571/
//     " 本（共 " L5588/" 条结果" L5758/"暂无书籍" L6371/"books.ve" L6405 域/
//     'BookService' L7266（书架域交叉）
//   - 事实：书架搜索结果域（bookshelfSearchResults + bookshelfSearchRow +
//     openBookshelfReader + setBookshelfReadingItem——BookService 交叉
//     T-601-01）；筛选条域（filterBar 全部分组/精确匹配/不聚合）；搜索
//     提示域（书名或作者）；双模式域（usesSourceSearch 全源/单源）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 视图主链: high（地址 + 位模式确证）
//   - 书架联动: medium（BookService T-601-01 交叉占位）
// 还原: 2026-11-20

import SwiftUI

/// 搜索主视图。
struct SearchView: View {

    @StateObject private var viewModel = SearchViewModel(
        sourceService: SourceService(), bookService: BookService())

    // 书架搜索域（bookshelfSearchResults 签名确证）。
    @State private var bookshelfItems: [BookshelfItem] = []
    @State private var pendingSingleSource: BookSource?
    @State private var showGroupPicker = false
    @State private var readingItem: BookshelfItem?

    private let sourceService = SourceService()

    /// bookshelfSearchResults getter（0x1009022ec L27-40 域确证）。
    private var bookshelfSearchResults: [BookshelfItem] {
        let query = viewModel.keyword
            .trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return bookshelfItems }
        return bookshelfItems.filter {
            $0.book.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// usesSourceSearch getter（签名确证）。
    private var usesSourceSearch: Bool {
        pendingSingleSource != nil
    }

    /// searchPrompt getter（签名确证；"书名或作者" L904 位模式确证）。
    private var searchPrompt: String {
        "书名或作者"
    }

    var body: some View {
        // 伪代码 0x100903d54（L42-140）：搜索主链。
        VStack(spacing: 0) {
            filterBar
            searchContent
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGroupPicker = true
                } label: {
                    // "选择分组" L3408 域确证。
                    Label("选择分组", systemImage: "line.3.horizontal.decrease")
                }
            }
        }
        .onAppear {
            viewModel.initializeIfNeeded()
            scheduleSourceReload()
            scheduleSearchFieldReady()
        }
        .sheet(isPresented: $showGroupPicker) { groupPickerSheet }
        .sheet(item: singleSourceBinding) { box in
            singleSourcePickerSheet(box)
        }
    }

    /// 分组选择 sheet（body 拆分域——类型检查超时消解，wave-77）。
    private var groupPickerSheet: some View {
        GroupPickerSheet(
            groups: viewModel.availableGroups,
            selectedGroup: viewModel.selectedGroup) { group in
            viewModel.selectedGroup = group ?? "全部分组"
            viewModel.onSourcesChanged()
        }
    }

    /// 单源 sheet 绑定（body 拆分域）。
    private var singleSourceBinding: Binding<SingleSourceBox?> {
        Binding(
            get: { pendingSingleSource.map { SingleSourceBox(source: $0) } },
            set: { pendingSingleSource = $0?.source })
    }

    /// 单源选择 sheet（body 拆分域）。
    @ViewBuilder
    private func singleSourcePickerSheet(_ box: SingleSourceBox) -> some View {
        SingleSourcePickerSheet(source: box.source) { picked in
            if let picked {
                Task {
                    let books = try? await SearchViewModel.searchSingleSource(
                        source: picked, keyword: viewModel.keyword, page: 1)
                    _ = books
                }
            }
        }
    }

    /// SingleSourceSheet 包装（sheet item 域确证）。
    struct SingleSourceBox: Identifiable {
        let source: BookSource
        var id: String { source.bookSourceUrl }
    }

    // MARK: 筛选条（0x1009081b0 L210-311 域确证）

    /// filterBar getter（0x1009081b0 L210-311 域确证）。
    private var filterBar: some View {
        HStack(spacing: 8.0) {
            Button {
                viewModel.toggleExactSearch()
            } label: {
                // "精确匹配 " L5571 域确证。
                Text(viewModel.exactSearch ? "精确匹配 开" : "精确匹配 关")
                    .appThemeText(.caption)
            }
            Button {
                viewModel.toggleAggregateResults()
            } label: {
                // "不聚合" L4557 域确证。
                Text(viewModel.aggregateResults ? "聚合" : "不聚合")
                    .appThemeText(.caption)
            }
            Button {
                showGroupPicker = true
            } label: {
                // "全部分组" L3394 域确证。
                Text("\(viewModel.selectedGroup) (\(viewModel.availableGroups.count)个分组)")
                    .appThemeText(.caption)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 6.0)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: 内容（0x100904b04 L162-196 域确证）

    /// searchContent getter（0x100904b04 L162-196 域确证）。
    private var searchContent: some View {
        List {
            Section {
                TextField(searchPrompt, text: $viewModel.keyword)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit {
                        submitSourceSearch()
                    }
                    .onAppear {
                        viewModel.initializeIfNeeded()
                    }
                if viewModel.isSearching {
                    HStack(spacing: 8.0) {
                        ProgressView()
                        Button("停止") {
                            viewModel.stopSearch()
                        }
                        .appThemeText(.caption)
                    }
                }
            }
            if viewModel.displayResults.isEmpty {
                emptyState
            } else {
                searchResultsView
            }
        }
        .listStyle(.plain)
    }

    /// 空态域（"未找到结果" L2808 + "…词或选择更多分组" @ptr L2882 +
    /// "到匹配结果\n" @ptr L2896 + "暂无书籍" L6371 域确证）。
    @ViewBuilder
    private var emptyState: some View {
        if viewModel.errorMessage != nil {
            Text(viewModel.errorMessage ?? "搜索失败")
                .appThemeText(.caption, opacity: 0.7)
        } else if !viewModel.searchHistory.isEmpty {
            searchHistoryView
        } else {
            VStack(spacing: 8.0) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("未找到结果")
                    .appThemeText(.body)
                Text("调整关键词或选择更多分组到匹配结果")
                    .appThemeText(.caption, opacity: 0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24.0)
        }
    }

    /// searchHistoryView getter（签名确证）。
    private var searchHistoryView: some View {
        Section("搜索历史") {
            ForEach(viewModel.searchHistory, id: \.self) { term in
                Button(term) {
                    viewModel.keyword = term
                    viewModel.performSearch()
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    viewModel.removeFromHistory(
                        viewModel.searchHistory[index])
                }
            }
            Button(role: .destructive) {
                viewModel.clearSearchHistory()
            } label: {
                Text("清空历史")
            }
        }
    }

    // MARK: 结果区（0x10090d654 L342-401 域确证）

    /// searchResultsView getter（0x10090d654 L342-401 域确证）。
    private var searchResultsView: some View {
        Section {
            // " N 条结果" L5758 域确证。
            HStack {
                Text("\(viewModel.displayResults.count) 条结果")
                    .appThemeText(.caption, opacity: 0.6)
                Spacer()
                if !viewModel.displayResults.isEmpty {
                    // " 本（共 " L5588 域确证。
                    Text(
                        "\(viewModel.displayResults.count)"
                            + " 本（共 \(viewModel.displayResults.count)）")
                        .appThemeText(.caption, opacity: 0.5)
                }
            }
            ForEach(viewModel.displayResults) { result in
                SearchResultRowView(result: result) {
                    viewModel.sourcesForDisplayResult(result)
                } onPick: { book in
                    // TODO(T-601-01): ReaderRouter 阅读入口。
                    _ = book
                }
            }
        }
    }

    // MARK: 动作（0x1009143c8 L198-201 + 0x100906180 L203-207 域确证）

    /// submitSourceSearch（0x1009143c8 L198-201 域确证）。
    private func submitSourceSearch() {
        if usesSourceSearch, let source = pendingSingleSource {
            Task {
                _ = try? await SearchViewModel.searchSingleSource(
                    source: source, keyword: viewModel.keyword, page: 1)
            }
        } else {
            viewModel.performSearch()
        }
    }

    /// consumePendingSingleSourceIfNeeded（0x100906180 L203-207 域确证）。
    private func consumePendingSingleSourceIfNeeded() {
        pendingSingleSource = nil
    }

    /// scheduleSourceReload（0x100906364 L142-150 域确证）。
    private func scheduleSourceReload() {
        viewModel.onSourcesChanged()
    }

    /// scheduleSearchFieldReady（0x100906520 L152-159 域确证）。
    private func scheduleSearchFieldReady() {
        // 焦点就绪域（签名确证）。
    }

    // MARK: 书架域（0x100910b70 L454-472 + 0x100911970 L474-483 +
    // 0x100911aec L485-494 域确证）

    /// bookshelfSearchView getter（0x1009056a8 L403-451 域确证）。
    @ViewBuilder
    private var bookshelfSearchView: some View {
        if !bookshelfSearchResults.isEmpty {
            Section("书架") {
                ForEach(bookshelfSearchResults) { item in
                    bookshelfSearchRow(for: item)
                }
            }
        }
    }

    /// bookshelfSearchRow(for:)（0x100910b70 L454-472 域确证）。
    private func bookshelfSearchRow(for item: BookshelfItem) -> some View {
        Button {
            openBookshelfReader(item)
        } label: {
            HStack {
                Text(item.book.name).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// openBookshelfReader（0x100911970 L474-483 域确证）。
    private func openBookshelfReader(_ item: BookshelfItem) {
        setBookshelfReadingItem(item)
    }

    /// setBookshelfReadingItem（0x100911aec L485-494 域确证）。
    private func setBookshelfReadingItem(_ item: BookshelfItem) {
        readingItem = item
        // TODO(T-601-01): ReaderRouter 阅读入口（'BookService' L7266 交叉）。
    }
}

/// 搜索结果行（SearchSubViews 域交叉）。
struct SearchResultRowView: View {
    let result: SearchResultBook
    let sourcesProvider: () -> [Book]
    let onPick: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(result.displayBook.name)
                    .lineLimit(1)
                Spacer()
                // " 本（共 " 域确证。
                Text("共 \(result.sourceCount) 个来源")
                    .appThemeText(.caption, opacity: 0.6)
            }
            if let author = result.displayBook.author {
                Text(author)
                    .appThemeText(.caption, opacity: 0.6)
            }
        }
        .contentShape(Rectangle())
    }
}
