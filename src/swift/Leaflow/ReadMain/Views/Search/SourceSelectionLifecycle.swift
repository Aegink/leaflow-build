// 原路径: ReadMain/Views/Search/SourceSelectionLifecycle.swift
// 证据:
//   - PGO: 22 条记录（index/task_functions.csv T-501-08 /
//     SourceSelectionLifecycle.swift；伪代码域 855 行）。关键地址：
//     body(content:) 0x100938de8 L17-32 / deferReadyRender 0x100938ff0
//     L34-44 / handleSelectedSourceChange(oldValue:newValue:) 0x100939738
//     L46-73 / appendMissingSourceNames 0x100939c4c L75-81 /
//     loadInitialState 0x10093a2d8 L83-100 / resolvedSourceName
//     0x1009397d4 L102-108 / loadHeaderCoverIfNeeded 0x10093ad1c L110-122 /
//     sourceSelectionLifecycle(isReady:selectedS…) 扩展（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/
//     SourceSelectionLifecycle.c（855 行）
//   - 字符串确证（位模式）："未知配置"（'未知配置' L513 域确证）
//   - 事实：生命周期修饰——初始装载 + 选中源变化联动 + 头部封面延迟装载 +
//     就绪渲染延迟（deferReadyRender 双段闭包确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 修饰签名确证）
// 还原: 2026-11-20

import SwiftUI

/// 换源生命周期修饰（地址域确证）。
struct SourceSelectionLifecycleModifier: ViewModifier {
    @Binding var isReady: Bool
    @Binding var selectedSource: Book?
    let allBooks: [Book]
    let loadCover: (Book) -> Void

    // 初始装载域（loadInitialState L83-100 域确证）。
    @State private var initialLoaded = false
    @State private var sourceNames: [String: String] = [:]

    func body(content: Content) -> some View {
        content
            .onAppear {
                Task { await loadInitialState() }
                deferReadyRender()
            }
            .onChange(of: selectedSource) { oldValue, newValue in
                handleSelectedSourceChange(oldValue: oldValue, newValue: newValue)
            }
    }

    /// deferReadyRender（0x100938ff0 L34-44 域确证）。
    private func deferReadyRender() {
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            await MainActor.run {
                isReady = true
            }
        }
    }

    /// handleSelectedSourceChange(oldValue:newValue:)
    ///（0x100939738 L46-73 域确证）。
    private func handleSelectedSourceChange(
        oldValue: Book?, newValue: Book?
    ) {
        guard newValue != oldValue else { return }
        appendMissingSourceNames()
        if let new = newValue {
            loadCover(new)
        }
    }

    /// appendMissingSourceNames（0x100939c4c L75-81 域确证）。
    private func appendMissingSourceNames() {
        for book in allBooks {
            let url = book.bookSourceUrl ?? ""
            guard !url.isEmpty, sourceNames[url] == nil else { continue }
            sourceNames[url] = resolvedSourceName(for: book)
        }
    }

    /// loadInitialState（0x10093a2d8 L83-100 域确证）。
    private func loadInitialState() async {
        appendMissingSourceNames()
        await MainActor.run {
            initialLoaded = true
        }
        if let selected = selectedSource {
            await loadHeaderCoverIfNeeded(for: selected)
        }
    }

    /// resolvedSourceName(for:)（0x1009397d4 L102-108 域确证；
    /// "未知配置" L513 域确证）。
    private func resolvedSourceName(for book: Book) -> String {
        guard let url = book.bookSourceUrl else { return "未知配置" }
        return SourceService().bookSources.first {
            $0.bookSourceUrl == url
        }?.bookSourceName ?? "未知配置"
    }

    /// loadHeaderCoverIfNeeded（0x10093ad1c L110-122 域确证）。
    private func loadHeaderCoverIfNeeded(for book: Book) async {
        guard book.coverUrl != nil else { return }
        loadCover(book)
    }

    /// loadHeaderCoverIfNeeded（签名确证重载）。
    private func loadHeaderCoverIfNeeded() async {
        if let selected = selectedSource {
            await loadHeaderCoverIfNeeded(for: selected)
        }
    }
}

extension View {
    /// sourceSelectionLifecycle（签名确证）。
    func sourceSelectionLifecycle(
        isReady: Binding<Bool>,
        selectedSource: Binding<Book?>,
        allBooks: [Book],
        loadCover: @escaping (Book) -> Void
    ) -> some View {
        modifier(
            SourceSelectionLifecycleModifier(
                isReady: isReady, selectedSource: selectedSource,
                allBooks: allBooks, loadCover: loadCover))
    }
}
