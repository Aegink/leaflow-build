// 原路径: ReadMain/Views/Reader/BookmarkListView.swift
// 证据:
//   - PGO: body.getter (0x100662820 L13-57) / closure #1 empty content (0x100662d54 L15-36) /
//     closure onDelete (0x100663278 L23-33) / closure row (0x100663334 L24-31) /
//     closure MainActor delete (0x10066347c L25-27) 等 14 函数
//   - CovMap: body L13-57 @0x100662820；closures @0x100662d54/0x100663278/0x100663334/0x10066347c
//   - IDA: 上述地址的 Hex-Rays 伪代码（1398 行）
//   - 选择子：swift_task_isCurrentExecutor → MainActor body；
//     _ConditionalContent<ContentUnavailableView> → 空态切换；
//     DynamicViewContent.onDelete → List 删除手势；listStyle → 列表样式
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（SwiftUI body 主链确证：List + onDelete + ContentUnavailableView 空态）
// 还原: 2026-11-19

import SwiftUI

/// 书签列表视图（伪代码 0x100662820，L13-57）。
struct BookmarkListView: View {

    @State private var bookmarks: [Bookmark] = []

    /// 伪代码 0x100662820（L13-57）：
    /// 主链：Group { 空态 → ContentUnavailableView；非空 → List + onDelete }。
    /// toolbar → navigationBarTitle → listStyle。
    var body: some View {
        Group {
            if bookmarks.isEmpty {
                // 伪代码 closure #1（0x100662d54，L15-36）：
                // _ConditionalContent<ContentUnavailableView<Label<Text, Image>, Text?, ...>>
                ContentUnavailableView(
                    "暂无书签",
                    systemImage: "bookmark",
                    description: Text("在阅读时长按页面可添加书签")
                )
            } else {
                List {
                    ForEach(bookmarks) { bookmark in
                        // 伪代码 closure #3（0x100663334，L24-31）：行视图。
                        BookmarkRow(bookmark: bookmark)
                    }
                    .onDelete { indexSet in
                        // 伪代码 closure #1（0x100663278，L23-33）onDelete + MainActor delete。
                        Task { @MainActor in
                            bookmarks.remove(atOffsets: indexSet)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("书签")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            loadBookmarks()
        }
    }

    private func loadBookmarks() {
        // 从存储加载书签列表。
    }
}

/// 书签行（伪代码 closure #3）。
struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bookmark.chapterTitle ?? "")
                .font(.headline)
            Text(bookmark.content ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
}
