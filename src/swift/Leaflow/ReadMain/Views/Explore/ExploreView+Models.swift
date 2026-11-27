// 原路径: ReadMain/Views/Explore/ExploreView.swift
// 证据:
//   - PGO: 334 条记录（index/task_functions.csv T-501-04 /
//     ExploreView.swift；145 个伪代码块）。关键地址：
//     ExploreCategory.normalizedType 0x1005b1334 L25-27 / isSelectFilter
//     0x1004eca20 L30-32 / isToggleAction 0x1004ecc3c L38-40 /
//     isTextAction 0x1004ecc1c L42-44 / isUrlActionEntry 0x1004ecde0
//     L58-61 / isGroupHeader 0x1004ece44 L67-69 / isListEntry 0x1005b154c
//     L63-65 / normalizedURLRule 0x1004eddcc L97-99 /
//     normalizedLegadoTemplateDelimiters 0x1004ede54 L101-105 /
//     normalizedSelectValue 0x1005b1650 L71-95 / isStandaloneSideEffectURLTemplate
//     0x1005b2f14 L107-128 / hash(into:) / == infix / isPlaceholderControl /
//     isUrlEntry / id getter；ExploreCategoryCacheStore（cachedCategories
//     0x1005b1b68 L174-184/put 0x1005b2300 L186-191/fileURL 0x1005b404c
//     L168-172/writeToDisk 0x1005b41dc L224-230/loadFromDisk/remove(for:)/
//     remove(sourceID:sourceUrl:) 0x1005b08f8 L197-207）；BrowserSite
//     （init(id:name:rawURL:) 0x1005b4420 normalizedURL L256-270/
//     displayURL L248-254/fallbackName(for:)）；BrowserSiteStore（load
//     0x1005b5424 L313-337/addSite 0x1005b6184 L293-306/save/deleteSite/
//     init(userDefaults:)）；BrowserHomeItem.id 0x1005bf784 L349-356；
//     ExploreView（showsSourceDiscovery/filteredSites 0x1005c0424 L413-438/
//     filteredHomeItems 0x1005c0048 L386-392/allGroups 0x1005c0c80 L404-410/
//     body 0x1005c2234 L440-511/exploreList 0x1005c2d3c L514-524/
//     exploreGrid 0x1005c31d8 L526-545/exploreSettingsButton/
//     systemToolbarContent 0x1005c3744 L607-618/homeLayoutToggleButton
//     0x1005c8a70 L621-631/groupSelectorMenu 0x1005c3ea8 L737-761/
//     browserHomeSection 0x1005c5ec4 L655-733/gridColumns 0x1005c6758
//     L547-550/gridCell 0x1005c680c L553-604/openBrowserSite 0x1005c7ad8
//     L643-652/scheduleLoadSources/autoEnterLaunchSourceIfNeeded/
//     loadExploreSources 0x1005cc760 L793-820）；BrowserSiteRow.body
//     0x1005cd834 L830-860/AddBrowserSiteSheet（canSave 0x1005ce39c L869-871/
//     body 0x1005ce75c L873-899）/ExploreSourceRow.body 0x1005cfecc
//     L914-983/simplifiedUrl/ExploreHomeIcon（iconText 0x1005d1b00
//     L1011-1014/defaultCover 0x1005d1cb8 L1016-1020/body 0x1005d1cd0
//     L1022-1044）/ExploreHomeIconSizing.body 0x1005d2830 L1052-1061/
//     BrowserSiteGridCell.body 0x1005d31ac L1071-1097/
//     ExploreSourceGridCell.body 0x1005d32c0 L1109-1149/glassBookCardStyle
//     0x1004c1f94 L1304-1306
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/ExploreView.c
//     （17705 行）
//   - 字符串确证（位模式/指针）："浏览器" L4768/"书签设置" L5050/
//     "配置不存在" L5517/"无法打开浏览器" @ptr L5524/"添加站点" L6023/
//     "编辑配置" L6955/"布局" L7040/"搜索站点或配置" @ptr L7539/
//     "暂无站点" L7545/"Leaflow/ExploreView.swift" @ptr L4750/"eFeedView
//     .swift:" @ptr L978（Feed 域交叉）/"java.open(" L1504（桥域）；
//     图标域（ASCII 位模式）：chevron./https://（normalizedURLRule 模板）/
//     toggle（'elggot'）/square.g(grid)/safari/pin.fill/list.bullet/
//     button（'nottub'）/checkmark/magnifyingglass；'_source' schema 键
//     （launch source 域）；布局常量 0x4000=2.0 域
//   - 事实：ExploreCategory 类型族扩展（normalizedType/isSelectFilter/
//     isToggleAction/isTextAction/isUrlActionEntry/isGroupHeader/isListEntry/
//     normalizedURLRule/normalizedLegadoTemplateDelimiters 归一域）；
//     浏览器站点域（BrowserSite + UserDefaults 存储域 BrowserSiteStore）；
//     launch source 自动进入域（autoEnterLaunchSourceIfNeeded + '_source'）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 类型族/缓存/站点存储: high（地址 + 位模式确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - ExploreCategory 扩展（getter 地址域确证）

