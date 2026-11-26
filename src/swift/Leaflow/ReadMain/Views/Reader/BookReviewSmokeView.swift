// 仅-smokeBookReview：真实ReaderView更多操作→评论呈现，固定正文及书评网络I/O。
import SwiftUI

@MainActor
struct BookReviewSmokeView: View {
    @State private var settings = ReadingSettings.load()
    @State private var vm = ReaderViewModel()
    @State private var ready = false
    @State private var failure: String?
    private let source = BookReviewSampleSelfTest.source()

    private var book: Book {
        Book(bookUrl: "https://sample.invalid/review-smoke", name: "固定书评书籍", bookSourceUrl: source.bookSourceUrl)
    }

    var body: some View {
        NavigationStack {
            Group {
                if ready {
                    ReaderView(settings: $settings, book: book, viewModel: vm) { _ in
                        try await Task.sleep(nanoseconds: 250_000_000)
                        let arguments = ProcessInfo.processInfo.arguments
                        if arguments.contains("-smokeReviewError") { throw URLError(.notConnectedToInternet) }
                        let text = arguments.contains("-smokeReviewEmpty") ? "" : BookReviewSampleSelfTest.body
                        return StrResponse(body: text, code: 200, message: "成功", headers: [:])
                    }
                } else if let failure {
                    Text(failure)
                } else { ProgressView("准备固定样本") }
            }
        }
        .task {
            guard !ready else { return }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("review-smoke-sources")
            do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
            catch { failure = "固定样本目录创建失败：\(error.localizedDescription)"; return }
            let service = SourceService(storageDirectory: directory)
            guard let data = try? JSONEncoder().encode([source]),
                  await service.importSourcesAsync(from: String(decoding: data, as: UTF8.self), storageKind: .local) >= 0
            else { failure = "固定样本写盘失败"; return }
            vm.sourceService = service
            vm.containerSize = CGSize(width: 320, height: 480)
            vm.chapterListProvider = { _, _ in
                ProcessInfo.processInfo.arguments.contains("-smokeReviewNoChapters")
                    ? [] : [BookReviewSampleSelfTest.chapter()]
            }
            vm.chapterContentProvider = { _, _, _ in
                ChapterContent(content: "固定正文，请从更多操作打开评论。", nextUrl: nil, isPay: false,
                    comments: [], readerAccessURL: nil, chapterTitle: "第一章")
            }
            ready = true
        }
    }
}
