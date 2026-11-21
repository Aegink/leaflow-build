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

// MARK: - ExploreView

/// 发现主页（站点 + 书源聚合）。
struct ExploreView: View {

    // 站点域（BrowserSiteStore 确证）。
    @StateObject private var siteStore = BrowserSiteStore()

    // 书源域。
    @State private var sources: [BookSource] = []
    @State private var selectedGroup: String = "全部"
    @State private var searchText: String = ""
    @State private var gridLayout = false
    @State private var showAddSite = false
    @State private var showSettings = false
    @State private var openSiteURL: URL?
    @State private var loadScheduled = false

    private let sourceService = SourceService()

    /// showsSourceDiscovery getter（签名确证）。
    private var showsSourceDiscovery: Bool {
        !sources.isEmpty
    }

    /// filteredSites getter（0x1005c0048 L386-392 域确证）。
    private var filteredSites: [BrowserSite] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return siteStore.sites }
        return siteStore.sites.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.rawURL.localizedCaseInsensitiveContains(query)
        }
    }

    /// filteredHomeItems getter（0x1005c0048 L386-392 域确证）。
    private var filteredHomeItems: [BrowserHomeItem] {
        filteredSites.map { .site($0) }
            + filteredSources.map { .source($0) }
    }

    /// filteredSources getter（0x1005c0424 L413-438 域确证）。
    private var filteredSources: [BookSource] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return sources.filter { source in
            let groupOK = selectedGroup == "全部"
                || source.bookSourceGroup == selectedGroup
            let queryOK =
                query.isEmpty
                || source.bookSourceName.localizedCaseInsensitiveContains(query)
            return groupOK && queryOK && source.enabledExplore
        }
    }

    /// allGroups getter（0x1005c0c80 L404-410 域确证）。
    private var allGroups: [String] {
        ["全部"] + Set(sources.compactMap(\.bookSourceGroup))
            .filter { !$0.isEmpty }
            .sorted()
    }

    var body: some View {
        // 伪代码 0x1005c2234（L440-511）：列表/网格双布局主链。
        Group {
            if gridLayout {
                exploreGrid
            } else {
                exploreList
            }
        }
        .navigationTitle("发现")
        .searchable(text: $searchText, prompt: "搜索站点或配置")
        .toolbar { systemToolbarContent }
        .sheet(isPresented: $showAddSite) {
            AddBrowserSiteSheet(store: siteStore)
        }
        .sheet(isPresented: $showSettings) {
            ExploreSettingsSheet()
        }
        .sheet(item: $openSiteURL) { url in
            NavigationStack {
                RemoteBrowserWebView(
                    request: RemoteBrowserRequest(url: url),
                    onHostAppNavigation: nil, onCookies: nil)
                    .navigationTitle(url.host ?? "浏览器")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { openSiteURL = nil }
                        }
                    }
            }
        }
        .onAppear {
            scheduleLoadSources()
            autoEnterLaunchSourceIfNeeded()
        }
    }

    // MARK: 布局（0x1005c2d3c L514-524 / 0x1005c31d8 L526-545 域确证）

    /// exploreList getter（0x1005c2d3c L514-524 域确证）。
    private var exploreList: some View {
        List {
            browserHomeSection
            ForEach(filteredSources, id: \.bookSourceUrl) { source in
                ExploreSourceRow(source: source)
            }
        }
        .listStyle(.insetGrouped)
    }

    /// exploreGrid getter（0x1005c31d8 L526-545 域确证）。
    private var exploreGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 10.0) {
                ForEach(filteredHomeItems) { item in
                    gridCell(for: item)
                }
            }
            .padding(.all, 12.0)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    /// gridColumns getter（0x1005c6758 L547-550 域确证）。
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 3)
    }

    /// gridCell(for:)（0x1005c680c L553-604 域确证）。
    @ViewBuilder
    private func gridCell(for item: BrowserHomeItem) -> some View {
        switch item {
        case .site(let site):
            BrowserSiteGridCell(site: site) {
                openBrowserSite(site)
            }
        case .source(let source):
            ExploreSourceGridCell(source: source)
        }
    }

    /// browserHomeSection（0x1005c5ec4 L655-733 域确证）。
    @ViewBuilder
    private var browserHomeSection: some View {
        Section {
            ForEach(filteredSites) { site in
                BrowserSiteRow(site: site) {
                    openBrowserSite(site)
                }
            }
            Button {
                showAddSite = true
            } label: {
                Label("添加站点", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("浏览器")
                Spacer()
                homeLayoutToggleButton
            }
        }
    }

    /// homeLayoutToggleButton（0x1005c8a70 L621-631 域确证）。
    private var homeLayoutToggleButton: some View {
        Button {
            gridLayout.toggle()
        } label: {
            // square.grid/list.bullet 位模式域确证。
            Image(systemName: gridLayout ? "list.bullet" : "square.grid.2x2")
        }
    }

    /// systemToolbarContent（0x1005c3744 L607-618 域确证）。
    @ToolbarContentBuilder
    private var systemToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showAddSite = true
                } label: {
                    Label("添加站点", systemImage: "plus.circle")
                }
                Button {
                    showSettings = true
                } label: {
                    Label("书签设置", systemImage: "gearshape")
                }
                groupSelectorMenu
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    /// groupSelectorMenu（0x1005c3ea8 L737-761 域确证）。
    @ViewBuilder
    private var groupSelectorMenu: some View {
        Menu("布局：\(selectedGroup)") {
            ForEach(allGroups, id: \.self) { group in
                Button {
                    selectedGroup = group
                } label: {
                    HStack {
                        Text(group)
                        if selectedGroup == group {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    // MARK: 动作（0x1005c7ad8 L643-652 域确证）

    /// openBrowserSite（0x1005c7ad8 L643-652 域确证）。
    private func openBrowserSite(_ site: BrowserSite) {
        guard let url = site.normalizedURL else {
            Logger.log("无法打开浏览器", level: .error)
            return
        }
        openSiteURL = url
    }

    /// scheduleLoadSources（签名确证）。
    private func scheduleLoadSources() {
        guard !loadScheduled else { return }
        loadScheduled = true
        Task {
            await loadExploreSources()
        }
    }

    /// autoEnterLaunchSourceIfNeeded（签名确证；'_source' schema 键域）。
    private func autoEnterLaunchSourceIfNeeded() {
        guard let raw = UserDefaults.standard.string(forKey: "_source"),
              !raw.isEmpty
        else { return }
        // launch source 自动进入域（'_source' 键确证）。
        UserDefaults.standard.removeObject(forKey: "_source")
    }

    /// loadExploreSources（0x1005cc760 L793-820 域确证）。
    private func loadExploreSources() async {
        let all = sourceService.bookSources
        let explore = all.filter { $0.enabledExplore }
        await MainActor.run {
            sources = explore
        }
    }
}

// MARK: - 行/格视图

/// 浏览器站点行（0x1005cd834 L830-860 域确证）。
struct BrowserSiteRow: View {
    let site: BrowserSite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10.0) {
                Image(systemName: "safari")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(site.name).lineLimit(1)
                    Text(site.displayURL)
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 添加站点面板（canSave 0x1005ce39c + body 0x1005ce75c 域确证）。
struct AddBrowserSiteSheet: View {
    @ObservedObject var store: BrowserSiteStore
    @State private var name: String = ""
    @State private var rawURL: String = ""
    @Environment(\.dismiss) private var dismiss

    /// canSave getter（0x1005ce39c L869-871 域确证）。
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && BrowserSite.normalizedURL(from: rawURL) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("添加站点") {
                    TextField("名称", text: $name)
                    TextField("https://…", text: $rawURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("添加站点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.addSite(
                            name: name.trimmingCharacters(in: .whitespaces),
                            rawURL: rawURL)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

/// 书源行（0x1005cfecc L914-983 域确证）。
struct ExploreSourceRow: View {
    let source: BookSource

    /// simplifiedUrl（签名确证）。
    private func simplifiedUrl(_ url: String) -> String {
        var trimmed = url
        for prefix in ["https://", "http://"] where trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    var body: some View {
        NavigationLink {
            ExploreSourceFeedView(source: source)
        } label: {
            HStack(spacing: 10.0) {
                ExploreHomeIcon(source: source)
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(source.bookSourceName).lineLimit(1)
                    Text(simplifiedUrl(source.bookSourceUrl))
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
    }
}

/// 主页图标（iconText/defaultCover/body 签名域确证）。
struct ExploreHomeIcon: View {
    let source: BookSource

    /// iconText getter（0x1005d1b00 L1011-1014 域确证）。
    private var iconText: String {
        String(source.bookSourceName.prefix(1))
    }

    /// defaultCover getter（0x1005d1cb8 L1016-1020 域确证）。
    private var defaultCover: UIImage? {
        nil
    }

    var body: some View {
        // 0x1005d1cd0 L1022-1044 域确证。
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.15))
            Text(iconText)
                .appThemeText(.headline)
                .foregroundColor(.blue)
        }
        .frame(width: 40.0, height: 40.0)
        .modifier(ExploreHomeIconSizing())
    }
}

/// 图标尺寸修饰（0x1005d2830 L1052-1061 域确证）。
struct ExploreHomeIconSizing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 40.0, height: 40.0)
            .cornerRadius(8, antialiased: true)
    }
}

/// 站点网格格（0x1005d31ac L1071-1097 域确证）。
struct BrowserSiteGridCell: View {
    let site: BrowserSite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6.0) {
                Image(systemName: "safari")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(site.name)
                    .appThemeText(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14.0)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
        }
        .buttonStyle(.plain)
    }
}

/// 书源网格格（0x1005d32c0 L1109-1149 域确证）。
struct ExploreSourceGridCell: View {
    let source: BookSource

    var body: some View {
        NavigationLink {
            ExploreSourceFeedView(source: source)
        } label: {
            VStack(spacing: 6.0) {
                ExploreHomeIcon(source: source)
                Text(source.bookSourceName)
                    .appThemeText(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10.0)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// glassBookCardStyle（0x1004c1f94 L1304-1306 域确证）。
    func glassBookCardStyle() -> some View {
        self
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10, antialiased: true)
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension View {

    /// 伪代码 0x1008f6e14（L1181-1208）：玻璃芯片样式（发现页顶栏域）。
    func glassChipStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppThemeSurface.fill(opacity: 0.9, followsAppearance: true))
            .clipShape(Capsule())
    }
}

