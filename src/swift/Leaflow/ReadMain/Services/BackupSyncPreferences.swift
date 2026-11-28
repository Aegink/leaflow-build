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
    private static let selectedKey = "BackupSyncEnabledCategories"
    private static let knownKey = "BackupSyncKnownCategories"
    private(set) var selectedCategories: Set<SyncCategory>

    /// 自动备份开关（BackupView 域桥）。
    var isAutoBackupEnabled: Bool {
        defaults.bool(forKey: "reader_auto_backup_enabled")
    }

    /// init（签名域确证）。
    init(defaults: UserDefaults = BackupSyncPreferences.runtimeDefaults) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: Self.selectedKey) {
            let known = defaults.stringArray(forKey: Self.knownKey) ?? saved
            selectedCategories = Set(saved.compactMap(SyncCategory.init(rawValue:)))
                .union(SyncCategory.defaults.subtracting(Set(known.compactMap(SyncCategory.init(rawValue:)))))
        } else if let legacy = defaults.stringArray(forKey: "reader_sync_categories") {
            selectedCategories = Self.migrateLegacyCategories(legacy)
        } else { selectedCategories = SyncCategory.defaults }
        persist()
        persistKnownCategories()
    }

    // 冒烟启动参数仅使用独立偏好域，不能改写用户同步分类。
    static var runtimeDefaults: UserDefaults {
        guard ProcessInfo.processInfo.arguments.contains("-smokeBackupSettings") else { return .standard }
        return UserDefaults(suiteName: "t1602-backup-settings-ui")!
    }

    /// isEnabled(SyncCategory)（签名域确证：缺省全开域）。
    func isEnabled(_ category: SyncCategory) -> Bool {
        selectedCategories.contains(category)
    }

    /// setEnabled(_:for: SyncCategory)（签名域确证）。
    func setEnabled(_ enabled: Bool, for category: SyncCategory) {
        if enabled {
            selectedCategories.insert(category)
        } else {
            selectedCategories.remove(category)
        }
        persist()
    }

    func setSelectedCategories(_ selected: Set<SyncCategory>) {
        selectedCategories = selected
        persist()
        persistKnownCategories()
    }

    // 仅迁移重建包旧7类键，不改写原版11类的含义。
    private static func migrateLegacyCategories(_ values: [String]) -> Set<SyncCategory> {
        var result = Set<SyncCategory>()
        for value in values {
            switch value {
            case "bookshelf": result.formUnion([.bookshelf, .localBooks])
            case "readingProgress": result.insert(.bookshelf)
            case "sources": result.insert(.config)
            case "themes": result.insert(.appearance)
            case "settings": result.formUnion([.readingSettings, .readingStats, .ttsSources])
            case "replaceRules": result.formUnion([.chapterRules, .replaceRules, .highlightRules])
            default: if let category = SyncCategory(rawValue: value) { result.insert(category) }
            }
        }
        return result
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
        defaults.set(selectedCategories.map(\.rawValue).sorted(), forKey: Self.selectedKey)
        defaults.synchronize()
    }

    /// persistKnownCategories（签名域确证）。
    func persistKnownCategories() {
        defaults.set(
            SyncCategory.allCases.map(\.rawValue), forKey: Self.knownKey)
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
        case .bookmarks: return "bookmark"
        case .readingStats: return "chart.bar"
        case .config: return "network"
        case .chapterRules: return "list.bullet"
        case .replaceRules: return "arrow_left_arrow_right"
        case .ttsSources: return "speaker.wave.2"
        case .readingSettings: return "textformat"
        case .highlightRules: return "highlighter"
        case .appearance: return "paintpalette"
        case .localBooks: return "folder"
        }
    }
}

