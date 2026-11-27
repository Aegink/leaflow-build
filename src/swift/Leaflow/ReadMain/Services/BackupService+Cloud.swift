// 原路径: ReadMain/Services/BackupService.swift
// 分册只改变边界，功能/桩/规模仍累计原文件。
import Foundation
import UIKit

extension BackupService {
    // MARK: iCloud 域（isICloudAvailable/resolveICloudRoot/backupTo/
    // restoreFrom/lastBackupDate 签名域确证）

    /// isICloudAvailable getter（签名域确证）。
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// resolveICloudRoot()（签名域确证）。
    func resolveICloudRoot() async -> URL? {
        guard isICloudAvailable else { return nil }
        guard let documents = FileManager.default.url(
            forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
        else {
            return nil
        }
        return documents.appendingPathComponent("qireader_backup",
                                               isDirectory: true)
    }

    /// backupToICloud(categories:)（签名域确证）。
    func backupToICloud(categories: Set<SyncCategory>) async throws {
        guard let root = await resolveICloudRoot() else {
            throw BackupError.iCloudUnavailable
        }
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "icloud_backup_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        try exportDataTree(
            to: staging, categories: categories, incremental: true)
        let destination = root.appendingPathComponent(
            fileDateStamp() + ".zip")
        try? fileManager.createDirectory(
            at: root, withIntermediateDirectories: true)
        try ZipUtility.createZip(from: staging, to: destination)
        try? fileManager.removeItem(at: staging)
    }

    /// restoreFromICloud(categories:)（签名域确证）。
    func restoreFromICloud(categories: Set<SyncCategory>) async throws {
        guard let root = await resolveICloudRoot() else {
            throw ICloudSyncError.rootUnavailable
        }
        let latest = (try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "zip" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
        guard let latest else { return }
        try await restoreBackup(from: latest, categories: categories)
    }

    /// iCloudLastBackupDate()（签名域确证）。
    func iCloudLastBackupDate() async -> Date? {
        guard let root = await resolveICloudRoot() else { return nil }
        let latest = (try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "zip" }
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate }
            .max()
        return latest
    }

    // MARK: WebDAV 域（backupToWebDAV/restoreFromWebDAV/preview/
    // lastBackupDate 签名域确证）

    /// backupToWebDAV(config:categories:progress:)（签名域确证：
    /// WebDAVClient.upload 桥）。
    func backupToWebDAV(
        config: WebDAVConfig, categories: Set<SyncCategory>,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        let client = try WebDAVClient(config: config)
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "webdav_backup_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try exportDataTree(
            to: staging, categories: categories, incremental: false)
        try fileManager.contentsOfDirectory(
            at: staging, includingPropertiesForKeys: nil).forEach { file in
            Task {
                try? await client.upload(
                    localFile: file, to: file.lastPathComponent)
            }
        }
    }

    /// restoreFromWebDAV(config:categories:progress:)（签名域确证：
    /// downloadTreeRecursively 桥）。
    func restoreFromWebDAV(
        config: WebDAVConfig, categories: Set<SyncCategory>,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        let client = try WebDAVClient(config: config)
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "webdav_restore_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        try await client.downloadTree(to: staging)
        try importDataTree(from: staging, categories: categories)
        try? fileManager.removeItem(at: staging)
    }

    /// previewWebDAVBackup(config:)（签名域确证）。
    func previewWebDAVBackup(config: WebDAVConfig) async throws
        -> [String: Any] {
        let client = try WebDAVClient(config: config)
        let entries = try await client.listTree()
        return ["entries": entries.count]
    }

    /// webDAVLastBackupDate(config:)（签名域确证）。
    func webDAVLastBackupDate(config: WebDAVConfig) async -> Date? {
        nil
    }

    // MARK: iCloud 文件域（ensureDownloaded/isItemDownloaded/
    // collectUndownloadedItems/downloadTreeRecursively 签名域确证）

    /// isItemDownloaded(URL)（签名域确证）。
    func isItemDownloaded(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [
            .ubiquitousItemDownloadingStatusKey]) else {
            return false
        }
        return values.ubiquitousItemDownloadingStatus
            == .current
    }

    /// collectUndownloadedItems(under:)（签名域确证）。
    func collectUndownloadedItems(under directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.allObjects.compactMap { $0 as? URL }
            .filter { !isItemDownloaded($0) }
    }

    /// ensureDownloaded(_:timeout:)（签名域确证）。
    func ensureDownloaded(_ url: URL, timeout: Double) async throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isItemDownloaded(url) { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// downloadTreeRecursively(at:timeout:)（签名域确证）。
    func downloadTreeRecursively(
        at directory: URL, timeout: Double
    ) async throws {
        for url in collectUndownloadedItems(under: directory) {
            try await ensureDownloaded(url, timeout: timeout)
        }
    }

    // MARK: 帮助域（fileDateStamp/userDefaultsDataSize 域还原桥）

    func fileDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    func userDefaultsDataSize(forKey key: String) -> Int64 {
        (defaultsObject(forKey: key) as? Data).map { Int64($0.count) } ?? 0
    }

    func defaultsObject(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: key)
    }
}
