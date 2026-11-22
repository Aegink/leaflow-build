// 原路径: ReadMain/Views/Bookshelf/BookshelfView.swift
// 证据:
//   - PGO: 191 条记录（index/task_functions.csv T-601-06 /
//     BookshelfView.swift；伪代码域 9716 行）。关键地址：
//     BookshelfItem.displayTitle（pgo_only）/ BookshelfDisplayItem.id
//     （pgo_only）/ resolvedGridColumnCount（签名）/ gridItemSpacing
//     0x10044d3f0 L122-129 / bookshelfUsesGroupSearchHeader 0x10044d5c4
//     L147-149 / bookshelfUsesLibrarySearchHeader 0x10044d660 L151-153 /
//     bookshelfUsesContinueReadingHeader（签名）/ body（签名）/
//     bookshelfChrome 0x10044e1ec L193-229 / selectedNetworkBookIds
//     （签名）/ selectedLocalBookIds（签名）/ allBookshelfItems
//     0x100450dec L700-709 / showNextPendingImport 0x100451860 L738-746 /
//     deleteSelectedBooks（签名）/ selectAll 0x100451ebc L752-759 /
//     groupSearchToolbarContent 0x10045259c L232-244 / standardToolbarContent
//     0x100452940 L281-301 / toggleEditing 0x100452dc8 L384-387 /
//     groupSearchOverflowMenu 0x100453164 L246-278 / showGroupFilter（签名）/
//     groupSelectionMenuItems 0x100462e4c L328-360 / groupManagementMenuItems
//     0x100454748 L363-382 / groupSelectorMenu 0x100455378 L309-325 /
//     displayRows（签名）/ displayItems（签名）/ defaultCoverVariants
//     0x100458194 L673-686 / recommendedItems 0x100458424 L419-425 /
//     recommendationScore 0x10045874c L688-695 / listItemView 0x10045927c
//     L642-671 / recommendationCard 0x10045cf04 L538-567 / deleteBook
//     0x10045dafc L767-769 / openReader 0x10045de60 L587-599 / gridItemView
//     0x10045e418 L615-638 / setReadingItem 0x10045f24c L601-611 /
//     toggleSelection 0x1004648f4 L729-735 / BookshelfGlassSearchField.body
//     0x100460f28 L776-808 / ContinueReadingCardScaleModifier.body
//     0x10044d6d0 L817-825 / bookshelfHeaderStyle（签名）/
//     bookshelfContent 0x1004503f4 L427-511 / bookshelfUsesSearchHeader
//     （签名）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/BookshelfView.c
//     （9716 行）
//   - 字符串域（位模式/指针）："分组管理" L2276/"当前分组：" L3076/
//     "network_" L4335/"刷新中 " L5409/"之前读过" L5561/'BookService' L168/
//     'Leaflow/BookshelfView.swift' @ptr L1500/"app_settings.json" @ptr
//     L8332/"org.idpf.epub-container" @ptr L8340/"清空搜索" L9044/
//     图标域 list.bullet/square.grid/chevron./checkmark/ellipsis/magnifyingglass
//   - 事实：三头部域（groupSearch/librarySearch/continueReading 三 header
//     确证）；双布局域（displayRows 列表 + displayItems 网格）；推荐域
//     （recommendedItems/recommendationScore/recommendationCard 确证）；
//     搜索域（BookshelfGlassSearchField + 清空搜索 域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 书架主链: high（地址 + 位模式确证）
//   - 推荐域: medium-high（签名族确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI
import UniformTypeIdentifiers

/// UTType 扩展（签名域确证）。
extension UTType {
    /// qireaderEPUB（签名确证）。
    static var qireaderEPUB: UTType {
        UTType(importedAs: "org.idpf.epub-container")
    }
}

/// 书架项扩展（displayTitle pgo_only 确证）。
extension BookshelfItem {
    var displayTitle: String {
        book.name
    }
}

/// 书架主视图。
struct BookshelfView: View {

    @StateObject private var vm = BookshelfViewModel(
        bookService: BookService(),
        localBookService: LocalBookService.shared)
    @StateObject private var bookService = BookService()

    @State private var searchText: String = ""
    @State private var isGrid = false
    @State private var showAddGroup = false
    @State private var pendingImportURLs: [URL] = []
    @State private var readingItem: BookshelfItem?

    /// resolvedGridColumnCount getter（签名确证）。
    private var resolvedGridColumnCount: Int {
        UIScreen.main.bounds.width > 500 ? 4 : 3
    }

    /// gridItemSpacing getter（0x10044d3f0 L122-129 域确证）。
    private var gridItemSpacing: CGFloat {
        10.0
    }

    /// bookshelfUsesGroupSearchHeader getter（0x10044d5c4 L147-149 域确证）。
    private var bookshelfUsesGroupSearchHeader: Bool {
        vm.selectedGroup != "全部"
    }

