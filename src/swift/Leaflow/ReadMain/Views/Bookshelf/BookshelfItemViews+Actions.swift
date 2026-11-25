// 原路径: ReadMain/Views/Bookshelf/BookshelfItemViews.swift
// 类型表 7403-7408：操作表与待阅读书；33864：长按、sheet、关闭后调度。
// 伪代码 0x10042746c L327-352 / 0x100427cb0 L354-361。
import SwiftUI

struct NetworkBookActionsModifier: ViewModifier {
    let book: Book
    let isEnabled: Bool
    let onDelete: () -> Void
    let onOpenReader: (Book) -> Void
    @State private var showActionSheet = false
    @State private var pendingReaderBook: Book?

    func body(content: Content) -> some View {
        content
            .onLongPressGesture {
                guard isEnabled else { return }
                pendingReaderBook = nil
                showActionSheet = true
            }
            .sheet(isPresented: $showActionSheet, onDismiss: schedulePendingReaderOpenIfPossible) {
                BookActionSheetView(book: book, onRead: { selected in
                    pendingReaderBook = selected
                    showActionSheet = false
                }, onDelete: { _ in
                    pendingReaderBook = nil
                    showActionSheet = false
                    onDelete()
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: book.id) { _, _ in
                pendingReaderBook = nil
                showActionSheet = false
            }
    }

    private func schedulePendingReaderOpenIfPossible() {
        // 只在 sheet 真正关闭后消费一次，避免阅读器与操作表同时呈现。
        guard let selected = NetworkBookReaderRequest.takePending(
            isPresented: showActionSheet, pending: &pendingReaderBook) else { return }
        onOpenReader(selected)
    }
}

enum NetworkBookReaderRequest {
    static func takePending(isPresented: Bool, pending: inout Book?) -> Book? {
        guard !isPresented else { return nil }
        defer { pending = nil }
        return pending
    }
}

extension View {
    func networkBookActions(book: Book, isEnabled: Bool = true,
        onDelete: @escaping () -> Void, onOpenReader: @escaping (Book) -> Void) -> some View {
        modifier(NetworkBookActionsModifier(book: book, isEnabled: isEnabled,
            onDelete: onDelete, onOpenReader: onOpenReader))
    }
}
