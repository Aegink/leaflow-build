// 原路径: ReadMain/Core/HighlightBackgroundImageAssetManager.swift
// 证据:
//   - PGO: 11 个主函数（index/task_functions.csv T-303-01 /
//     HighlightBackgroundImageAssetManager.swift），
//     地址：errorDescription 0x1001be34c L22-31 / importImage(from:) 0x1001be724
//     L57-64 / contentType(for:) 0x1001be878 L153-158 / importImage(data:...)
//     0x1001beb24 L70-104 / contentType(data:) 0x1001bf218 L164-177 /
//     normalizedExtension 0x1001bf7f8 L179-184 / makeAssetID 0x1001bf8e0
//     L145-147 / localURL(for:) 0x1001bf974 L106-116 / localURL(forAssetURLString:)
//     0x1001bfd88 L118-126 / image(forAssetURLString:) 0x1001bff7c L128-139 /
//     contentType closure #1 (String) -> String 0x1001bf634 L168
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/HighlightBackgroundImageAssetManager.c
//   - 事实：与 ChapterTitleAssetManager 同构（导入/枚举/URL 解析），
//     差异点：makeAssetID 生成（L145-147）+ forAssetURLString 双入口（L118-126）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（同构选择子确证）
// 还原: 2026-11-19

import Foundation
import UIKit

/// 高亮背景图错误。
enum HighlightBackgroundImageAssetError: LocalizedError {
    case importFailed(String)
    case notFound(String)

    /// 伪代码 0x1001be34c（L22-31）。
    var errorDescription: String? {
        switch self {
        case .importFailed(let detail):
            return "高亮背景图导入失败：\(detail)"
        case .notFound(let id):
            return "高亮背景图不存在：\(id)"
        }
    }
}

/// 高亮背景图资产（ID + URL）。
struct HighlightBackgroundImageAsset: Identifiable {
    let id: String
    let fileURL: URL
}

/// 高亮背景图资产目录（与 ChapterTitleAssetManager 同构）。
final class HighlightBackgroundImageAssetManager {

    private let assetsDirectory: URL
    private let fileManager = FileManager.default

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        assetsDirectory = caches.appendingPathComponent("highlight_bg_assets", isDirectory: true)
        try? fileManager.createDirectory(
            at: assetsDirectory, withIntermediateDirectories: true)
    }

    /// 伪代码 0x1001be724（L57-64）：URL 导入。
    func importImage(from url: URL) throws -> HighlightBackgroundImageAsset {
        let data = try Data(contentsOf: url)
        return try importImage(
            data: data, preferredFilename: url.lastPathComponent)
    }

    /// 伪代码 0x1001beb24（L70-104）：数据导入（Data.write(to:options:1) 同构确证）。
    func importImage(
        data: Data, preferredFilename: String?
    ) throws -> HighlightBackgroundImageAsset {
        let ext = Self.normalizedExtension(preferredFilename)
            ?? Self.mimeExtension(Self.contentType(data: data))
        let id = Self.makeAssetID()
        let fileURL = assetsDirectory.appendingPathComponent("\(id).\(ext)")
        try data.write(to: fileURL, options: .atomic)
        return HighlightBackgroundImageAsset(id: id, fileURL: fileURL)
    }

    /// 伪代码 0x1001bf8e0（L145-147）：资产 ID 生成。
    static func makeAssetID() -> String {
        UUID().uuidString
    }

    /// 伪代码 0x1001bf974（L106-116）：按 ID 定位。
    func localURL(for id: String) -> URL? {
        let url = assetsDirectory.appendingPathComponent(id)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// 伪代码 0x1001bfd88（L118-126）：资产 URL 串定位
    ///（qititle-bg:// 域；解析细节待真机对照）。
    func localURL(forAssetURLString urlString: String) -> URL? {
        guard urlString.hasPrefix("qititle-bg://") else { return nil }
        let id = String(urlString.dropFirst("qititle-bg://".count))
        return localURL(for: id)
    }

    /// 伪代码 0x1001bff7c（L128-139）：按资产 URL 串取图。
    func image(forAssetURLString urlString: String) -> UIImage? {
        guard let url = localURL(forAssetURLString: urlString),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: 类型/扩展名（同构）

    /// 伪代码 0x1001be878（L153-158）+ closure #1（0x1001bf634，L168）。
    static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }

    /// 伪代码 0x1001bf218（L164-177）：数据魔数判定。
    static func contentType(data: Data) -> String {
        guard data.count > 4 else { return "application/octet-stream" }
        let bytes = [UInt8](data.prefix(8))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) { return "image/webp" }
        return "application/octet-stream"
    }

    /// 伪代码 0x1001bf7f8（L179-184）。
    static func normalizedExtension(_ filename: String?) -> String? {
        guard let filename else { return nil }
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "webp"].contains(ext) ? ext : nil
    }

    /// 同构 MIME → 扩展名。
    static func mimeExtension(_ mime: String) -> String {
        switch mime {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        default: return "bin"
        }
    }
}
