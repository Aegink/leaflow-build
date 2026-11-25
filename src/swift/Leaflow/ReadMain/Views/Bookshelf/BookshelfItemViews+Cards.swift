// 原路径: ReadMain/Views/Bookshelf/BookshelfItemViews.swift
// 类型表 7441-7472：选择/编辑状态与删除、阅读、点击回调；原 body 包含动作修饰器。
// 伪代码：BookGridItem 0x10042899c L392-468；BookCardItem 0x10042b194 L523-538。
import SwiftUI

struct BookGridItem: View {
    let book: Book
    let isSelected: Bool
    let isEditing: Bool
    let onDelete: () -> Void
    let onOpenReader: (Book) -> Void
    let onTap: () -> Void
    private let bookService = BookService()

    private var cachedChapterCount: Int {
        ChapterCacheService.shared.getCachedChapterIndices(bookUrl: book.bookUrl ?? "").count
    }
    private var gridProgress: Double { book.readingProgress }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                BookCoverView(book: book).aspectRatio(0.72, contentMode: .fit)
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(4)
                } else if bookService.isPinned(book.id) {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange).padding(4)
                }
            }
            Text(book.name).appThemeText(.caption).lineLimit(2).multilineTextAlignment(.center)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .networkBookActions(book: book, isEnabled: !isEditing, onDelete: onDelete, onOpenReader: onOpenReader)
        .accessibilityValue(isEditing ? isSelected ? "已选择" : "未选择" : "")
    }
}

struct BookCardItem: View {
    let book: Book
    let cardHeight: CGFloat
    let isSelected: Bool
    let isEditing: Bool
    let onDelete: () -> Void
    let onOpenReader: (Book) -> Void
    let onTap: () -> Void

    private var cachedChapterCount: Int {
        ChapterCacheService.shared.getCachedChapterIndices(bookUrl: book.bookUrl ?? "").count
    }
    private var cachedLatestChapter: String? { book.lastChapter }
    private var listCardLayout: BookshelfListCardLayout { .init(cardHeight: cardHeight) }
    private var displaysTags: Bool { !listCardLayout.hidesTags }
    private var categoryTag: String { book.kind?.components(separatedBy: ",").first ?? "" }
    private var accurateProgress: Double { book.readingProgress }
    private var accurateProgressText: String { "已读 \(Int(accurateProgress * 100))%" }
    private var progressLeadingInset: CGFloat { listCardLayout.coverWidth + 10 }

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            cardContent
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .networkBookActions(book: book, isEnabled: !isEditing, onDelete: onDelete, onOpenReader: onOpenReader)
        .accessibilityValue(isEditing ? isSelected ? "已选择" : "未选择" : "")
    }

    // 0x10042b524 L542-609：封面、名称/作者、章节细项与标签消费。
    private var cardContent: some View {
        HStack(spacing: 10) {
            BookCoverView(book: book)
                .frame(width: listCardLayout.coverWidth, height: listCardLayout.coverHeight)
                .bookshelfCoverCornerClip()
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name).lineLimit(listCardLayout.titleLineLimit)
                if let author = book.author {
                    Text(author).appThemeText(.caption, opacity: 0.6).lineLimit(1)
                }
                chapterDetails
                if displaysTags, !categoryTag.isEmpty { BookTagBadge(title: categoryTag) }
            }
            Spacer()
        }
    }

    // 0x10042d8b8 L623-649：最新章与缓存章数。
    @ViewBuilder private var chapterDetails: some View {
        if let latest = cachedLatestChapter { chapterInfoRow(systemImage: "book", text: "最新章节: \(latest)") }
        if cachedChapterCount > 0 {
            chapterInfoRow(systemImage: "arrow.down.circle", text: "已缓存 \(cachedChapterCount) 章")
        }
    }
    private func chapterInfoRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.caption2).foregroundStyle(.secondary)
            Text(text).appThemeText(.caption, opacity: 0.6).lineLimit(1)
        }
    }
}
