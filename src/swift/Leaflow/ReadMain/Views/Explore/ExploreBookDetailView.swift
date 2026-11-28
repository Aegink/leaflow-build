// 原路径: ReadMain/Views/Explore/ExploreBookDetailView.swift
// 证据:
//   - PGO: 272 条记录（index/task_functions.csv T-501-02 /
//     ExploreBookDetailView.swift；140 个伪代码块）。关键地址：
//     init(book:availableSources:onRead:initialChapters:) 0x1004b140c
//     L27-36 / bookshelfBook 0x1004b22d8 L73-75 / bookSource 0x1004b2674
//     L93-99 / sourceStateSource 0x1004b2828 L101-107 /
//     currentSourceVariable 0x1004b2b2c L109-112 / hasLogin 0x1004b2c20
//     L116-119 / trackedSearchObservationKey 0x1004b2d44 L133-136 /
//     inlineSourceOptions 0x1004b2e9c L145-170 / inlineSourceRows
//     0x1004b5570 L180-189 / body 0x1004b5a24 L195-323 / moreMenu
//     0x1004db150 L364-436 / bookTypeOptions 0x1004bab18 L327-333 /
//     applyBookTypeSelection 0x1004babc4 L339-350 / toggleSkipUpdate
//     0x1004bdfbc L352-360 / headerSection 0x1004b6584 L440-485 /
//     applyBookshelfGroupSelection 0x1004b87c8 L527-550 /
//     normalizedBookshelfGroupName 0x1004b24a8 L552-556 / metadataBar
//     0x1004b6c70 L560-576 / groupMetadataItem 0x1004c2f18 L584-597 /
//     metadataDivider 0x1004c8628 L578-582 / bookTypeMetadataItem
//     0x1004df6ec L599-621 / updateMetadataItem 0x1004c3998 L623-636 /
//     chapterOverview 0x1004b6e04 L705-782 / chapterRow 0x1004cabbc
//     L784-807 / readFromChapter 0x1004ba124 L809-830 /
//     inlineSourcesCard 0x1004b83c0 L877-925 / inlineSourceRow
//     0x1004ddfdc L928-998 / sourceModeTag 0x1004cedc4 L1001-1019 /
//     variableEditorSheet 0x1004b8298 L1023-1072 / bookVariableEditorSheet
//     0x1004b91a8 L1076-1125 / saveBookVariable 0x1004d2be0 L1129-1141 /
//     mergedFetchedBookWithLocalState 0x1004bbec0 L1143-1160 /
//     saveSourceVariable 0x1004d0cd0 L1164-1171 / refreshAfterSourceChange
//     0x1004b965c L1175-1200 / refreshBookInfo 0x1004bf0b4 L1204-1218 /
//     loadChapters 0x1004bcc80 L1222-1241 / makeSourceIdentity
//     0x1004d348c L1257-1259 / deduplicatedSourceCandidates 0x1004b155c
//     L1261-1271 / syncAuxiliaryState 0x1004bc170 L1284-1315 /
//     debugDescribe 0x1004bbd70 L1317-1321 /
//     observeTrackedSearchSourcesIfNeeded 0x1004bd26c L1329-1344 /
//     refreshTrackedSearchSourcesFromCache 0x1004d3684 L1347-1358 /
//     replaceTrackedAvailableSourcesIfNeeded 0x1004bdb34 L1361-1374 /
//     deduplicatedSources 0x1004bdda4 L1376-1378 /
//     trackedSourcesFingerprint 0x1004d38b4 L1380-1390 /
//     BookDetailAutoFetchPolicy.shouldAutoFetchBookInfo
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/
//     ExploreBookDetailView.c（14887 行）
//   - 字符串确证（位模式/指针）："配置登录" L3546/"源变量" L3597/"书籍变量"
//     L3648/"更多书架操作" @ptr L3708/"开始阅读" L4660/"书架" L4967/
//     "展开全部" L6626/"暂无目录信息" @ptr L7475/"更新于 " L8090/
//     "查看全部 N 个来源"（L10312 + L9807）/"清除源变量" L12144/
//     "书籍变量 (bookVariable)" @ptr L12675/"确定要从书架中删除《" @ptr
//     L12444/"在浏览器中打开" @ptr L13066/"https://" L9457/" 个来源" L9806/
//     "[EXPLORE-DETAIL-DIAG] session=" @ptr L14419 + " author="/" bookId="/
//     " bookUrl="/" sourceUrl="/" storage="/" chapters="/" current" 诊断域/
//     "bookType" L2976/"skipUpdate" L3058/"sourceVariable_" L183；
//     图标域 "ellipsis"/"text.alignleft"/"person.fill"/"book.fill"/
//     "checkmark"/"bell.slash"/"bell.fill"/"folder.fill"/"lock.fill"/
//     "chevron."；布局常量 0x4014=5.0/0x4024=10.0 域
//   - 事实：追踪搜索源域（trackedSearchObservationKey + trackedSourceBase
//     Candidates + observe/replace/refreshTracked + fingerprint 三段闭包
//     确证）；去重域（deduplicatedSourceCandidates/deduplicatedSources/
//     makeSourceIdentity）；书类型域（bookType/skipUpdate keys + 三段
//     options）；诊断域 [EXPLORE-DETAIL-DIAG]
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链（换源/目录/变量/书架）: high（地址 + 位模式确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
//   - 书架写回: medium（BookService 骨架，T-601-01 交叉登记）
// 还原: 2026-11-20

