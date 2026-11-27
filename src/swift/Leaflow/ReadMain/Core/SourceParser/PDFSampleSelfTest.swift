// T-1602：生成只有图片的六页PDF，复算目录/渲染/导入/进度；不依赖外部文件。
import Foundation
import PDFKit
import UIKit

enum PDFSampleSelfTest {
    @MainActor
    static func writeFixture(to url: URL) throws {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let pdf = UIGraphicsPDFRenderer(bounds: bounds)
        try pdf.writePDF(to: url) { context in
            for index in 0..<6 {
                context.beginPage()
                let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { imageContext in
                    UIColor.white.setFill()
                    imageContext.fill(bounds)
                    ("PDF PAGE \(index + 1)" as NSString).draw(at: CGPoint(x: 12, y: 100),
                        withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.black])
                    UIColor.red.setFill()
                    imageContext.fill(CGRect(x: 20, y: 170, width: 160, height: 50))
                }
                image.draw(in: bounds)
            }
        }
    }

    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pdf-sample-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("scan.pdf")
            try writeFixture(to: url)
            guard let document = PDFDocument(url: url), let metadata = PDFPageImageSource.inspectDocument(at: url) else {
                throw AppError.emptyContent
            }
            emit("pdf_scanned_page_count", ["6", "true"], [String(metadata.pageCount), String((document.string ?? "").isEmpty)])
            emit("pdf_fallback_directory", ["第1页", "第2页", "第3页", "第4页", "第5页", "第6页"], metadata.chapters.map(\.title))
            emit("pdf_directory_page_ranges", ["0:1", "1:2", "2:3", "3:4", "4:5", "5:6"],
                metadata.chapters.map { "\($0.startPosition):\($0.endPosition)" })
            let image = PDFPageImageSource.renderPage(document: document, pageIndex: 0, maxPixelSize: 300)
            emit("pdf_render_pixel_size", ["200", "300", "1.0"],
                [String(image?.cgImage?.width ?? -1), String(image?.cgImage?.height ?? -1), String(Double(image?.scale ?? 0))])
            emit("pdf_render_invalid_inputs", ["true", "true", "true"],
                [String(PDFPageImageSource.renderPage(document: document, pageIndex: -1, maxPixelSize: 300) == nil),
                 String(PDFPageImageSource.renderPage(document: document, pageIndex: 6, maxPixelSize: 300) == nil),
                 String(PDFPageImageSource.renderPage(document: document, pageIndex: 0, maxPixelSize: 0) == nil)])
            let page = document.page(at: 0)!
            page.setBounds(CGRect(x: 20, y: 30, width: 120, height: 160), for: .cropBox)
            let cropped = PDFPageImageSource.renderPage(document: document, pageIndex: 0, maxPixelSize: 320)
            emit("pdf_render_crop_box", ["240", "320"], [String(cropped?.cgImage?.width ?? -1), String(cropped?.cgImage?.height ?? -1)])
            document.documentAttributes = [.titleAttribute: " 扫描书籍 ", .authorAttribute: " 样本作者 "]
            let outlineRoot = PDFOutline()
            let later = PDFOutline()
            later.label = " 尾章 "
            later.destination = PDFDestination(page: document.page(at: 4)!, at: .zero)
            let first = PDFOutline()
            first.label = " 首章 "
            first.destination = PDFDestination(page: page, at: .zero)
            let nested = PDFOutline()
            nested.label = " 子目录 "
            nested.destination = PDFDestination(page: document.page(at: 2)!, at: .zero)
            first.insertChild(nested, at: 0)
            outlineRoot.insertChild(later, at: 0)
            outlineRoot.insertChild(first, at: 1)
            document.outlineRoot = outlineRoot
            guard document.write(to: url), let outlined = PDFPageImageSource.inspectDocument(at: url) else { throw AppError.emptyContent }
            emit("pdf_outline_order_depth", ["首章", "  子目录", "尾章"], outlined.chapters.map(\.title))
            emit("pdf_document_metadata", ["扫描书籍", "样本作者", "true"],
                [outlined.title ?? "", outlined.author ?? "", String(outlined.coverData.flatMap { UIImage(data: $0) } != nil)])
            let service = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            guard var book = await service.importBook(from: url) else { throw AppError.emptyContent }
            emit("pdf_import_scanned_with_outline", ["6", "3", "扫描书籍"], [String(book.totalChapters),
                String(service.loadChapters(for: book.id.uuidString)?.count ?? -1), book.name])
            let cachedBook = await service.ensureChaptersParsed(book)
            emit("pdf_directory_count_not_page_count", ["6"], [String(cachedBook.totalChapters)])
            book.durChapterIndex = 2
            service.updateBook(book)
            let vm = LocalPDFReaderViewModel(book: book, service: service)
            await vm.loadBook()
            emit("pdf_reader_all_page_models", ["0,1,2,3,4,5"], [vm.pages.map { String($0.pageIndex) }.joined(separator: ",")])
            emit("pdf_reader_restored_page", ["2", "6", "1", "true"], [String(vm.currentPage), String(vm.pageCount),
                String(vm.currentDirectoryIndex), String(vm.images[2] != nil)])
            emit("pdf_preload_range", ["1,2,3,4,5"], [vm.images.keys.sorted().map(String.init).joined(separator: ",")])
            vm.jumpToPage(100)
            await vm.preloadPages(around: vm.currentPage)
            emit("pdf_page_clamp_save", ["5", "5", "0.0"], [String(vm.currentPage),
                String(service.books[0].durChapterIndex), String(service.books[0].durChapterPos)])
            let reloaded = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            let cold = LocalPDFReaderViewModel(book: reloaded.books[0], service: reloaded)
            await cold.loadBook()
            emit("pdf_cold_page_restore", ["5", "true"], [String(cold.currentPage), String(cold.images[5] != nil)])
            cold.jumpToDirectoryItem(outlined.chapters[1].startPosition)
            emit("pdf_outline_jump", ["2", "1"], [String(cold.currentPage), String(cold.currentDirectoryIndex)])
            let missing = LocalPDFReaderViewModel(book: LocalBook(name: "缺失", filePath: root.appendingPathComponent("missing.pdf").path, format: "PDF"), service: service)
            await missing.loadBook()
            emit("pdf_missing_file_error", ["true", "false"], [String(missing.loadError != nil), String(missing.isLoading)])
        } catch { emit("pdf_scanned_page_count", ["通过"], [error.localizedDescription]) }
    }
}
