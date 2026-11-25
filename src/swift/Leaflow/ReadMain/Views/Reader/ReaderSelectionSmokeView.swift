// 仅-smokeReaderSelection：原生选文菜单与生产呈现/保存链，固定正文替换网络I/O。
import SwiftUI

struct ReaderSelectionSmokeView: View {
    @State private var settings = ReadingSettings.load()
    @State private var vm = ReaderViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ReaderSelectionSmokeText(content: vm.chapterContents.first ?? "")
                    .frame(height: 220)
                Text(vm.chapterContents.first ?? "加载中")
                    .accessibilityIdentifier("reader-selection-result")
                Text("已保存规则：\(vm.replaceRuleService.loadRules().count)")
            }
            .padding()
            .navigationTitle("固定选文样本")
            .modifier(ReaderSelectionPresentationModifier(vm: vm))
        }
        .task {
            guard vm.currentBook == nil else { return }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("reader-selection-smoke")
            vm.replaceRuleService = ReplaceRuleService(storageDirectory: directory)
            vm.replaceRuleService.clearAllRules()
            vm.configure(book: Book(bookUrl: "https://sample.invalid/selection-smoke", name: "固定选文样本"), settings: settings)
            vm.containerSize = CGSize(width: 320, height: 480)
            let chapter = try? JSONDecoder().decode(Chapter.self,
                from: Data(#"{"name":"第一章","url":"https://sample.invalid/1","index":0}"#.utf8))
            vm.chapterListProvider = { _, _ in chapter.map { [$0] } ?? [] }
            vm.chapterContentProvider = { _, _, _ in
                ChapterContent(content: "sample", nextUrl: nil, isPay: false, comments: [],
                    readerAccessURL: nil, chapterTitle: "第一章")
            }
            await vm.loadBookWithProgress(nil, needRefresh: false, targetChapterIndex: nil, targetPageOffset: nil)
        }
    }
}

private struct ReaderSelectionSmokeText: UIViewRepresentable {
    let content: String
    func makeUIView(context: Context) -> SelectableReaderTextView {
        let view = SelectableReaderTextView(isSelectable: true)
        view.font = .preferredFont(forTextStyle: .title2)
        view.accessibilityIdentifier = "reader-selection-text"
        return view
    }
    func updateUIView(_ view: SelectableReaderTextView, context: Context) {
        if view.text != content { view.text = content }
    }
}
