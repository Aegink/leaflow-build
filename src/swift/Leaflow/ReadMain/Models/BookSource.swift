// 原路径: ReadMain/Models/BookSource.swift
// 证据:
//   - PGO: 16 个主函数（index/task_functions.csv T-1001-01 / BookSource.swift），
//     地址：RawJSONValue.init(from:) 0x1002310b0 L12-35 / RawJSONValue.encode(to:)
//     0x1002315d0 L37-56 / RawJSONValue.stringValue 0x100231954 L58-74 /
//     LenientJSONString.init(from:) 0x1002328cc（pgo 共体）/
//     JSONStringBacked.init(from:) 0x100231c48 L88-95 / decodeLenientStringIfPresent
//     0x100231f7c L99-102 / decodeObjectOrJSONStringIfPresent 0x10023205c+5 共体块
//     L104-113 / BookSource.id 0x1002332a4 L153 / BookSource.init(from:)
//     0x1002339b0 L229-279 / readState 0x100230ba8 L380-399 / writeState 0x100230e00
//     L406-416 / removeState 0x100231094 L419-424
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/BookSource.c（1266 行，16 块）
//   - 关键调用：dispatch thunk of Decoder.singleValueContainer / SingleValueDecodingContainer
//     .decodeNil|decode / String.data(using:.utf8, allowLossyConversion:false) /
//     JSONDecoder.decode(_:from:) / DecodingError.dataCorruptedError(in:debugDescription:)
//     （25 字符字面量 0x101261910）/ KeyedDecodingContainer.decodeIfPresent /
//     UserDefaults standardUserDefaults setObject:forKey:|removeObjectForKey:
//   - 事实：RawJSONValue —— 枚举包装 Any（decodeNil → nil，其余 decode(Any.Type)，
//     encode 走 singleValueContainer）；JSONStringBacked —— 字符串值再经
//     JSONDecoder 解码为 A（utf8 data，失败 → dataCorruptedError）；
//     decodeObjectOrJSONStringIfPresent —— 先按对象解码失败回退 JSON 字符串
//     （6 个 ICF 共体块 = 6 个规则字段）；init(from:) 35 字段解码链
//     （decodeIfPresent 占多数 + 6 规则对象 + StorageKind 回退闭包，
//     init 默认字节位 +160/+176/+192 = true 确证）；
//     id（L153 单行，返回 bookSourceUrl）；state 系（UserDefaults，键含
//     bookSourceUrl 拼接确证）；StorageKind.label/shortLabel/icon/color（pgo 内联）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - RawJSONValue/JSONStringBacked/lenient 解码扩展: high（调用链确证）
//   - init(from:) 字段链: high（decodeIfPresent 链 + 默认字节位确证；字段名为还原命名）
//   - state 系/id/StorageKind 展示属性: high（UserDefaults 选择子确证）
// 还原: 2026-11-19

import Foundation

// MARK: - JSON 宽松解码辅助（mangle 内私有族）

/// Any 包装（伪代码 0x1002310b0，L12-35：singleValueContainer + decodeNil 判定）。
enum RawJSONValue: Codable {
    case null
    case value(Any)

    init() { self = .null }

    /// Any 归一（容器递归包装；不支持的类型 → nil）。
    private static func normalize(_ any: Any) -> Any? {
        switch any {
        case let v as String: return v
        case let v as Bool: return v
        case let v as Int: return v
        case let v as Double: return v
        case let v as [Any]:
            let mapped = v.compactMap { normalize($0) }
            return mapped.isEmpty && !v.isEmpty ? nil : mapped
        case let v as [String: Any]:
            var out: [String: Any] = [:]
            for (key, item) in v {
                guard let normalized = normalize(item) else { return nil }
                out[key] = normalized
            }
            return out
        case is NSNull: return nil
        default: return nil
        }
    }

    /// Any 包装构造（JSONSerialization 域值 → RawJSONValue）。
    init?(any raw: Any) {
        guard let normalized = Self.normalize(raw) else { return nil }
        self = .value(normalized)
    }

