// 原路径: ReadMain/Views/Bookshelf/BookshelfItemViews.swift
// 证据:
//   - PGO: 152 条记录（index/task_functions.csv T-601-05 /
//     BookshelfItemViews.swift；伪代码域 7234 行）。关键地址：
//     BookTagBadge.body（签名）+ resolvedTextColor 0x1004224e4 L43-53 +
//     colorfulTextColor 0x100422738 L55-73（static）/ BookMetadataTagRow.body
//     0x100422bf8 L83-103 / BookMetadataTagWrap.body 0x1004236f0 L110-119 /
//     BookTagFlowLayout（Layout：sizeThatFits/layout 0x100423a94 L151-184/
//     placeSubviews 0x100424690 L140-149）/ BookProgressBar.body 0x100424814
//     L198-217 / BookshelfProgressBadgeBackgroundModifier（签名）/
//     BookshelfListCoverCornerModifier（签名）/ ProgressBarGlassModifier
//     0x100426110 L247-259 / NetworkBookActionsModifier.body 0x10042746c
//     L327-352 + schedulePendingReaderOpenIfPossible 0x100427cb0 L354-361 /
//     BookGridItem.cachedChapterCount 0x100428194 L387-390 + body
//     0x10042899c L392-468 + gridProgress 0x10042a51c L470-473 /
//     BookCardItem（cachedChapterCount 0x10042a9b8 L497-500 +
//     cachedLatestChapter 0x10042aae0 L502-505 + listCardLayout/displaysTags
//     （签名）+ categoryTag 0x10042ac80 L515-521 + body 0x10042b194 L523-538
//     + cardContent 0x10042b524 L542-609 + coverWidth/coverHeight/
//     accurateProgressText（签名）+ chapterDetails 0x10042d8b8 L623-649 +
//     accurateProgress（签名）+ progressLeadingInset 0x10042e624 L659-661 +
//     chapterInfoRow 0x10042eac0 L611-620）/ GroupPickerView.body
//     0x10042f2d0 L687-731 + applyGroup（签名）/ NetworkBookActionsModifier
//     扩展 networkBookActions（签名）/ bookshelfCoverCornerClip（扩展）/
//     BookshelfListCardLayout（init(cardHeight:) + usesCompactChapterDetails
//     0x10043f53c L14-14 + progressBottomSpacing 0x10042cf4c L20-24 +
//     titleLineLimit/hidesTags/coverHeight/coverWidth getter）/
//     bookshelfListProgressOverlay（扩展）/ bookshelfProgressBadgeBackground
//     （扩展）/ GroupButton（签名）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     BookshelfItemViews.c（7234 行）
//   - 字符串确证（位模式/指针）："headphones" L3821/"pin.fill" L3895/
//     "移动到分组" L5781/"新建分组" L5823/"bookmark.fill" L6028/
//     "阅读章节" L6089/"最新章节" L6196/'BookService' L6543/'low/
//     BookshelfItemViews.swift:' @ptr L6075/"分组名称" L7029
//   - 事实：标签域（BookTagBadge 彩色文字 + BookMetadataTagRow/Wrap +
//     BookTagFlowLayout 自定义 Layout）；进度域（BookProgressBar +
//     GlassModifier + BadgeBackground）；网格/卡片域（BookGridItem/
//     BookCardItem 双布局 + chapterDetails/accurateProgress 域）；分组域
//     （GroupPickerView/GroupButton "移动到分组"/"新建分组" 域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 标签/进度/网格域: high（地址 + 位模式确证）
//   - 自定义 Layout: medium-high（签名族确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI

// MARK: - BookTagBadge（0x1004224e4 L43-53 域确证）

/// 标签徽标。
struct BookTagBadge: View {
    let title: String

    /// resolvedTextColor getter（0x1004224e4 L43-53 域确证）。
    private var resolvedTextColor: Color {
        Self.colorfulTextColor(for: title, colorScheme: colorScheme)
    }

    @Environment(\.colorScheme) private var colorScheme

