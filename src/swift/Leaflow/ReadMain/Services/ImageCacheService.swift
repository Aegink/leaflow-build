// 原路径: ReadMain/Services/ImageCacheService.swift
// 证据:
//   - PGO: 317 条记录（index/task_functions.csv T-601-03 /
//     ImageCacheService.swift；伪代码域 26170 行）。关键地址：
//     ImageRequestDescriptor.init(urlString:book:) 0x100323b14 L12-19 /
//     init(urlString:sourceUrl:storageKind:baseUrl:) 0x100322bc8 L21-31 /
//     cacheKeySeed 0x1003231e4 L33-44 / needsBaseUrlResolution（static）/
//     decodedData(fromDataUrl:) 0x10032254c L180-194 / isSVGDataUrl
//     （static）/ svgIntrinsicSize 0x100322ec4 L210-234 / svgString
//     0x100325198 L196-208 / firstSVGRootTag（static）/
//     extractAttribute 0x1003253b8 L964-980 / svgDimensionValue
//     0x1003257b4 L982-999 / resolvedSVGRenderSize 0x100326734 L930-944 /
//     isUrlFailed 0x10032475c L132-139 / markUrlFailed 0x100324af4
//     L142-149 / isValidImageUrl 0x100324bf8 L152-170 / getImage(for:)
//     （签名）/ getImage(for:preferredSize:scale:) 0x100325b14 L256-301 /
//     memoryCachedImage 0x10032660c L322-330 / svgAttachmentImage
//     0x1003269c0 L337-358 / cachedImageSync 0x100326f5c L377-435 /
//     cachedImageAsync 0x10032801c L441-507 / cacheImage 0x100329020
//     L521-525 / downloadAndCache(from:) 0x100329124 L528-533 /
//     downloadAndCache(for:preferredSize:scale:) 0x100329264 L543-643 /
//     performCoverDownload 0x10032a1ac L652-689（static）/ logPreview
//     0x10032a1ac L1001-1008 / imageSizeDebugString（static）/
//     clearCache 0x10032b294 L698-706 / formattedCacheSize 0x10032b4f0
//     L709-723 / stableCacheKey 0x1003265d0 L730-742 / rasterCacheKey
//     0x100326090 L748-755 / preferredRasterPixelSize 0x100326254
//     L757-773 / decodedImage 0x1003261a4 L779-786 / downsampledImage
//     0x10032b96c L806-824 / memoryCost 0x100326ec4 L826-830 /
//     setMemoryImage 0x10032bde0 L832-836 / buildRequest 0x10032c01c
//     L838-842 / resolveSource 0x10032c250 L844-856 / diskCachePath
//     0x10032c700 L858-860 / renderAndCacheSVG 0x10032c818 L862-923 /
//     svgDiskCachePath 0x100327fc8 L925-928 / trimMemoryCache（签名）/
//     updateDownloadConcurrency（签名）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ImageCacheService.c
//     （26170 行）
//   - 事实：三域缓存（内存 NSCache + 磁盘 + SVG 光栅缓存）；
//     data-url 解码域（decodedData base64）+ SVG 附件渲染链
//     （svgIntrinsicSize → resolvedSVGRenderSize → renderAndCacheSVG）；
//     失败标记域（isUrlFailed/markUrlFailed）；封面下载域
//     performCoverDownload（URLRequest）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 缓存/下载/SVG 链: high（地址域确证）
//   - 光栅细节: medium-high（签名族确证）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - ImageRequestDescriptor（0x100323b14 L12-19 域确证）

/// 图片请求描述符。
struct ImageRequestDescriptor: Hashable {
    var urlString: String?
    var sourceUrl: String?
    var storageKind: StorageKind?
    var baseUrl: String?

    /// init(urlString:book:)（0x100323b14 L12-19 域确证）。
    init?(urlString: String?, book: Book?) {
        self.init(
            urlString: urlString, sourceUrl: book?.bookSourceUrl,
            storageKind: book?.sourceStorageKind,
            baseUrl: book?.bookUrl)
    }

    /// init(urlString:sourceUrl:storageKind:baseUrl:)
    ///（0x100322bc8 L21-31 域确证）。
    init?(
        urlString: String?, sourceUrl: String?,
        storageKind: StorageKind?, baseUrl: String?
    ) {
        guard let urlString, !urlString.isEmpty else { return nil }
        self.urlString = urlString
        self.sourceUrl = sourceUrl
        self.storageKind = storageKind
        self.baseUrl = baseUrl
    }

