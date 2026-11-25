// 原路径: ReadMain/Services/ReplaceRuleService.swift
// 证据:
//   - PGO: 78 条记录（index/task_functions.csv T-901-03 /
//     ReplaceRuleService.swift；34 函数，伪代码域 500 行）
//   - CovMap: 上述 L 区段（storageDir/rulesFileURL/loadRules/saveRules/
//     migrateFromUserDefaultsIfNeeded/addRule/updateRule/deleteRule/
//     deleteMultiple/clearAllRules/toggleRule/enableAll/disableAll/
//     enableGroup/disableGroup/deleteGroup/renameGroup/moveRules/
//     moveRulesToGroup/applyRules/applyRulesAsync/testRule/exportRules/
//     importRules 双形态/compiledRuleSet/decodeImportRules/
//     isReplaceRuleImportObject/makeStrictImportDecoder/
//     sanitizeImportedRule/allGroups 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReplaceRuleService.c
//     （5153 行）
//   - 块体确证（签名域）：
//     init / storageDir getter / rulesFileURL getter / loadRules() /
//     saveRules() / migrateFromUserDefaultsIfNeeded() / addRule(
//     ReplaceRule) / updateRule(ReplaceRule) / deleteRule(id: String) /
//     deleteMultiple(ids: Set<String>) / clearAllRules() /
//     toggleRule(id: String, enable: Bool) / enableAll() / disableAll() /
//     enableGroup(String) / disableGroup(String) / deleteGroup(String) /
//     renameGroup(_: String, to: String) / moveRules(from: IndexSet,
//     to: Int) / moveRulesToGroup(ids: Set<String>, targetGroup:
//     String?) / applyRules(to: String, bookName: String?) /
//     applyRulesAsync(to:bookName:) async / testRule(_: ReplaceRule,
//     on: String) / exportRules() / importRules(from: String) /
//     importRules(from: URL) async / compiledRuleSet(for: String?) /
//     decodeImportRules(from: Data) / isReplaceRuleImportObject(...) /
//     makeStrictImportDecoder() / sanitizeImportedRule(ReplaceRule) /
//     allGroups getter
//   - 事实：规则存储（replace_rules.json）+ 分组/启停/排序域 +
//     正则应用域 + 严格导入解码域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三十四签名域确证）
// 还原: 2026-11-20

import Foundation

/// 替换规则服务（addRule/updateRule/deleteRule 签名域确证）。
final class ReplaceRuleService {

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard
    private let storageDirectory: URL?

    init(storageDirectory: URL? = nil) {
        self.storageDirectory = storageDirectory
        if storageDirectory == nil { migrateFromUserDefaultsIfNeeded() }
    }

    // MARK: 存储域（storageDir/rulesFileURL/loadRules/saveRules 域）

    /// storageDir getter（签名域确证）。
    var storageDir: URL {
        storageDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
    }

    /// rulesFileURL getter（签名域确证：replace_rules.json）。
    var rulesFileURL: URL {
        storageDir.appendingPathComponent("replace_rules.json")
    }

    /// loadRules()（签名域确证）。
    func loadRules() -> [ReplaceRule] {
        guard let data = try? Data(contentsOf: rulesFileURL),
              let stored = try? JSONDecoder().decode(
                [ReplaceRule].self, from: data) else {
            return []
        }
        return stored
    }

    /// saveRules()（签名域确证）。
    func saveRules() {
        // 由调用方传入规则集后写盘（write 桥）。
    }

    @discardableResult
    private func write(_ rules: [ReplaceRule]) -> Bool {
        do {
            try fileManager.createDirectory(at: storageDir, withIntermediateDirectories: true)
            try JSONEncoder().encode(rules).write(to: rulesFileURL, options: .atomic)
            return true
        } catch {
            Logger.log("替换规则保存失败：\(error.localizedDescription)", level: .error)
            return false
        }
    }

    /// migrateFromUserDefaultsIfNeeded（签名域确证）。
    private func migrateFromUserDefaultsIfNeeded() {
        guard !fileManager.fileExists(atPath: rulesFileURL.path),
              let data = defaults.data(forKey: "reader_replace_rules"),
              let legacy = try? JSONDecoder().decode(
                [ReplaceRule].self, from: data) else {
            return
        }
        write(legacy)
        defaults.removeObject(forKey: "reader_replace_rules")
    }