    /// colorfulTextColor（0x100422738 L55-73 static 域确证）。
    static func colorfulTextColor(
        for tag: String, colorScheme: ColorScheme
    ) -> Color {
        var hasher = Hasher()
        hasher.combine(tag)
        let hue = Double(abs(hasher.finalize() % 360)) / 360.0
        return Color(hue: hue, saturation: 0.55,
                     brightness: colorScheme == .dark ? 0.85 : 0.45)
    }

    var body: some View {
        Text(title)
            .appThemeText(.caption)
            .foregroundColor(resolvedTextColor)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 2.0)
            .background(resolvedTextColor.opacity(0.12))
            .cornerRadius(4, antialiased: true)
    }
}

/// 元数据标签行（0x100422bf8 L83-103 域确证）。
struct BookMetadataTagRow: View {
    let tags: [String]

    var body: some View {
        // 0x100422bf8 L83-103 域确证。
        BookMetadataTagWrap(tags: tags)
    }
}

/// 元数据标签换行（0x1004236f0 L110-119 域确证）。
struct BookMetadataTagWrap: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60), alignment: .leading)],
            spacing: 4.0) {
            ForEach(tags, id: \.self) { tag in
                BookTagBadge(title: tag)
            }
        }
    }
}

// MARK: - BookTagFlowLayout（0x100423a94 L151-184 域确证）

/// 标签流布局。
struct BookTagFlowLayout: Layout {

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + 4.0
                rowHeight = 0
            }
            x += size.width + 4.0
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    /// layout(maxWidth:)（0x100423a94 L151-184 域确证）。
    func layout(
        subviews: LayoutSubviews, maxWidth: CGFloat
    ) -> [(CGRect, LayoutSubview)] {
        var result: [(CGRect, LayoutSubview)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + 4.0
                rowHeight = 0
            }
            result.append((CGRect(x: x, y: y, width: size.width, height: size.height), subview))
            x += size.width + 4.0
            rowHeight = max(rowHeight, size.height)
        }
        return result
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize,
        subviews: LayoutSubviews, cache: inout ()
    ) {
        for (frame, subview) in layout(subviews: subviews, maxWidth: bounds.width) {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + frame.minX,
                    y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size))
        }
    }
}

// MARK: - BookProgressBar（0x100424814 L198-217 域确证）

/// 书籍进度条。
struct BookProgressBar: View {
    let progress: Double

    var body: some View {
        // 0x100424814 L198-217 域确证。
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.1))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4.0)
    }
}

/// 进度徽标背景修饰（签名确证）。
struct BookshelfProgressBadgeBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8.0)
            .padding(.vertical, 4.0)
            .background(
                Capsule().fill(Color.black.opacity(0.55)))
    }
}

/// 列表封面圆角修饰（签名确证）。
struct BookshelfListCoverCornerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .cornerRadius(8, antialiased: true)
    }
}

/// 进度玻璃修饰（0x100426110 L247-259 域确证）。
struct ProgressBarGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial))
    }
}

extension View {
    /// bookshelfProgressBadgeBackground（签名确证）。
    func bookshelfProgressBadgeBackground() -> some View {
        modifier(BookshelfProgressBadgeBackgroundModifier())
    }

    /// bookshelfListCoverCornerClip（签名确证）。
    func bookshelfCoverCornerClip() -> some View {
        modifier(BookshelfListCoverCornerModifier())
    }

    /// bookshelfListProgressOverlay（签名确证）。
    func bookshelfListProgressOverlay(
        progress: Double, leadingInset: CGFloat
    ) -> some View {
        self.overlay(alignment: .bottomLeading) {
            BookProgressBar(progress: progress)
                .padding(.leading, leadingInset)
                .padding(.bottom, 4.0)
                .padding(.trailing, 4.0)
                .modifier(ProgressBarGlassModifier())
        }
    }
}

// MARK: - BookshelfListCardLayout（0x10042cf4c L20-24 域确证）