import SwiftUI

// MARK: - 自动获取策略

/// 详情自动获取策略（shouldAutoFetchBookInfo 签名确证）。
enum BookDetailAutoFetchPolicy {

    /// shouldAutoFetchBookInfo(for:source:)（签名确证）。
    static func shouldAutoFetchBookInfo(
        for book: Book, source: BookSource?
    ) -> Bool {
        source != nil
            && (book.intro?.isEmpty ?? true)
    }
}

// MARK: - BookDetailView

/// 发现书籍详情页。
@MainActor
struct BookDetailView: View {

    let onRead: (Book) -> Void

    // init 域（0x1004b140c L27-36 确证）。
    // @State：刷新域有写回（refreshBookInfo/refreshAfterSourceChange，
    // wave-16）。
    @State var baseBook: Book
    @State var availableSources: [Book]
    @State var initialChapters: [Chapter]?

    // 状态域。
    @State var chapters: [Chapter] = []
    @State var isLoadingChapters = false
    @State var isRefreshingInfo = false
    @State var showVariableEditor = false
    @State var showSourceLogin = false
    @State var showBookVariableEditor = false
    @State var sourceVariableText: String = ""
    @State var bookVariableText: String = ""
    @State var showGroupPicker = false
    @State var chaptersExpanded = false
    @State var observedSearchToken: String = ""
    @State var trackedSources: [Book] = []
    @State var deleteConfirmBook: Book?

    @EnvironmentObject var bookService: BookService
    @ObservedObject var sourceService: SourceService
    @State var ready = false
    let diagSession = UUID().uuidString.prefix(6)

    init(
        book: Book, availableSources: [Book],
        onRead: @escaping (Book) -> Void,
        initialChapters: [Chapter]? = nil,
        sourceService: SourceService = .shared
    ) {
        self.baseBook = book
        self.onRead = onRead
        _sourceService = ObservedObject(wrappedValue: sourceService)
        _availableSources = State(initialValue: availableSources)
        _initialChapters = State(initialValue: initialChapters)
        _chapters = State(initialValue: initialChapters ?? [])
    }

    // MARK: 状态 getter（地址域确证）

    /// bookshelfBook getter（0x1004b22d8 L73-75；书架域 T-601-01 交叉）。
    var bookshelfBook: Book? {
        BookDetailState.bookshelfBook(for: baseBook, bookshelf: bookService.bookshelf)
    }

    /// isInBookshelf getter（签名确证）。
    var isInBookshelf: Bool {
        bookshelfBook != nil
    }

    /// displayBook getter（签名确证）。
    var displayBook: Book {
        bookshelfBook ?? baseBook
    }

    /// bookSource getter（0x1004b2674 L93-99 域确证）。
    var bookSource: BookSource? {
        BookDetailState.source(for: displayBook, service: sourceService)
    }

    /// sourceStateSource getter（0x1004b2828 L101-107 域确证）。
    var sourceStateSource: BookSource? {
        BookDetailState.stateSource(for: displayBook, service: sourceService)
    }

    /// currentSourceVariable（0x1004b2b2c L109-112 域确证）。
    func currentSourceVariable() -> String {
        BookDetailState.sourceVariable(sourceStateSource)
    }

    /// hasLogin getter（0x1004b2c20 L116-119 域确证）。
    var hasLogin: Bool {
        sourceStateSource?.loginUrl != nil
    }

    /// currentGroupValue getter（签名确证）。
    var currentGroupValue: String {
        displayBook.group ?? ""
    }