    /// 解包值（stringValue/JSONSerialization 域消费）。
    var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case .value(let any): return any
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        // Any 非 Decodable——标量逐档宽容解码 + 容器递归（语义同伪代码）。
        if let v = try? container.decode(Bool.self) { self = .value(v); return }
        if let v = try? container.decode(Int.self) { self = .value(v); return }
        if let v = try? container.decode(Double.self) { self = .value(v); return }
        if let v = try? container.decode(String.self) { self = .value(v); return }
        if let arr = try? container.decode([RawJSONValue].self) {
            self = .value(arr.map { $0.anyValue })
            return
        }
        if let dict = try? container.decode([String: RawJSONValue].self) {
            var out: [String: Any] = [:]
            for (key, item) in dict { out[key] = item.anyValue }
            self = .value(out)
            return
        }
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Unsupported JSON value kind"))
    }

    func encode(to encoder: Encoder) throws {
        // 伪代码 0x1002315d0（L37-56）：singleValueContainer encode。
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .value(let any):
            // Any 非 Encodable——按具体类型分派（Bool 先于 Int 防 NSNumber 重叠）。
            switch any {
            case let v as String:
                try container.encode(v)
            case let v as Bool:
                try container.encode(v)
            case let v as Int:
                try container.encode(v)
            case let v as Double:
                try container.encode(v)
            case let v as [Any]:
                try container.encode(v.compactMap(RawJSONValue.init(any:)))
            case let v as [String: Any]:
                var out: [String: RawJSONValue] = [:]
                for (key, item) in v {
                    guard let wrapped = RawJSONValue(any: item) else { continue }
                    out[key] = wrapped
                }
                try container.encode(out)
            default:
                try container.encodeNil()
            }
        }
    }

    /// 伪代码 0x100231954（L58-74）：值转 JSON 字符串（String.Encoding.utf8 确证）。
    var stringValue: String? {
        guard case .value(let any) = self else { return nil }
        if let string = any as? String {
            return string
        }
        guard let data = try? JSONSerialization.data(withJSONObject: any, options: [.fragmentsAllowed]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

/// JSON 字符串再解码（伪代码 0x100231c48，L88-95）。
/// singleValueContainer 解出 String → utf8 data → JSONDecoder.decode(A.self)；
/// data 失败（v21 >> 60 == 15 的空/坏对象判定）→ dataCorruptedError（25 字符描述）。
enum JSONStringBacked<A: Decodable> {
    static func decode(_ type: A.Type, from decoder: Decoder) throws -> A {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let data = string.data(using: .utf8, allowLossyConversion: false) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Data is not valid UTF-8 JSON string"))
        }
        return try JSONDecoder().decode(A.self, from: data)
    }
}

enum LenientJSONString {
    /// 伪代码 0x1002328cc 块（共体）：字符串字段宽容解码（对象先转 JSON 串）。
    static func decode(from decoder: Decoder) throws -> String {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            return string
        }
        // 对象/数组 → JSON 串（Any 非 Decodable——经 RawJSONValue 递归桥）。
        if let value = try? container.decode(RawJSONValue.self),
           case .value(let any) = value,
           let data = try? JSONSerialization.data(
               withJSONObject: any, options: [.fragmentsAllowed]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Value is neither String nor JSON object"))
    }
}

private extension KeyedDecodingContainer {
    /// 伪代码 0x100231f7c（L99-102）：宽容字符串（nil → nil）。
    func decodeLenientStringIfPresent(forKey key: K) throws -> String? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        return try LenientJSONString.decode(from: superDecoder())
    }

    /// 伪代码 0x10023205c 等 6 个 ICF 共体块（L104-113）：
    /// 先按对象解码，失败回退 JSON 字符串再解码。
    func decodeObjectOrJSONStringIfPresent<A: Decodable>(
        _ type: A.Type, forKey key: K
    ) throws -> A? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        do {
            return try decode(A.self, forKey: key)
        } catch {
            let string = try LenientJSONString.decode(from: superDecoder())
            guard let data = string.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(A.self, from: data)
        }
    }
}

// MARK: - 规则子结构（init() 默认构造确证）

struct SearchRule: Codable, Equatable {
    var checkKeyWord: String = ""
    var bookList: String = ""
    var name: String = ""
    var author: String = ""
    var coverUrl: String = ""
    var intro: String = ""
    var kind: String = ""
    var lastChapter: String = ""
    var bookUrl: String = ""
    var wordCount: String = ""