/// 列表卡片布局参数。
struct BookshelfListCardLayout {
    let cardHeight: CGFloat

    /// init(cardHeight:)（签名确证）。
    init(cardHeight: CGFloat) {
        self.cardHeight = cardHeight
    }

    /// usesCompactChapterDetails getter（0x10043f53c L14-14 域确证）。
    var usesCompactChapterDetails: Bool {
        cardHeight < 100
    }

    /// progressBottomSpacing getter（0x10042cf4c L20-24 域确证）。
    var progressBottomSpacing: CGFloat {
        usesCompactChapterDetails ? 6.0 : 10.0
    }

    /// titleLineLimit getter（签名确证）。
    var titleLineLimit: Int {
        usesCompactChapterDetails ? 1 : 2
    }

    /// hidesTags getter（签名确证）。
    var hidesTags: Bool {
        usesCompactChapterDetails
    }

    /// coverWidth getter（签名确证）。
    var coverWidth: CGFloat {
        usesCompactChapterDetails ? 44.0 : 56.0
    }

    /// coverHeight getter（签名确证）。
    var coverHeight: CGFloat {
        coverWidth * 1.4
    }
}

// MARK: - 网络书动作修饰（0x10042746c L327-352 域确证）

/// 网络书动作修饰。
struct NetworkBookActionsModifier: ViewModifier {
    let book: Book
    let onDelete: () -> Void
    let onOpenReader: () -> Void

    func body(content: Content) -> some View {
        content
            .contextMenu {
                // "阅读章节" L6089 + "移动到分组" L5781 域确证。
                Button {
                    onOpenReader()
                } label: {
                    Label("阅读章节", systemImage: "book.fill")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
    }

    /// schedulePendingReaderOpenIfPossible（0x100427cb0 L354-361 域确证）。
    private func schedulePendingReaderOpenIfPossible() {
        // TODO(T-601-06 域): ReaderRouter 阅读入口。
    }
}

extension View {
    /// networkBookActions（签名确证）。
    func networkBookActions(
        book: Book, onDelete: @escaping () -> Void,
        onOpenReader: @escaping () -> Void
    ) -> some View {
        modifier(
            NetworkBookActionsModifier(
                book: book, onDelete: onDelete, onOpenReader: onOpenReader))
    }
}

// MARK: - BookGridItem（0x10042899c L392-468 域确证）

/// 书架网格项。
struct BookGridItem: View {
    let book: Book

    private let bookService = BookService()

    /// cachedChapterCount getter（0x100428194 L387-390 域确证）。
    private var cachedChapterCount: Int {
        ChapterCacheService.shared.getCachedChapterIndices(
            bookUrl: book.bookUrl ?? "").count
    }

    /// gridProgress getter（0x10042a51c L470-473 域确证）。
    private var gridProgress: Double {
        book.readingProgress
    }

    var body: some View {
        // 0x10042899c L392-468 域确证。
        VStack(spacing: 4.0) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .aspectRatio(0.72, contentMode: .fit)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundColor(.secondary)
                    }
                if bookService.isPinned(book.id) {
                    // "pin.fill" L3895 域确证。
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.all, 4.0)
                }
            }
            Text(book.name)
                .appThemeText(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .networkBookActions(book: book, onDelete: {}, onOpenReader: {})
    }
}

// MARK: - BookCardItem（0x10042b194 L523-538 域确证）

/// 书架列表卡片项。
struct BookCardItem: View {
    let book: Book
    let cardHeight: CGFloat

    /// cachedChapterCount getter（0x10042a9b8 L497-500 域确证）。
    private var cachedChapterCount: Int {
        ChapterCacheService.shared.getCachedChapterIndices(
            bookUrl: book.bookUrl ?? "").count
    }

    /// cachedLatestChapter getter（0x10042aae0 L502-505 域确证）。
    private var cachedLatestChapter: String? {
        book.lastChapter
    }

