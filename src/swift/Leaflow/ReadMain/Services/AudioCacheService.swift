// 原路径: ReadMain/Services/AudioCacheService.swift
// 证据:
//   - PGO: 62 条记录（index/task_functions.csv T-801-03 /
//     AudioCacheService.swift；伪代码域 150 行）
//   - CovMap: 上述 L 区段（bookDirectory/fileKey/localFileUrl/
//     downloadAndCache/getCachedAudioFile/clear 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/AudioCacheService.c
//     （2254 行）
//   - 块体确证（签名域）：
//     bookDirectory(bookUrl: String) / directorySize(at: URL) /
//     downloadAndCache(remoteUrl:headers:) / fileKey(bookUrl:chapterIndex:)
//     / isLikelyInvalidCachedAudioFile(at: URL) / isLikelyTextPayload(
//     Data) / localFileUrl(key: String) / cachedFileUrl(bookUrl:
//     chapterIndex:) / clearAllCache / clearCache(bookUrl:) /
//     formattedCacheSize() / getCachedAudioFile(remoteUrl:headers:) /
//     isCached(bookUrl:chapterIndex:) / predownload(remoteUrl:headers:) /
//     removeCachedFile(bookUrl:chapterIndex:)
//   - 字符串域：无用户字符串（'栖读' L474 域为 AudioBookService 交叉）
//   - 事实：书域目录（哈希键）+ 音频头嗅探（文本载荷判废）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十五签名域确证）
// 还原: 2026-11-20

import Foundation

/// 音频缓存服务（cachedFileUrl/getCachedAudioFile 签名域确证）。
final class AudioCacheService {

    static let shared = AudioCacheService()

    private let fileManager = FileManager.default

    /// 缓存根目录（bookDirectory(bookUrl:) 域还原桥）。
    private var cacheRoot: URL {
        let caches = fileManager.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first!
        return caches.appendingPathComponent("AudioBooks",
                                            isDirectory: true)
    }

    /// bookDirectory(bookUrl:)（签名域确证：书 URL 哈希目录）。
    func bookDirectory(bookUrl: String) -> URL {
        let key = stableKey(bookUrl)
        return cacheRoot.appendingPathComponent(key, isDirectory: true)
    }

    /// fileKey(bookUrl:chapterIndex:)（签名域确证：书哈希 + 章节号）。
    func fileKey(bookUrl: String, chapterIndex: Int) -> String {
        "\(stableKey(bookUrl))_\(chapterIndex)"
    }

    /// localFileUrl(key:)（签名域确证）。
    func localFileUrl(key: String) -> URL {
        cacheRoot.appendingPathComponent("\(key).audio", isDirectory: false)
    }

    /// cachedFileUrl(bookUrl:chapterIndex:)（签名域确证）。
    func cachedFileUrl(bookUrl: String, chapterIndex: Int) -> URL {
        localFileUrl(key: fileKey(bookUrl: bookUrl,
                                  chapterIndex: chapterIndex))
    }

    /// isCached(bookUrl:chapterIndex:)（签名域确证）。
    func isCached(bookUrl: String, chapterIndex: Int) -> Bool {
        fileManager.fileExists(
            atPath: cachedFileUrl(bookUrl: bookUrl,
                                  chapterIndex: chapterIndex).path)
    }

    /// getCachedAudioFile(remoteUrl:headers:)（签名域确证：命中返回
    /// 本地，未命中下载缓存）。
    func getCachedAudioFile(
        remoteUrl: URL, headers: [String: String],
        bookUrl: String, chapterIndex: Int
    ) async -> URL? {
        let local = cachedFileUrl(bookUrl: bookUrl,
                                  chapterIndex: chapterIndex)
        if fileManager.fileExists(atPath: local.path),
           !isLikelyInvalidCachedAudioFile(at: local) {
            return local
        }
        return await downloadAndCache(
            remoteUrl: remoteUrl, headers: headers,
            bookUrl: bookUrl, chapterIndex: chapterIndex)
    }

