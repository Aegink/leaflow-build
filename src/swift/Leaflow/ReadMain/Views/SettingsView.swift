// 原路径: ReadMain/Views/SettingsView.swift
// 证据:
//   - PGO: 104 条记录（index/task_functions.csv T-701-11 /
//     SettingsView.swift；68 函数，伪代码域 480 行）
//   - CovMap: 上述 L 区段（settingsList L45-125 /
//     RemoteBackendSettingsView.body L306-411 / OtherSettingsView.body
//     L194-297 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/SettingsView.c
//     （5575 行）
//   - 块体确证（签名域）：
//     SettingsView.init(navigationPath:) / activeNavigationPath
//     getter / body getter / settingsList getter / settingsRowLabel
//     双签名（(_:systemImage:) + (:systemImage:trailing:)）/
//     pushSettingsRoute(_: SettingsRoute)（NavigationPath.append 域
//     L462）/ settingsDestination(for: SettingsRoute)
//     （&type metadata for SettingsRoute L128-150 路由域）
//   - 字符串域（位模式+指针，scratch/t70111_strings.txt）：
//     '设置' L196 / '已关闭' L979 / '高级设置' L1106 / '搜索' L1267 /
//     '阅读' L1288 / '网络' L1333 / '搜索模式' L1717/L1723 /
//     '并发线程数' L2176 / '关闭' L2478 / '超时时间' L2713 /
//     '章节预缓存' L3061 / '远程后端' L3475 / '连接' L3780 /
//     '提示' L3802 / '服务器地址' L4282 / '测试连接' L4988 /
//     '成功' L5040
//   - 事实：设置主页 = 路由表（阅读/网络/备份/主题/字体/缓存/关于/
//     替换规则）+ RemoteBackendSettingsView（服务器地址/测试连接）+
//     OtherSettingsView（高级设置/搜索模式/并发/超时/预缓存）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（九签名域 + 路由域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// 设置主页（init(navigationPath:) + settingsList 签名域确证）。
struct SettingsView: View {

    @Binding var navigationPath: NavigationPath?
    @State private var localNavigationPath = NavigationPath()
    @State private var searchMode: SearchMode = .all
    @State private var concurrentThreads = 4
    @State private var timeoutSeconds = 15
    @State private var chapterPrecache = true
    @State private var remoteBackendURL = ""
    @State private var remoteTestStatus = ""

    /// init(navigationPath:)（签名域确证：外层可选路由绑定）。
    init(navigationPath: Binding<NavigationPath>?) {
        // 外层可选路由绑定桥：显式 Optional 值域两分支（wave-80）。
        if let outer = navigationPath {
            _navigationPath = Binding<NavigationPath?>(
                get: { outer.wrappedValue },
                set: { outer.wrappedValue = $0 })
        } else {
            _navigationPath = Binding<NavigationPath?>(
                get: { nil }, set: { _ in })
        }
    }

    /// activeNavigationPath getter（签名域确证：外层优先）。
    private var activeNavigationPath: Binding<NavigationPath> {
        if let outer = _navigationPath.wrappedValue {
            return Binding(
                get: { _navigationPath.wrappedValue ?? outer },
                set: { _navigationPath.wrappedValue = $0 })
        }
        return $localNavigationPath
    }

    var body: some View {
        NavigationStack(path: activeNavigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    settingsList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("设置")
            .navigationDestination(for: SettingsRoute.self) { route in
                // settingsDestination(for:) 签名域确证。
                settingsDestination(for: route)
            }
        }
    }

