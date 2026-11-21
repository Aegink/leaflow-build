// 原路径: ReadMain/Views/Reader/LocalReaderSearchView.swift
// 证据:
//   - PGO: 13 个主函数（index/task_functions.csv T-304-03 / LocalReaderSearchView.swift），
//     地址：LocalFullTextSearchView.body 0x10071e144 L31-117 / performSearch
//     0x100720ce4 L157-221
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/LocalReaderSearchView.c
//   - 事实：本地书全文搜索（与 FullTextSearchView 同域，数据源为本地章文本）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（主链确证）
// 还原: 2026-11-19

import SwiftUI

/// 本地书全文搜索。
struct LocalFullTextSearchView: View {

    var chapterContentProvider: (Int) -> String
    var chapterCount: Int
    var onPickResult: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>?

    /// 结果条目（与 FullTextSearchView.SearchResult 同域）。
    struct SearchResult: Identifiable {
        let chapterIndex: Int
        let position: Int
        let snippet: String
        var id: String { "\(chapterIndex)-\(position)" }
    }

    var body: some View {
        // 伪代码 0x10071e144（L31-117）。
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView.search
                } else {
                    List(results) { result in
                        Button {
                            onPickResult(result.chapterIndex, result.position)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.snippet)
                                    .font(.readerUI(.body).weight(.medium))
                            }
                        }
                    }
                }
            }
            .navigationTitle("全文搜索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .searchable(text: $keyword, prompt: "搜索正文")
            .onChange(of: keyword, initial: false) { _, newValue in
                performSearch(keyword: newValue)
            }
        }
    }

    /// 伪代码 0x100720ce4（L157-221）：全文检索
    ///（与 FullTextSearchView.performSearch 同构，Task + lowercased + range 确证）。
    private func performSearch(keyword: String) {
        searchTask?.cancel()
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        searchTask = Task(priority: .userInitiated) {
            let lowered = trimmed.lowercased()
            var found: [SearchResult] = []
            for chapterIndex in 0..<chapterCount {
                if Task.isCancelled { return }
                let content = chapterContentProvider(chapterIndex)
                let loweredContent = content.lowercased()
                var cursor = loweredContent.startIndex
                while let hit = loweredContent.range(
                    of: lowered, options: [], range: cursor..<loweredContent.endIndex) {
                    let snippetStart = loweredContent.index(
                        hit.lowerBound, offsetBy: -24, limitedBy: loweredContent.startIndex)
                        ?? loweredContent.startIndex
                    let snippetEnd = loweredContent.index(
                        hit.upperBound, offsetBy: 40, limitedBy: loweredContent.endIndex)
                        ?? loweredContent.endIndex
                    found.append(SearchResult(
                        chapterIndex: chapterIndex,
                        position: loweredContent.distance(
                            from: loweredContent.startIndex, to: hit.lowerBound),
                        snippet: String(content[snippetStart..<snippetEnd])))
                    cursor = hit.upperBound
                    if found.count >= 100 { break }
                }
                if found.count >= 100 { break }
            }
            await MainActor.run {
                results = found
            }
        }
    }
}
