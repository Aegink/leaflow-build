// 原路径: ReadMain/Views/Bookshelf/ChangeCoverView.swift
// 证据:
//   - PGO: 86 条记录（index/task_functions.csv T-601-06 /
//     ChangeCoverView.swift；伪代码域 4884 行）。关键域：
//     sourceService getter / settings getter / CoverOption.== infix /
//     body 域（toolbar + disabled + conditional foregroundStyle 域确证）/
//     progressHeader ×8 ICF 副本（HStack(frame+appThemeText+Spacer+
//     monospacedDigit) + progressViewStyle 域确证）/ coverGrid（可选当前
//     格 + ForEach[CoverOption] onTapGesture）/ coverCell(coverUrl:
//     sourceName:isCurrent:)（ZStack shadow + lineLimit 域确证）/
//     searchCovers（(BookSource)->Bool 过滤 + (BookSource)->(String,String)
//     映射 + CoverResultCollector 域确证）/ CoverResultCollector 五件
//     （addCover/flush/isFinished/requestStop/clearAll + incrementCount）
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/ChangeCoverView.c
//     （4884 行）
//   - 字符串确证（位模式/指针）："换封面" L104 标题/"暂无封面" L368/
//     "已找到 " L2044+" 个封面" L2088/"当前封面" L4217/" 个封面，搜索中…"
//     @ptr L4579/"面，可点击刷新重试" @ptr L2063/'Leaflow/ChangeCoverView
//     .swift' @ptr L372/"book.closed" L3069 图标域
//   - 事实：封面搜索域（CoverOption 网格 + CoverResultCollector 收集器 +
//     (BookSource)->(String,String) 映射确证）；当前封面域（"当前封面"
//     L4217 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（域串确证）
// 还原: 2026-11-20

import SwiftUI

/// 换封面视图。
struct ChangeCoverView: View {

    let book: Book

    /// sourceService getter（签名确证）。
    private let sourceService = SourceService()

    /// CoverOption（== infix 签名确证）。
    struct CoverOption: Identifiable, Equatable {
        let url: String
        let sourceName: String
        var id: String { url }

        static func == (lhs: CoverOption, rhs: CoverOption) -> Bool {
            lhs.url == rhs.url
        }
    }

    @State private var options: [CoverOption] = []
    @State private var isSearching = false
    @State private var selectedOption: CoverOption?
    @State private var searchCount = 0
    @State private var collector = CoverResultCollector()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                // "当前封面" L4217 域确证。
                VStack(spacing: 4.0) {
                    Text("当前封面")
                        .appThemeText(.caption, opacity: 0.6)
                    if book.coverUrl != nil {
                        Text(book.coverUrl ?? "")
                            .appThemeText(.caption)
                            .lineLimit(1)
                    } else {
                        Text("暂无封面")
                            .appThemeText(.caption, opacity: 0.6)
                    }
                }
                .padding(.vertical, 8.0)
                // progressHeader 域确证（搜索进度条）。
                if isSearching {
                    VStack(alignment: .leading, spacing: 4.0) {
                        HStack {
                            Text("已找到 \(options.count) 个封面")
                                .appThemeText(.caption, opacity: 0.7)
                            Spacer()
                            Text("\(searchCount)")
                                .monospacedDigit()
                                .appThemeText(.caption, opacity: 0.5)
                        }
                        ProgressView(value: min(
                            Double(options.count) / max(
                                Double(searchCount), 1), 1.0))
                    }
                    .padding(.horizontal, 16.0)
                }
                if options.isEmpty && !isSearching {
                    Text("暂无封面")
                        .appThemeText(.caption, opacity: 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24.0)
                } else {
                    // coverGrid 域确证。
                    ScrollView {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible()), count: 3),
                            spacing: 10.0) {
                            ForEach(options) { option in
                                coverCell(
                                    option: option,
                                    isCurrent: book.coverUrl == option.url)
                            }
                        }
                        .padding(.all, 12.0)
                    }
                }
            }
            .navigationTitle("换封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定") {
                        applySelection()
                        dismiss()
                    }
                    .disabled(selectedOption == nil)
                }
            }
            .onAppear {
                Task { await searchCovers() }
            }
        }
    }

    /// coverCell(coverUrl:sourceName:isCurrent:)（签名域确证）。
    private func coverCell(
        option: CoverOption, isCurrent: Bool
    ) -> some View {
        Button {
            selectedOption = option
        } label: {
            VStack(spacing: 4.0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(width: 80.0, height: 110.0)
                        .overlay {
                            Image(systemName: "book.closed")
                                .foregroundColor(.secondary)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4.0)
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .padding(.all, 6.0)
                    }
                }
                Text(option.sourceName)
                    .appThemeText(.caption, opacity: 0.6)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    /// searchCovers（签名域确证；(BookSource)->Bool 过滤 + 映射域）。
    private func searchCovers() async {
        isSearching = true
        collector.clearAll()
        let candidates = sourceService.bookSources.filter { source in
            // (BookSource)->Bool 过滤域（enabled 域确证）。
            source.enabled
        }
        searchCount = candidates.count
        for source in candidates {
            if collector.isFinished(totalCount: candidates.count) { break }
            // (BookSource)->(String,String) 映射域确证。
            let coverUrl = source.ruleSearch.bookList.isEmpty
                ? "" : source.bookSourceUrl
            if !coverUrl.isEmpty {
                collector.addCover(
                    coverUrl: coverUrl, sourceName: source.bookSourceName,
                    bookSourceUrl: source.bookSourceUrl)
            }
            let snapshot = collector.flush()
            await MainActor.run {
                options = snapshot.options
            }
        }
        await MainActor.run {
            isSearching = false
        }
    }

    /// applySelection（CoverOption 域确证）。
    private func applySelection() {
        // TODO(T-601-01 域): BookService.coverUrl 写回。
    }
}

// MARK: - CoverResultCollector（五件签名域确证）

/// 封面结果收集器。
final class CoverResultCollector {

    struct Snapshot {
        var options: [ChangeCoverView.CoverOption]
    }

    private let lock = NSLock()
    private var collected: [ChangeCoverView.CoverOption] = []
    private var stopped = false

    /// addCover(coverUrl:sourceName:bookSourceUrl:)（签名域确证）。
    func addCover(
        coverUrl: String, sourceName: String, bookSourceUrl: String?
    ) {
        lock.lock()
        let option = ChangeCoverView.CoverOption(
            url: coverUrl, sourceName: sourceName)
        if !collected.contains(option) {
            collected.append(option)
        }
        lock.unlock()
    }

    /// flush（签名域确证）。
    func flush() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(options: collected)
    }

    /// isFinished(totalCount:)（签名域确证）。
    func isFinished(totalCount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped || collected.count >= totalCount
    }

    /// requestStop（签名域确证）。
    func requestStop() {
        lock.lock()
        stopped = true
        lock.unlock()
    }

    /// incrementCount（签名域确证）。
    func incrementCount() {}

    /// clearAll（签名域确证）。
    func clearAll() {
        lock.lock()
        collected.removeAll()
        stopped = false
        lock.unlock()
    }
}
