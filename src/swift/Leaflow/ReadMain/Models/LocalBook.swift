// 原路径: ReadMain/Models/LocalBook.swift
// 证据:
//   - PGO: 40 条记录（index/task_functions.csv T-601-01 /
//     LocalBook.swift；伪代码域 1253 行）。关键地址：
//     LocalBook.filePath 0x100241344 L38-41（×3 ICF 副本）/ hash(into:)
//     0x1002413c4 L43-45 / == infix（签名）/ readingProgressText
//     0x1002414dc L66-71 / readingProgress 0x100241fdc L74-78 /
//     displayLanguage/displayFormat/displayStatus（签名）/
//     LocalChapter.displayTitle 0x1002434a0 L89-89 / LocalChapter.init
//     0x100340254 L107-114（id/title/startPosition/endPosition/sta… 签名）/
//     ChapterRule.init(id:name:pattern:) 0x100243518 L125-129 /
//     ChapterRuleManager（allRules getter/loadRules 0x1002436c8 L174-178/
//     saveRules/addRule 0x100243a60 L185-188/updateRule 0x100243cb0
//     L190-194/deleteRule/init 0x1002461c0 L168-172/ruleName(forPattern:)
//     签名）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/LocalBook.c（1253 行）
//   - 字符串域（指针）："entType" L788 域（格式域交叉确证）
//   - 事实：本地书域（filePath/readingProgress/format 展示族）；
//     章节规则管理域（ChapterRuleManager 五件 + ruleName 反查）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 签名域确证）
// 还原: 2026-11-20

import Foundation

// MARK: - LocalBook（0x100241344 L38-41 域确证）

/// 本地书籍模型。
struct LocalBook: Codable, Identifiable, Equatable, Hashable {

    var id: UUID = UUID()
    var name: String
    var author: String?
    var filePath: String
    var format: String
    var durChapterIndex: Int = 0
    var durChapterPos: Double = 0
    var totalChapters: Int = 0
    var group: String?
    var addedAt: Date = Date()

    /// filePath getter（0x100241344 L38-41 域确证）。
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    /// displayFormat getter（签名确证；"entType" L788 域交叉）。
    var displayFormat: String {
        format.uppercased()
    }

    /// displayLanguage getter（签名确证）。
    var displayLanguage: String {
        "中文"
    }

    /// displayStatus getter（签名确证）。
    var displayStatus: String {
        totalChapters > 0 ? "已导入" : "待解析"
    }

    /// readingProgress getter（0x100241fdc L74-78 域确证）。
    var readingProgress: Double {
        guard totalChapters > 0 else { return 0 }
        return min(Double(durChapterIndex + 1) / Double(totalChapters), 1.0)
    }

    /// readingProgressText getter（0x1002414dc L66-71 域确证）。
    var readingProgressText: String {
        "已读 \(Int(readingProgress * 100))%"
    }

    /// hash(into:)（0x1002413c4 L43-45 域确证）。
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// == infix（签名确证）。
    static func == (lhs: LocalBook, rhs: LocalBook) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - LocalChapter（0x100340254 L107-114 域确证）

/// 本地章节模型。
struct LocalChapter: Codable, Identifiable, Equatable, Hashable {

    var id: Int
    var title: String
    var startPosition: Int
    var endPosition: Int
    var startTag: String?

    /// init（0x100340254 L107-114 域确证）。
    init(
        id: Int, title: String, startPosition: Int, endPosition: Int,
        startTag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.startTag = startTag
    }

    /// displayTitle getter（0x1002434a0 L89-89 域确证）。
    var displayTitle: String {
        title
    }
}

// MARK: - ChapterRule（0x100243518 L125-129 域确证）

/// 章节规则模型。
struct ChapterRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var pattern: String

    /// init(id:name:pattern:)（0x100243518 L125-129 域确证）。
    init(id: UUID = UUID(), name: String, pattern: String) {
        self.id = id
        self.name = name
        self.pattern = pattern
    }
}

// MARK: - ChapterRuleManager（0x1002461c0 L168-172 域确证）

/// 章节规则管理器。
final class ChapterRuleManager: ObservableObject {

    static let shared = ChapterRuleManager()

    @Published private(set) var rules: [ChapterRule] = []

    private let storageKey = "chapter_rules"

    /// init（0x1002461c0 L168-172 域确证）。
    private init() {
        loadRules()
    }

    /// allRules getter（签名确证）。
    var allRules: [ChapterRule] {
        rules
    }

    /// loadRules（0x1002436c8 L174-178 域确证）。
    private func loadRules() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(
                [ChapterRule].self, from: data)
        else { return }
        rules = stored
    }

    /// saveRules（签名确证）。
    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// addRule（0x100243a60 L185-188 域确证）。
    func addRule(_ rule: ChapterRule) {
        rules.append(rule)
        saveRules()
    }

    /// updateRule（0x100243cb0 L190-194 域确证）。
    func updateRule(_ rule: ChapterRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }
        rules[index] = rule
        saveRules()
    }

    /// deleteRule（签名确证）。
    func deleteRule(_ rule: ChapterRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    /// ruleName(forPattern:)（签名确证）。
    func ruleName(forPattern pattern: String?) -> String? {
        guard let pattern else { return nil }
        return rules.first { $0.pattern == pattern }?.name
    }
}
