// T-1602：Python标准库zipfile生成的真实deflate EPUB，含默认命名空间、中文路径和倒序spine。
import Foundation

enum EpubSampleSelfTest {
    static func writeFixture(to url: URL) throws {
        try Data(base64Encoded: fixture)!.write(to: url, options: .atomic)
    }
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
            emit("epub_namespaced_title", ["固定EPUB书籍"], [parsed.title ?? ""])
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
            emit("epub_import_metadata_and_cover", ["固定EPUB书籍", "UTF-8", "true"],
                [imported?.name ?? "", imported?.detectedEncoding ?? "",
                 String(imported.map { cold.coverCache.coverExists(for: $0.id.uuidString) } ?? false)])
            let edited = await service.importBook(from: file, title: "用户书名", author: "用户作者", coverData: nil)
            emit("epub_preserve_user_metadata", ["用户书名", "用户作者"], [edited?.name ?? "", edited?.author ?? ""])
            try metadataCases(file: file, root: root, emit: emit)
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
            // 固定零条目ZIP，单独验证EOCD边界；系统目录归档另有目录往返样本。
            try Data([0x50, 0x4B, 0x05, 0x06] + Array(repeating: UInt8(0), count: 18)).write(to: emptyZip)
            try ZipUtility.extractZip(from: emptyZip, to: root.appendingPathComponent("empty-output"))
            emit("zip_empty_archive", ["0"], [String(ZipUtility.findEOCD(in: try Data(contentsOf: emptyZip))?.entryCount ?? -1)])
            emit("zip_invalid_deflate_rejected", ["true"], [String(ZipUtility.inflateRawDeflate(Data([0xFF]), expectedSize: 10) == nil)])
            emit("zip_invalid_record_offsets", ["true", "true"],
                [String(ZipUtility.parseCentralDirectoryEntry(data: data, offset: -1) == nil),
                 String(ZipUtility.parseLocalFileHeader(data: data, offset: data.count) == nil)])
        } catch { emit("epub_namespaced_title", ["通过"], [error.localizedDescription]) }
    }

    private static func metadataCases(file: URL, root: URL, emit: (String, [String], [String]) -> Void) throws {
        let extracted = root.appendingPathComponent("metadata-cases")
        try ZipUtility.extractZip(from: file, to: extracted)
        let base = extracted.appendingPathComponent("OEBPS")
        let opf = base.appendingPathComponent("content.opf")
        func writePackage(metadata: String, cover: String = "", guide: String = "", spine: String = "<itemref idref=\"chapter\"/>") throws {
            let xml = """
            <package xmlns="http://www.idpf.org/2007/opf"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\(metadata)</metadata>
            <manifest><item id="chapter" href="two.xhtml" media-type="application/xhtml+xml"/>\(cover)</manifest>
            <spine>\(spine)</spine>\(guide)</package>
            """
            try xml.write(to: opf, atomically: true, encoding: .utf8)
        }
        try writePackage(metadata: "<dc:title>  元数据标题  </dc:title><dc:creator>  样本作者  </dc:creator>")
        let withAuthor = try SimpleEpubParser.parseContents(in: extracted)
        emit("epub_metadata_author_trimmed", ["元数据标题", "样本作者"], [withAuthor.title ?? "", withAuthor.author ?? ""])
        try writePackage(metadata: "<dc:title> </dc:title>")
        let absent = try SimpleEpubParser.parseContents(in: extracted)
        emit("epub_missing_metadata_optional", ["true", "true"], [String(absent.title == nil), String(absent.author == nil)])
        let coverItem = "<item id=\"art\" href=\"cover.jpg\" media-type=\"image/jpeg\" properties=\"nav COVER-IMAGE\"/>"
        try writePackage(metadata: "", cover: coverItem)
        emit("epub_cover_properties", ["fixed-cover"], [String(data: try SimpleEpubParser.parseContents(in: extracted).coverData ?? Data(), encoding: .utf8) ?? ""])
        try writePackage(metadata: "<meta name=\"COVER\" content=\"missing\"/>", cover: coverItem)
        emit("epub_cover_missing_meta_fallback", ["fixed-cover"], [String(data: try SimpleEpubParser.parseContents(in: extracted).coverData ?? Data(), encoding: .utf8) ?? ""])
        try "<html><body><img src=\"cover.jpg?size=1#image\"/></body></html>".write(to: base.appendingPathComponent("cover.xhtml"), atomically: true, encoding: .utf8)
        try writePackage(metadata: "", guide: "<guide><reference type=\"COVER\" href=\"cover.xhtml#start\"/></guide>")
        emit("epub_guide_cover_html", ["fixed-cover"], [String(data: try SimpleEpubParser.parseContents(in: extracted).coverData ?? Data(), encoding: .utf8) ?? ""])
        try "<html><body><svg><image href=\"cover.jpg\"/></svg></body></html>".write(to: base.appendingPathComponent("cover.xhtml"), atomically: true, encoding: .utf8)
        emit("epub_guide_cover_svg", ["fixed-cover"], [String(data: try SimpleEpubParser.parseContents(in: extracted).coverData ?? Data(), encoding: .utf8) ?? ""])
        try writePackage(metadata: "", cover: "<item id=\"unrelated\" href=\"art.jpg\" media-type=\"image/jpeg\"/>")
        try Data("not-a-cover".utf8).write(to: base.appendingPathComponent("art.jpg"))
        emit("epub_unrelated_image_not_cover", ["true"], [String(try SimpleEpubParser.parseContents(in: extracted).coverData == nil)])
        try writePackage(metadata: "", spine: "")
        emit("epub_missing_spine_manifest_fallback", ["章二标题"],
            try SimpleEpubParser.parseContents(in: extracted).chapters.map(\.title))
        try writePackage(metadata: "", spine: "<itemref idref=\"chapter\"/><itemref idref=\"chapter\"/>")
        emit("epub_duplicate_spine_path", ["1"], [String(try SimpleEpubParser.parseContents(in: extracted).chapters.count)])
        try "<html><body><h2>标题/保留</h2><p>标题/保留</p><p>保留正文</p></body></html>"
            .write(to: base.appendingPathComponent("two.xhtml"), atomically: true, encoding: .utf8)
        let clean = try SimpleEpubParser.parseContents(in: extracted)
        emit("epub_remove_repeated_heading", ["标题/保留", "保留正文"], [clean.chapters[0].title, clean.chapters[0].content])
        try "<html><body><h2>空标题</h2><p>空标题</p></body></html>"
            .write(to: base.appendingPathComponent("two.xhtml"), atomically: true, encoding: .utf8)
        var message = ""
        do { _ = try SimpleEpubParser.parseContents(in: extracted) } catch { message = error.localizedDescription }
        emit("epub_empty_content_error", ["未解析到可阅读章节"], [message])
    }

    private static let fixture = "UEsDBBQAAAAIAEAHfF1SBUtvagAAAI8AAAAWAAAATUVUQS1JTkYvY29udGFpbmVyLnhtbE3MMQrDMAyF4asE76134XgoZE6hJzCOTA22ZCwZevy2GZJsb/i/5yKThkzYp08tJLMZnYCDZAEKFQU0AjekjeOoSAp7Bgcz3nVmTbmgnHNKo5RbC/qezbo8ni/7Bz9+55aM9c5ekD3O/BdQSwMEFAAAAAgAQAd8XdNwueEdAQAA7AEAABEAAABPRUJQUy9jb250ZW50Lm9wZpWRTU7DMBCFrxIZZYXIpAipVZQENVL3bDiAZU8Sl/hHyUDKIbgA7FkisYTzUHEN3PwJluw89nvf87NTx8UdrzA46MZ0GauJXALQ932kpCsj21ZwGcdrsK5keaqRuOTER3kixeJw920zqKUAbFCjoQ5W0Qq8S4qEFDWYH18+j2/Pu5vb4uvj9fv9KYXlaEAHhmvMmLAP2LJAWEMeM8+QpzDnezk3qsSO8lQR6kDJjFmDLKhbLDMW7tbhtgi3cbi7CotNuImjQ026uT5kqzOyjgUapeIX9Oh8HneuUYKTsgYG2bmvd8pb0NTbGe2XI+u/jKnVSBmGaO+qvxSl/V/A3mE11l1Kdk4ZHGHe73nzXeaIX7undzi5Jw9MX5z/AFBLAwQUAAAICABAB3xdO8X8z0YAAABPAAAAEgAAAE9FQlBTL+eroOS4gC54aHRtbLPJKMnNsbNJyk+ptLPJMLJ7vnrBkx0Nzxa0v1w0w0YfKGBTYPds7eJn09qfT9lko18A4j9fs+bJrp5n67aC+foQvfpggwBQSwMEFAAAAAgAQAd8XZ/rd147AAAAPwAAAA8AAABPRUJQUy90d28ueGh0bWyzySjJzbGzScpPqbSzyTC0e756wZNdPc8WtL9cNMNGHyhgU2D3bO3iZ9Pan+ycaaNfYGejD1GrD9YIAFBLAwQUAAAACABAB3xd+QKFog0AAAALAAAADwAAAE9FQlBTL2NvdmVyLmpwZ0vLrEhN0U3OL0stAgBQSwECFAAUAAAACABAB3xdUgVLb2oAAACPAAAAFgAAAAAAAAAAAAAAgAEAAAAATUVUQS1JTkYvY29udGFpbmVyLnhtbFBLAQIUABQAAAAIAEAHfF3TcLnhHQEAAOwBAAARAAAAAAAAAAAAAACAAZ4AAABPRUJQUy9jb250ZW50Lm9wZlBLAQIUABQAAAgIAEAHfF07xfzPRgAAAE8AAAASAAAAAAAAAAAAAACAAeoBAABPRUJQUy/nq6DkuIAueGh0bWxQSwECFAAUAAAACABAB3xdn+t3XjsAAAA/AAAADwAAAAAAAAAAAAAAgAFgAgAAT0VCUFMvdHdvLnhodG1sUEsBAhQAFAAAAAgAQAd8XfkChaINAAAACwAAAA8AAAAAAAAAAAAAAIAByAIAAE9FQlBTL2NvdmVyLmpwZ1BLBQYAAAAABQAFAD0BAAACAwAAAAA="
}