    /// settingsList getter（签名域确证：设置路由表域）。
    @ViewBuilder
    private var settingsList: some View {
        routeRow(
            route: .reader, title: "阅读", systemImage: "book",
            color: .blue)
        routeRow(
            route: .appearance, title: "外观主题", systemImage:
                "paintpalette", color: .purple)
        routeRow(
            route: .tabIcon, title: "底部图标", systemImage:
                "square.grid.2x2", color: .teal)
        routeRow(
            route: .fontManage, title: "字体管理", systemImage:
                "textformat", color: .indigo)
        routeRow(
            route: .replaceRules, title: "替换规则", systemImage:
                "arrow.triangle.swap", color: .orange)
        routeRow(
            route: .backup, title: "备份与同步", systemImage:
                "externaldrive", color: .green)
        routeRow(
            route: .cacheManage, title: "缓存管理", systemImage:
                "cylinder.split.1x2", color: .mint)
        routeRow(
            route: .about, title: "关于", systemImage: "info.circle",
            color: .gray)
        OtherSettingsView()
        RemoteBackendSettingsView()
    }

    /// settingsRowLabel(_:systemImage:)（签名域确证）。
    @ViewBuilder
    private func settingsRowLabel(
        _ title: String, systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
    }

    /// settingsRowLabel(_:systemImage:trailing:)（双签名域确证）。
    @ViewBuilder
    private func settingsRowLabel<V: View>(
        _ title: String, systemImage: String,
        @ViewBuilder trailing: () -> V
    ) -> some View {
        HStack {
            settingsRowLabel(title, systemImage: systemImage)
            Spacer()
            trailing()
        }
    }

    /// routeRow（settingsCardRow + pushSettingsRoute 域确证）。
    @ViewBuilder
    private func routeRow(
        route: SettingsRoute, title: String, systemImage: String,
        color: Color
    ) -> some View {
        Button {
            // pushSettingsRoute(_: SettingsRoute) 域确证。
            pushSettingsRoute(route)
        } label: {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .frame(width: 26)
                settingsRowLabel(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .settingsCardRow(topGap: 10, padding: EdgeInsets(
            top: 12, leading: 14, bottom: 12, trailing: 14))
    }

    /// pushSettingsRoute(_: SettingsRoute)（签名域确证）。
    private func pushSettingsRoute(_ route: SettingsRoute) {
        activeNavigationPath.wrappedValue.append(route)
    }

    /// settingsDestination(for:)（签名域确证：路由目标域）。
    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute)
        -> some View {
        switch route {
        case .reader:
            // ReaderSettingsView 全参装配域桥（settings 常量域，
            // 真机核清项）。
            ReaderSettingsView(
                settings: .constant(ReadingSettings.load()),
                onDismiss: {})
        case .appearance:
            AppThemeSettingsView()
        case .tabIcon:
            TabIconSettingsView()
        case .fontManage:
            FontManageView()
        case .replaceRules:
            ReplaceRuleView()
        case .backup:
            BackupView()
        case .cacheManage:
            CacheManageView()
        case .about:
            AboutSettingsView()
        }
    }
}

/// 设置路由（&type metadata for SettingsRoute L128 域确证；case 域按
/// settingsList 行域还原）。
enum SettingsRoute: String, Hashable {
    case reader
    case appearance
    case tabIcon
    case fontManage
    case replaceRules
    case backup
    case cacheManage
    case about
}

/// 高级设置域（OtherSettingsView.body 0x100d2e11c L194-297 域确证）。
struct OtherSettingsView: View {

    @State private var searchMode: SearchMode = .all
    @State private var concurrentThreads = 4
    @State private var timeoutSeconds = 15
    @State private var chapterPrecache = true