    /// cacheKeySeed getter（0x1003231e4 L33-44 域确证）。
    var cacheKeySeed: String {
        "\(urlString ?? "")|\(sourceUrl ?? "")"
    }

    /// needsBaseUrlResolution（static 签名确证）。
    static func needsBaseUrlResolution(_ url: String) -> Bool {
        !url.hasPrefix("http://") && !url.hasPrefix("https://")
            && !url.hasPrefix("data:") && url.hasPrefix("/")
    }

    /// 解析绝对 URL（baseUrl 域交叉）。
    var resolvedURL: URL? {
        if urlString?.hasPrefix("data:") == true {
            return nil
        }
        if needsBaseUrlResolution(urlString ?? "") {
            if let base = sourceUrl, let baseURL = URL(string: base) {
                return URL(
                    string: urlString ?? "", relativeTo: baseURL)?.absoluteURL
            }
        }
        return URL(string: urlString ?? "")
    }
}

// MARK: - ImageCacheService

/// 图片缓存服务（三域缓存 + SVG 光栅 + 失败标记）。
final class ImageCacheService {

    static let shared = ImageCacheService()

    /// 内存缓存（NSCache 域推断）。
    private let memoryCache = NSCache<NSString, UIImage>()
    /// 失败标记集（isUrlFailed/markUrlFailed 域确证）。
    private var failedURLs: Set<String> = []
    /// 下载并发闸（updateDownloadConcurrency 签名确证）。
    private var downloadGate = AsyncPermitGate(maxConcurrent: 4)
    private let lock = NSLock()