    /// normalizedBookshelfGroupName（0x1004b24a8 L552-556 域确证）。
    func normalizedBookshelfGroupName(_ name: String?) -> String {
        BookDetailState.normalizedGroup(name) ?? "未分组"
    }

    /// updateToggleValue getter（签名确证）。
    var updateToggleValue: String {
        BookDetailState.skipsUpdate(displayBook) ? "已跳过更新" : "自动更新"
    }

    /// trackedSearchObservationKey getter（0x1004b2d44 L133-136 域确证）。
    var trackedSearchObservationKey: String {
        "\(displayBook.name)|\(trackedSourceAuthor ?? "")"
    }

    /// trackedSourceBookname getter（签名确证）。
    var trackedSourceBookname: String {
        displayBook.name
    }

    /// trackedSourceAuthor getter（0x1004e2620 L129-131 域确证）。
    var trackedSourceAuthor: String? {
        displayBook.author
    }

    /// shouldTrackSearchSources getter（签名确证）。
    var shouldTrackSearchSources: Bool {
        availableSources.isEmpty && !displayBook.name.isEmpty
    }

    /// trackedSourceBaseCandidates getter（签名确证）。
    var trackedSourceBaseCandidates: [Book] {
        trackedSources
    }

    /// inlineSourceOptions（0x1004b2e9c L145-170 域确证）。
    var inlineSourceOptions: [Book] {
        Self.deduplicatedSourceCandidates(
            [displayBook] + availableSources + trackedSources)
    }

    /// inlineSourceTotalCount getter（签名确证）。
    var inlineSourceTotalCount: Int {
        inlineSourceOptions.count
    }

    /// shouldShowInlineSources getter（签名确证）。
    var shouldShowInlineSources: Bool {
        inlineSourceOptions.count > 1
    }

    /// inlineSourceRows getter（0x1004b5570 L180-189 域确证）。
    var inlineSourceRows: [Book] {
        Array(inlineSourceOptions.prefix(4))
    }

    /// shouldShowInlineSourceOverflowButton getter（签名确证）。
    var shouldShowInlineSourceOverflowButton: Bool {
        inlineSourceTotalCount > inlineSourceRows.count
    }

    /// currentBookTypeOption getter（签名确证；"bookType" L2976 域）。
    var currentBookTypeOption: (
        value: Int, title: String, icon: String, color: Color
    ) {
        let kind = BookDetailState.selectedType(displayBook, service: sourceService)
        return bookTypeOptions.first { $0.value == kind }
            ?? bookTypeOptions[0]
    }

    /// bookTypeOptions getter（0x1004bab18 L327-333 域确证）。
    var bookTypeOptions: [(value: Int, title: String, icon: String, color: Color)] {
        [
            (value: 0, title: "文本", icon: "text.alignleft", color: .blue),
            (value: 1, title: "音频", icon: "waveform", color: .purple),
            (value: 2, title: "图片", icon: "photo", color: .orange),
        ]
    }

    // MARK: 主体

    var body: some View {
        // 伪代码 0x1004b5a24（L195-323）：ScrollView 详情主链。
        ScrollView {
            VStack(alignment: .leading, spacing: 12.0) {
                headerSection
                metadataBar
                actionButtonsRow
                chapterOverview
                if shouldShowInlineSources {
                    inlineSourcesCard
                }
            }
            .padding(.all, 12.0)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(displayBook.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .sheet(isPresented: $showVariableEditor) {
            variableEditorSheet
        }
        .sheet(isPresented: $showSourceLogin) {
            if let source = sourceStateSource {
                SourceLoginView(source: source, book: displayBook, chapter: nil)
            }
        }
        .sheet(isPresented: $showBookVariableEditor) {
            bookVariableEditorSheet
        }
        .sheet(isPresented: $showGroupPicker) {
            bookshelfGroupPicker
        }
        .task {
            await bookService.waitUntilReady()
            if !sourceService.hasLoadedOnce { await sourceService.loadLocalSources() }
            guard !Task.isCancelled else { return }
            syncAuxiliaryState(with: displayBook)
            ready = true
            if chapters.isEmpty { await loadChapters() }
            await observeTrackedSearchSourcesIfNeeded()
        }
        .confirmationDialog(
            "确定要从书架中删除《\(displayBook.name)》",
            isPresented: Binding(
                get: { deleteConfirmBook != nil },
                set: { if !$0 { deleteConfirmBook = nil } }),
            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let target = deleteConfirmBook {
                    baseBook = target
                    bookService.deleteBook(target)
                }
                deleteConfirmBook = nil
            }
            Button("取消", role: .cancel) { deleteConfirmBook = nil }
        }
    }

}
