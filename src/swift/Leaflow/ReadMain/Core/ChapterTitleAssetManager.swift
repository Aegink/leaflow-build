// 原路径: ReadMain/Core/ChapterTitleAssetManager.swift
// 证据:
//   - PGO: 37 个主函数（index/task_functions.csv T-303-01 / ChapterTitleAssetManager.swift），
//     地址：ChapterTitleAssetError.errorDescription 0x1001a6664 L30-41 /
//     importImage(from:) 0x1001a69e8 L59-66 / contentType(for: URL) 0x1001a6b08
//     L256-261 / importImage(data:preferredFilename:) 0x1001a7db4 0x1001a6db4
//     L68-100 / contentType(data:) 0x1001a73f0 L263-276 / normalizedExtension
//     0x1001a7adc L283-288 / importPackagedAsset 0x1001a7bc4 L102-128
//     （Data.write(to:options:1) L609 确证）/ mimeExtension 0x1001a7e34 L290-298 /
//     listAssets 0x1001a8058 L130-140（contentsOfDirectoryAtURL 确证）/
//     asset(from:) 0x1001a8404 L242-254 / localURL(for:) 0x1001a8ff8 L147-157 /
//     isSafeAssetID 0x1001a94cc L238-240（fileExistsAtPath: 确证）/
//     packagedAsset(for:) 0x1001a9600 L164-178 / removeAssets 0x1001a9b34
//     L184-189 / extractAssetIDs 0x1001a9d90 L195-208（matchesInString:
//     numberOfRanges/rangeAtIndex: 确证）/ rewriteAssetIDs 0x1001aa30c L214-232
//     （'":"' 字面量确证）/ ChapterTitleAssetURLSchemeHandler.webView(_:start:)
//     0x1001aa788 L308-330（URLRequest.url/host/pathComponents L4658-4694 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/ChapterTitleAssetManager.c
//   - 事实：资产 ID 正则匹配提取（matchesInString 确证）→ ID 映射重写
//     （'":"' 键值对拼接）；本地目录枚举（contentsOfDirectoryAtURL）+
//     isSafeAssetID 防目录穿越（fileExistsAtPath: 白名单）；URLSchemeHandler
//     经 host/pathComponents 定位资产回图
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导入/枚举/ID 重写/SchemeHandler 主链: high（选择子确证）
//   - 正则模式串与目录名: medium（待真机对照）
// 还原: 2026-11-19

import Foundation
import WebKit

/// 资产操作错误（LocalizedError）。
enum ChapterTitleAssetError: LocalizedError {
    case invalidAssetID(String)
    case importFailed(String)
    case notFound(String)

    /// 伪代码 0x1001a6664（L30-41）：errorDescription。
    var errorDescription: String? {
        switch self {
        case .invalidAssetID(let id):
            return "非法资产 ID：\(id)"
        case .importFailed(let detail):
            return "资产导入失败：\(detail)"
        case .notFound(let id):
            return "资产不存在：\(id)"
        }
    }
}

/// 章节标题资产（图片素材）。
struct ChapterTitleAsset: Identifiable {
    let id: String
    let fileURL: URL
    let contentType: String
}

/// 打包资产载荷（包导入链确证）。
struct ChapterTitlePackagedAsset {
    let id: String
    let data: Data
    let preferredFilename: String?
}

/// 标题资产目录管理器（图片导入/枚举/白名单/ID 重写/URLScheme）。
final class ChapterTitleAssetManager {

    /// 0x1001a6808：Application Support/ChapterTitleAssets。
    private let assetsDirectory: URL
    private let fileManager = FileManager.default