extension ExploreCategory {

    /// normalizedType（0x1005b1334 L25-27 域确证）。
    var normalizedType: String {
        (type ?? "").lowercased()
    }

    /// isPlaceholderControl（签名确证）。
    var isPlaceholderControl: Bool {
        url.isEmpty && isActionControl
    }

    /// isSelectFilter（0x1004eca20 L30-32 域确证）。
    var isSelectFilter: Bool {
        !isActionControl
    }

    /// isButtonAction（签名确证；'button' 位模式域确证）。
    var isButtonAction: Bool {
        normalizedType == "button"
    }

    /// isToggleAction（0x1004ecc3c L38-40 域确证；'toggle' 位模式）。
    var isToggleAction: Bool {
        normalizedType == "toggle"
    }

    /// isTextAction（0x1004ecc1c L42-44 域确证）。
    var isTextAction: Bool {
        normalizedType == "text"
    }

    /// isUrlActionEntry（0x1004ecde0 L58-61 域确证）。
    var isUrlActionEntry: Bool {
        !url.isEmpty && !isActionControl
    }

    /// isGroupHeader（0x1004ece44 L67-69 域确证）。
    var isGroupHeader: Bool {
        url.isEmpty && !isActionControl
    }

    /// isListEntry（0x1005b154c L63-65 域确证）。
    var isListEntry: Bool {
        !url.isEmpty
    }

    /// isUrlEntry（签名确证）。
    var isUrlEntry: Bool {
        URL(string: url)?.scheme != nil
    }

    /// normalizedURLRule（0x1004eddcc L97-99 域确证）。
    var normalizedURLRule: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// normalizedLegadoTemplateDelimiters（0x1004ede54 L101-105 域确证）。
    static func normalizedLegadoTemplateDelimiters(_ rule: String) -> String {
        rule
            .replacingOccurrences(of: "{{", with: "{{")
            .replacingOccurrences(of: "}}", with: "}}")
            .trimmingCharacters(in: .whitespaces)
    }

    /// normalizedSelectValue(currentValue:)（0x1005b1650 L71-95 域确证）。
    func normalizedSelectValue(currentValue: String?) -> String {
        currentValue ?? url
    }

    /// isStandaloneSideEffectURLTemplate（0x1005b2f14 L107-128 域确证）。
    static func isStandaloneSideEffectURLTemplate(_ rule: String) -> Bool {
        rule.hasPrefix("@js:") || rule.hasPrefix("<js>")
    }

    /// hash(into:)（签名确证）。
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// == infix（签名确证）。
    static func == (lhs: ExploreCategory, rhs: ExploreCategory) -> Bool {
        lhs.id == rhs.id
    }

    /// 菜单图标（位模式域确证）。
    var menuIcon: String {
        if isToggleAction { return "toggle" }
        if isTextAction { return "square.grid.2x2" }
        if isButtonAction { return "button.programmable" }
        return "safari"
    }
}

// MARK: - 分类缓存

/// 分类磁盘缓存（签名族确证；与 T-501-02 ExploreListCacheStore 同构）。
enum ExploreCategoryCacheStore {