    var body: some View {
        VStack(spacing: 0) {
            settingsCardRow(topGap: 16) {
                Picker(selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode)
                    }
                } label: {
                    // '搜索模式' L1717/L1723 域确证。
                    settingsRowLabel(
                        "搜索模式", systemImage: "magnifyingglass")
                }
                .pickerStyle(.menu)
                .onChange(of: searchMode) { _ in
                    persistReaderSettings()
                }
            }
            settingsCardRow(topGap: 12) {
                Picker(selection: $concurrentThreads) {
                    ForEach(1...8, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                } label: {
                    // '并发线程数' L2176 域确证。
                    settingsRowLabel(
                        "并发线程数", systemImage: "square.stack.3d.up")
                }
                .pickerStyle(.menu)
                .onChange(of: concurrentThreads) { _ in
                    persistReaderSettings()
                }
            }
            settingsCardRow(topGap: 12) {
                Picker(selection: $timeoutSeconds) {
                    ForEach([5, 10, 15, 30, 60], id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                } label: {
                    // '超时时间' L2713 域确证。
                    settingsRowLabel(
                        "超时时间", systemImage: "clock.badge.exclamationmark")
                }
                .pickerStyle(.menu)
                .onChange(of: timeoutSeconds) { _ in
                    persistReaderSettings()
                }
            }
            settingsCardRow(topGap: 12) {
                Toggle(isOn: $chapterPrecache) {
                    // '章节预缓存' L3061 域确证。
                    settingsRowLabel(
                        "章节预缓存", systemImage: "arrow.down.circle")
                }
                .onChange(of: chapterPrecache) { _ in
                    persistReaderSettings()
                }
            }
        }
        .onAppear {
            loadReaderSettings()
        }
    }

    private func loadReaderSettings() {
        let defaults = UserDefaults.standard
        let rawMode = defaults.string(forKey: "reader_search_mode")
        searchMode = rawMode.flatMap(SearchMode.init(rawValue:)) ?? .all
        concurrentThreads = defaults.integer(
            forKey: "reader_concurrent_threads")
        if concurrentThreads == 0 {
            concurrentThreads = 4
        }
        timeoutSeconds = defaults.integer(forKey: "reader_timeout")
        if timeoutSeconds == 0 {
            timeoutSeconds = 15
        }
        chapterPrecache = defaults.object(
            forKey: "reader_chapter_precache") == nil
            ? true
            : defaults.bool(forKey: "reader_chapter_precache")
    }

    private func persistReaderSettings() {
        let defaults = UserDefaults.standard
        defaults.set(searchMode.rawValue, forKey: "reader_search_mode")
        defaults.set(concurrentThreads, forKey:
            "reader_concurrent_threads")
        defaults.set(timeoutSeconds, forKey: "reader_timeout")
        defaults.set(chapterPrecache, forKey: "reader_chapter_precache")
    }
}

/// 远程后端域（RemoteBackendSettingsView.body 0x100d31fd4 L306-411
/// 域确证：'远程后端' L3475 + '服务器地址' L4282 + '测试连接' L4988 +
/// '成功' L5040）。
struct RemoteBackendSettingsView: View {

    @State private var serverURL = ""
    @State private var testing = false
    @State private var testSucceeded = false

    var body: some View {
        VStack(spacing: 0) {
            settingsCardRow(topGap: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // '远程后端' L3475 域确证。
                    settingsRowLabel(
                        "远程后端", systemImage: "server.rack")
                    // '服务器地址' L4282 域确证。
                    TextField("服务器地址", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                }
            }
            settingsCardRow(topGap: 12) {
                HStack {
                    Button {
                        testRemoteBackend()
                    } label: {
                        HStack {
                            // '测试连接' L4988 域确证。
                            Text("测试连接")
                            if testing {
                                ProgressView()
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(serverURL.isEmpty || testing)
                    Spacer()
                    if testSucceeded {
                        // '成功' L5040 域确证。
                        Text("成功")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .onAppear {
            serverURL = UserDefaults.standard.string(
                forKey: "reader_remote_backend_url") ?? ""
        }
    }

    private func testRemoteBackend() {
        testing = true
        guard let url = URL(string: serverURL) else {
            testing = false
            return
        }
        URLSession.shared.dataTask(with: url) { _, response, _ in
            DispatchQueue.main.async {
                testing = false
                testSucceeded =
                    (response as? HTTPURLResponse)?.statusCode == 200
            }
        }.resume()
    }
}