    /// 伪代码 SearchRule.init()（pgo 内联默认构造）。
    init() {}
}



struct TocRule: Codable, Equatable {
    var chapterList: String = ""
    var chapterName: String = ""
    var chapterUrl: String = ""
    var isVolume: String = ""
    var isVip: String = ""
    var updateTime: String = ""
    var nextTocUrl: String = ""

    init() {}
}



struct ContentRule: Codable, Equatable {
    var content: String = ""
    var nextContentUrl: String = ""
    var webJs: String = ""
    var sourceRegex: String = ""
    var replaceRegex: String = ""
    var imageStyle: String = ""
    var payAction: String = ""

    init() {}
}



struct BookInfoRule: Codable, Equatable {
    var initRule: String = ""
    var name: String = ""
    var author: String = ""
    var kind: String = ""
    var wordCount: String = ""
    var lastChapter: String = ""
    var intro: String = ""
    var coverUrl: String = ""
    var tocUrl: String = ""

    init() {}
}



struct ExploreRule: Codable, Equatable {
    var exploreUrl: String = ""
    var bookList: String = ""
    var name: String = ""
    var author: String = ""
    var coverUrl: String = ""
    var intro: String = ""
    var kind: String = ""
    var lastChapter: String = ""
    var bookUrl: String = ""
    var wordCount: String = ""

    init() {}
}



struct ReviewRule: Codable {
    var reviewList: String = ""
    var content: String = ""
    var author: String = ""
    var date: String = ""
    var rating: String = ""

    init() {}
}

// MARK: - 存储类别

/// 书源存储类别（label/shortLabel/icon/color 四展示属性，pgo 内联确证）。
enum StorageKind: String, Codable {
    case local
    case remote
    case thirdParty

    /// 展示标签（pgo_only getter）。
    var label: String {
        switch self {
        case .local: return "本地书源"
        case .remote: return "在线书源"
        case .thirdParty: return "第三方"
        }
    }

    /// 短标签（pgo_only getter）。
    var shortLabel: String {
        switch self {
        case .local: return "本"
        case .remote: return "网"
        case .thirdParty: return "三"
        }
    }

    /// 图标符号名（pgo_only getter）。
    var icon: String {
        switch self {
        case .local: return "internaldrive"
        case .remote: return "network"
        case .thirdParty: return "link"
        }
    }

    /// 色名（pgo_only getter；返回 CSS 色名）。
    var color: String {
        switch self {
        case .local: return "systemGreen"
        case .remote: return "systemBlue"
        case .thirdParty: return "systemOrange"
        }
    }
}

// MARK: - 书源

/// 书源模型（legado 兼容 JSON；35 字段解码链确证）。
struct BookSource: Codable, Identifiable, Equatable {
    var bookSourceUrl: String
    var bookSourceName: String
    var bookSourceGroup: String?
    var bookSourceType: Int?
    var bookSourceComment: String?

    // 启用开关（init 默认字节位 +160/+176/+192 = true 确证）。
    var enabled: Bool = true
    var enabledExplore: Bool = true
    var enabledCookieJar: Bool = true
    var enabledBookInfo: Bool = false
    var enabledToc: Bool = false
    var enabledContent: Bool = false
    var enabledReview: Bool = false

    /// 源级初始化规则（35 字段解码链 + == 比较域确证，wave-16 补成员）。
    var initRule: String = ""

    /// 源级变量（legado 兼容 JSON 串域——BookActionSheetView 消费域确证）。
    var variable: String = ""

    var header: String?
    var loginUrl: String?
    var bookUrlPattern: String?
    var loginUi: String?
    var concurrentRate: String?
    var coverDecodeUrl: String?
    var lastUpdateTime: Int64 = 0
    var customOrder: Int = 0
    var weight: Int = 0
    var expireTime: Int64 = 0
    var respondTime: Int64 = 180000

    var ruleSearch = SearchRule()
    var ruleToc = TocRule()
    var ruleContent = ContentRule()
    var ruleBookInfo = BookInfoRule()
    var ruleExplore = ExploreRule()
    var ruleReview = ReviewRule()

