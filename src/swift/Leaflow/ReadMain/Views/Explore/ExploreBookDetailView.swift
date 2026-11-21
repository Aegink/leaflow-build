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
struct BookDetailView: View {

    let onRead: (Book) -> Void

    // init 域（0x1004b140c L27-36 确证）。
    private var baseBook: Book
    @State private var availableSources: [Book]
    @State private var initialChapters: [Chapter]?

    // 状态域。
    @State private var chapters: [Chapter] = []
    @State private var isLoadingChapters = false
    @State private var isRefreshingInfo = false
    @State private var showVariableEditor = false
    @State private var showBookVariableEditor = false
    @State private var sourceVariableText: String = ""
    @State private var bookVariableText: String = ""
    @State private var showGroupPicker = false
    @State private var chaptersExpanded = false
    @State private var observedSearchToken: String = ""
    @State private var trackedSources: [Book] = []
    @State private var deleteConfirmBook: Book?

    private let sourceService = SourceService()
    private let diagSession = UUID().uuidString.prefix(6)

    init(
        book: Book, availableSources: [Book],
        onRead: @escaping (Book) -> Void,
        initialChapters: [Chapter]? = nil
    ) {
        self.baseBook = book
        self.onRead = onRead
        _availableSources = State(initialValue: availableSources)
        _initialChapters = State(initialValue: initialChapters)
        _chapters = State(initialValue: initialChapters ?? [])
    }

    // MARK: 状态 getter（地址域确证）

    /// bookshelfBook getter（0x1004b22d8 L73-75；书架域 T-601-01 交叉）。
    private var bookshelfBook: Book? {
        // TODO(T-601-01): BookService 书架域接入。
        nil
    }

    /// isInBookshelf getter（签名确证）。
    private var isInBookshelf: Bool {
        bookshelfBook != nil
    }

    /// displayBook getter（签名确证）。
    private var displayBook: Book {
        bookshelfBook ?? baseBook
    }

    /// bookSource getter（0x1004b2674 L93-99 域确证）。
    private var bookSource: BookSource? {
        sourceService.bookSources.first {
            $0.bookSourceUrl == displayBook.bookSourceUrl
        }
    }

    /// sourceStateSource getter（0x1004b2828 L101-107 域确证）。
    private var sourceStateSource: BookSource? {
        bookSource
    }

    /// currentSourceVariable（0x1004b2b2c L109-112 域确证）。
    private func currentSourceVariable() -> String {
        sourceStateSource?.variable ?? ""
    }

    /// hasLogin getter（0x1004b2c20 L116-119 域确证）。
    private var hasLogin: Bool {
        sourceStateSource?.loginUrl != nil
    }

    /// currentGroupValue getter（签名确证）。
    private var currentGroupValue: String {
        displayBook.group ?? ""
    }