    /// bookshelfUsesLibrarySearchHeader getter（0x10044d660 L151-153 域确证）。
    private var bookshelfUsesLibrarySearchHeader: Bool {
        vm.selectedGroup == "全部"
    }

    /// bookshelfUsesContinueReadingHeader getter（签名确证）。
    private var bookshelfUsesContinueReadingHeader: Bool {
        !vm.allBookshelfItems(for: vm.selectedGroup).isEmpty
    }

    /// bookshelfUsesSearchHeader getter（签名确证）。
    private var bookshelfUsesSearchHeader: Bool {
        bookshelfUsesGroupSearchHeader || bookshelfUsesLibrarySearchHeader
    }

    /// bookshelfHeaderStyle getter（签名确证）。
    private var bookshelfHeaderStyle: String {
        bookshelfUsesContinueReadingHeader ? "continueReading" : "standard"
    }

    /// selectedNetworkBookIds getter（签名确证）。
    private var selectedNetworkBookIds: [String] {
        Array(vm.selectedIds)
    }

    /// selectedLocalBookIds getter（签名确证）。
    private var selectedLocalBookIds: [String] {
        Array(vm.selectedIds)
    }

    /// allBookshelfItems getter（0x100450dec L700-709 域确证）。
    private var allBookshelfItems: [BookshelfItem] {
        vm.allBookshelfItems(for: vm.selectedGroup)
    }

    var body: some View {
        Group {
            bookshelfContent
        }
        .navigationTitle("书架")
        .toolbar { standardToolbarContent }
        .searchable(text: $searchText, prompt: "搜索书名")
        .bookshelfPresentations(vm: vm, bookService: bookService)
        .onAppear {
            vm.initializeIfNeeded()
        }
    }

    // MARK: 内容区（0x1004503f4 L427-511 域确证）