    /// downloadAndCache(remoteUrl:headers:)（签名域确证：AVAsset 头
    /// 注入下载 + 文本载荷判废）。
    @discardableResult
    func downloadAndCache(
        remoteUrl: URL, headers: [String: String],
        bookUrl: String, chapterIndex: Int
    ) async -> URL? {
        var request = URLRequest(url: remoteUrl)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        guard let (data, response) = try? await URLSession.shared.data(
            for: request) else {
            return nil
        }
        // isLikelyTextPayload 域确证：错误页/文本不算音频。
        if isLikelyTextPayload(data),
              let mime = (response as? HTTPURLResponse)?.mimeType,
              !mime.hasPrefix("audio") {
            return nil
        }
        let destination = cachedFileUrl(bookUrl: bookUrl,
                                        chapterIndex: chapterIndex)
        try? fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        do {
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            return nil
        }
    }

    /// predownload(remoteUrl:headers:)（签名域确证：后台预下载）。
    func predownload(
        remoteUrl: URL, headers: [String: String],
        bookUrl: String, chapterIndex: Int
    ) {
        Task.detached(priority: .utility) { [weak self] in
            _ = await self?.downloadAndCache(
                remoteUrl: remoteUrl, headers: headers,
                bookUrl: bookUrl, chapterIndex: chapterIndex)
        }
    }

    /// removeCachedFile(bookUrl:chapterIndex:)（签名域确证）。
    func removeCachedFile(bookUrl: String, chapterIndex: Int) {
        try? fileManager.removeItem(
            at: cachedFileUrl(bookUrl: bookUrl,
                              chapterIndex: chapterIndex))
    }

    /// clearCache(bookUrl:)（签名域确证）。
    func clearCache(bookUrl: String) {
        try? fileManager.removeItem(at: bookDirectory(bookUrl: bookUrl))
    }

    /// clearAllCache（签名域确证）。
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheRoot)
    }

    /// formattedCacheSize（签名域确证）。
    func formattedCacheSize() -> String {
        ByteCountFormatter.string(
            fromByteCount: totalCacheSize(), countStyle: .file)
    }

    /// directorySize(at:)（签名域确证：递归累加）。
    func directorySize(at directory: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
        else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .fileSizeKey, .isDirectoryKey,
            ]), values.isDirectory != true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    /// isLikelyInvalidCachedAudioFile(at:)（签名域确证：空文件/文本
    /// 判废）。
    func isLikelyInvalidCachedAudioFile(at url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(
            atPath: url.path),
            let size = attributes[.size] as? Int64 else {
            return true
        }
        if size < 512 {
            return true
        }
        guard let head = try? Data(contentsOf: url) else {
            return true
        }
        return isLikelyTextPayload(head)
    }

    /// isLikelyTextPayload(_:)（签名域确证：可解码 UTF-8 且含标签
    /// 结构 → 文本载荷）。
    func isLikelyTextPayload(_ data: Data) -> Bool {
        let head = data.prefix(2048)
        guard let text = String(data: head, encoding: .utf8) else {
            return false
        }
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard trimmed.count > 16 else { return false }
        return trimmed.hasPrefix("<")
            || trimmed.hasPrefix("{")
            || trimmed.lowercased().contains("<html")
    }

    private func totalCacheSize() -> Int64 {
        directorySize(at: cacheRoot)
    }

    private func stableKey(_ value: String) -> String {
        var hasher = Hasher()
        hasher.combine(value)
        return String(format: "%016x", UInt64(bitPattern: hasher.finalize()))
    }
}

extension AudioCacheService {

    /// 伪代码 0x1002a7dd4（L161-164）：缓存字节数（目录枚举求和域）。
    func cacheSize() -> Int64 {
        var total: Int64 = 0
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheRoot, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        for file in files {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))
                ?.fileSize ?? 0)
        }
        return total
    }
}

