// 原路径: ReadMain/Views/Reader/ReaderChapterListView.swift
// 证据:
//   - PGO: 29 个主函数（index/task_functions.csv T-301-06 / ReaderChapterListView.swift），
//     核心地址：displayChapters getter 0x10078d2b8 L37-41（+过滤闭包 0x10078d5b8 L40）/
//     themeColorScheme 0x10078dca8 L43-45 / body 0x10078e230 L49-83（+ScrollViewReader/
//     toolbar/chapterSection 闭包 0x10078f118-f510） / leadingButtons 0x1007901f8 L88-97 /
//     scrollToggleButton 0x100790d18 L99-115（+MainActor 闭包 0x100790e80）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderChapterListView.c（3661 行）
//   - 关键选择子/调用：ScrollDismissesKeyboardMode.interactively/SearchFieldPlacement.toolbar/
//     ToolbarItemPlacement.topBarLeading|topBarTrailing/Glass.regular/
//     PresentationDetent.medium|large/PresentationContentInteraction.scrolls/
//     Font.readerUI/Font.system/DispatchTime.now + OS_dispatch_queue.main
//   - 事实：body = NavigationStack + ScrollViewReader { List } + toolbar(leading/trailing)
//     + searchable(.toolbar) + scrollDismissesKeyboard(.interactively)；
//     displayChapters 过滤闭包（L40：按搜索词过滤章节）；
//     scrollToggleButton（L99-115）：DispatchQueue.main.async（L100-108 MainActor 闭包
//     + DispatchTime 确证）；presentationDetents([.medium, .large]) +
//     presentationContentInteraction(.scrolls)
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body 结构/装饰链: high（SwiftUI builder opaque 描述确证）
//   - displayChapters/themeColorScheme: high
//   - 列表行内布局细节: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 阅读器章节列表（搜索 + 跳转 + 滚动按钮）。
struct ReaderChapterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var chapters: [ReaderChapterListChapter]
    @Binding var currentChapterIndex: Int
    var onPickChapter: (Int) -> Void
    /// 主题管理（ivar 0x1004b9bf0 L8 确证：_themeManager）。
    private var themeManager = ThemeManager.shared
    @State private var searchText = ""

    /// 伪代码 0x10078d2b8（L37-41）+ 过滤闭包（0x10078d5b8，L40）：
    /// 搜索词过滤章节（标题 contains）。
    private var displayChapters: [ReaderChapterListChapter] {
        guard !searchText.isEmpty else { return chapters }
        return chapters.filter { chapter in
            chapter.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 伪代码 0x10078dca8（L43-45）：主题色方案。
    private var themeColorScheme: ColorScheme {
        themeManager.isDark ? .dark : .light
    }

    var body: some View {
        // 伪代码 0x10078e230（L49-83）：ScrollViewReader + List + toolbar + searchable。
        ScrollViewReader { proxy in
            NavigationStack {
                List {
                    chapterSection
                }
                .searchable(text: $searchText, placement: .toolbar)
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        leadingButtons(proxy: proxy)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                            .appThemeText(.body, weight: .semibold)
                    }
                }
                .toolbarTitleDisplayMode(.inline)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
            }
        }
        .preferredColorScheme(themeColorScheme)
    }

    /// 章节分区（chapterSection，闭包 0x10078f510 L52-54）。
    private var chapterSection: some View {
        Section("目录") {
            ForEach(Array(displayChapters.enumerated()), id: \.offset) { index, chapter in
                Button {
                    onPickChapter(chapter.index)
                    dismiss()
                } label: {
                    HStack {
                        Text(chapter.title)
                            .appThemeText(.body)
                        Spacer()
                        if chapter.index == currentChapterIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .frame(alignment: .center)
                }
                .id(chapter.index)
            }
        }
    }

    /// 伪代码 0x1007901f8（L88-97）：前导按钮（回到当前章节）。
    private func leadingButtons(proxy: ScrollViewProxy) -> some View {
        HStack {
            scrollToggleButton(proxy: proxy)
        }
    }

    /// 伪代码 0x100790d18（L99-115）+ MainActor 闭包（0x100790e80，L100-108）：
    /// DispatchQueue.main.async 延迟滚动到当前章节。
    private func scrollToggleButton(proxy: ScrollViewProxy) -> some View {
        Button {
            DispatchQueue.main.async {
                withAnimation {
                    proxy.scrollTo(currentChapterIndex, anchor: .top)
                }
            }
        } label: {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 15, weight: .semibold))
                .frame(alignment: .center)
        }
        .buttonStyle(.glass)
    }
}

/// 章节列表条目模型（PGO：displayChapters [A] 泛型 —— 以具体条目落地）。
struct ReaderChapterListChapter: Identifiable {
    let index: Int
    let title: String
    var id: Int { index }
}