    init(applicationSupportDirectory: URL? = nil, legacyCachesDirectory: URL? = nil) {
        let support = applicationSupportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        assetsDirectory = support.appendingPathComponent("ChapterTitleAssets", isDirectory: true)
        try? fileManager.createDirectory(
            at: assetsDirectory, withIntermediateDirectories: true)
        let caches = legacyCachesDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let legacy = caches.appendingPathComponent("chapter_title_assets")
        for source in (try? fileManager.contentsOfDirectory(at: legacy, includingPropertiesForKeys: [.isRegularFileKey])) ?? [] {
            let target = assetsDirectory.appendingPathComponent(source.lastPathComponent)
            guard (try? source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  !fileManager.fileExists(atPath: target.path) else { continue }
            try? fileManager.copyItem(at: source, to: target)
        }
    }

    // MARK: 导入

    /// 伪代码 0x1001a69e8（L59-66）：从 URL 导入。
    func importImage(from url: URL) throws -> ChapterTitleAsset {
        let data = try Data(contentsOf: url)
        return try importImage(data: data, preferredFilename: url.lastPathComponent)
    }

    /// 伪代码 0x1001a6db4（L68-100）：数据导入（uuid 文件名 + Data.write(to:options:1) 确证）。
    func importImage(
        data: Data, preferredFilename: String?
    ) throws -> ChapterTitleAsset {
        let ext = Self.normalizedExtension(preferredFilename)
            ?? Self.mimeExtension(Self.contentType(data: data))
        let id = UUID().uuidString
        let fileURL = assetsDirectory.appendingPathComponent("\(id).\(ext)")
        try data.write(to: fileURL, options: .atomic)
        return ChapterTitleAsset(
            id: id, fileURL: fileURL,
            contentType: Self.contentType(data: data))
    }

    /// 伪代码 0x1001a7bc4（L102-128）：打包资产导入（Data.write(to:options:1) L609 确证）。
    func importPackagedAsset(_ asset: ChapterTitlePackagedAsset) throws -> ChapterTitleAsset {
        // isSafeAssetID 为实例域（签名确证）——直接调用。
        guard isSafeAssetID(asset.id) else {
            throw ChapterTitleAssetError.invalidAssetID(asset.id)
        }
        let ext = Self.normalizedExtension(asset.preferredFilename)
            ?? Self.mimeExtension(Self.contentType(data: asset.data))
        let fileURL = assetsDirectory.appendingPathComponent("\(asset.id).\(ext)")
        try asset.data.write(to: fileURL, options: .atomic)
        return ChapterTitleAsset(
            id: asset.id, fileURL: fileURL,
            contentType: Self.contentType(data: asset.data))
    }

    // MARK: 枚举与定位

    /// 伪代码 0x1001a8058（L130-140）：枚举资产
    ///（contentsOfDirectoryAtURL:includingPropertiesForKeys: 确证）。
    func listAssets() -> [ChapterTitleAsset] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: assetsDirectory, includingPropertiesForKeys: nil) else { return [] }
        return urls.map { url in
            ChapterTitleAsset(
                id: url.deletingPathExtension().lastPathComponent,
                fileURL: url,
                contentType: Self.contentType(for: url))
        }
    }

    /// 伪代码 0x1001a8ff8（L147-157）：按 ID 定位（目录枚举比对确证）。
    func localURL(for id: String) -> URL? {
        listAssets().first { $0.id == id }?.fileURL
    }

    /// 伪代码 0x1001a9600（L164-178）：按 ID 取打包载荷。
    func packagedAsset(for id: String) throws -> ChapterTitlePackagedAsset {
        guard let url = localURL(for: id),
              let data = try? Data(contentsOf: url) else {
            throw ChapterTitleAssetError.notFound(id)
        }
        return ChapterTitlePackagedAsset(
            id: id, data: data, preferredFilename: url.lastPathComponent)
    }

    /// 伪代码 0x1001a9b34（L184-189）：批量删除。
    func removeAssets(ids: Set<String>) {
        for url in listAssets() where ids.contains(url.id) {
            try? fileManager.removeItem(at: url.fileURL)
        }
    }

    // MARK: ID 提取与重写

    /// 伪代码 0x1001a9d90（L195-208）：正则提取资产 ID
    ///（matchesInString:numberOfRanges/rangeAtIndex: 确证）。
    /// 模式：qititle-asset://<id>（scheme 域确证；正则串待真机对照）。
    static func extractAssetIDs(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "qititle-asset://([A-Za-z0-9\\-]+)") else {
            return []
        }
        let nsText = text as NSString
        let matches = regex.matches(
            in: text, options: [],
            range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return nsText.substring(with: range)
        }
    }

    /// 伪代码 0x1001aa30c（L214-232）：按映射重写 ID
    ///（'":"' 字面量 = 键值对 JSON 拼接确证）。
    static func rewriteAssetIDs(in text: String, idMap: [String: String]) -> String {
        var result = text
        for (old, new) in idMap {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result
    }

    // MARK: 类型/扩展名

    /// 伪代码 0x1001a6b08（L256-261）：URL → MIME。
    static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        default: return "application/octet-stream"
        }
    }

    /// 伪代码 0x1001a73f0（L263-276）：数据魔数 → MIME。
    static func contentType(data: Data) -> String {
        guard data.count > 8 else { return "application/octet-stream" }
        let bytes = [UInt8](data.prefix(8))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) { return "image/webp" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        return "application/octet-stream"
    }

    /// 伪代码 0x1001a7adc（L283-288）：文件名 → 规范扩展名。
    static func normalizedExtension(_ filename: String?) -> String? {
        guard let filename else { return nil }
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "webp", "gif"].contains(ext) ? ext : nil
    }

    /// 伪代码 0x1001a7e34（L290-298）：MIME → 扩展名。
    static func mimeExtension(_ mime: String) -> String {
        switch mime {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        case "image/gif": return "gif"
        default: return "bin"
        }
    }

    /// 伪代码 0x1001a94cc（L238-240）：安全 ID（fileExistsAtPath: 白名单确证）。
    func isSafeAssetID(_ id: String) -> Bool {
        guard !id.isEmpty,
              !id.contains("/"), !id.contains("..") else { return false }
        return listAssets().contains { $0.id == id }
    }

    /// 伪代码 0x1001a8404（L242-254）：URL → 资产。
    func asset(from url: URL) -> ChapterTitleAsset? {
        listAssets().first { $0.fileURL == url }
    }
}

// MARK: - URLSchemeHandler

/// qititle-asset:// scheme 处理（WKURLSchemeTask 确证）。
final class ChapterTitleAssetURLSchemeHandler: NSObject, WKURLSchemeHandler {

    private let assetManager: ChapterTitleAssetManager

    /// pgo_only init(assetManager:)。
    init(assetManager: ChapterTitleAssetManager) {
        self.assetManager = assetManager
    }

    /// 伪代码 0x1001aa788（L308-330）：host/pathComponents 定位资产回图
    ///（URLRequest.url/host/pathComponents L4658-4694 确证）。
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme == "qititle-asset",
              let assetID = url.pathComponents.count > 1
                  ? url.pathComponents.last : nil,
              let localURL = assetManager.localURL(for: assetID),
              let data = try? Data(contentsOf: localURL) else {
            // guard 绑定在失败块不可见——经请求 URL 回取（wave-16）。
            urlSchemeTask.didFailWithError(
                ChapterTitleAssetError.notFound(
                    urlSchemeTask.request.url?.absoluteString ?? ""))
            return
        }
        let response = URLResponse(
            url: url,
            mimeType: ChapterTitleAssetManager.contentType(for: localURL),
            expectedContentLength: data.count,
            textEncodingName: nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 取消无操作。
    }
}
