// 原路径: ReadMain/Services/MangaImageCacheService.swift
// 证据:
//   - PGO: 29 个主函数（index/task_functions.csv T-304-02 / MangaImageCacheService.swift），
//     地址：init 0x10035d56c L110-123 / MangaImageDecoder.decode(data:url:source:)
//     0x10035c530 L12-36 / normalizedRule 0x10035cd28 L38-47 / byteData(from: JSValue)
//     0x10035ced0 L49-70 / getImage(url:headers:requestContext:) 0x10035da74
//     L132-173（cacheKey → loadFromDisk → NSCache setObject:forKey:cost: 确证）/
//     removeActiveTask 0x10035e3b8 L175-177 / preloadImages 0x10035e448 L185-189 /
//     preloadImage 0x10035e58c L205-230 / clearAll 0x10035ec14 L245-252 /
//     directorySize 0x10035efac L263-277 / loadFromSource 0x10035f39c L286-340
//     （inspectDocument/PDFPageImageSource.renderPage/NSURLSession.bytes|data 确证）/
//     isSuccessfulImageResponse 0x1003608b0 L385-395（statusCode 200-299 确证）/
//     decodeImageLoadResult 0x100360f8c L363-383 / renderPDFPage 0x100361518
//     L404-415（pdfDocuments ivar + PDFPageImageSource.renderPage(2048.0) +
//     PDFPageImageSource.parse 确证）/ cacheKey 0x10036171c L421-435 /
//     loadFromDisk 0x100361d3c L437-442 / saveToDisk 0x100362008 L449-453
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/MangaImageCacheService.c
//   - 事实：三级缓存（NSCache 内存 → 磁盘 → 网络源）+ PDF 页渲染通道
//     （PDFPageImageSource.parse → renderPage(2048)）+ JS 解码通道
//     （MangaImageDecoder，normalizedRule/byteData(from: JSValue)）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 三级缓存/PDF 通道/statusCode: high（选择子+字面量确证）
//   - JS 解码域细节: medium-high（byteData 签名确证）
// 还原: 2026-11-19

import Foundation
import PDFKit
import UIKit
import JavaScriptCore

/// PDF 页图片请求（url 形态：pdf://<bookId>/<pageIndex>）。
struct PDFPageImageRequest: Equatable {
    let bookId: String
    let pageIndex: Int
}

/// PDF 文档元数据。
struct PDFDocumentMetadata {
    var pageCount: Int
    var chapters: [LocalChapter]
}

// MARK: - JS 解码器

/// 漫画图片 JS 解码器（normalizedRule/byteData 确证）。
enum MangaImageDecoder {

    /// 伪代码 0x10035cd28（L38-47）：规则串归一。
    static func normalizedRule(_ rule: String) -> String {
        rule.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 伪代码 0x10035ced0（L49-70）：JSValue → 字节数组
    ///（byteData(from: JSValue) 签名确证）。
    static func byteData(from value: Any?) -> Data? {
        guard let array = value as? [NSNumber] else { return nil }
        return Data(array.compactMap { $0.uint8Value })
    }

    /// 伪代码 0x10035c530（L12-36）：数据解码主入口
    ///（规则命中走 JS；否则原样转图）。
    static func decode(
        data: Data,
        url: String,
        source: BookSource?,
        requestContext: MangaImageRequestContext?
    ) -> UIImage? {
        if let rule = requestContext?.imageDecodeRule, !rule.isEmpty,
           let decoded = decodeViaJS(data: data, rule: rule, url: url, source: source) {
            return decoded
        }
        return UIImage(data: data)
    }

    /// JS 规则解码（AnalyzeRule 域消费；桥细节待真机对照）。
    private static func decodeViaJS(
        data: Data, rule: String, url: String, source: BookSource?
    ) -> UIImage? {
        guard let decoded = JSRuleDecoder.apply(rule: rule, data: data, url: url) else {
            return nil
        }
        return UIImage(data: decoded)
    }
}

/// JS 规则解码桥（占位；AnalyzeRule 域 T-201 消费）。
enum JSRuleDecoder {
    static func apply(rule: String, data: Data, url: String) -> Data? {
        nil
    }
}

// MARK: - 缓存服务

/// 漫画图片缓存服务（内存/磁盘/网络三级 + PDF 通道）。
@MainActor
final class MangaImageCacheService {

    /// 加载结果（closure #4 返回域确证）。
    enum ImageLoadResult {
        case image(UIImage)
        case failure(String)
    }

    static let shared = MangaImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheDirectory: URL
    private var pdfDocuments: [String: PDFDocument] = [:]
    private var activeTasks: [String: Task<ImageLoadResult, Never>] = [:]
    private let fileManager = FileManager.default

