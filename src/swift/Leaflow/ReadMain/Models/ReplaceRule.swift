// 原路径: ReadMain/Models/ReplaceRule.swift
// 证据:
//   - PGO: 4 个主函数（index/task_functions.csv T-1001-01 / ReplaceRule.swift），
//     地址：init(id:name:pattern:replacement:isRegex:enabled:scope:scopeTitle:...)
//     0x1007c7980 L38-52 / init(from:) 0x100251328 L56-102（+closure #1/#2/#3）/
//     encode(to:) 0x100251e9c L112-127
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/ReplaceRule.c（566 行，4 块）
//   - 关键调用：CharacterSet.whitespacesAndNewlines + trimmingCharacters（L281-283
//     确证）/ KeyedDecodingContainer.decode(_:forKey:) 长链（L249-L375，约 20 字段）/
//     DecodingError 域 / CodingUserInfoKey 参与确证
//   - 事实：init(id:...) —— 12 参全量构造（pseudocode 签名确证：isRegex/enabled/
//     scope/scopeTitle/scopeContent/excludeScope/timeoutMillisecond/order/group）；
//     init(from:) —— 全字段 decode + pattern/replacement trim（whitespacesAndNewlines
//     确证）；encode(to:) —— 对称编码
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 构造/decode/encode 链: high（签名+trim 确证）
//   - 字段名/默认值: medium（pseudocode 变量为寄存器名，字段名还原命名）
// 还原: 2026-11-19

import Foundation

/// 替换规则（legado 兼容）。
struct ReplaceRule: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var pattern: String
    var replacement: String
    var isRegex: Bool?
    var enabled: Bool?
    var scope: String?
    var scopeTitle: Bool?
    var scopeContent: Bool?
    var excludeScope: String?
    var timeoutMillisecond: Int?
    var order: Int?
    var group: String?

    /// 伪代码 0x1007c7980（L38-52）：12 参全量构造（签名确证）。
    init(
        id: String = UUID().uuidString,
        name: String,
        pattern: String,
        replacement: String,
        isRegex: Bool? = nil,
        enabled: Bool? = nil,
        scope: String? = nil,
        scopeTitle: Bool? = nil,
        scopeContent: Bool? = nil,
        excludeScope: String? = nil,
        timeoutMillisecond: Int? = nil,
        order: Int? = nil,
        group: String? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
        self.isRegex = isRegex
        self.enabled = enabled
        self.scope = scope
        self.scopeTitle = scopeTitle
        self.scopeContent = scopeContent
        self.excludeScope = excludeScope
        self.timeoutMillisecond = timeoutMillisecond
        self.order = order
        self.group = group
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, pattern, replacement, isRegex, enabled, scope
        case scopeTitle, scopeContent, excludeScope
        case timeoutMillisecond, order, group
    }

    /// 伪代码 0x100251328（L56-102 + closure #1/#2/#3）：
    /// 全字段 decode；pattern/replacement trim（whitespacesAndNewlines 确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        pattern = (try container.decode(String.self, forKey: .pattern))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        replacement = (try container.decodeIfPresent(String.self, forKey: .replacement) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        isRegex = try container.decodeIfPresent(Bool.self, forKey: .isRegex)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        scopeTitle = try container.decodeIfPresent(Bool.self, forKey: .scopeTitle)
        scopeContent = try container.decodeIfPresent(Bool.self, forKey: .scopeContent)
        excludeScope = try container.decodeIfPresent(String.self, forKey: .excludeScope)
        timeoutMillisecond = try container.decodeIfPresent(Int.self, forKey: .timeoutMillisecond)
        order = try container.decodeIfPresent(Int.self, forKey: .order)
        group = try container.decodeIfPresent(String.self, forKey: .group)
    }

    /// 伪代码 0x100251e9c（L112-127）：对称编码。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(pattern, forKey: .pattern)
        try container.encode(replacement, forKey: .replacement)
        try container.encodeIfPresent(isRegex, forKey: .isRegex)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(scopeTitle, forKey: .scopeTitle)
        try container.encodeIfPresent(scopeContent, forKey: .scopeContent)
        try container.encodeIfPresent(excludeScope, forKey: .excludeScope)
        try container.encodeIfPresent(timeoutMillisecond, forKey: .timeoutMillisecond)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(group, forKey: .group)
    }
}
