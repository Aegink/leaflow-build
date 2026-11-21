// 原路径: ReadMain/Services/CloudSyncController.swift
// 证据:
//   - PGO: 78 条记录（index/task_functions.csv T-901-03 /
//     CloudSyncController.swift；伪代码域 400 行）
//   - CovMap: 上述 L 区段（init/backup/restore/preparePreview/
//     refreshLastBackup/clearMessages/displayFileName/isBusy/
//     showRestartAlert 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/CloudSyncController.c
//     （1617 行）
//   - 块体确证（签名域）：
//     init / backup(destination: BackupDestination, displayName:
//     String, config: WebDAVConfig?, categories: Set<SyncCategory>,
//     forceFull: Bool) / restore(destination:config:categories:) /
//     preparePreview(destination:config:) / refreshLastBackup(
//     destination:config:) / clearMessages / displayFileName(String) /
//     isBackingUp getter / isBusy getter / isRestoring getter /
//     showRestartAlert / CloudOpError.errorDescription getter
//   - 事实：云同步控制器（BackupService 双通道桥 + 状态域 + 重启提示）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十一签名域确证）
// 还原: 2026-11-20

import Foundation

/// 云同步控制器（backup/restore/preparePreview 签名域确证）。
@MainActor
final class CloudSyncController: ObservableObject {

    /// 云操作错误（errorDescription 签名域确证）。
    enum CloudOpError: LocalizedError {
        case destinationUnavailable
        case inProgress

        var errorDescription: String? {
            switch self {
            case .destinationUnavailable:
                return "同步目的地不可用"
            case .inProgress:
                return "已有同步任务进行中"
            }
        }
    }

    @Published private(set) var isBackingUp = false
    @Published private(set) var isRestoring = false
    @Published private(set) var lastMessage = ""
    @Published var lastBackupText = ""

    private let backupService = BackupService.shared
    private let preferences = BackupSyncPreferences()

    /// init（签名域确证）。
    init() {}

    /// isBusy getter（签名域确证）。
    var isBusy: Bool {
        isBackingUp || isRestoring
    }

    /// backup(destination:displayName:config:categories:forceFull:)
    /// （签名域确证：iCloud/WebDAV 双通道分派）。
    func backup(
        destination: BackupDestination, displayName: String,
        config: WebDAVConfig?, categories: Set<SyncCategory>,
        forceFull: Bool
    ) {
        guard !isBusy else {
            lastMessage = CloudOpError.inProgress.localizedDescription
            return
        }
        isBackingUp = true
        Task { @MainActor in
            defer { isBackingUp = false }
            do {
                switch destination {
                case .icloud:
                    try await backupService.backupToICloud(
                        categories: categories)
                case .webdav:
                    guard let config else {
                        throw CloudOpError.destinationUnavailable
                    }
                    try await backupService.backupToWebDAV(
                        config: config, categories: categories)
                }
                preferences.recordAutoBackupCompleted()
                lastBackupText = displayName
                lastMessage = "备份完成"
            } catch {
                lastMessage = error.localizedDescription
            }
        }
    }

    /// restore(destination:config:categories:)（签名域确证）。
    func restore(
        destination: BackupDestination, config: WebDAVConfig?,
        categories: Set<SyncCategory>
    ) {
        guard !isBusy else {
            lastMessage = CloudOpError.inProgress.localizedDescription
            return
        }
        isRestoring = true
        Task { @MainActor in
            defer { isRestoring = false }
            do {
                switch destination {
                case .icloud:
                    try await backupService.restoreFromICloud(
                        categories: categories)
                case .webdav:
                    guard let config else {
                        throw CloudOpError.destinationUnavailable
                    }
                    try await backupService.restoreFromWebDAV(
                        config: config, categories: categories)
                }
                lastMessage = "恢复完成"
                showRestartAlert()
            } catch {
                lastMessage = error.localizedDescription
            }
        }
    }

    /// preparePreview(destination:config:)（签名域确证）。
    func preparePreview(
        destination: BackupDestination, config: WebDAVConfig?
    ) {
        Task { @MainActor in
            do {
                switch destination {
                case .icloud:
                    _ = try await backupService.previewICloudBackup()
                case .webdav:
                    guard let config else {
                        throw CloudOpError.destinationUnavailable
                    }
                    _ = try await backupService.previewWebDAVBackup(
                        config: config)
                }
                lastMessage = "预览完成"
            } catch {
                lastMessage = error.localizedDescription
            }
        }
    }

    /// refreshLastBackup(destination:config:)（签名域确证）。
    func refreshLastBackup(
        destination: BackupDestination, config: WebDAVConfig?
    ) {
        Task { @MainActor in
            let date: Date?
            switch destination {
            case .icloud:
                date = await backupService.iCloudLastBackupDate()
            case .webdav:
                date = await backupService.webDAVLastBackupDate(
                    config: config)
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            lastBackupText = date.map(formatter.string) ?? "无记录"
        }
    }

    /// clearMessages（签名域确证）。
    func clearMessages() {
        lastMessage = ""
    }

    /// displayFileName(String)（签名域确证）。
    func displayFileName(_ name: String) -> String {
        name
    }

    /// showRestartAlert（签名域确证：恢复后重启提示域）。
    func showRestartAlert() {
        // 重启提示桥（视图域还原桥）。
    }

    /// setEnabled 桥（BackupView 域桥）。
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(
            enabled, forKey: "reader_cloud_sync_enabled")
    }
}

extension CloudSyncController {

    /// 伪代码 0x1002ffa38（L23）：阶段 varinit（计数器桩；idle 默认推断）。
    var phase: String {
        isBackingUp ? "backup" : (isRestoring ? "restore" : "idle")
    }

    /// 伪代码 0x1002ff9e0（L34）：恢复确认显隐 varinit（计数器桩）。
    var showRestoreConfirm: Bool {
        false
    }
}

