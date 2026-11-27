// 原路径: ReadMain/Views/Settings/SyncCategoriesView.swift
// 证据:
//   - PGO: 14 条记录（index/task_functions.csv T-701-08 /
//     SyncCategoriesView.swift；body 签名域）
//   - CovMap: 上述 L 区段（body 域：同步内容开关组）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     SyncCategoriesView.c（457 行）
//   - 块体确证（签名域）：body getter
//   - 字符串域（位模式，scratch/t70108_sync_strings.txt）：
//     '同步内容' L97
//   - 事实：SyncCategory 开关组（CloudSyncController backup/
//     restore categories: Set<SyncCategory> 域交叉确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（body 域 + categories 交叉确证）
// 还原: 2026-11-20

import SwiftUI

/// 同步内容设置（body 签名域确证：SyncCategory 开关组）。
struct SyncCategoriesView: View {

    @State private var selectedCategories: Set<SyncCategory> =
        SyncCategory.defaults

    var body: some View {
        Form {
            Section {
                ForEach(SyncCategory.allCases, id: \.self) { category in
                    Toggle(isOn: Binding(
                        get: { selectedCategories.contains(category) },
                        set: { included in
                            if included {
                                selectedCategories.insert(category)
                            } else {
                                selectedCategories.remove(category)
                            }
                            persist()
                        })) {
                        Label(category.displayName, systemImage:
                                category.systemImage)
                    }
                    .accessibilityIdentifier("sync-category-" + category.rawValue)
                }
            } header: {
                Text("同步内容")
            } footer: {
                Text("备份与网盘同步将包含以上选中内容")
            }
        }
        .navigationTitle("同步内容")
        .onAppear {
            load()
        }
    }

    private func load() {
        selectedCategories = BackupSyncPreferences().selectedCategories
    }

    private func persist() {
        BackupSyncPreferences().setSelectedCategories(selectedCategories)
    }
}

/// 类型表5739及0x101339740：11个原版同步分类，默认排除本地书文件。
enum SyncCategory: String, CaseIterable, Codable, Hashable {
    case bookshelf
    case bookmarks
    case readingStats
    case config
    case chapterRules
    case replaceRules
    case ttsSources
    case readingSettings
    case highlightRules
    case appearance
    case localBooks

    static var defaults: Set<SyncCategory> {
        Set(allCases).subtracting([.localBooks])
    }

    var displayName: String {
        switch self {
        case .bookshelf: return "书架与阅读进度"
        case .bookmarks: return "书签"
        case .readingStats: return "阅读统计"
        case .config: return "配置"
        case .chapterRules: return "目录规则"
        case .replaceRules: return "替换规则"
        case .ttsSources: return "朗读源"
        case .readingSettings: return "阅读设置"
        case .highlightRules: return "高亮规则"
        case .appearance: return "外观与主题"
        case .localBooks: return "本地书籍"
        }
    }

}
