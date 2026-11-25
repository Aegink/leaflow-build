// 原路径: ReadMain/Views/Bookshelf/LocalBookItemViews.swift
// 证据:
//   - PGO: 64 条记录（index/task_functions.csv T-601-07 /
//     LocalBookItemViews.swift；伪代码域 3912 行）。关键地址：
//     LocalBookGridItem.body 0x1004a5d98 L16-94 / LocalBookCardItem
//     .listCardLayout 0x1004a7cfc L114-116 + displaysTags（签名）+
//     body 0x1004a83c8 L122-143；'kItemViews.swift' @ptr L1309 域
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     LocalBookItemViews.c（3912 行）
//   - 字符串域（位模式/指针）："pin.fill" L404/"bookmark.fill" L2489/
//     "阅读章节" L2557/"最新章节" L2672/'low/BookshelfItemViews.swift:'
//     @ptr L2537 域（BookshelfItemViews 交叉确证）
//   - 事实：双布局域（LocalBookGridItem + LocalBookCardItem 对应
//     BookGridItem/BookCardItem T-601-05 交叉确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 交叉确证）
// 还原: 2026-11-20

import SwiftUI

struct LocalBookActionsModifier: ViewModifier {
    let book: LocalBook
    let onRead: (LocalBook) -> Void
    let onDelete: (LocalBook) -> Void
    @State private var showActions = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture { showActions = true }
            .sheet(isPresented: $showActions) {
                LocalBookActionSheetView(book: book,
                    onRead: {
                        showActions = false
                        onRead($0)
                    }, onDelete: onDelete)
            }
    }
}

extension View {
    func localBookActions(book: LocalBook,
        onRead: @escaping (LocalBook) -> Void,
        onDelete: @escaping (LocalBook) -> Void) -> some View {
        modifier(LocalBookActionsModifier(
            book: book, onRead: onRead, onDelete: onDelete))
    }
}

/// 本地书网格项（0x1004a5d98 L16-94 域确证）。
struct LocalBookGridItem: View {
    let book: LocalBook

    var body: some View {
        // 0x1004a5d98 L16-94 域确证。
        VStack(spacing: 4.0) {
            ZStack(alignment: .bottom) {
                LocalBookCoverImage(
                    bookId: book.id.uuidString, title: book.name,
                    author: book.author, fileType: book.displayFormat)
                    .frame(height: 110.0)
                    .bookshelfCoverCornerClip()
                VStack {
                    Spacer()
                    Text(book.readingProgressText)
                        .appThemeText(.caption, opacity: 0.7)
                        .padding(.horizontal, 6.0)
                        .padding(.vertical, 2.0)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4, antialiased: true)
                        .padding(.bottom, 4.0)
                }
            }
            Text(book.name)
                .appThemeText(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

/// 本地书列表卡片项（0x1004a83c8 L122-143 域确证）。
struct LocalBookCardItem: View {
    let book: LocalBook

    /// listCardLayout getter（0x1004a7cfc L114-116 域确证）。
    private var listCardLayout: BookshelfListCardLayout {
        BookshelfListCardLayout(cardHeight: 72.0)
    }

    /// displaysTags getter（签名确证）。
    private var displaysTags: Bool {
        !listCardLayout.hidesTags
    }

    var body: some View {
        // 0x1004a83c8 L122-143 域确证。
        HStack(spacing: 10.0) {
            LocalBookCoverImage(
                bookId: book.id.uuidString, title: book.name,
                author: book.author, fileType: book.displayFormat)
                .frame(
                    width: listCardLayout.coverWidth,
                    height: listCardLayout.coverHeight)
                .bookshelfCoverCornerClip()
            VStack(alignment: .leading, spacing: 4.0) {
                Text(book.name)
                    .lineLimit(listCardLayout.titleLineLimit)
                if let author = book.author {
                    Text(author)
                        .appThemeText(.caption, opacity: 0.6)
                }
                Text("格式: \(book.displayFormat)")
                    .appThemeText(.caption, opacity: 0.5)
                Text(book.readingProgressText)
                    .appThemeText(.caption, opacity: 0.6)
            }
            Spacer()
        }
        .padding(.vertical, 4.0)
    }
}

extension LocalBookCardItem {

    /// 伪代码 0x100911ed0（L106）：标签显隐 varinit（计数器桩；设置联动
    /// 推断）。
    var showsTags: Bool {
        true
    }
}

