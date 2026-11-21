// 原路径: ReadMain/Views/Bookshelf/LocalBookActionSheetView.swift
// 证据:
//   - PGO: 35 条记录（index/task_functions.csv T-601-06 /
//     LocalBookActionSheetView.swift；伪代码域 2474 行）。关键域：
//     body（padding 双段 + Spacer 域确证）/ bookInfoCard / actionButtons
//     签名确证；'kActionSheetView.swift' @ptr L412/"》吗？" L416/
//     "pin.slash" L1620/"arrow.clockwise" L1789+"重新分章" L1791 域确证
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     LocalBookActionSheetView.c（2474 行）
//   - 事实：本地书操作面板（bookInfoCard + actionButtons 双段；
//     重新分章域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（域串确证）
// 还原: 2026-11-20

import SwiftUI

/// 本地书操作面板。
struct LocalBookActionSheetView: View {

    let book: LocalBook
    let onRead: (LocalBook) -> Void
    let onDelete: (LocalBook) -> Void

    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private let localBookService = LocalBookService.shared

    var body: some View {
        // body（padding 双段 + Spacer 域确证）。
        NavigationStack {
            ScrollView {
                VStack(spacing: 12.0) {
                    bookInfoCard
                    actionButtons
                }
                .padding(.all, 12.0)
            }
            .navigationTitle(book.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog(
                "确定要删除《\(book.name)》吗？",
                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("确认删除", role: .destructive) {
                    onDelete(book)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: 信息卡（签名域确证）

    private var bookInfoCard: some View {
        HStack(spacing: 10.0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 50.0, height: 70.0)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundColor(.secondary)
                }
            VStack(alignment: .leading, spacing: 4.0) {
                Text(book.name)
                    .appThemeText(.headline)
                if let author = book.author {
                    Text(author)
                        .appThemeText(.caption, opacity: 0.6)
                }
                Text(book.displayFormat)
                    .appThemeText(.caption, opacity: 0.5)
                Text(book.readingProgressText)
                    .appThemeText(.caption, opacity: 0.6)
            }
            Spacer()
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    // MARK: 动作按钮（签名域确证）

    private var actionButtons: some View {
        VStack(spacing: 8.0) {
            Button {
                onRead(book)
            } label: {
                Label("开始阅读", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                Task {
                    _ = await localBookService.reparseChapters(book)
                }
            } label: {
                // "arrow.clockwise"+"重新分章" L1789+L1791 域确证。
                Label("重新分章", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            Button {
                localBookService.markAsReading(
                    bookId: book.id.uuidString)
            } label: {
                Label("置顶", systemImage: "pin.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            Button {
                localBookService.setBookGroup(
                    bookId: book.id.uuidString, groupName: "未分组")
            } label: {
                Label("移动到分组", systemImage: "folder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
    }
}
