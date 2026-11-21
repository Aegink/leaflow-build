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
        let raw = UserDefaults.standard.stringArray(
            forKey: "reader_sync_categories") ?? []
        let selected = Set(raw.compactMap(SyncCategory.init(rawValue:)))
        selectedCategories = selected.isEmpty
            ? SyncCategory.defaults : selected
    }

    private func persist() {
        UserDefaults.standard.set(
            selectedCategories.map(\.rawValue),
            forKey: "reader_sync_categories")
    }
}

/// 同步分类（CloudSyncController categories: Set<SyncCategory> 域
/// 交叉确证；case 域按 '同步内容' 脚注枚举还原）。
enum SyncCategory: String, CaseIterable, Codable, Hashable {
    case bookshelf
    case readingProgress
    case bookmarks
    case sources
    case replaceRules
    case themes
    case settings

    static var defaults: Set<SyncCategory> {
        [.bookshelf, .readingProgress, .sources]
    }

    var displayName: String {
        switch self {
        case .bookshelf: return "书架"
        case .readingProgress: return "阅读进度"
        case .bookmarks: return "书签与笔记"
        case .sources: return "书源"
        case .replaceRules: return "替换规则"
        case .themes: return "主题"
        case .settings: return "应用设置"
        }
    }

}