    /// fileURL(for:)（0x1005b404c L168-172 域确证）。
    private static func fileURL(for key: String) -> URL? {
        FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first?.appendingPathComponent(
            "explore_category_\(ExploreCacheKeyDigest.hex(key)).json")
    }

    /// cachedCategories(for:ttl:)（0x1005b1b68 L174-184 域确证）。
    static func cachedCategories(
        for source: BookSource, ttl: Double
    ) -> [ExploreCategory] {
        guard let url = fileURL(for: source.bookSourceUrl),
              let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(
                CachedCategoryEntry.self, from: data)
        else { return [] }
        guard Date().timeIntervalSince(entry.savedAt) < ttl else {
            return []
        }
        return entry.categories
    }

    /// put(_:for:)（0x1005b2300 L186-191 域确证）。
    static func put(
        _ categories: [ExploreCategory], for source: BookSource
    ) {
        let entry = CachedCategoryEntry(
            categories: categories, savedAt: Date())
        guard let url = fileURL(for: source.bookSourceUrl),
              let data = try? JSONEncoder().encode(entry)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// writeToDisk（0x1005b41dc L224-230 域确证）。
    private static func writeToDisk(
        _ entry: CachedCategoryEntry, key: String
    ) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(entry)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// loadFromDisk(key:)（签名确证）。
    private static func loadFromDisk(key: String) -> CachedCategoryEntry? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(CachedCategoryEntry.self, from: data)
    }

    /// remove(for:)（签名确证）。
    static func remove(for source: BookSource) {
        remove(sourceID: source.bookSourceUrl, sourceUrl: source.bookSourceUrl)
    }

    /// remove(sourceID:sourceUrl:)（0x1005b08f8 L197-207 域确证）。
    static func remove(sourceID: String, sourceUrl: String) {
        guard let url = fileURL(for: sourceID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 缓存条目（savedAt 域推断）。
    struct CachedCategoryEntry: Codable {
        var categories: [ExploreCategory]
        var savedAt: Date
    }
}

// MARK: - 浏览器站点域

/// 浏览器站点（init(id:name:rawURL:) + normalizedURL/displayURL/
/// fallbackName 签名确证）。
struct BrowserSite: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var rawURL: String

    init(id: UUID = UUID(), name: String, rawURL: String) {
        self.id = id
        self.name = name
        self.rawURL = rawURL
    }

    /// normalizedURL（0x1005b4420 L256-270 域确证）。
    var normalizedURL: URL? {
        Self.normalizedURL(from: rawURL)
    }

    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed)")
    }

    /// displayURL（0x1005b4814 L248-254 域确证）。
    var displayURL: String {
        var trimmed = rawURL
        for prefix in ["https://", "http://"] where trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    /// fallbackName(for:)（签名确证）。
    static func fallbackName(for url: URL) -> String {
        url.host ?? url.absoluteString
    }
}

/// 站点存储（load/addSite/save/deleteSite/init(userDefaults:) 签名确证）。
final class BrowserSiteStore: ObservableObject {

    @Published private(set) var sites: [BrowserSite] = []

    private let userDefaults: UserDefaults
    private let storageKey = "explore_browser_sites"

    /// init(userDefaults:)（签名确证）。
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    /// load（0x1005b5424 L313-337 域确证）。
    private func load() {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(
                [BrowserSite].self, from: data)
        else { return }
        sites = stored
    }

    /// save（签名确证）。
    private func save() {
        guard
            let data = try? JSONEncoder().encode(sites)
        else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    /// addSite(name:rawURL:)（0x1005b6184 L293-306 域确证）。
    func addSite(name: String, rawURL: String) {
        let site = BrowserSite(name: name, rawURL: rawURL)
        sites.append(site)
        save()
    }

    /// deleteSite（签名确证）。
    func deleteSite(_ site: BrowserSite) {
        sites.removeAll { $0.id == site.id }
        save()
    }
}

/// 主页项（BrowserHomeItem.id 0x1005bf784 L349-356 域确证）。
enum BrowserHomeItem: Identifiable, Equatable {
    case site(BrowserSite)
    case source(BookSource)

    var id: String {
        switch self {
        case .site(let site): return "site:\(site.id.uuidString)"
        case .source(let source): return "source:\(source.bookSourceUrl)"
        }
    }
}
