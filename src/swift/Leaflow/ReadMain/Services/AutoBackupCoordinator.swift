// 原路径: ReadMain/Services/AutoBackupCoordinator.swift
// 证据:
//   - PGO: 1 条记录（index/task_functions.csv T-901-02 /
//     AutoBackupCoordinator.swift；triggerIfDue 签名域）
//   - CovMap: 上述 L 区段（triggerIfDue 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/AutoBackupCoordinator.c
//     （195 行）
//   - 块体确证（签名域）：triggerIfDue()
//   - 字符串域（位模式，scratch/t90102_auto.txt）：'关闭' L14 /
//     '书签' L54（分类域交叉）
//   - 事实：自动备份协调器（BackupSyncPreferences.isAutoBackupEnabled
//     + 上次备份间隔域桥）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（单签名域 + prefs 桥确证）
// 还原: 2026-11-20

import Foundation

/// 自动备份协调器（triggerIfDue 签名域确证）。
@MainActor
final class AutoBackupCoordinator {

    static let shared = AutoBackupCoordinator()

    private let preferences = BackupSyncPreferences()

    /// 上次自动备份时间（BackupView lastBackupDate 域桥）。
    private(set) var lastBackupDate: Date? {
        get {
            let raw = UserDefaults.standard.double(
                forKey: "reader_auto_backup_last")
            return raw == 0 ? nil : Date(timeIntervalSince1970: raw)
        }
        set {
            UserDefaults.standard.set(
                newValue?.timeIntervalSince1970 ?? 0,
                forKey: "reader_auto_backup_last")
        }
    }

    /// 自动备份开关（BackupView 域桥）。
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(
            enabled, forKey: "reader_auto_backup_enabled")
    }

    /// triggerIfDue()（签名域确证：24 小时间隔门）。
    func triggerIfDue() {
        let enabled = UserDefaults.standard.bool(
            forKey: "reader_auto_backup_enabled")
        guard enabled else { return }
        if let last = lastBackupDate,
           Date().timeIntervalSince(last) < 86_400 {
            return
        }
        Task { @MainActor in
            do {
                _ = try await BackupService.shared.exportBackup(
                    categories: BackupSyncPreferences().selectedCategories)
                lastBackupDate = Date()
            } catch {
                // 失败静默域（下次触发重试桥）。
            }
        }
    }
}
