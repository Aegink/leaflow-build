// 原路径: ReadMain/Models/BookSource.swift
// 证据: 0x1002339b0 L229-279 字段解码；0x100230ba8 L380-399 状态存取。
// JSON辅助与六组规则分册仍归本原始文件，336文件分母不变。
import Foundation

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

    /// headerMap 桥（header JSON 串 → 键值域——CookiePersistenceService/
    /// LoginService 消费域确证；非 JSON 串原样缺失，wave-16 补桥）。
    var headerMap: [String: String] {
        guard let header,
              let data = header.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data)
                  as? [String: String]
        else { return [:] }
        return map
    }
    var loginUrl: String?
    var bookUrlPattern: String?
    var loginUi: String?
    var concurrentRate: String?
    var coverDecodeUrl: String?
    // T-1601-B5：按 index/swift_types_dump.txt BookSource 字段表补齐
    // （原版 35 字段；此前缺 searchUrl/exploreUrl → 导入源丢搜索地址与
    // 发现地址，搜索/发现链必然为空）。
    var loginCheckJs: String?
    var checkKeyWord: String?
    var variableComment: String?
    var providerType: Int?
    var customButton: Bool?
    var eventListener: Bool?
    var jsLib: String?
    var coverDecodeJs: String?
    var searchUrl: String?
    var exploreUrl: String?
    var exploreScreen: String?
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

    /// 发现 URL 归一（T-1601-B5）：原版字段 `exploreUrl` 为主；旧还原
    /// 曾把地址放在 `ruleExplore.exploreUrl`，保留回退以兼容既有数据。
    var resolvedExploreUrl: String {
        let primary = (exploreUrl ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return primary.isEmpty ? ruleExplore.exploreUrl : primary
    }

    /// 成员级构造（骨架签名 init(bookSourceUrl:bookSourceName:) 确证）。
    init(bookSourceUrl: String, bookSourceName: String) {
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceName = bookSourceName
    }

    // MARK: Codable

    /// 伪代码 0x1002339b0（L229-279）：35 字段解码链
    ///（decodeIfPresent 占多数 + 6 个规则对象 decodeObjectOrJSONStringIfPresent +
    /// StorageKind 回退闭包确证）。init() 赋非可选双字段（wave-16）。
    init() {
        bookSourceUrl = ""
        bookSourceName = ""
    }

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
        // T-1601-B5：原版 35 字段补齐（dump 字段表 + CodingKeys）。
        loginCheckJs = try container.decodeLenientStringIfPresent(forKey: .loginCheckJs)
        checkKeyWord = try container.decodeLenientStringIfPresent(forKey: .checkKeyWord)
        variableComment = try container.decodeLenientStringIfPresent(forKey: .variableComment)
        providerType = try container.decodeIfPresent(Int.self, forKey: .providerType)
        customButton = try container.decodeIfPresent(Bool.self, forKey: .customButton)
        eventListener = try container.decodeIfPresent(Bool.self, forKey: .eventListener)
        jsLib = try container.decodeLenientStringIfPresent(forKey: .jsLib)
        coverDecodeJs = try container.decodeLenientStringIfPresent(forKey: .coverDecodeJs)
        searchUrl = try container.decodeLenientStringIfPresent(forKey: .searchUrl)
        exploreUrl = try container.decodeLenientStringIfPresent(forKey: .exploreUrl)
        exploreScreen = try container.decodeLenientStringIfPresent(forKey: .exploreScreen)
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
        case loginCheckJs, checkKeyWord, variableComment, providerType
        case customButton, eventListener, jsLib, coverDecodeJs
        case searchUrl, exploreUrl, exploreScreen
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
            && lhs.loginCheckJs == rhs.loginCheckJs
            && lhs.checkKeyWord == rhs.checkKeyWord
            && lhs.jsLib == rhs.jsLib
            && lhs.coverDecodeJs == rhs.coverDecodeJs
            && lhs.searchUrl == rhs.searchUrl
            && lhs.exploreUrl == rhs.exploreUrl
            && lhs.exploreScreen == rhs.exploreScreen
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
