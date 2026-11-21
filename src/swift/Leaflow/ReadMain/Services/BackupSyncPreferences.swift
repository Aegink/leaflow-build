// 原路径: ReadMain/Services/BackupSyncPreferences.swift
// 证据:
//   - PGO: 22 条记录（index/task_functions.csv T-901-02 /
//     BackupSyncPreferences.swift；伪代码域 140 行）
//   - CovMap: 上述 L 区段（init/persist/persistKnownCategories/
//     isEnabled/recordAutoBackupCompleted/setEnabled 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/
//     BackupSyncPreferences.c（649 行）
//   - 块体确证（签名域）：
//     init / persist / persistKnownCategories / isEnabled(
//     SyncCategory) / recordAutoBackupCompleted / setEnabled(
//     Bool, for: SyncCategory)
//   - 事实：同步偏好域（分类开关 + 自动备份时间域，
//     reader_sync_categories 域与 T-701-08 SyncCategoriesView 对齐）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（六签名域确证）
// 还原: 2026-11-20

import Foundation

/// 备份同步偏好（init/isEnabled/setEnabled 签名域确证）。
final class BackupSyncPreferences {

    private let defaults: UserDefaults

    /// 自动备份开关（BackupView 域桥）。
    var isAutoBackupEnabled: Bool {
        defaults.bool(forKey: "reader_auto_backup_enabled")
    }

    /// init（签名域确证）。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// isEnabled(SyncCategory)（签名域确证：缺省全开域）。
    func isEnabled(_ category: SyncCategory) -> Bool {
        let raw = defaults.stringArray(
            forKey: "reader_sync_categories")
        guard let raw else { return true }
        let selected = Set(raw.compactMap(SyncCategory.init(rawValue:)))
        if selected.isEmpty { return true }
        return selected.contains(category)
    }

    /// setEnabled(_:for: SyncCategory)（签名域确证）。
    func setEnabled(_ enabled: Bool, for category: SyncCategory) {
        var raw = Set(
            (defaults.stringArray(forKey: "reader_sync_categories") ?? [])
                .compactMap(SyncCategory.init(rawValue:)))
        if enabled {
            raw.insert(category)
        } else {
            raw.remove(category)
        }
        defaults.set(
            raw.map(\.rawValue), forKey: "reader_sync_categories")
        persist()
    }

    /// recordAutoBackupCompleted（签名域确证）。
    func recordAutoBackupCompleted() {
        defaults.set(
            Date().timeIntervalSince1970,
            forKey: "reader_auto_backup_last")
        persist()
    }

    /// persist（签名域确证）。
    func persist() {
        defaults.synchronize()
    }

    /// persistKnownCategories（签名域确证）。
    func persistKnownCategories() {
        defaults.set(
            SyncCategory.allCases.map(\.rawValue),
            forKey: "reader_sync_known_categories")
        persist()
    }
}

// MARK: - T-1401-13/15 逐域补齐（自动备份频率域）

/// 自动备份频率（id 0x1002dd37c / displayName 0x1002dd3e8 / isDue
/// 0x1002dcfbc 域；档位推断）。
enum AutoBackupFrequency: String, CaseIterable, Codable {
    case daily
    case weekly
    case monthly

    /// 伪代码 0x1002dd37c（L11）：rawValue 身份。
    var id: String {
        rawValue
    }

    /// 伪代码 0x1002dd3e8（L13-20）：展示名。
    var displayName: String {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }

    /// 伪代码 0x1002dcfbc（L23-34）：到期判定——lastBackup 距今超过档位
    /// 间隔域（7/30 天推断）。
    func isDue(lastBackup: Date?) -> Bool {
        guard let lastBackup else { return true }
        let interval: TimeInterval
        switch self {
        case .daily: interval = 86_400
        case .weekly: interval = 7 * 86_400
        case .monthly: interval = 30 * 86_400
        }
        return Date().timeIntervalSince(lastBackup) >= interval
    }
}

extension SyncCategory {

    /// 伪代码 0x1002dd608（L51）：rawValue 身份。
    var id: String {
        rawValue
    }

    /// 伪代码 0x1002dd934（L69-83）：SF Symbol 档位（图标域推断）。
    /// 去重：SyncCategoriesView.swift 同名实现已删除（本文件为域归属）。
    var systemImage: String {
        switch self {
        case .bookshelf: return "books.vertical"
        case .readingProgress: return "book"
        case .bookmarks: return "bookmark"
        case .sources: return "network"
        case .replaceRules: return "arrow_left_arrow_right"
        case .themes: return "paintpalette"
        case .settings: return "gearshape"
        }
    }
}

