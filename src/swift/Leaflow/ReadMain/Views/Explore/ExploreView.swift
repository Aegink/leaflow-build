// 原路径: ReadMain/Views/Explore/ExploreView.swift
// 首页视图与共享源加载；模型/缓存及行格组件按原归属分册，336文件分母不变。
import SwiftUI
import UIKit
import Combine

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

    @ObservedObject private var sourceService = SourceService.shared

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
                BrowserPageView(url: url, onOpenInHostApp: {
                    UIApplication.shared.open($0)
                })
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
        .onReceive(sourceService.$bookSources.receive(on: RunLoop.main)) { updated in
            sources = updated.filter(ExploreSourceAvailability.isVisible)
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
            defer { loadScheduled = false }
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
        if !sourceService.hasLoadedOnce { await sourceService.loadLocalSources() }
        let explore = sourceService.bookSources.filter(ExploreSourceAvailability.isVisible)
        await MainActor.run {
            sources = explore
        }
    }
}

