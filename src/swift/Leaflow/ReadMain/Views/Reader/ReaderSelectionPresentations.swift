// 原始归属: ReadMain/Views/Reader/ReaderViewModifiers.swift
// 类型表10935/11766与0x1008a4b74 L542-554：选文草稿、保存、启用本书并刷新。
import SwiftUI

struct ReaderReplaceRuleDraft: Identifiable, Equatable {
    let id = UUID()
    let sourceText: String
}

struct ReaderSelectionPresentationModifier: ViewModifier {
    let vm: ReaderViewModel
    @State private var draft: ReaderReplaceRuleDraft?
    @State private var active = false

    func body(content: Content) -> some View {
        content
            .onAppear { active = true }
            .onDisappear { active = false }
            .onReceive(NotificationCenter.default.publisher(for: .readerRequestReplaceRule)) { notification in
                guard active, vm.currentBook != nil,
                      let text = notification.userInfo?["selectedText"] as? String,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                draft = ReaderReplaceRuleDraft(sourceText: text)
            }
            .sheet(item: $draft) { item in
                ReplaceRuleCreationSheet(sourceText: item.sourceText) { pattern, replacement in
                    Task { @MainActor in
                        if !(await vm.saveSelectedTextReplaceRule(pattern: pattern, replacement: replacement)) {
                            AppErrorPresenter.shared.show("替换规则保存失败", level: .error, duration: 2.5)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
    }
}

extension ReaderViewModel {
    /// 先确认落盘，再启用本书并重新拉取原始正文，避免重复对已处理文本应用规则。
    func saveSelectedTextReplaceRule(pattern: String, replacement: String) async -> Bool {
        guard !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var book = currentBook else { return false }
        let rule = ReaderReplaceRuleCreation.makeRule(pattern: pattern, replacement: replacement)
        guard replaceRuleService.addRule(rule) else { return false }
        let chapter = currentChapterIndex
        let page = currentPageInChapter
        if ReaderReplaceRuleCreation.enableReplaceRuleIfNeeded(&book.useReplaceRule) {
            currentBook = book
            bookService.updateBook(book)
        }
        await loadBookWithProgress(nil, needRefresh: true, targetChapterIndex: chapter, targetPageOffset: page)
        return true
    }
}
