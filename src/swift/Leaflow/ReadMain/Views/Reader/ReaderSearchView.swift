// 原路径: ReadMain/Views/Reader/ReaderSearchView.swift
// 证据:
//   - PGO: 28 个主函数（index/task_functions.csv T-301-08 / ReaderSearchView.swift），
//     地址：FullTextSearchView.body 0x1007c82a0 L26-87（+结果行闭包族 0x1007c9a2c-ca1fc
//     L47-66 / toolbar 闭包 0x1007cabe8 L79-85）/ performSearch(keyword:)
//     0x1007ca2ac L89-165（+闭包 0x1007cacf0 L114-164）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderSearchView.c（1605 行）
//   - 关键调用：ContentUnavailableView（空态确证）/ Font.readerUI + Weight.medium /
//     Edge.Set.vertical + HorizontalAlignment.leading / TaskPriority.userInitiated
//     （确证）/ String.lowercased + StringProtocol.range(of:options:range:locale:)
//     （L1298/L1358 确证）
//   - 事实：body = List(结果行) + 空态 ContentUnavailableView + toolbar；
//     performSearch：Task(userInitiated) 后台全文检索（大小写不敏感，
//     逐章节 range 匹配）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body 结构/performSearch 主链: high（builder 描述 + 调用确证）
//   - 结果高亮样式细节: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 全文搜索视图。
struct FullTextSearchView: View {
    @Binding var chapters: [ReaderChapterListChapter]
    var chapterContentProvider: (Int) -> String
    var onPickResult: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    /// 检索结果条目。
    struct SearchResult: Identifiable {
        let chapterIndex: Int
        let pageIndex: Int
        let snippet: String
        var id: String { "\(chapterIndex)-\(pageIndex)" }
    }

    var body: some View {
        // 伪代码 0x1007c82a0（L26-87）。body 拆分结果组子视图
        // （类型检查超时消解，wave-63）。
        NavigationStack {
            searchResultsGroup
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
                .navigationTitle("全文搜索")
        }
        .searchable(text: $keyword, prompt: "搜索正文")
        .onChange(of: keyword, initial: false) { _, newValue in
            performSearch(keyword: newValue)
        }
    }

    /// 结果组（body 拆分域：空态 ContentUnavailableView / 结果列表）。
    @ViewBuilder
    private var searchResultsGroup: some View {
        if results.isEmpty {
            ContentUnavailableView.search
        } else {
            List(results) { result in
                SearchResultRow(result: result) {
                    onPickResult(result.chapterIndex, result.pageIndex)
                    dismiss()
                }
            }
        }
    }

    /// 伪代码 0x1007ca2ac（L89-165）+ 闭包（0x1007cacf0，L114-164）：
    /// Task(userInitiated) 后台检索；大小写不敏感（lowercased + range(of:options:)）。
    private func performSearch(keyword: String) {
        searchTask?.cancel()
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isSearching = true
        searchTask = Task(priority: .userInitiated) {
            let lowered = trimmed.lowercased()
            var found: [SearchResult] = []
            for chapter in chapters {
                if Task.isCancelled { return }
                let content = chapterContentProvider(chapter.index)
                let loweredContent = content.lowercased()
                var searchRange = loweredContent.startIndex..<loweredContent.endIndex
                while let hit = loweredContent.range(of: lowered, options: [], range: searchRange) {
                    let snippetStart = loweredContent.index(
                        hit.lowerBound, offsetBy: -24, limitedBy: loweredContent.startIndex)
                        ?? loweredContent.startIndex
                    let snippetEnd = loweredContent.index(
                        hit.upperBound, offsetBy: 40, limitedBy: loweredContent.endIndex)
                        ?? loweredContent.endIndex
                    found.append(SearchResult(
                        chapterIndex: chapter.index,
                        pageIndex: 0,
                        snippet: String(content[snippetStart..<snippetEnd])))
                    searchRange = hit.upperBound..<loweredContent.endIndex
                    if found.count >= 100 { break }
                }
                if found.count >= 100 { break }
            }
            await MainActor.run {
                self.results = found
                self.isSearching = false
            }
        }
    }
}
/// 结果行（body 拆分子视图——原 Button + label 域）。
private struct SearchResultRow: View {
    let result: FullTextSearchView.SearchResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.snippet)
                    .font(.readerUI(.body).weight(.medium))
                    .padding(.vertical, 2)
            }
        }
    }
}