    /// bookshelfContent getter（0x1004503f4 L427-511 域确证）。
    private var bookshelfContent: some View {
        Group {
            if displayItems.isEmpty {
                // 空态（'去搜索添加一些书籍吧' 串域确证；T-1601-C2：
                // 新装首屏此前为纯白，无引导）。搜索无结果单独文案。
                VStack(spacing: 12.0) {
                    Image(systemName: "books.vertical")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(
                        searchText.isEmpty
                            ? "去搜索添加一些书籍吧" : "没有搜索结果")
                        .appThemeText(.caption, opacity: 0.6)
                }
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .center)
            } else if isGrid {
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible()),
                            count: resolvedGridColumnCount),
                        spacing: gridItemSpacing) {
                        ForEach(displayItems) { item in
                            gridItemView(for: item)
                        }
                    }
                    .padding(.all, 12.0)
                }
            } else {
                List {
                    ForEach(displayRows, id: \.id) { item in
                        listItemView(for: item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable {
            await vm.refreshAllChapters(for: vm.selectedGroup)
        }
    }

    /// displayItems getter（签名确证）。
    private var displayItems: [BookshelfItem] {
        allBookshelfItems.filter { item in
            searchText.isEmpty
                || item.book.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// displayRows getter（签名确证）。
    private var displayRows: [BookshelfItem] {
        displayItems
    }

    /// recommendedItems getter（0x100458424 L419-425 域确证）。
    private var recommendedItems: [BookshelfItem] {
        allBookshelfItems
            .sorted { recommendationScore(for: $0) > recommendationScore(for: $1) }
            .prefix(3)
            .map { $0 }
    }

    /// recommendationScore(for:)（0x10045874c L688-695 域确证）。
    private func recommendationScore(for item: BookshelfItem) -> Double {
        let recency = vm.lastReadTime(for: item).timeIntervalSince1970
        let progress = item.book.readingProgress
        return recency / 1e9 + progress
    }

    /// recommendationCard（0x10045cf04 L538-567 域确证）。
    private func recommendationCard(
        for item: BookshelfItem
    ) -> some View {
        Button {
            openReader(item: item)
        } label: {
            HStack(spacing: 8.0) {
                Image(systemName: "book.closed")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(item.book.name)
                        .lineLimit(1)
                    // "之前读过" L5561 域确证。
                    Text("之前读过")
                        .appThemeText(.caption, opacity: 0.6)
                }
                Spacer()
            }
            .padding(.all, 10.0)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: 行/格视图（0x10045927c L642-671 + 0x10045e418 L615-638 域确证）

    /// listItemView(for:)（0x10045927c L642-671 域确证）。
    private func listItemView(
        for item: BookshelfItem
    ) -> some View {
        BookCardItem(book: item.book, cardHeight: 72.0)
            .networkBookActions(
                book: item.book,
                onDelete: { deleteBook(item.book) },
                onOpenReader: { openReader(item: item) })
            .onTapGesture {
                openReader(item: item)
            }
    }

    /// gridItemView(for:)（0x10045e418 L615-638 域确证）。
    private func gridItemView(
        for item: BookshelfItem
    ) -> some View {
        BookGridItem(book: item.book)
            .networkBookActions(
                book: item.book,
                onDelete: { deleteBook(item.book) },
                onOpenReader: { openReader(item: item) })
            .onTapGesture {
                openReader(item: item)
            }
    }

    // MARK: 工具栏（0x100452940 L281-301 域确证）

    /// standardToolbarContent getter（0x100452940 L281-301 域确证）。
    @ToolbarContentBuilder
    private var standardToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                groupSelectionMenuItems
                Divider()
                groupManagementMenuItems
            } label: {
                // "当前分组：" L3076 域确证。
                Text(vm.selectedGroup)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12.0) {
                Button {
                    toggleEditing()
                } label: {
                    Image(systemName: vm.isEditMode ? "checkmark.circle" : "ellipsis")
                }
                Button {
                    isGrid.toggle()
                } label: {
                    // list.bullet/square.grid 域确证。
                    Image(systemName: isGrid ? "list.bullet" : "square.grid.2x2")
                }
            }
        }
    }

    /// groupSelectorMenu（0x100455378 L309-325 域确证）。
    @ViewBuilder
    private var groupSelectorMenu: some View {
        ForEach(bookService.groups, id: \.self) { group in
            Button {
                vm.selectedGroup = group
            } label: {
                HStack {
                    Text(group)
                    if vm.selectedGroup == group {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    /// groupSelectionMenuItems（0x100462e4c L328-360 域确证）。
    @ViewBuilder
    private var groupSelectionMenuItems: some View {
        groupSelectorMenu
    }

    /// groupManagementMenuItems（0x100454748 L363-382 域确证；
    /// "分组管理" L2276 域确证）。
    @ViewBuilder
    private var groupManagementMenuItems: some View {
        Button {
            showAddGroup = true
        } label: {
            Label("分组管理", systemImage: "folder.badge.gearshape")
        }
        Button {
            vm.showImport = true
        } label: {
            Label("导入", systemImage: "square.and.arrow.down")
        }
    }

    /// groupSearchToolbarContent（0x10045259c L232-244 域确证）。
    private var groupSearchToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                searchText = ""
            } label: {
                // "清空搜索" L9044 域确证。
                Text("清空搜索")
            }
        }
    }

    /// groupSearchOverflowMenu（0x100453164 L246-278 域确证）。
    private var groupSearchOverflowMenu: some View {
        Menu {
            groupManagementMenuItems
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    // MARK: 动作域（0x100452dc8 L384-387 + 0x10045de60 L587-599 + 0x10045f24c
    // L601-611 + 0x1004648f4 L729-735 + 0x100451860 L738-746 + 0x10045dafc
    // L767-769 域确证）

    /// toggleEditing（0x100452dc8 L384-387 域确证）。
    private func toggleEditing() {
        vm.isEditMode.toggle()
        if !vm.isEditMode {
            vm.clearSelection()
        }
    }

    /// openReader(item:)（0x10045de60 L587-599 域确证）。
    private func openReader(item: BookshelfItem) {
        setReadingItem(item)
        // TODO(T-601-06 域): ReaderRouter 阅读入口。
    }

    /// setReadingItem（0x10045f24c L601-611 域确证）。
    private func setReadingItem(_ item: BookshelfItem) {
        readingItem = item
    }

    /// toggleSelection（0x1004648f4 L729-735 域确证）。
    private func toggleSelection(_ id: String) {
        if vm.selectedIds.contains(id) {
            vm.selectedIds.remove(id)
        } else {
            vm.selectedIds.insert(id)
        }
    }

    /// selectAll（0x100451ebc L752-759 域确证）。
    private func selectAll() {
        vm.selectAll()
    }

    /// showNextPendingImport（0x100451860 L738-746 域确证）。
    private func showNextPendingImport() {
        guard let next = pendingImportURLs.first else { return }
        pendingImportURLs.removeFirst()
        vm.startImportFromFile(next)
    }

    /// deleteBook（0x10045dafc L767-769 域确证）。
    private func deleteBook(_ book: Book) {
        vm.deleteBook(book)
    }

    /// defaultCoverVariants（0x100458194 L673-686 域确证）。
    private func defaultCoverVariants(
        for items: [BookshelfItem]
    ) -> [String] {
        items.map { item in
            "cover_\(String(item.book.name.hashValue % 5 + 1)).png"
        }
    }
}

// MARK: - 搜索框（0x100460f28 L776-808 域确证）

/// 毛玻璃搜索框。
struct BookshelfGlassSearchField: View {
    @Binding var text: String

    var body: some View {
        // 0x100460f28 L776-808 域确证。
        HStack(spacing: 8.0) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索", text: $text)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10.0)
        .padding(.vertical, 6.0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial))
    }
}

/// 继续阅读卡片缩放修饰（0x10044d6d0 L817-825 域确证）。
struct ContinueReadingCardScaleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0)
    }
}
