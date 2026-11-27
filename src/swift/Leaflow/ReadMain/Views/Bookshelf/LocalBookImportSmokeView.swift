// 仅-smokeLocalBookImport：固定文件经真实导入页、磁盘服务与本地阅读器。
import SwiftUI

@MainActor
struct LocalBookImportSmokeView: View {
    @ObservedObject private var service = LocalBookService.shared
    @State private var input: URL?
    @State private var importing: URL?
    @State private var reading: LocalBook?
    @State private var settings = ReadingSettings.load()
    @State private var error: String?
    private var isEpub: Bool { ProcessInfo.processInfo.arguments.contains("-smokeEpubImport") }
    private var isPDF: Bool { ProcessInfo.processInfo.arguments.contains("-smokePDFImport") }
    private var title: String { isEpub ? "固定EPUB书籍" : isPDF ? "固定PDF书籍" : "固定导入书籍" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let input {
                    Button("导入固定文件") { importing = input }
                        .accessibilityIdentifier("local-import-fixture")
                }
                if let book = service.books.first(where: { $0.name == title }) {
                    Button(book.name) { reading = book }
                        .accessibilityIdentifier("local-import-read")
                    Text("章节数：\(book.totalChapters)")
                        .accessibilityIdentifier("local-import-chapter-count")
                    Button("删除固定书籍") { service.deleteBook(book) }
                        .accessibilityIdentifier("local-import-delete")
                }
                if let error { Text(error) }
            }
            .navigationTitle("本地导入验证")
            .sheet(item: $importing) { url in
                NavigationStack { LocalBookImportView(fileURL: url) }
            }
            .fullScreenCover(item: $reading) { book in
                NavigationStack {
                    Group {
                        if isPDF { LocalPDFReaderView(book: book) }
                        else { LocalReaderView(book: book, settings: $settings) }
                    }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("关闭") { reading = nil }
                                    .accessibilityIdentifier("local-import-reader-close")
                            }
                        }
                }
            }
        }
        .task {
            do {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(isEpub ? "sample.epub" : title + (isPDF ? ".pdf" : ".txt"))
                if isEpub { try EpubSampleSelfTest.writeFixture(to: url) }
                else if isPDF { try PDFSampleSelfTest.writeFixture(to: url) }
                else {
                    try "第一章 初见\n固定本地正文已经到达阅读器。\n第二章 重逢\n固定本地正文乙。\n第三章 终章\n固定本地正文丙。"
                        .write(to: url, atomically: true, encoding: .utf8)
                }
                input = url
            } catch { self.error = error.localizedDescription }
        }
    }
}
