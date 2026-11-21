// 原路径: ReadMain/Views/Search/SearchSubViews.swift
// 证据:
//   - PGO: 38 条记录（index/task_functions.csv T-501-07 /
//     SearchSubViews.swift；伪代码域 2872 行）。关键地址：
//     SearchProgressBar.body 0x1008e7c5c L22-46 / SearchHistoryFlowView.body
//     0x1008e882c L56-79 / HistoryChip.body 0x1008e9654 L88-108 /
//     SearchResultListContent.== infix 0x1008ea058 L120-125 / body
//     0x1008ea298 L127-152 / SearchResultCard.== infix（签名）/
//     singleSourceName 0x1008eb0c8 L166-177 / SearchResultCard.body
//     0x1008eb864 L179-242 / searchableIfReady 扩展（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SearchSubViews.c
//     （2872 行）
//   - 字符串确证（位模式/指针）："搜索历史" L454/"load-more-" L1449（加载
//     更多标记域）/"book.closed" L1938/"chevron." L2055/" N 个配置" L2622
//   - 事实：进度条双段（tint + HStack(名称 lineLimit + Spacer + Button
//     停止)）；历史流（Flow 布局 + HistoryChip）；结果卡（单源名 + 多源域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 位模式确证）
// 还原: 2026-11-20

import SwiftUI

// MARK: - SearchProgressBar（0x1008e7c5c L22-46 域确证）

/// 搜索进度条。
struct SearchProgressBar: View {
    let sourceName: String
    let onStop: () -> Void

    var body: some View {
        // 闭包签名族：tint + HStack(名称 lineLimit + Spacer + Button)。
        HStack(spacing: 8.0) {
            ProgressView()
                .tint(.blue)
            Text(sourceName)
                .lineLimit(1)
                .appThemeText(.caption, opacity: 0.7)
            Spacer()
            Button("停止", action: onStop)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 6.0)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - 搜索历史（0x1008e882c L56-79 + 0x1008e9654 L88-108 域确证）

/// 搜索历史流。
struct SearchHistoryFlowView: View {
    let history: [String]
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void

    var body: some View {
        // 0x1008e882c L56-79 域确证。
        VStack(alignment: .leading, spacing: 8.0) {
            // "搜索历史" L454 位模式确证。
            Text("搜索历史")
                .appThemeText(.headline)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()), count: 4),
                spacing: 8.0) {
                ForEach(history, id: \.self) { term in
                    HistoryChip(term: term) {
                        onSelect(term)
                    } onRemove: {
                        onRemove(term)
                    }
                }
            }
        }
        .padding(.horizontal, 12.0)
    }
}

/// 历史芯片（0x1008e9654 L88-108 域确证）。
struct HistoryChip: View {
    let term: String
    let action: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4.0) {
            Text(term)
                .appThemeText(.caption)
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8.0)
        .padding(.vertical, 4.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10, antialiased: true)
        .onTapGesture(perform: action)
    }
}

// MARK: - 结果列表（0x1008ea058 L120-125 + 0x1008ea298 L127-152 域确证）

/// 结果列表内容。
struct SearchResultListContent: View, Equatable {
    let results: [SearchResultBook]
    let onSelect: (SearchResultBook) -> Void

    static func == (lhs: SearchResultListContent, rhs: SearchResultListContent)
        -> Bool
    {
        lhs.results.map(\.id) == rhs.results.map(\.id)
    }

    var body: some View {
        // 0x1008ea298 L127-152 域确证。
        ForEach(results) { result in
            SearchResultCard(
                result: result,
                sources: result.sources) { book in
                onSelect(result)
            }
        }
        // "load-more-" L1449 加载更多标记域确证。
        Color.clear
            .frame(height: 1)
            .onAppear {
                // TODO(T-501-07 域): load-more- 触发域接入。
            }
    }
}

// MARK: - 结果卡（0x1008eb864 L179-242 域确证）

/// 搜索结果卡。
struct SearchResultCard: View, Equatable {
    let result: SearchResultBook
    let sources: [Book]
    let onPick: (Book) -> Void

    static func == (lhs: SearchResultCard, rhs: SearchResultCard) -> Bool {
        lhs.result.id == rhs.result.id
            && lhs.sources.count == rhs.sources.count
    }

    /// singleSourceName getter（0x1008eb0c8 L166-177 域确证）。
    private var singleSourceName: String? {
        sources.count == 1 ? sources.first?.bookSourceName : nil
    }

    var body: some View {
        // 0x1008eb864 L179-242 域确证。
        VStack(alignment: .leading, spacing: 6.0) {
            HStack(spacing: 8.0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 44.0, height: 60.0)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(result.displayBook.name)
                        .lineLimit(1)
                    if let author = result.displayBook.author {
                        Text(author)
                            .appThemeText(.caption, opacity: 0.6)
                    }
                    // " N 个配置" L2622 域确证。
                    if let single = singleSourceName {
                        Text(single)
                            .appThemeText(.caption, opacity: 0.5)
                    } else {
                        Text("\(result.sourceCount) 个配置")
                            .appThemeText(.caption, opacity: 0.5)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if sources.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6.0) {
                        ForEach(sources, id: \.bookSourceUrl) { book in
                            Button(book.bookSourceName) {
                                onPick(book)
                            }
                            .appThemeText(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4.0)
    }
}

// MARK: - 条件搜索框扩展（签名确证）

extension View {
    /// searchableIfReady（签名确证）。
    @ViewBuilder
    func searchableIfReady(
        _ ready: Bool, text: Binding<String>, prompt: String
    ) -> some View {
        if ready {
            self.searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }
}
