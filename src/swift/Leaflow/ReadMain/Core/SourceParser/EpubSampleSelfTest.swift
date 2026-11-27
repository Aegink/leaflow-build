// T-1602：Python标准库zipfile生成的真实deflate EPUB，含默认命名空间、中文路径和倒序spine。
import Foundation

enum EpubSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("epub-sample-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let file = root.appendingPathComponent("sample.epub")
            let data = Data(base64Encoded: fixture)!
            try data.write(to: file)
            let parsed = try SimpleEpubParser.parse(epubURL: file)
            emit("epub_namespaced_title", ["固定EPUB书籍"], [parsed.title])
            emit("epub_spine_order_titles", ["章二标题", "章一标题"], parsed.chapters.map(\.title))
            emit("epub_deflate_unicode_paths", ["正文乙", "正文甲\n\n第二段"], parsed.chapters.map(\.content))
            emit("epub_cover_bytes", ["fixed-cover"], [parsed.coverData.flatMap { String(data: $0, encoding: .utf8) } ?? ""])
            let service = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            let imported = await service.importBook(from: file)
            emit("epub_import_content_cache", ["2", "正文乙", "正文甲\n\n第二段"],
                [String(imported?.totalChapters ?? -1), imported.flatMap { service.getChapterContent(book: $0, chapterIndex: 0) } ?? "",
                 imported.flatMap { service.getChapterContent(book: $0, chapterIndex: 1) } ?? ""])
            let cold = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            emit("epub_import_cold_reload", ["1", "正文乙"], [String(cold.books.count),
                cold.books.first.flatMap { cold.getChapterContent(book: $0, chapterIndex: 0) } ?? ""])
            var corrupted = data
            let central = ZipUtility.findEOCD(in: data)!.centralDirectoryOffset
            corrupted[central + 16] ^= 0x01
            try corrupted.write(to: file)
            var rejected = false
            do { _ = try SimpleEpubParser.parse(epubURL: file) } catch { rejected = true }
            emit("zip_corrupt_crc_rejected", ["true"], [String(rejected)])
            var traversal = data
            let unsafeName = Data(("../" + String(repeating: "x", count: 19)).utf8)
            traversal.replaceSubrange(30..<52, with: unsafeName)
            traversal.replaceSubrange((central + 46)..<(central + 68), with: unsafeName)
            try traversal.write(to: file)
            var traversalRejected = false
            do { try ZipUtility.extractZip(from: file, to: root.appendingPathComponent("extracted")) }
            catch { traversalRejected = true }
            emit("zip_parent_path_rejected", ["true", "false"], [String(traversalRejected),
                String(FileManager.default.fileExists(atPath: root.appendingPathComponent(String(repeating: "x", count: 19)).path))])
            let emptyDirectory = root.appendingPathComponent("empty")
            try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
            let emptyZip = root.appendingPathComponent("empty.zip")
            try ZipUtility.createZip(from: emptyDirectory, to: emptyZip)
            try ZipUtility.extractZip(from: emptyZip, to: root.appendingPathComponent("empty-output"))
            emit("zip_empty_archive", ["0"], [String(ZipUtility.findEOCD(in: try Data(contentsOf: emptyZip))?.entryCount ?? -1)])
            emit("zip_invalid_deflate_rejected", ["true"], [String(ZipUtility.inflateRawDeflate(Data([0xFF]), expectedSize: 10) == nil)])
            emit("zip_invalid_record_offsets", ["true", "true"],
                [String(ZipUtility.parseCentralDirectoryEntry(data: data, offset: -1) == nil),
                 String(ZipUtility.parseLocalFileHeader(data: data, offset: data.count) == nil)])
        } catch { emit("epub_namespaced_title", ["通过"], [error.localizedDescription]) }
    }

    private static let fixture = "UEsDBBQAAAAIAEAHfF1SBUtvagAAAI8AAAAWAAAATUVUQS1JTkYvY29udGFpbmVyLnhtbE3MMQrDMAyF4asE76134XgoZE6hJzCOTA22ZCwZevy2GZJsb/i/5yKThkzYp08tJLMZnYCDZAEKFQU0AjekjeOoSAp7Bgcz3nVmTbmgnHNKo5RbC/qezbo8ni/7Bz9+55aM9c5ekD3O/BdQSwMEFAAAAAgAQAd8XdNwueEdAQAA7AEAABEAAABPRUJQUy9jb250ZW50Lm9wZpWRTU7DMBCFrxIZZYXIpAipVZQENVL3bDiAZU8Sl/hHyUDKIbgA7FkisYTzUHEN3PwJluw89nvf87NTx8UdrzA46MZ0GauJXALQ932kpCsj21ZwGcdrsK5keaqRuOTER3kixeJw920zqKUAbFCjoQ5W0Qq8S4qEFDWYH18+j2/Pu5vb4uvj9fv9KYXlaEAHhmvMmLAP2LJAWEMeM8+QpzDnezk3qsSO8lQR6kDJjFmDLKhbLDMW7tbhtgi3cbi7CotNuImjQ026uT5kqzOyjgUapeIX9Oh8HneuUYKTsgYG2bmvd8pb0NTbGe2XI+u/jKnVSBmGaO+qvxSl/V/A3mE11l1Kdk4ZHGHe73nzXeaIX7undzi5Jw9MX5z/AFBLAwQUAAAICABAB3xdO8X8z0YAAABPAAAAEgAAAE9FQlBTL+eroOS4gC54aHRtbLPJKMnNsbNJyk+ptLPJMLJ7vnrBkx0Nzxa0v1w0w0YfKGBTYPds7eJn09qfT9lko18A4j9fs+bJrp5n67aC+foQvfpggwBQSwMEFAAAAAgAQAd8XZ/rd147AAAAPwAAAA8AAABPRUJQUy90d28ueGh0bWyzySjJzbGzScpPqbSzyTC0e756wZNdPc8WtL9cNMNGHyhgU2D3bO3iZ9Pan+ycaaNfYGejD1GrD9YIAFBLAwQUAAAACABAB3xd+QKFog0AAAALAAAADwAAAE9FQlBTL2NvdmVyLmpwZ0vLrEhN0U3OL0stAgBQSwECFAAUAAAACABAB3xdUgVLb2oAAACPAAAAFgAAAAAAAAAAAAAAgAEAAAAATUVUQS1JTkYvY29udGFpbmVyLnhtbFBLAQIUABQAAAAIAEAHfF3TcLnhHQEAAOwBAAARAAAAAAAAAAAAAACAAZ4AAABPRUJQUy9jb250ZW50Lm9wZlBLAQIUABQAAAgIAEAHfF07xfzPRgAAAE8AAAASAAAAAAAAAAAAAACAAeoBAABPRUJQUy/nq6DkuIAueGh0bWxQSwECFAAUAAAACABAB3xdn+t3XjsAAAA/AAAADwAAAAAAAAAAAAAAgAFgAgAAT0VCUFMvdHdvLnhodG1sUEsBAhQAFAAAAAgAQAd8XfkChaINAAAACwAAAA8AAAAAAAAAAAAAAIAByAIAAE9FQlBTL2NvdmVyLmpwZ1BLBQYAAAAABQAFAD0BAAACAwAAAAA="
}