    /// normalizedBookshelfGroupName（0x1004b24a8 L552-556 域确证）。
    private func normalizedBookshelfGroupName(_ name: String?) -> String {
        (name ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            ? "未分组" : name!.trimmingCharacters(in: .whitespaces)
    }

    /// updateToggleValue getter（签名确证）。
    private var updateToggleValue: String {
        displayBook.skipUpdate == true ? "已跳过更新" : "自动更新"
    }

    /// trackedSearchObservationKey getter（0x1004b2d44 L133-136 域确证）。
    private var trackedSearchObservationKey: String {
        "\(displayBook.name)|\(trackedSourceAuthor ?? "")"
    }

    /// trackedSourceBookname getter（签名确证）。
    private var trackedSourceBookname: String {
        displayBook.name
    }

    /// trackedSourceAuthor getter（0x1004e2620 L129-131 域确证）。
    private var trackedSourceAuthor: String? {
        displayBook.author
    }

    /// shouldTrackSearchSources getter（签名确证）。
    private var shouldTrackSearchSources: Bool {
        availableSources.isEmpty && !displayBook.name.isEmpty
    }

    /// trackedSourceBaseCandidates getter（签名确证）。
    private var trackedSourceBaseCandidates: [Book] {
        trackedSources
    }

    /// inlineSourceOptions（0x1004b2e9c L145-170 域确证）。
    private var inlineSourceOptions: [Book] {
        Self.deduplicatedSourceCandidates(
            [displayBook] + availableSources + trackedSources)
    }

    /// inlineSourceTotalCount getter（签名确证）。
    private var inlineSourceTotalCount: Int {
        inlineSourceOptions.count
    }

    /// shouldShowInlineSources getter（签名确证）。
    private var shouldShowInlineSources: Bool {
        inlineSourceOptions.count > 1
    }

    /// inlineSourceRows getter（0x1004b5570 L180-189 域确证）。
    private var inlineSourceRows: [Book] {
        Array(inlineSourceOptions.prefix(4))
    }

    /// shouldShowInlineSourceOverflowButton getter（签名确证）。
    private var shouldShowInlineSourceOverflowButton: Bool {
        inlineSourceTotalCount > inlineSourceRows.count
    }

    /// currentBookTypeOption getter（签名确证；"bookType" L2976 域）。
    private var currentBookTypeOption: (
        value: Int, title: String, icon: String, color: Color
    ) {
        let kind = displayBook.bookType
        return bookTypeOptions.first { $0.value == kind }
            ?? bookTypeOptions[0]
    }

    /// bookTypeOptions getter（0x1004bab18 L327-333 域确证）。
    private var bookTypeOptions: [(value: Int, title: String, icon: String, color: Color)] {
        [
            (value: 0, title: "文本", icon: "text.alignleft", color: .blue),
            (value: 8, title: "音频", icon: "waveform", color: .purple),
            (value: 16, title: "图片", icon: "photo", color: .orange),
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
        .sheet(isPresented: $showBookVariableEditor) {
            bookVariableEditorSheet
        }
        .sheet(isPresented: $showGroupPicker) {
            bookshelfGroupPicker
        }
        .onAppear {
            if chapters.isEmpty {
                Task { await loadChapters() }
            }
            Task { await observeTrackedSearchSourcesIfNeeded() }
        }
        .confirmationDialog(
            "确定要从书架中删除《\(displayBook.name)》",
            isPresented: Binding(
                get: { deleteConfirmBook != nil },
                set: { if !$0 { deleteConfirmBook = nil } }),
            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                // TODO(T-601-01): BookService 移除书架。
                deleteConfirmBook = nil
            }
            Button("取消", role: .cancel) { deleteConfirmBook = nil }
        }
    }

    // MARK: 头部

    /// headerSection（0x1004b6584 L440-485 域确证）。
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12.0) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 90.0, height: 120.0)
                .overlay {
                    Image(systemName: "book.fill")
                        .foregroundColor(.secondary)
                }
            VStack(alignment: .leading, spacing: 6.0) {
                Text(displayBook.name)
                    .appThemeText(.title)
                if let author = displayBook.author {
                    Label(author, systemImage: "person.fill")
                        .appThemeText(.caption, opacity: 0.7)
                }
                // 源状态域（"源变量" L3597 域交叉）。
                HStack(spacing: 6.0) {
                    SourceFeatureTag(
                        title: hasLogin ? "已登录" : "未登录",
                        enabled: hasLogin)
                    if let storage = displayBook.sourceStorageKind {
                        Text(storage.label)
                            .appThemeText(.caption, opacity: 0.6)
                    }
                }
                // "更新于 " L8090 域确证。
                if let update = displayBook.lastChapter {
                    Text("更新于 \(update)")
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    /// metadataBar（0x1004b6c70 L560-576 域确证）。
    private var metadataBar: some View {
        HStack(spacing: 8.0) {
            groupMetadataItem
            metadataDivider
            bookTypeMetadataItem
            metadataDivider
            updateMetadataItem
        }
        .padding(.vertical, 6.0)
    }

    /// metadataDivider（0x1004c8628 L578-582 域确证）。
    private var metadataDivider: some View {
        Divider().frame(height: 24.0)
    }

    /// metadataLabel(icon:title:value:color:)（签名确证）。
    private func metadataLabel(
        icon: String, title: String, value: String, color: Color
    ) -> some View {
        HStack(spacing: 6.0) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1.0) {
                Text(title)
                    .appThemeText(.caption, opacity: 0.6)
                Text(value)
                    .appThemeText(.caption)
            }
        }
    }

    /// groupMetadataItem（0x1004c2f18 L584-597 域确证）。
    private var groupMetadataItem: some View {
        metadataLabel(
            icon: "folder.fill", title: "分组",
            value: normalizedBookshelfGroupName(displayBook.group),
            color: .blue)
    }

    /// bookTypeMetadataItem（0x1004df6ec L599-621 域确证）。
    private var bookTypeMetadataItem: some View {
        metadataLabel(
            icon: currentBookTypeOption.icon,
            title: "类型", value: currentBookTypeOption.title,
            color: currentBookTypeOption.color)
    }

    /// updateMetadataItem（0x1004c3998 L623-636 域确证；"skipUpdate" L3058）。
    private var updateMetadataItem: some View {
        metadataLabel(
            icon: displayBook.skipUpdate == true ? "bell.slash" : "bell.fill",
            title: "更新", value: updateToggleValue, color: .orange)
    }

    // MARK: 动作行

    /// actionButtonsRow（签名确证；"开始阅读" L4660 + "书架" L4967 域）。
    private var actionButtonsRow: some View {
        HStack(spacing: 10.0) {
            Button {
                onRead(displayBook)
            } label: {
                Label("开始阅读", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                if isInBookshelf {
                    deleteConfirmBook = displayBook
                } else {
                    // TODO(T-601-01): BookService 加入书架。
                }
            } label: {
                Label(
                    isInBookshelf ? "在书架" : "书架",
                    systemImage: isInBookshelf ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: 章节

    /// chapterOverview（0x1004b6e04 L705-782 域确证）。
    @ViewBuilder
    private var chapterOverview: some View {
        infoCard(icon: "list.bullet", title: "目录") {
            if isLoadingChapters {
                HStack(spacing: 8.0) {
                    ProgressView()
                    Text("加载目录中...")
                        .appThemeText(.caption, opacity: 0.6)
                }
            } else if chapters.isEmpty {
                Text("暂无目录信息")
                    .appThemeText(.caption, opacity: 0.6)
            } else {
                let visible = chaptersExpanded
                    ? chapters : Array(chapters.prefix(6))
                ForEach(
                    Array(visible.enumerated()), id: \.1.index
                ) { index, chapter in
                    chapterRow(
                        chapter,
                        label: chapter.name,
                        isFirst: index == 0 && !chaptersExpanded,
                        isLast: index == visible.count - 1)
                }
                Button {
                    chaptersExpanded.toggle()
                } label: {
                    // "展开全部" L6626 域确证。
                    Text(chaptersExpanded ? "收起" : "展开全部")
                        .appThemeText(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// chapterRow（0x1004cabbc L784-807 域确证；"lock.fill" L8459 VIP 域）。
    @ViewBuilder
    private func chapterRow(
        _ chapter: Chapter, label: String, isFirst: Bool, isLast: Bool
    ) -> some View {
        Button {
            readFromChapter(chapter)
        } label: {
            HStack {
                Text(label)
                    .lineLimit(1)
                Spacer()
                if chapter.isVip || chapter.showsLockedIndicator {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6.0)
        }
        .buttonStyle(.plain)
    }

    /// readFromChapter（0x1004ba124 L809-830 域确证）。
    private func readFromChapter(_ chapter: Chapter) {
        var target = displayBook
        target.durChapterTitle = chapter.name
        onRead(target)
    }

    // MARK: 换源卡

    /// inlineSourcesCard（0x1004b83c0 L877-925 域确证）。
    @ViewBuilder
    private var inlineSourcesCard: some View {
        infoCard(icon: "arrow.triangle.swap", title: "换源") {
            VStack(spacing: 4.0) {
                ForEach(
                    Array(inlineSourceRows.enumerated()), id: \.1.bookUrl
                ) { index, candidate in
                    inlineSourceRow(
                        candidate,
                        isLast: index == inlineSourceRows.count - 1)
                }
                if shouldShowInlineSourceOverflowButton {
                    // "查看全部 N 个来源" L10312 + L9806 域确证。
                    Button {
                        // TODO(T-601-01): 换源列表页接入（ChangeSourceView）。
                    } label: {
                        Text("查看全部 \(inlineSourceTotalCount) 个来源")
                            .appThemeText(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    /// inlineSourceRow（0x1004ddfdc L928-998 域确证）。
    @ViewBuilder
    private func inlineSourceRow(_ candidate: Book, isLast: Bool) -> some View {
        Button {
            Task { await refreshAfterSourceChange(candidate) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2.0) {
                    HStack(spacing: 6.0) {
                        Text(sourceName(for: candidate))
                            .lineLimit(1)
                        if let kind = candidate.sourceStorageKind {
                            sourceModeTag(for: kind)
                        }
                    }
                    if let latest = candidate.latestChapter {
                        Text(latest)
                            .appThemeText(.caption, opacity: 0.6)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if candidate.bookUrl == displayBook.bookUrl {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 6.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// sourceModeTag(for:)（0x1004cedc4 L1001-1019 域确证）。
    @ViewBuilder
    private func sourceModeTag(for kind: StorageKind) -> some View {
        Text(kind.label)
            .appThemeText(.caption)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 1.0)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(4, antialiased: true)
    }

    /// sourceName(for:)（签名确证）。
    private func sourceName(for book: Book) -> String {
        guard let url = book.bookSourceUrl else { return "未知来源" }
        return sourceService.bookSources.first {
            $0.bookSourceUrl == url
        }?.bookSourceName ?? simplifiedBookSourceUrl(url)
    }

    /// simplifiedBookSourceUrl（签名确证；"https://" L9457 域确证）。
    private func simplifiedBookSourceUrl(_ url: String) -> String {
        var trimmed = url
        for prefix in ["https://", "http://"] where trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    /// sourceName getter（签名确证）。
    private var sourceName: String? {
        bookSource?.bookSourceName
    }

    // MARK: 菜单

    /// moreMenu（0x1004db150 L364-436 域确证；七按钮 TupleView 域确证）。
    private var moreMenu: some View {
        Menu {
            // "配置登录" L3546。
            Button {
                // TODO(T-401-06): SourceLoginView 接入（source:sourceStateSource）。
            } label: {
                Label("配置登录", systemImage: "person.badge.key")
            }
            // "源变量" L3597。
            Button {
                sourceVariableText = currentSourceVariable()
                showVariableEditor = true
            } label: {
                Label("源变量", systemImage: "variable")
            }
            // "书籍变量" L3648。
            Button {
                bookVariableText = displayBook.variable ?? ""
                showBookVariableEditor = true
            } label: {
                Label("书籍变量", systemImage: "book.closed")
            }
            // "更多书架操作" @ptr L3708。
            Button {
                showGroupPicker = true
            } label: {
                Label("更多书架操作", systemImage: "folder.badge.gearshape")
            }
            // "在浏览器中打开" @ptr L13066。
            Button {
                if let url = URL(string: displayBook.bookUrl ?? "") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("在浏览器中打开", systemImage: "safari")
            }
            // 类型切换 + 更新跳过（"bookType"/"skipUpdate" 域确证）。
            Menu("书籍类型") {
                ForEach(bookTypeOptions, id: \.value) { option in
                    Button(option.title) {
                        applyBookTypeSelection(option.value)
                    }
                }
            }
            Button {
                toggleSkipUpdate()
            } label: {
                Label(updateToggleValue, systemImage: "bell")
            }
            Divider()
            // "清除源变量" L12144。
            Button(role: .destructive) {
                clearSourceVariable()
            } label: {
                Label("清除源变量", systemImage: "xmark.bin")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    /// applyBookTypeSelection（0x1004babc4 L339-350 域确证）。
    private func applyBookTypeSelection(_ value: Int) {
        // TODO(T-601-01): BookService.bookType 写回（bookType 域确证）。
    }

    /// toggleSkipUpdate（0x1004bdfbc L352-360 域确证；"skipUpdate" L3058）。
    private func toggleSkipUpdate() {
        // TODO(T-601-01): BookService.skipUpdate 写回。
    }

    /// bookshelfGroupPickerTitle getter（签名确证）。
    private var bookshelfGroupPickerTitle: String {
        "选择分组"
    }

    /// bookshelfGroupPicker（分组选择；applyBookshelfGroupSelection 消费）。
    private var bookshelfGroupPicker: some View {
        SourceGroupPickerSheet(
            existingGroups: ["未分组", "在读", "想读"],
            mergeSourceGroup: "") { group in
            applyBookshelfGroupSelection(group)
        }
    }

    /// applyBookshelfGroupSelection（0x1004b87c8 L527-550 域确证）。
    private func applyBookshelfGroupSelection(_ group: String?) {
        // TODO(T-601-01): BookService.group 写回。
    }

    // MARK: 变量编辑器

    /// variableEditorSheet（0x1004b8298 L1023-1072 域确证；"源变量" L3597）。
    private var variableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("源变量")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $sourceVariableText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveSourceVariable() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("源变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showVariableEditor = false }
                }
            }
        }
    }

    /// bookVariableEditorSheet（0x1004b91a8 L1076-1125 域确证；
    /// "书籍变量 (bookVariable)" @ptr L12675）。
    private var bookVariableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("书籍变量 (bookVariable)")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $bookVariableText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveBookVariable() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("书籍变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showBookVariableEditor = false }
                }
            }
        }
    }

    /// saveSourceVariable（0x1004d0cd0 L1164-1171 域确证）。
    private func saveSourceVariable() {
        // TODO(T-501-01 交叉): RemoteBackendService.setVariable 远端写回。
        showVariableEditor = false
    }

    /// saveBookVariable（0x1004d2be0 L1129-1141 域确证）。
    private func saveBookVariable() {
        // TODO(T-501-01 交叉): RemoteBackendService.setBookVariable 写回。
        showBookVariableEditor = false
    }

    /// clearSourceVariable（"清除源变量" L12144 域确证）。
    private func clearSourceVariable() {
        // TODO(T-501-01 交叉): RemoteBackendService.setVariable 清空。
    }

    // MARK: 信息卡

    /// infoCard(icon:title:content:)（签名确证）。
    @ViewBuilder
    private func infoCard<Content: View>(
        icon: String, title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Label(title, systemImage: icon)
                .appThemeText(.headline)
            content()
        }
        .padding(.all, 12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    /// introCard（签名确证）。
    @ViewBuilder
    private func introCard(_ text: String) -> some View {
        if !text.isEmpty {
            infoCard(icon: "doc.plaintext", title: "简介") {
                Text(text)
                    .appThemeText(.caption, opacity: 0.8)
            }
        }
    }

    // MARK: 主链

    /// loadChapters（0x1004bcc80 L1222-1241 域确证）。
    private func loadChapters() async {
        guard let source = bookSource else { return }
        isLoadingChapters = true
        defer { isLoadingChapters = false }
        do {
            let list = try await sourceService.getChapterList(
                source: source, book: displayBook, needRefresh: false)
            await MainActor.run {
                chapters = list
                syncAuxiliaryState(with: displayBook)
            }
        } catch {
            await MainActor.run {
                chapters = initialChapters ?? []
            }
        }
    }

    /// refreshBookInfo（0x1004bf0b4 L1204-1218 域确证）。
    private func refreshBookInfo() {
        guard let source = bookSource else { return }
        isRefreshingInfo = true
        Task {
            let info = await sourceService.getBookInfo(
                source: source, book: displayBook, canReName: false)
            await MainActor.run {
                isRefreshingInfo = false
                if let info {
                    let merged = mergedFetchedBookWithLocalState(
                        info, base: displayBook)
                    baseBook = merged
                    syncAuxiliaryState(with: merged)
                }
            }
        }
    }

    /// mergedFetchedBookWithLocalState（0x1004bbec0 L1143-1160 域确证）。
    private func mergedFetchedBookWithLocalState(
        _ fetched: Book, base: Book
    ) -> Book {
        var merged = fetched
        merged.group = base.group
        merged.skipUpdate = base.skipUpdate
        merged.bookType = base.bookType
        merged.variable = base.variable
        return merged
    }

    /// syncAuxiliaryState(with:)（0x1004bc170 L1284-1315 域确证）。
    private func syncAuxiliaryState(with book: Book) {
        _ = debugDescribe(book)
        refreshTrackedSearchSourcesFromCache()
    }

    /// refreshAfterSourceChange（0x1004b965c L1175-1200 域确证）。
    private func refreshAfterSourceChange(_ target: Book) async {
        baseBook = target
        chapters = []
        await loadChapters()
    }

    /// observeTrackedSearchSourcesIfNeeded（0x1004bd26c L1329-1344 域确证）。
    private func observeTrackedSearchSourcesIfNeeded() async {
        guard shouldTrackSearchSources else { return }
        let token = trackedSearchObservationKey
        guard token != observedSearchToken else { return }
        observedSearchToken = token
        // 追踪搜索源域（"author="/"bookId=" 诊断域确证）。
        Logger.log(
            "[EXPLORE-DETAIL-DIAG] session=\(diagSession)"
                + " author=\(trackedSourceAuthor ?? "")"
                + " bookUrl=\(displayBook.bookUrl ?? "")"
                + " sourceUrl=\(displayBook.bookSourceUrl ?? "")"
                + " chapters=\(chapters.count)",
            level: .info)
    }

    /// replaceTrackedAvailableSourcesIfNeeded（0x1004bdb34 L1361-1374 域）。
    private func replaceTrackedAvailableSourcesIfNeeded(
        _ candidates: [Book]
    ) {
        let fingerprint = trackedSourcesFingerprint(candidates)
        guard fingerprint != trackedSourcesFingerprint(trackedSources) else {
            return
        }
        trackedSources = Self.deduplicatedSources(candidates)
    }

    /// refreshTrackedSearchSourcesFromCache（0x1004d3684 L1347-1358 域）。
    private func refreshTrackedSearchSourcesFromCache() {
        // 缓存域（ChangeSourceCache T-601-01 交叉登记）。
    }

    // MARK: 去重域

    /// deduplicatedSourceCandidates（0x1004b155c L1261-1271 static 域确证）。
    static func deduplicatedSourceCandidates(
        _ candidates: [Book]
    ) -> [Book] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            let identity = makeSourceIdentity(for: candidate)
            guard !identity.isEmpty else { return false }
            return seen.insert(identity).inserted
        }
    }

    /// deduplicatedSources（0x1004bdda4 L1376-1378 域确证）。
    private func deduplicatedSources(_ candidates: [Book]) -> [Book] {
        Self.deduplicatedSourceCandidates(candidates)
    }

    /// makeSourceIdentity(for:)（0x1004d348c L1257-1259 static 域确证）。
    static func makeSourceIdentity(for book: Book) -> String {
        (book.bookSourceUrl ?? "") + "|" + (book.bookUrl ?? "")
    }

    /// sourceIdentity(for:)（签名确证）。
    private func sourceIdentity(for book: Book) -> String {
        Self.makeSourceIdentity(for: book)
    }

    /// trackedSourcesFingerprint（0x1004d38b4 L1380-1390 域确证；
    /// 三段隐式闭包 name/author/index 确证）。
    private func trackedSourcesFingerprint(_ candidates: [Book]) -> [String] {
        candidates.map { candidate in
            "\(candidate.name)|\(candidate.author ?? "")|"
                + "\(candidate.bookUrl ?? "")"
        }
    }

    // MARK: 诊断

    /// debugDescribe（0x1004bbd70 L1317-1321 域确证）。
    private func debugDescribe(_ book: Book) -> String {
        "[EXPLORE-DETAIL-DIAG] session=\(diagSession)"
            + " author=\(book.author ?? "")"
            + " bookId=\(book.bookUrl ?? "")"
            + " bookUrl=\(book.bookUrl ?? "")"
            + " sourceUrl=\(book.bookSourceUrl ?? "")"
            + " storage=\(book.sourceStorageKind?.rawValue ?? "")"
    }

    /// debugDescribeSource（签名确证）。
    private func debugDescribeSource(_ source: BookSource?) -> String {
        source.map { "source=\($0.bookSourceUrl)" } ?? "source=nil"
    }
}