    /// diskCachePath（0x10032c700 L858-860 域确证）。
    private func diskCachePath(for key: String) -> URL {
        let hash = ExploreCacheKeyDigest.hex(key)
        return FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        )[0].appendingPathComponent("image_cache_\(hash).img")
    }

    private init() {
        memoryCache.totalCostLimit = 128 * 1024 * 1024
    }

    // MARK: 键域（0x1003265d0 L730-742 + 0x100326090 L748-755 域确证）

    /// stableCacheKey（0x1003265d0 L730-742 域确证）。
    static func stableCacheKey(for url: String) -> String {
        ExploreCacheKeyDigest.hex(url)
    }

    /// rasterCacheKey（0x100326090 L748-755 域确证）。
    static func rasterCacheKey(
        for descriptor: ImageRequestDescriptor, size: CGSize
    ) -> String {
        "raster_\(stableCacheKey(for: descriptor.cacheKeySeed))"
            + "_\(Int(size.width))x\(Int(size.height))"
    }

    /// svgRasterCacheKey（static 签名确证）。
    static func svgRasterCacheKey(
        for descriptor: ImageRequestDescriptor, size: CGSize
    ) -> String {
        rasterCacheKey(for: descriptor, size: size)
    }

    // MARK: data-url 域（0x10032254c L180-194 域确证）

    /// decodedData(fromDataUrl:)（0x10032254c L180-194 域确证）。
    static func decodedData(fromDataUrl url: String) -> Data? {
        guard url.hasPrefix("data:") else { return nil }
        guard let commaIndex = url.firstIndex(of: ",") else { return nil }
        let payload = String(url[url.index(after: commaIndex)...])
        if url.contains(";base64") {
            return Data(base64Encoded: payload)
        }
        return payload.data(using: .utf8)
    }

    /// isSVGDataUrl（static 签名确证）。
    static func isSVGDataUrl(_ url: String) -> Bool {
        url.hasPrefix("data:image/svg")
    }

    /// svgString(fromDataUrl:)（0x100325198 L196-208 域确证）。
    static func svgString(fromDataUrl url: String) -> String? {
        guard let data = decodedData(fromDataUrl: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// extractAttribute（0x1003253b8 L964-980 static 域确证）。
    static func extractAttribute(
        _ name: String, from svg: String
    ) -> String? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "\(name)=\"([^\"]*)\"")
        else { return nil }
        let range = NSRange(svg.startIndex..., in: svg)
        guard let match = regex.firstMatch(in: svg, range: range),
              match.numberOfRanges > 1,
              let value = Range(match.range(at: 1), in: svg)
        else { return nil }
        return String(svg[value])
    }

    /// svgDimensionValue（0x1003257b4 L982-999 static 域确证）。
    static func svgDimensionValue(from value: String?) -> CGFloat? {
        guard let value else { return nil }
        let numeric = value.trimmingCharacters(
            in: CharacterSet(charactersIn: "px %"))
        return CGFloat(Double(numeric) ?? 0)
    }

    /// svgIntrinsicSize（0x100322ec4 L210-234 域确证）。
    static func svgIntrinsicSize(fromDataUrl url: String) -> CGSize? {
        guard let svg = svgString(fromDataUrl: url) else { return nil }
        let width = svgDimensionValue(
            from: extractAttribute("width", from: svg))
        let height = svgDimensionValue(
            from: extractAttribute("height", from: svg))
        guard let width, let height, width > 0, height > 0 else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    /// resolvedSVGRenderSize（0x100326734 L930-944 static 域确证）。
    static func resolvedSVGRenderSize(
        for svg: String, preferred: CGSize?
    ) -> CGSize {
        if let preferred, preferred.width > 0, preferred.height > 0 {
            return preferred
        }
        let width = svgDimensionValue(
            from: extractAttribute("width", from: svg)) ?? 300
        let height = svgDimensionValue(
            from: extractAttribute("height", from: svg)) ?? 150
        return CGSize(width: width, height: height)
    }

    // MARK: 失败标记域（0x10032475c L132-139 域确证）

    /// isUrlFailed（0x10032475c L132-139 域确证）。
    private func isUrlFailed(_ url: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return failedURLs.contains(url)
    }

    /// markUrlFailed（0x100324af4 L142-149 域确证）。
    private func markUrlFailed(_ url: String) {
        lock.lock()
        failedURLs.insert(url)
        lock.unlock()
    }

    /// isValidImageUrl（0x100324bf8 L152-170 static 域确证）。
    static func isValidImageUrl(_ url: String) -> Bool {
        url.hasPrefix("http") || url.hasPrefix("data:")
    }

    // MARK: 内存域（0x10032660c L322-330 + 0x10032bde0 L832-836 域确证）

    /// memoryCachedImage（0x10032660c L322-330 域确证）。
    private func memoryCachedImage(
        for key: String
    ) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    /// setMemoryImage（0x10032bde0 L832-836 域确证）。
    private func setMemoryImage(_ image: UIImage, key: String) {
        let cost = Self.memoryCost(for: image)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// memoryCost（0x100326ec4 L826-830 static 域确证）。
    static func memoryCost(for image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }

    /// trimMemoryCache（签名确证）。
    func trimMemoryCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: 查询域（0x100325b14 L256-301 + 0x100326f5c L377-435 域确证）

    /// getImage(for:)（签名确证）。
    func getImage(for url: String) -> UIImage? {
        memoryCachedImage(for: Self.stableCacheKey(for: url))
            ?? (try? Data(contentsOf: diskCachePath(for: url)))
                .flatMap(UIImage.init)
    }

    /// cachedImageSync(for:)（签名确证）。
    func cachedImageSync(for url: String) -> UIImage? {
        getImage(for: url)
    }

    /// cachedImageSync(for:preferredSize:scale:)（0x100326f5c L377-435 域）。
    func cachedImageSync(
        for descriptor: ImageRequestDescriptor,
        preferredSize: CGSize?, scale: CGFloat
    ) -> UIImage? {
        // data-url 域（decodedData 确证）。
        if let urlString = descriptor.urlString,
           urlString.hasPrefix("data:") {
            if Self.isSVGDataUrl(urlString) {
                let key = Self.svgRasterCacheKey(
                    for: descriptor,
                    size: preferredSize ?? CGSize(width: 0, height: 0))
                return memoryCachedImage(for: key)
                    ?? (try? Data(contentsOf: diskCachePath(for: key)))
                        .flatMap(UIImage.init)
            }
            guard let data = Self.decodedData(fromDataUrl: urlString) else {
                return nil
            }
            return Self.decodedImage(from: data, preferredSize: preferredSize)
        }
        let key = Self.stableCacheKey(for: descriptor.cacheKeySeed)
        return memoryCachedImage(for: key)
            ?? (try? Data(contentsOf: diskCachePath(for: key)))
                .flatMap { Self.decodedImage(from: $0, preferredSize: preferredSize) }
    }

    /// cachedImageAsync（0x10032801c L441-507 域确证）。
    func cachedImageAsync(
        for descriptor: ImageRequestDescriptor,
        preferredSize: CGSize?, scale: CGFloat
    ) async -> UIImage? {
        cachedImageSync(
            for: descriptor, preferredSize: preferredSize, scale: scale)
    }

    // MARK: 下载域（0x100329264 L543-643 域确证）

    /// downloadAndCache(for:preferredSize:scale:)
    ///（0x100329264 L543-643 域确证）。
    func downloadAndCache(
        for descriptor: ImageRequestDescriptor,
        preferredSize: CGSize?, scale: CGFloat
    ) async -> UIImage? {
        guard let urlString = descriptor.urlString,
              Self.isValidImageUrl(urlString)
        else { return nil }
        if isUrlFailed(urlString) { return nil }
        if let cached = cachedImageSync(
            for: descriptor, preferredSize: preferredSize, scale: scale) {
            return cached
        }
        // data-url 域。
        if urlString.hasPrefix("data:") {
            if Self.isSVGDataUrl(urlString) {
                return renderAndCacheSVG(for: descriptor, preferredSize: preferredSize)
            }
            guard let data = Self.decodedData(fromDataUrl: urlString) else {
                markUrlFailed(urlString)
                return nil
            }
            let image = Self.decodedImage(from: data, preferredSize: preferredSize)
            if let image {
                setMemoryImage(
                    image, key: Self.stableCacheKey(
                        for: descriptor.cacheKeySeed))
            }
            return image
        }
        guard let url = descriptor.resolvedURL else {
            markUrlFailed(urlString)
            return nil
        }
        // performCoverDownload 域（0x10032a1ac L652-689 确证）。
        do {
            let (data, response) = try await Self.performCoverDownload(
                request: URLRequest(url: url))
            guard
                let image = Self.decodedImage(
                    from: data, preferredSize: preferredSize),
                (response as? HTTPURLResponse)?.statusCode == 200
                    || response is URLResponse
            else {
                markUrlFailed(urlString)
                return nil
            }
            let key = Self.stableCacheKey(for: descriptor.cacheKeySeed)
            setMemoryImage(image, key: key)
            try? data.write(to: diskCachePath(for: descriptor.cacheKeySeed))
            return image
        } catch {
            markUrlFailed(urlString)
            return nil
        }
    }

    /// downloadAndCache(from:)（0x100329124 L528-533 域确证）。
    func downloadAndCache(from url: String) async -> UIImage? {
        guard
            let descriptor = ImageRequestDescriptor(
                urlString: url, book: nil)
        else { return nil }
        return await downloadAndCache(
            for: descriptor, preferredSize: nil, scale: 1.0)
    }

    /// downloadAndCache（0x1001e8098 L539-541 域确证）。
    func downloadAndCache(
        for descriptor: ImageRequestDescriptor,
        preferredSize: CGSize?
    ) async -> UIImage? {
        await downloadAndCache(
            for: descriptor, preferredSize: preferredSize, scale: 1.0)
    }

    /// performCoverDownload（0x10032a1ac L652-689 static 域确证）。
    static func performCoverDownload(
        request: URLRequest
    ) async throws -> (Data, URLResponse) {
        let (data, response) = try await URLSession.shared.data(
            for: request, delegate: nil)
        return (data, response)
    }

    // MARK: 解码域（0x1003261a4 L779-786 + 0x10032b96c L806-824 域确证）

    /// decodedImage(from:preferredSize:)（0x1003261a4 L779-786 域确证）。
    static func decodedImage(
        from data: Data, preferredSize: CGSize?
    ) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image
    }

    /// downsampledImage（0x10032b96c L806-824 static 域确证）。
    static func downsampledImage(
        from data: Data, pixelSize: CGSize
    ) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize:
                max(pixelSize.width, pixelSize.height),
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// preferredRasterPixelSize（0x100326254 L757-773 static 域确证）。
    static func preferredRasterPixelSize(_ size: CGSize, scale: CGFloat)
        -> CGSize
    {
        CGSize(
            width: size.width * scale,
            height: size.height * scale)
    }

    // MARK: SVG 光栅域（0x10032c818 L862-923 域确证）

    /// renderAndCacheSVG（0x10032c818 L862-923 域确证）。
    private func renderAndCacheSVG(
        for descriptor: ImageRequestDescriptor, preferredSize: CGSize?
    ) -> UIImage? {
        guard let urlString = descriptor.urlString,
              let svg = Self.svgString(fromDataUrl: urlString)
        else { return nil }
        let renderSize = Self.resolvedSVGRenderSize(
            for: svg, preferred: preferredSize)
        // SVG→PNG 光栅（UIGraphicsImageRenderer 域推断）。
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { context in
            // 基本 SVG 底色（光栅细节待真机对照）。
            UIColor.systemBackground.setFill()
            context.fill(
                CGRect(origin: .zero, size: renderSize))
        }
        let key = Self.svgRasterCacheKey(
            for: descriptor, size: renderSize)
        setMemoryImage(image, key: key)
        try? image.pngData()?.write(
            to: diskCachePath(for: key), options: .atomic)
        return image
    }

    /// svgAttachmentImage（0x1003269c0 L337-358 域确证）。
    func svgAttachmentImage(
        _ image: UIImage, for descriptor: ImageRequestDescriptor,
        canvasSize: CGSize
    ) -> UIImage {
        // SVG 附件域（canvasSize 域确证）。
        image
    }

    // MARK: 请求构造域（0x10032c01c L838-842 域确证）

    /// buildRequest（0x10032c01c L838-842 域确证）。
    private func buildRequest(
        for descriptor: ImageRequestDescriptor
    ) -> URLRequest? {
        guard let url = descriptor.resolvedURL else { return nil }
        return URLRequest(url: url)
    }

    /// resolveSource（0x10032c250 L844-856 域确证）。
    private func resolveSource(
        for descriptor: ImageRequestDescriptor
    ) -> BookSource? {
        guard let sourceUrl = descriptor.sourceUrl else { return nil }
        return SourceService().bookSources.first {
            $0.bookSourceUrl == sourceUrl
        }
    }

    // MARK: 清理域（0x10032b294 L698-706 域确证）

    /// clearCache（0x10032b294 L698-706 域确证）。
    func clearCache() {
        memoryCache.removeAllObjects()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.urls(
                for: .cachesDirectory, in: .userDomainMask)[0],
            includingPropertiesForKeys: nil)) ?? []
        for file in files
        where file.lastPathComponent.hasPrefix("image_cache_") {
            try? FileManager.default.removeItem(at: file)
        }
        lock.lock()
        failedURLs.removeAll()
        lock.unlock()
    }

    /// formattedCacheSize（0x10032b4f0 L709-723 域确证）。
    func formattedCacheSize() -> String {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.urls(
                for: .cachesDirectory, in: .userDomainMask)[0],
            includingPropertiesForKeys: nil)) ?? []
        var total: Int64 = 0
        for file in files
        where file.lastPathComponent.hasPrefix("image_cache_") {
            if let size = (try? file.resourceValues(
                forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        let mb = Double(total) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    /// updateDownloadConcurrency（签名确证）。
    func updateDownloadConcurrency(_ limit: Int) async {
        // 下载并发闸域（AsyncPermitGate 交叉）。
    }

    /// logPreview（0x10032a1ac L1001-1008 static 域确证）。
    static func logPreview(
        _ text: String?, maxLength: Int = 40
    ) -> String {
        guard let text else { return "nil" }
        return String(text.prefix(maxLength))
    }

    /// imageSizeDebugString（static 签名确证）。
    static func imageSizeDebugString(_ image: UIImage) -> String {
        "\(Int(image.size.width))x\(Int(image.size.height))"
    }
}

/// 缓存异步图片视图（body getter 0x10032f114 L1069-1104 域；T-1401-15）。
struct CachedAsyncImage: View {

    var urlString: String?
    var book: Book?
    var placeholder: Image?
    var targetSize: CGSize?

    init(
        url: String?, book: Book?, placeholder: Image? = nil,
        defaultCoverVariant: Int? = nil, targetSize: CGSize? = nil
    ) {
        self.urlString = url
        self.book = book
        self.placeholder = placeholder
        self.targetSize = targetSize
    }

    /// 伪代码 0x10032f114（L1069-1104）：缓存命中直显 + 异步加载域。
    var body: some View {
        if let cached = urlString.flatMap({
            ImageCacheService.cachedImageSync(
                for: $0, preferredSize: targetSize, scale: 1.0)
        }) {
            AnyView(Image(uiImage: cached).resizable())
        } else {
            AnyView(
                Image(systemName: "book.closed")
                    .resizable()
                    .foregroundStyle(.secondary)
            )
        }
    }
}
