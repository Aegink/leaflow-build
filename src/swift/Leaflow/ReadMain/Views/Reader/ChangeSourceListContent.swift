// 原路径: ReadMain/Views/Reader/ChangeSourceListContent.swift
// 证据:
//   - PGO: body.getter (0x100670c9c L15-21) / emptyContent (0x100671078 L23-31) /
//     resultsSection (0x100670900 L33-41) / resultRow closure (0x100671520 L35-37) /
//     resultRow(for:) (0x10067156c L43-57) / sectionHeader (L34-40) / searchingIndicator /
//     headerTitle / rowBackground(isCurrent:) / countText 等 10 函数
//   - CovMap: body L15-21 @0x100670c9c；emptyContent L23-31 @0x100671078；
//     resultsSection L33-41 @0x100670900；resultRow L43-57 @0x10067156c
//   - IDA: 上述地址的 Hex-Rays 伪代码（803 行）
//   - 选择子：MainActor body；sectionHeader getter；List + ForEach rows；
//     TupleView<HStack<searchingIndicator/textCase/Spacer/countText>>；
//     rowBackground(isCurrent:) → Color；StorageKind 判定
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（SwiftUI body 主链确证：List/Section/ForEach/行视图/搜索指示器/计数）
// 还原: 2026-11-19

import SwiftUI

/// 换源列表内容视图（伪代码 0x100670c9c，L15-21）。
struct ChangeSourceListContent: View {

    let results: [Book]
    let currentBookUrl: String
    let isSearching: Bool
    let onSelect: (Book) -> Void

    /// 伪代码 0x100670c9c（L15-21）：主 body —— List + Section(results) + Section(header)。
    var body: some View {
        List {
            Section {
                ForEach(results, id: \.bookUrl) { book in
                    resultRow(book)
                        .onTapGesture {
                            onSelect(book)
                        }
                }
            } header: {
                sectionHeader
            }
        }
        .listStyle(.plain)
    }

    /// 伪代码 0x100670900（L33-41）：结果列表 Section。
    private var resultsSection: some View {
        Section {
            ForEach(results, id: \.bookUrl) { book in
                resultRow(book)
            }
        }
    }

    /// 伪代码 emptyContent（0x100671078，L23-31）：空态。
    private var emptyContent: some View {
        ContentUnavailableView(
            "无结果",
            systemImage: "magnifyingglass",
            description: Text("未找到其他来源")
        )
    }

    /// 伪代码 sectionHeader（closure #1，HStack：searchingIndicator + textCase + Spacer + countText）。
    private var sectionHeader: some View {
        HStack {
            searchingIndicator
            Text(headerTitle)
                .textCase(.uppercase)
            Spacer()
            countText
        }
        .progressViewStyle(.linear)
    }

    /// 伪代码 searchingIndicator：isSearching 时显示 ProgressView。
    @ViewBuilder
    private var searchingIndicator: some View {
        if isSearching {
            ProgressView()
        }
    }

    /// 伪代码 headerTitle：标题。
    private var headerTitle: String {
        isSearching ? "正在搜索来源..." : "来源列表"
    }

    /// 伪代码 countText：计数。
    private var countText: some View {
        Text("\(results.count)")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    /// 伪代码 0x10067156c（L43-57）：结果行 + rowBackground(isCurrent:)。
    private func resultRow(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.name)
                .font(.body)
            HStack {
                Text(book.origin)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let lastChapter = book.lastChapter {
                    Text(lastChapter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .background(rowBackground(isCurrent: book.bookUrl == currentBookUrl))
    }

    /// 伪代码 rowBackground(isCurrent:)：当前来源高亮。
    private func rowBackground(isCurrent: Bool) -> Color {
        isCurrent ? Color.blue.opacity(0.1) : Color.clear
    }
}