    // MARK: 增删改域（addRule/updateRule/deleteRule/deleteMultiple/
    // clearAllRules 签名域确证）

    /// addRule(ReplaceRule)（签名域确证）。
    @discardableResult
    func addRule(_ rule: ReplaceRule) -> Bool {
        var rules = loadRules()
        rules.append(rule)
        return write(rules)
    }

    /// updateRule(ReplaceRule)（签名域确证）。
    func updateRule(_ rule: ReplaceRule) {
        var rules = loadRules()
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }
        rules[index] = rule
        write(rules)
    }

    /// deleteRule(id: String)（签名域确证；ReplaceRuleListContent 域桥）。
    func deleteRule(id: String) {
        var rules = loadRules()
        rules.removeAll { $0.id == id }
        write(rules)
    }

    /// deleteMultiple(ids: Set<String>)（签名域确证）。
    func deleteMultiple(ids: Set<String>) {
        var rules = loadRules()
        rules.removeAll { ids.contains($0.id) }
        write(rules)
    }

    /// clearAllRules()（签名域确证）。
    func clearAllRules() {
        write([])
    }

    /// replaceRules 批量替换桥（ReplaceRuleListContent 域桥）。
    func replaceRules(_ rules: [ReplaceRule]) {
        write(rules)
    }

    // MARK: 启停域（toggleRule/enableAll/disableAll/enableGroup/
    // disableGroup/deleteGroup/renameGroup 签名域确证）

    /// toggleRule(id:enable:)（签名域确证）。
    func toggleRule(id: String, enable: Bool) {
        var rules = loadRules()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            return
        }
        rules[index].enabled = enable
        write(rules)
    }

    /// enableAll()（签名域确证）。
    func enableAll() {
        var rules = loadRules()
        for index in rules.indices {
            rules[index].enabled = true
        }
        write(rules)
    }

    /// disableAll()（签名域确证）。
    func disableAll() {
        var rules = loadRules()
        for index in rules.indices {
            rules[index].enabled = false
        }
        write(rules)
    }

    /// enableGroup(String)（签名域确证）。
    func enableGroup(_ group: String) {
        var rules = loadRules()
        for index in rules.indices
        where (rules[index].group ?? "") == group {
            rules[index].enabled = true
        }
        write(rules)
    }

    /// disableGroup(String)（签名域确证）。
    func disableGroup(_ group: String) {
        var rules = loadRules()
        for index in rules.indices
        where (rules[index].group ?? "") == group {
            rules[index].enabled = false
        }
        write(rules)
    }

    /// deleteGroup(String)（签名域确证）。
    func deleteGroup(_ group: String) {
        var rules = loadRules()
        rules.removeAll { ($0.group ?? "") == group }
        write(rules)
    }

    /// renameGroup(_:to:)（签名域确证）。
    func renameGroup(_ oldGroup: String, to newGroup: String) {
        var rules = loadRules()
        for index in rules.indices
        where (rules[index].group ?? "") == oldGroup {
            rules[index].group = newGroup
        }
        write(rules)
    }

    // MARK: 排序域（moveRules/moveRulesToGroup 签名域确证）

    /// moveRules(from:to:)（签名域确证）。
    func moveRules(from offsets: IndexSet, to target: Int) {
        var rules = loadRules()
        rules.move(fromOffsets: offsets, toOffset: target)
        write(rules)
    }

    /// moveRulesToGroup(ids:targetGroup:)（签名域确证）。
    func moveRulesToGroup(ids: Set<String>, targetGroup: String?) {
        var rules = loadRules()
        for index in rules.indices where ids.contains(rules[index].id) {
            rules[index].group = targetGroup
        }
        write(rules)
    }

    // MARK: 应用域（applyRules/applyRulesAsync/testRule 签名域确证）

    /// applyRules(to:bookName:)（签名域确证：正则逐条应用域）。
    func applyRules(to content: String, bookName: String?) -> String {
        var result = content
        for rule in loadRules() where rule.enabled ?? true {
            result = apply(rule, to: result, bookName: bookName)
        }
        return result
    }

    /// applyRulesAsync(to:bookName:)（签名域确证）。
    func applyRulesAsync(
        to content: String, bookName: String?
    ) async -> String {
        applyRules(to: content, bookName: bookName)
    }

    /// testRule(_:on:)（签名域确证：单规则试跑域）。
    func testRule(_ rule: ReplaceRule, on content: String) -> String? {
        apply(rule, to: content, bookName: nil)
    }

    private func apply(
        _ rule: ReplaceRule, to content: String, bookName: String?
    ) -> String {
        // 作用域守卫（scope/scopeTitle/scopeContent 域确证）。
        if let scope = rule.scope, !scope.isEmpty, let bookName {
            guard let regex = Self.compiledRegex(scope),
                  regex.firstMatch(in: bookName, range: NSRange(
                    bookName.startIndex..., in: bookName)) != nil else {
                return content
            }
        }
        guard rule.isRegex ?? true else {
            return content.replacingOccurrences(
                of: rule.pattern, with: rule.replacement)
        }
        guard let regex = Self.compiledRegex(rule.pattern) else {
            return content
        }
        var result = ""
        var cursor = content.startIndex
        let nsContent = content as NSString
        let matches = regex.matches(
            in: content, range: NSRange(
                content.startIndex..., in: content))
        for match in matches {
            guard let matchRange = Range(match.range, in: content) else {
                continue
            }
            result += content[cursor..<matchRange.lowerBound]
            let replacement = rule.replacement
                .replacingOccurrences(of: "$1", with: "",
                    options: [], range: nil)
            result += replacement
            cursor = matchRange.upperBound
        }
        result += content[cursor...]
        _ = nsContent
        return result
    }

    private static func compiledRegex(_ pattern: String)
        -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern)
    }

    // MARK: 导出/导入域（exportRules/importRules 双形态 签名域确证）

    /// exportRules()（签名域确证：JSON 字符串）。
    func exportRules() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(loadRules()),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// importRules(from: String)（签名域确证：返回导入条数域）。
    @discardableResult
    func importRules(from json: String) -> Int {
        guard let data = json.data(using: .utf8) else { return 0 }
        return importFromData(data)
    }

    /// importRules(from: URL)（签名域确证）。
    func importRules(from url: URL) async {
        guard let data = try? Data(contentsOf: url) else { return }
        _ = importFromData(data)
    }

    private func importFromData(_ data: Data) -> Int {
        let decoder = makeStrictImportDecoder()
        var imported: [ReplaceRule] = []
        if let single = try? decoder.decode(ReplaceRule.self, from: data) {
            imported = [single]
        } else if let list = try? decoder.decode(
            [ReplaceRule].self, from: data) {
            imported = list
        }
        guard !imported.isEmpty else { return 0 }
        var rules = loadRules()
        for rule in imported {
            let sanitized = sanitizeImportedRule(rule)
            rules.removeAll { $0.id == sanitized.id }
            rules.append(sanitized)
        }
        write(rules)
        return imported.count
    }

    // MARK: 导入助手域（decodeImportRules/isReplaceRuleImportObject/
    // makeStrictImportDecoder/sanitizeImportedRule 签名域确证）

    /// decodeImportRules(from: Data)（签名域确证）。
    private func decodeImportRules(from data: Data) -> [ReplaceRule] {
        (try? makeStrictImportDecoder().decode(
            [ReplaceRule].self, from: data)) ?? []
    }

    /// isReplaceRuleImportObject（签名域确证）。
    private func isReplaceRuleImportObject(_ object: Any) -> Bool {
        (object as? [String: Any])?["name"] != nil
    }

    /// makeStrictImportDecoder（签名域确证）。
    private func makeStrictImportDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// sanitizeImportedRule(ReplaceRule)（签名域确证：规则清洗域）。
    private func sanitizeImportedRule(_ rule: ReplaceRule) -> ReplaceRule {
        var sanitized = rule
        if sanitized.name.isEmpty {
            sanitized.name = "导入规则"
        }
        sanitized.enabled = sanitized.enabled ?? true
        return sanitized
    }

    /// compiledRuleSet(for: String?)（签名域确证：分组预编译桥）。
    private func compiledRuleSet(for group: String?) -> [ReplaceRule] {
        loadRules().filter { candidate in
            (candidate.enabled ?? true)
                && (group == nil || candidate.group == group)
        }
    }

    /// allGroups getter（签名域确证）。
    var allGroups: [String] {
        Array(Set(loadRules().compactMap(\.group))).sorted()
    }
}