    init() {
        memoryCache.countLimit = 128
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = caches.appendingPathComponent("manga_images", isDirectory: true)
        try? fileManager.createDirectory(
            at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: 主入口

    /// 伪代码 0x10035da74（L132-173）：取图主链
    ///（cacheKey → 内存 → 磁盘 → 网络；NSCache setObject:forKey:cost: L817 确证）。
    func getImage(
        url: String,
        headers: [String: String],
        requestContext: MangaImageRequestContext?
    ) async -> ImageLoadResult {
        let key = Self.cacheKey(for: url, requestContext: requestContext)
        // 内存缓存。
        if let cached = memoryCache.object(forKey: key as NSString) {
            return .image(cached)
        }
        // 磁盘缓存。
        if let data = loadFromDisk(key: key),
           let image = MangaImageDecoder.decode(
            data: data, url: url,
            source: requestContext?.source,
            requestContext: requestContext) {
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return .image(image)
        }
        // 去重活动任务。
        if let active = activeTasks[key] {
            return await active.value
        }
        let task = Task<ImageLoadResult, Never> {
            let result = await loadFromSource(
                url: url, headers: headers, requestContext: requestContext)
            removeActiveTask(key: key)
            if case .image(let image) = result {
                memoryCache.setObject(image, forKey: key as NSString)
            }
            return result
        }
        activeTasks[key] = task
        return await task.value
    }

    /// 伪代码 0x10035e3b8（L175-177）：活动任务移除。
    private func removeActiveTask(key: String) {
        activeTasks.removeValue(forKey: key)
    }

    // MARK: 网络源

    /// 伪代码 0x10035f39c（L286-340）：网络加载
    ///（PDF 通道 inspectDocument/renderPage + NSURLSession.data 确证）。
    private func loadFromSource(
        url: String,
        headers: [String: String],
        requestContext: MangaImageRequestContext?
    ) async -> ImageLoadResult {
        // PDF 页通道（pdf:// 前缀推断）。
        if url.hasPrefix("pdf://") {
            guard let request = PDFPageImageSource.parse(url),
                  let bookURL = PDFPageImageSource.makeURL(bookId: request.bookId) else {
                return .failure("PDF 源无效")
            }
            if let image = renderPDFPage(request) {
                return .image(image)
            }
            return .failure("PDF 页渲染失败")
        }
        // HTTP 通道（NSURLSession.data 确证）。
        guard let requestURL = URL(string: url) else {
            return .failure("URL 无效")
        }
        var request = URLRequest(url: requestURL)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard Self.isSuccessfulImageResponse(response) else {
                return .failure("响应码非 2xx")
            }
            guard let image = MangaImageDecoder.decode(
                data: data, url: url,
                source: requestContext?.source,
                requestContext: requestContext) else {
                return .failure("图片解码失败")
            }
            saveToDisk(data: data, key: Self.cacheKey(for: url, requestContext: requestContext))
            return .image(image)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    /// 伪代码 0x1003608b0（L385-395）：statusCode 200-299 确证。
    static func isSuccessfulImageResponse(_ response: URLResponse?) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return (200...299).contains(httpResponse.statusCode)
    }

    /// 伪代码 0x100360f8c（L363-383）：载荷 → 结果。
    private func decodeImageLoadResult(data: Data, url: String) -> ImageLoadResult {
        if let image = UIImage(data: data) {
            return .image(image)
        }
        return .failure("图片解码失败")
    }

    // MARK: PDF 通道

    /// 伪代码 0x100361518（L404-415）：PDF 页渲染
    ///（pdfDocuments ivar + PDFPageImageSource.renderPage(2048.0)/parse 确证）。
    private func renderPDFPage(_ request: PDFPageImageRequest) -> UIImage? {
        let document: PDFDocument
        if let cached = pdfDocuments[request.bookId] {
            document = cached
        } else {
            guard let bookURL = PDFPageImageSource.makeURL(bookId: request.bookId),
                  let loaded = PDFDocument(url: bookURL) else { return nil }
            pdfDocuments[request.bookId] = loaded
            document = loaded
        }
        return PDFPageImageSource.renderPage(
            document: document, pageIndex: request.pageIndex, maxPixelSize: 2048.0)
    }

    // MARK: 预加载

    /// 伪代码 0x10035e448（L185-189）：批量预加载。
    func preloadImages(urls: [String], headers: [String: String]) {
        for url in urls {
            preloadImage(url: url, headers: headers)
        }
    }

    /// 伪代码 0x10035e58c（L205-230）+ closure #2（0x10035e930，L211-228）。
    private func preloadImage(url: String, headers: [String: String]) {
        let key = Self.cacheKey(for: url, requestContext: nil)
        guard memoryCache.object(forKey: key as NSString) == nil,
              loadFromDisk(key: key) == nil else { return }
        BackgroundWork.fireAndForgetAsync(priority: .utility) { [weak self] in
            _ = await self?.getImage(url: url, headers: headers, requestContext: nil)
        }
    }

    // MARK: 磁盘/清理

    /// 伪代码 0x100361d3c（L437-442）：磁盘读。
    private func loadFromDisk(key: String) -> Data? {
        let url = diskCacheDirectory.appendingPathComponent(Self.diskFileName(for: key))
        return try? Data(contentsOf: url)
    }

    /// 伪代码 0x100362008（L449-453）：磁盘写。
    private func saveToDisk(data: Data, key: String) {
        let url = diskCacheDirectory.appendingPathComponent(Self.diskFileName(for: key))
        try? data.write(to: url, options: .atomic)
    }

    /// 伪代码 0x10036171c（L421-435）：缓存键（url + 上下文哈希）。
    static func cacheKey(for url: String, requestContext: MangaImageRequestContext?) -> String {
        guard let context = requestContext,
              let rule = context.imageDecodeRule, !rule.isEmpty else {
            return url
        }
        return "\(url)#\(rule)"
    }

    /// 磁盘文件名（hash 域）。
    private static func diskFileName(for key: String) -> String {
        "\(abs(key.hashValue)).img"
    }

    /// 伪代码 0x10035ec14（L245-252）：清空全部。
    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheDirectory)
        try? fileManager.createDirectory(
            at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    /// 伪代码 0x10035efac（L263-277）：目录体积。
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }
}
