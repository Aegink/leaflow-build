// 仅-smokeReaderPageTurn：生产PageViewController与提交链，固定跨章三页。
import SwiftUI

@MainActor
struct ReaderPageTurnSmokeView: View {
    @State private var settings = ReadingSettings.load()
    @State private var vm = ReaderViewModel()
    @State private var ready = false
    @State private var showSettings = false
    private let testsWidgets = ProcessInfo.processInfo.arguments.contains("-smokeLayoutWidgets")

    init() {
        let defaults = ProcessInfo.processInfo.arguments.contains("-smokeLayoutWidgets")
            ? UserDefaults(suiteName: "t1602-widget-editor-ui")! : .standard
        _settings = State(initialValue: ReadingSettings.load(from: defaults))
    }

    var body: some View {
        VStack(spacing: 0) {
            if testsWidgets {
                Button("阅读设置") { showSettings = true }.accessibilityIdentifier("reader-widget-open-settings")
            }
            Text("全局页\(vm.currentPageIndex)，章节\(vm.currentChapterIndex)")
                .accessibilityIdentifier("reader-turn-position")
            if ready {
                PageViewController(pages: vm.pages, currentPageIndex: vm.currentPageIndex,
                    settings: settings, bookName: "固定翻页书籍", totalChapters: 2,
                    speechHighlight: .none, colorVersion: settings.typographyRevision, isRebuildPending: false,
                    pageMode: ProcessInfo.processInfo.arguments.contains("-smokePageCurl") ? .curl : .horizontal,
                    isDoublePageActive: false, menuVisible: false,
                    pageTurnCommand: nil, onTap: {}, onPageCommitted: { vm.handlePageCommitted($0) })
            }
        }
        .modifier(ReaderWidgetEditingModifier(settings: $settings, bookName: "固定翻页书籍", chapterTitle: "固定章节"))
        .sheet(isPresented: $showSettings) {
            ReaderSettingsView(settings: $settings, onDismiss: { showSettings = false })
        }
        .task {
            guard !ready else { return }
            vm.pages = ReaderPageTurnSampleSelfTest.pages()
            ready = true
        }
    }
}
