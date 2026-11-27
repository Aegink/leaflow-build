// 仅-smokeReaderPageTurn：生产PageViewController与提交链，固定跨章三页。
import SwiftUI

@MainActor
struct ReaderPageTurnSmokeView: View {
    @State private var settings = ReadingSettings.load()
    @State private var vm = ReaderViewModel()
    @State private var ready = false

    var body: some View {
        VStack(spacing: 0) {
            Text("全局页\(vm.currentPageIndex)，章节\(vm.currentChapterIndex)")
                .accessibilityIdentifier("reader-turn-position")
            if ready {
                PageViewController(pages: vm.pages, currentPageIndex: vm.currentPageIndex,
                    settings: settings, bookName: "固定翻页书籍", totalChapters: 2,
                    speechHighlight: .none, colorVersion: 0, isRebuildPending: false,
                    pageMode: ProcessInfo.processInfo.arguments.contains("-smokePageCurl") ? .curl : .horizontal,
                    isDoublePageActive: false, menuVisible: false,
                    pageTurnCommand: nil, onTap: {}, onPageCommitted: { vm.handlePageCommitted($0) })
            }
        }
        .task {
            guard !ready else { return }
            vm.pages = ReaderPageTurnSampleSelfTest.pages()
            ready = true
        }
    }
}
