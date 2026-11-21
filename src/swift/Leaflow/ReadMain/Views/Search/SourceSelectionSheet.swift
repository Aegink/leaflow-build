// 原路径: ReadMain/Views/Search/SourceSelectionSheet.swift
// 证据:
//   - PGO: 47 条记录（index/task_functions.csv T-501-08 /
//     SourceSelectionSheet.swift；伪代码域 2707 行）。关键地址：
//     indexedSources getter 0x1009411d4 L54-74 / body 0x1009417bc L76-109 /
//     SourceSelectionReadyContent.body 0x10094224c L123-126 /
//     selectSource 0x100942550 L146-156 / bookHeader 0x100941c10 L179-216 /
//     sourceList 0x10094227c L137-144 / sheetTitleBar（签名）/
//     SourceSelectionSourceList.body 0x100943be8 L226-246 /
//     isCurrentSource 0x1009445b8 L248-254 /
//     SourceSelectionReaderCoverModifier.body 0x100944908 L260-272 /
//     SourceRow.body 0x100944d04 L289-345 / readyContent getter /
//     sourceSelectionReaderCover 扩展 / init(book:onComplete:onCancel:)
//     （签名确证）；"选择配置" L488 域确证 / "已在书架" L1230 位模式 /
//     "book.closed" L964/"book.pag(e)" L1856 图标域
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/
//     SourceSelectionSheet.c（2707 行）
//   - 事实：IndexedSource 域（索引源列表）+ 就绪条件内容（_ConditionalContent
//     ReadyContent/Color 域确证）+ 封面阅读修饰（ReaderCoverModifier）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 条件内容域确证）
// 还原: 2026-11-20

import SwiftUI

/// 换源面板。
struct SourceSelectionSheet: View {

    struct IndexedSource: Identifiable {
        let index: Int
        let book: Book
        var id: Int { index }
    }

    let book: SearchResultBook
    let onComplete: (Bool) -> Void
    let onCancel: () -> Void

    /// 就绪域（deferReadyRender 交叉 T-501-08 Lifecycle）。
    @State private var isReady = false
    @State private var selectedSource: Book?

    /// indexedSources getter（0x1009411d4 L54-74 域确证）。
    private var indexedSources: [IndexedSource] {
        book.sources.enumerated().map { index, book in
            IndexedSource(index: index, book: book)
        }
    }

    var body: some View {
        // 伪代码 0x1009417bc（L76-109）：就绪条件内容（_ConditionalContent
        // ReadyContent/Color 域确证）。
        Group {
            if isReady {
                SourceSelectionReadyContent(
                    book: book,
                    indexedSources: indexedSources,
                    selectedSource: $selectedSource,
                    onComplete: onComplete)
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }
        }
        .modifier(
            SourceSelectionLifecycleModifier(
                isReady: $isReady,
                selectedSource: $selectedSource,
                allBooks: book.sources) { _ in })
    }
}

// MARK: - 就绪内容（0x10094224c L123-126 域确证）

/// 就绪内容体。
struct SourceSelectionReadyContent: View {

    let book: SearchResultBook
    let indexedSources: [SourceSelectionSheet.IndexedSource]
    @Binding var selectedSource: Book?
    let onComplete: (Bool) -> Void

    /// sheetTitleBar getter（签名确证；"选择配置" L488 域确证）。
    private var sheetTitleBar: some View {
        HStack {
            Text("选择配置")
                .appThemeText(.headline)
            Spacer()
            Button {
                onComplete(false)
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16.0)
        .padding(.vertical, 10.0)
    }

    /// bookHeader getter（0x100941c10 L179-216 域确证）。
    private var bookHeader: some View {
        HStack(spacing: 10.0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 52.0, height: 72.0)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            VStack(alignment: .leading, spacing: 4.0) {
                Text(book.displayBook.name)
                    .appThemeText(.headline)
                if let author = book.displayBook.author {
                    Text(author)
                        .appThemeText(.caption, opacity: 0.6)
                }
                // "已在书架" L1230 域确证。
                Text("已在书架")
                    .appThemeText(.caption, opacity: 0.5)
            }
            Spacer()
        }
    }

    /// sourceList getter（0x10094227c L137-144 域确证）。
    private var sourceList: some View {
        SourceSelectionSourceList(
            indexedSources: indexedSources,
            selectedSource: $selectedSource)
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetTitleBar
            bookHeader
            sourceList
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    /// selectSource（0x100942550 L146-156 域确证）。
    private func selectSource(_ source: SourceSelectionSheet.IndexedSource) {
        selectedSource = source.book
        onComplete(true)
    }
}

// MARK: - 源列表（0x100943be8 L226-246 域确证）

/// 换源源列表。
struct SourceSelectionSourceList: View {

    let indexedSources: [SourceSelectionSheet.IndexedSource]
    @Binding var selectedSource: Book?

    /// isCurrentSource（0x1009445b8 L248-254 域确证）。
    private func isCurrentSource(_ source: SourceSelectionSheet.IndexedSource)
        -> Bool
    {
        selectedSource?.bookUrl == source.book.bookUrl
    }

    var body: some View {
        // 0x100943be8 L226-246 域确证。
        List {
            ForEach(indexedSources) { indexed in
                SourceRow(
                    indexed: indexed,
                    isCurrent: isCurrentSource(indexed)) {
                    selectedSource = indexed.book
                }
            }
        }
        .listStyle(.plain)
    }
}

/// 源行（0x100944d04 L289-345 域确证）。
struct SourceRow: View {
    let indexed: SourceSelectionSheet.IndexedSource
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8.0) {
                // 序号徽标（IndexedSource 域确证）。
                Text("\(indexed.index + 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24.0)
                VStack(alignment: .leading, spacing: 2.0) {
                    // Book 无 bookSourceName——bookSourceUrl 域桥
                    //（源名以 URL 代显，真机核清项）。
                    Text(indexed.book.bookSourceUrl ?? "")
                        .lineLimit(1)
                    if let latest = indexed.book.latestChapter {
                        Text(latest)
                            .appThemeText(.caption, opacity: 0.6)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 封面阅读修饰（0x100944908 L260-272 域确证）

/// 阅读封面修饰。
struct SourceSelectionReaderCoverModifier: ViewModifier {
    let selected: Book

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if selected.coverUrl != nil {
                    Image(systemName: "book.pages")
                        .padding(.all, 8.0)
                        .foregroundColor(.secondary)
                }
            }
    }
}

extension View {
    /// sourceSelectionReaderCover（签名确证）。
    func sourceSelectionReaderCover(selected: Book) -> some View {
        modifier(SourceSelectionReaderCoverModifier(selected: selected))
    }
}
