// T-1602：实际选择通知、规则写盘、启用和重载，只替换目录与正文I/O。
import Foundation
import UIKit

enum ReaderSelectionSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        var values: [String] = []
        for initial: Int? in [nil, 0, 1, 2, -1] {
            var value = initial
            values.append("\(ReaderReplaceRuleCreation.enableReplaceRuleIfNeeded(&value)):\(value ?? -99)")
        }
        emit("reader_replace_enable", ["true:1", "true:1", "false:1", "false:2", "false:-1"], values)

        let text = SelectableReaderTextView(isSelectable: true)
        text.text = "  选文😀  "
        text.selectedRange = NSRange(location: 0, length: text.text.utf16.count)
        var replacePayload = ""
        var bookmarkPayload = ""
        let center = NotificationCenter.default
        let replaceToken = center.addObserver(forName: .readerRequestReplaceRule, object: nil, queue: nil) {
            replacePayload = $0.userInfo?["selectedText"] as? String ?? ""
        }
        let bookmarkToken = center.addObserver(forName: .readerRequestAddBookmark, object: nil, queue: nil) {
            bookmarkPayload = $0.userInfo?["selectedText"] as? String ?? ""
        }
        text.createReplaceRule(nil)
        text.addBookmark(nil)
        text.text = "   "
        text.selectedRange = NSRange(location: 0, length: 3)
        text.createReplaceRule(nil)
        emit("reader_selection_notifications", ["选文😀", "选文😀", "true"],
            [replacePayload, bookmarkPayload, String(text.selectedTextForMenuAction() == nil)])
        center.removeObserver(replaceToken)
        center.removeObserver(bookmarkToken)

        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: directory) }
            let service = ReplaceRuleService(storageDirectory: directory)
            let pattern = "a.b" + String(repeating: "😀", count: 25)
            let rule = ReaderReplaceRuleCreation.makeRule(pattern: pattern, replacement: "$1\\value")
            let saved = service.addRule(rule)
            let reloaded = ReplaceRuleService(storageDirectory: directory)
            emit("reader_replace_literal_roundtrip", ["true", "false", "true", "true", "$1\\value aXb"],
                [String(saved), String(rule.isRegex ?? true), String(rule.enabled ?? false),
                 String(rule.name == "阅读页添加: " + String(pattern.prefix(20))),
                 reloaded.applyRules(to: pattern + " aXb", bookName: nil)])

            let chapter = try JSONDecoder().decode(Chapter.self,
                from: Data(#"{"name":"第一章","url":"https://sample.invalid/1","index":0}"#.utf8))
            let settings = ReadingSettings.load()
            let vm = ReaderViewModel()
            vm.replaceRuleService = service
            vm.configure(book: Book(bookUrl: "https://sample.invalid/selection", name: "固定选文样本"), settings: settings)
            vm.containerSize = CGSize(width: 320, height: 480)
            vm.chapterListProvider = { _, _ in [chapter] }
            vm.chapterContentProvider = { _, _, _ in
                ChapterContent(content: "a.b aXb", nextUrl: nil, isPay: false, comments: [],
                    readerAccessURL: nil, chapterTitle: chapter.name)
            }
            await vm.loadBookWithProgress(nil, needRefresh: false, targetChapterIndex: nil, targetPageOffset: nil)
            let result = await vm.saveSelectedTextReplaceRule(pattern: "a.b", replacement: "新正文")
            emit("reader_replace_visible_refresh", ["true", "1", "新正文 aXb", "true", "false"],
                [String(result), String(vm.currentBook?.useReplaceRule ?? -1), vm.chapterContents.first ?? "",
                 String(vm.pages.map(\.content).joined().contains("新正文")), String(vm.hasError)])

            let file = directory.appendingPathComponent("不能作为目录")
            try Data().write(to: file)
            vm.replaceRuleService = ReplaceRuleService(storageDirectory: file)
            vm.currentBook?.useReplaceRule = 0
            let before = vm.chapterContents
            let failed = await vm.saveSelectedTextReplaceRule(pattern: "a.b", replacement: "不应生效")
            emit("reader_replace_write_failure", ["false", "0", "true"],
                [String(failed), String(vm.currentBook?.useReplaceRule ?? -1), String(before == vm.chapterContents)])
        } catch {
            emit("reader_replace_setup", ["成功"], [error.localizedDescription])
            return
        }
        emit("reader_replace_setup", ["成功"], ["成功"])
    }
}