    /// 存储类别（默认值初始化确证；推断映射）。
    var storageKind: StorageKind = .remote

    /// 伪代码 0x1002332a4（L153 单行）：id 即 bookSourceUrl。
    var id: String {
        bookSourceUrl
    }

    /// 成员级构造（骨架签名 init(bookSourceUrl:bookSourceName:) 确证）。
    init(bookSourceUrl: String, bookSourceName: String) {
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceName = bookSourceName
    }

    // MARK: Codable

    /// 伪代码 0x1002339b0（L229-279）：35 字段解码链
    ///（decodeIfPresent 占多数 + 6 个规则对象 decodeObjectOrJSONStringIfPresent +
    /// StorageKind 回退闭包确证）。
    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookSourceUrl = try container.decodeLenientStringIfPresent(forKey: .bookSourceUrl) ?? ""
        bookSourceName = try container.decodeLenientStringIfPresent(forKey: .bookSourceName) ?? ""
        bookSourceGroup = try container.decodeLenientStringIfPresent(forKey: .bookSourceGroup)
        bookSourceType = try container.decodeIfPresent(Int.self, forKey: .bookSourceType)
        bookSourceComment = try container.decodeLenientStringIfPresent(forKey: .bookSourceComment)

        // 默认 true 三开关（init 字节位确证），缺省回落 decodeIfPresent。
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        enabledExplore = try container.decodeIfPresent(Bool.self, forKey: .enabledExplore) ?? true
        enabledCookieJar = try container.decodeIfPresent(Bool.self, forKey: .enabledCookieJar) ?? true
        enabledBookInfo = try container.decodeIfPresent(Bool.self, forKey: .enabledBookInfo) ?? false
        enabledToc = try container.decodeIfPresent(Bool.self, forKey: .enabledToc) ?? false
        enabledContent = try container.decodeIfPresent(Bool.self, forKey: .enabledContent) ?? false
        enabledReview = try container.decodeIfPresent(Bool.self, forKey: .enabledReview) ?? false

        header = try container.decodeLenientStringIfPresent(forKey: .header)
        loginUrl = try container.decodeLenientStringIfPresent(forKey: .loginUrl)
        bookUrlPattern = try container.decodeLenientStringIfPresent(forKey: .bookUrlPattern)
        loginUi = try container.decodeLenientStringIfPresent(forKey: .loginUi)
        concurrentRate = try container.decodeLenientStringIfPresent(forKey: .concurrentRate)
        coverDecodeUrl = try container.decodeLenientStringIfPresent(forKey: .coverDecodeUrl)
        lastUpdateTime = try container.decodeIfPresent(Int64.self, forKey: .lastUpdateTime) ?? 0
        customOrder = try container.decodeIfPresent(Int.self, forKey: .customOrder) ?? 0
        weight = try container.decodeIfPresent(Int.self, forKey: .weight) ?? 0
        expireTime = try container.decodeIfPresent(Int64.self, forKey: .expireTime) ?? 0
        respondTime = try container.decodeIfPresent(Int64.self, forKey: .respondTime) ?? 180000

        // 6 个规则对象：对象/JSON 字符串双路径（0x10023205c 族确证）。
        initRule = try container.decodeLenientStringIfPresent(forKey: .initRule) ?? ""
        variable = try container.decodeLenientStringIfPresent(forKey: .variable) ?? ""
        ruleSearch = try container.decodeObjectOrJSONStringIfPresent(SearchRule.self, forKey: .ruleSearch) ?? SearchRule()
        ruleToc = try container.decodeObjectOrJSONStringIfPresent(TocRule.self, forKey: .ruleToc) ?? TocRule()
        ruleContent = try container.decodeObjectOrJSONStringIfPresent(ContentRule.self, forKey: .ruleContent) ?? ContentRule()
        ruleBookInfo = try container.decodeObjectOrJSONStringIfPresent(BookInfoRule.self, forKey: .ruleBookInfo) ?? BookInfoRule()
        ruleExplore = try container.decodeObjectOrJSONStringIfPresent(ExploreRule.self, forKey: .ruleExplore) ?? ExploreRule()
        ruleReview = try container.decodeObjectOrJSONStringIfPresent(ReviewRule.self, forKey: .ruleReview) ?? ReviewRule()