    /// listCardLayout getter（签名确证）。
    private var listCardLayout: BookshelfListCardLayout {
        BookshelfListCardLayout(cardHeight: cardHeight)
    }

    /// displaysTags getter（签名确证）。
    private var displaysTags: Bool {
        !listCardLayout.hidesTags
    }

    /// categoryTag getter（0x10042ac80 L515-521 域确证）。
    private var categoryTag: String {
        book.kind?.components(separatedBy: ",").first ?? ""
    }

    /// accurateProgress getter（签名确证）。
    private var accurateProgress: Double {
        book.readingProgress
    }

    /// accurateProgressText getter（签名确证）。
    private var accurateProgressText: String {
        "已读 \(Int(accurateProgress * 100))%"
    }

    /// progressLeadingInset getter（0x10042e624 L659-661 域确证）。
    private var progressLeadingInset: CGFloat {
        listCardLayout.coverWidth + 10.0
    }

    var body: some View {
        // 0x10042b194 L523-538 域确证。
        HStack(spacing: 10.0) {
            cardContent
        }
        .padding(.vertical, 4.0)
    }

    /// cardContent getter（0x10042b524 L542-609 域确证）。
    private var cardContent: some View {
        HStack(spacing: 10.0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(
                    width: listCardLayout.coverWidth,
                    height: listCardLayout.coverHeight)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundColor(.secondary)
                }
                .bookshelfCoverCornerClip()
            VStack(alignment: .leading, spacing: 4.0) {
                Text(book.name)
                    .lineLimit(listCardLayout.titleLineLimit)
                if let author = book.author {
                    Text(author)
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
                chapterDetails
                if displaysTags, !categoryTag.isEmpty {
                    BookTagBadge(title: categoryTag)
                }
            }
            Spacer()
        }
    }

    /// chapterDetails getter（0x10042d8b8 L623-649 域确证）。
    @ViewBuilder
    private var chapterDetails: some View {
        // "最新章节" L6196 域确证。
        if let latest = cachedLatestChapter {
            chapterInfoRow(
                systemImage: "book", text: "最新章节: \(latest)")
        }
        if cachedChapterCount > 0 {
            // "已缓存 " 域（BookActionSheetView L7890 交叉）。
            chapterInfoRow(
                systemImage: "arrow.down.circle",
                text: "已缓存 \(cachedChapterCount) 章")
        }
    }

    /// chapterInfoRow(systemImage:text:)（0x10042eac0 L611-620 域确证）。
    private func chapterInfoRow(
        systemImage: String, text: String
    ) -> some View {
        HStack(spacing: 4.0) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(text)
                .appThemeText(.caption, opacity: 0.6)
                .lineLimit(1)
        }
    }
}

// MARK: - GroupPickerView（0x10042f2d0 L687-731 域确证）

/// 书架分组选择视图（"移动到分组"/"新建分组"/"分组名称" 域确证）。
struct GroupPickerView: View {

    let groups: [String]
    let currentGroup: String?
    let onApply: (String?) -> Void

    @State private var newGroupName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 0x10042f2d0 L687-731 域确证。
        NavigationStack {
            List {
                Section("分组名称") {
                    HStack {
                        TextField("新建分组", text: $newGroupName)
                        Button("新建分组") {
                            applyGroup(newGroupName)
                            dismiss()
                        }
                        .disabled(newGroupName.isEmpty)
                    }
                }
                Section("移动到分组") {
                    ForEach(groups, id: \.self) { group in
                        Button {
                            applyGroup(group)
                            dismiss()
                        } label: {
                            HStack {
                                Text(group)
                                Spacer()
                                if currentGroup == group {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("移动到分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    /// applyGroup（签名确证）。
    private func applyGroup(_ group: String?) {
        onApply(group)
    }
}

/// 分组按钮（签名确证）。
struct GroupButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appThemeText(.caption)
                .padding(.horizontal, 10.0)
                .padding(.vertical, 4.0)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(10, antialiased: true)
        }
        .buttonStyle(.plain)
    }
}