        // StorageKind 回退闭包（implicit closure #1 确证）。
        storageKind = try container.decodeIfPresent(StorageKind.self, forKey: .storageKind) ?? .remote
    }

    private enum CodingKeys: String, CodingKey {
        case bookSourceUrl, bookSourceName, bookSourceGroup, bookSourceType, bookSourceComment
        case enabled, enabledExplore, enabledCookieJar, enabledBookInfo, enabledToc
        case enabledContent, enabledReview
        case initRule
        case variable
        case header, loginUrl, bookUrlPattern, loginUi, concurrentRate, coverDecodeUrl
        case lastUpdateTime, customOrder, weight, expireTime, respondTime
        case ruleSearch, ruleToc, ruleContent, ruleBookInfo, ruleExplore, ruleReview
        case storageKind
    }

    // MARK: 源级状态存取（UserDefaults）

    /// 状态键（readState 链：书源 url 拼接确证）。
    var stateKey: String {
        "source.state.\(bookSourceUrl)"
    }

    /// 伪代码 0x100230ba8（L380-399）：读状态
    ///（standardUserDefaults objectForKey 链确证）。
    static func readState(_ key: String, source: BookSource) -> String? {
        UserDefaults.standard.string(forKey: "\(source.stateKey).\(key)")
    }

    /// 伪代码 0x100230e00（L406-416）：写状态（nil → removeObjectForKey 确证）。
    static func writeState(_ key: String, source: BookSource, value: String?) {
        let fullKey = "\(source.stateKey).\(key)"
        if let value {
            UserDefaults.standard.set(value, forKey: fullKey)
        } else {
            UserDefaults.standard.removeObject(forKey: fullKey)
        }
    }

    /// 伪代码 0x100231094（L419-424）：删状态。
    static func removeState(_ key: String, source: BookSource) {
        UserDefaults.standard.removeObject(forKey: "\(source.stateKey).\(key)")
    }

    /// 有状态判定（骨架签名 hasStoredState(_)）。
    static func hasStoredState(_ key: String, source: BookSource) -> Bool {
        UserDefaults.standard.object(forKey: "\(source.stateKey).\(key)") != nil
    }
}

extension BookSource {

    /// 手工 ==（Equatable 合成对 `init` 反引号/backtick 成员不稳定——构建域桥）。
}

extension BookSource {

    /// 手工 ==（Equatable 合成异常桥——initRule 重命名后合成域待 macOS 核）。
    static func == (lhs: BookSource, rhs: BookSource) -> Bool {
        lhs.bookSourceUrl == rhs.bookSourceUrl
            && lhs.bookSourceName == rhs.bookSourceName
            && lhs.enabled == rhs.enabled
            && lhs.enabledExplore == rhs.enabledExplore
            && lhs.enabledCookieJar == rhs.enabledCookieJar
            && lhs.enabledBookInfo == rhs.enabledBookInfo
            && lhs.enabledToc == rhs.enabledToc
            && lhs.enabledContent == rhs.enabledContent
            && lhs.enabledReview == rhs.enabledReview
            && lhs.header == rhs.header
            && lhs.loginUrl == rhs.loginUrl
            && lhs.bookUrlPattern == rhs.bookUrlPattern
            && lhs.loginUi == rhs.loginUi
            && lhs.concurrentRate == rhs.concurrentRate
            && lhs.coverDecodeUrl == rhs.coverDecodeUrl
            && lhs.lastUpdateTime == rhs.lastUpdateTime
            && lhs.customOrder == rhs.customOrder
            && lhs.weight == rhs.weight
            && lhs.expireTime == rhs.expireTime
            && lhs.respondTime == rhs.respondTime
            && lhs.storageKind == rhs.storageKind
            && lhs.id == rhs.id
            && lhs.ruleSearch == rhs.ruleSearch
            && lhs.ruleToc == rhs.ruleToc
            && lhs.ruleContent == rhs.ruleContent
            && lhs.ruleBookInfo == rhs.ruleBookInfo
            && lhs.ruleExplore == rhs.ruleExplore
            && lhs.initRule == rhs.initRule
    }
}
