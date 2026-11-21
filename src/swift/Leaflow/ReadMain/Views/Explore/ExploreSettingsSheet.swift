// 原路径: ReadMain/Views/Explore/ExploreSettingsSheet.swift
// 证据:
//   - PGO: 111 条记录（index/task_functions.csv T-501-03 /
//     ExploreSettingsSheet.swift；92 函数，伪代码域 432 行）
//   - CovMap: 上述 L 区段（sheet L18-366 / picker L379-432）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/
//     ExploreSettingsSheet.c（8949 行，92 块索引
//     0x1004fc4e8-0x10050c1ec）
//   - 块体确证（地址+行号域）：
//     settingsNavigation 0x1004fde3c L48-71（NavigationStack + sheet +
//     toolbar 链，ReadingSettings Bindable 域 L74-76）/ settingsList
//     0x1004fe174 L77-83（Section 元组域）+ '书签布局' L968 +
//     MenuPickerStyle L981 / homeSection 0x1004fe3d8 L87-108 +
//     '首屏配置' L1063 + Toggle 域 'square.grid.2x2' L1163 /
//     layoutSection '排列方式' L4649 + '网格列数' L2692 +
//     launchSourceSection 0x1004fe708 L132-157 + 'Telegram 群组'
//     L5798 + 'paperplane' L5801 + 'arrow.up' L5804 + chevron 域
//     L4556 / feedCountSection 0x1005025fc L199-221 + '竖排展示数'
//     L4840 + 'list.number' L4843 + '横滑展示数' L4911 /
//     feedPrefetchSection 0x100502980 L223-239 + '预加载数量' L5070 /
//     cacheSection 0x1004ff248 L241-259 + '书签缓存' L1810 +
//     '缓存有效期' L5151 / coverConcurrencySection 0x100502cf0
//     L261-277 + '封面并发数' L5272 / keywordSection 0x100501f40
//     L280-317 + '添加关键词' L3285 + 'plus.circle' L3264 +
//     onDelete 域 L118 + onSubmit 域 L3351 / alternateSection
//     0x10050227c L320-333 + '竖排数量' L5608 + '横滑数量' L5679 /
//     trimmedNewKeyword 0x100506590 L335-337 / addKeyword
//     0x100506384 L339-347 / launchSourceDisplayName 0x10050135c
//     L350-354（first(where:) 域 L132-133）/ numberPickerRow
//     0x100500238 L357-366（ForEach(range) tag 域 L358-362）/
//     picker filtered 0x1005085b4 L379-383 / picker body 0x100508ed8
//     L385-413 + '书签设置' L279 + navigationBarTitleDisplayMode
//     inline L303 + '不启用' L8146 / picker row 0x10050a3f4 L419-432
//     + 'checkmark' L8728 / launchCandidates closure #1/#2 0x1004fcd78
//     L25-25（filter+map 链）
//   - 字符串域（位模式+指针，scratch/t50103_strings.txt）：'首屏配置'
//     L1063 / '书签布局' L4400 / '排列方式' L4649 / '网格列数' L2692 /
//     'square.grid.2x2' L1163 / 'Telegram 群组' L5798 / 'paperplane'
//     L5801 / 'arrow.up' L5804 / '竖排展示数' L4840 / 'list.number'
//     L4843 / '横滑展示数' L4911 / '预加载数量' L5070 / '缓存有效期'
//     L5151 / '封面并发数' L5272 / '添加关键词' L3285 / 'plus.circle'
//     L3264/L6963 / '竖排数量' L5608 / '横滑数量' L5679 / '不启用'
//     L8146 / '配置（' L8400 / 'checkmark' L8728 / 'chevron.' L4556
//   - 事实：ReadingSettings 绑定域（settingsNavigation L74-76 Bindable
//     链）；无参构造对齐 ExploreView L416 / ExploreSourceFeedView
//     L318 调用点（前 Task-501-03 占位注释）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（Section 域 + 字符串全链确证；ReadingSettings 之外的
//   explore 键按 UserDefaults reader_explore_* 还原桥）
// 还原: 2026-11-20

import SwiftUI

/// 发现页设置面板（settingsNavigation 0x1004fde3c L48-71 域确证）。
struct ExploreSettingsSheet: View {

    /// 启动源候选（id getter 0x1004fc7dc 域确证：id 为字符串键）。
    struct LaunchSourceCandidate: Identifiable, Hashable {
        let id: String
        let name: String
        let url: String
    }

    /// 布局档位（label/icon getter 签名 L147-148 + 'square.grid.2x2'
    /// L1163 / '列表'/'网格' label 域 L1211 确证）。
    enum LayoutOption: Int, Hashable, CaseIterable {
        case grid
        case list

        var label: String {
            switch self {
            case .grid: return "网格"
            case .list: return "列表"
            }
        }

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "arrow.right.circle"
            }
        }
    }

    /// 无参构造（ExploreView L416 / ExploreSourceFeedView L318 调用点）。
    init() {
        _settings = State(initialValue: ReadingSettings.load())
    }

    // ReadingSettings Bindable 域（settingsNavigation L74-76 确证）。
    @State private var settings: ReadingSettings

    @State private var showLaunchSourcePicker = false
    @State private var newKeyword = ""
    private let sourceService = SourceService()

    var body: some View {
        NavigationStack {
            Form {
                settingsList(
                    settings: settings,
                    // layoutOption 为 UserDefaults 计算域——Binding 闭包
                    // 直连 UserDefaults，绕过 self 不可变域（wave-16）。
                    layoutBinding: Binding(
                        get: {
                            LayoutOption(
                                rawValue: UserDefaults.standard.integer(
                                    forKey: "reader_explore_layout")) ?? .grid
                        },
                        set: {
                            UserDefaults.standard.set(
                                $0.rawValue, forKey: "reader_explore_layout")
                        }))
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // closure #1 0x1004fd8d4 L59 域确证：收起面板。
                        persist()
                    }
                }
            }
            .sheet(isPresented: $showLaunchSourcePicker) {
                // closure #3 0x1004fd924 L62-69 域确证：启动源选择 sheet。
                ExploreLaunchSourcePicker(
                    candidates: Self.launchCandidates(
                        from: sourceService.bookSources),
                    selectedID: Binding(
                        get: { Self.launchSourceID },
                        set: { Self.launchSourceID = $0 }))
            }
        }
    }

    /// settingsList（0x1004fe174 L77-83 域确证：Section 元组域）。
    @ViewBuilder
    private func settingsList(
        settings: ReadingSettings,
        layoutBinding: Binding<LayoutOption>
    ) -> some View {
        homeSection(settings: settings)
        layoutSection(settings: settings, layoutBinding: layoutBinding)
        launchSourceSection
        feedSettingsSections(settings: settings)
        cacheSection(settings: settings)
        keywordSection(settings: settings)
        alternateSection(settings: settings)
    }

    // MARK: 首屏（homeSection 0x1004fe3d8 L87-108 域确证）

    private func homeSection(settings: ReadingSettings) -> some View {
        Section {
            // Toggle 域 L1155-1165 确证：'square.grid.2x2' 图标。
            Toggle(isOn: boolBinding("reader_explore_show_home")) {
                AppThemeSettingsLabel(
                    "展示书签页", systemImage: "square.grid.2x2")
            }
        } header: {
            Text("首屏配置")
        } footer: {
            Text("在发现页顶部展示书签入口")
        }
    }

    // MARK: 布局（layoutSection '书签布局' L968/L4400 + MenuPickerStyle
    // L981 域确证）

    private func layoutSection(
        settings: ReadingSettings, layoutBinding: Binding<LayoutOption>
    ) -> some View {
        Section {
            Picker(selection: layoutBinding) {
                ForEach(LayoutOption.allCases, id: \.self) { option in
                    AppThemeSettingsLabel(
                        option.label, systemImage: option.icon)
                        .tag(option)
                }
            } label: {
                Text("排列方式")
            }
            .pickerStyle(.menu)
            numberPickerRow(
                "网格列数", systemImage: "square.grid.2x2",
                selection: intBinding("reader_explore_grid_columns"),
                range: 2...6)
        } header: {
            Text("书签布局")
        }
    }

    // MARK: 启动源（launchSourceSection 0x1004fe708 L132-157 域确证）

    private var launchSourceSection: some View {
        Section {
            Button {
                // closure #1 0x1005008e8 L133-151 域确证：弹出启动源选择。
                showLaunchSourcePicker = true
            } label: {
                // contentShape 域 L136-149 确证：整行可点 + 标签 +
                // 当前值 + chevron。
                HStack {
                    AppThemeSettingsLabel(
                        "启动源", systemImage: "paperplane")
                    Spacer()
                    Text(launchSourceDisplayName)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text("启动源")
        } footer: {
            // '配置（' L8400 域确证：当前配置说明脚注。
            Text("配置（点击行选择书签启动源）")
        }
    }

    // MARK: Feed 设置（feedSettingsSections 三段：0x100501cbc L179-197 /
    // 0x1005025fc L199-221 / 0x100502980 L223-239 域确证）

    @ViewBuilder
    private func feedSettingsSections(settings: ReadingSettings)
        -> some View {
        rankingModeSection(settings: settings)
        feedCountSection(settings: settings)
        feedPrefetchSection(settings: settings)
    }

    private func rankingModeSection(settings: ReadingSettings) -> some View {
        Section {
            Picker(selection: Binding(
                get: { settings.exploreRanking },
                set: {
                    settings.exploreRanking = $0
                    persist()
                })) {
                ForEach(ExploreSectionRankingMode.allCases,
                        id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            } label: {
                Text("循环数量")
            }
            .pickerStyle(.menu)
        } header: {
            Text("排序方式")
        }
    }

    private func feedCountSection(settings: ReadingSettings) -> some View {
        Section {
            // 双 numberPickerRow 域 L202-215 确证：
            // '竖排展示数' L4840 + 'list.number' L4843 /
            // '横滑展示数' L4911。
            numberPickerRow(
                "竖排展示数", systemImage: "list.number",
                selection: intBinding("reader_explore_feed_count_vertical"),
                range: 3...20)
            numberPickerRow(
                "横滑展示数", systemImage: "rectangle.split.2x1",
                selection:
                    intBinding("reader_explore_feed_count_horizontal"),
                range: 2...10)
        } header: {
            Text("展示数量")
        }
    }

    private func feedPrefetchSection(settings: ReadingSettings) -> some View {
        Section {
            numberPickerRow(
                "预加载数量", systemImage: "arrow.down.circle",
                selection: intBinding("reader_explore_feed_prefetch"),
                range: 0...10)
        } header: {
            Text("预加载")
        }
    }

    // MARK: 缓存（cacheSection 0x1004ff248 L241-259 + coverConcurrency
    // 0x100502cf0 L261-277 域确证）

    private func cacheSection(settings: ReadingSettings) -> some View {
        Section {
            Picker(selection: Binding(
                get: { settings.exploreCacheTTL },
                set: {
                    settings.exploreCacheTTL = $0
                    persist()
                })) {
                ForEach(ExploreCacheTTLOption.allCases, id: \.self) { ttl in
                    Text(ttl.label).tag(ttl)
                }
            } label: {
                Text("缓存有效期")
            }
            .pickerStyle(.menu)
            coverConcurrencySection(settings: settings)
        } header: {
            Text("书签缓存")
        }
    }

    private func coverConcurrencySection(settings: ReadingSettings)
        -> some View {
        numberPickerRow(
            "封面并发数", systemImage: "photo.stack",
            selection: intBinding("reader_explore_cover_concurrency"),
            range: 1...8)
    }

    // MARK: 关键词（keywordSection 0x100501f40 L280-317 域确证：
    // onDelete 域 L118 + onSubmit 域 L3351 + '添加关键词' L3285）

    private func keywordSection(settings: ReadingSettings) -> some View {
        Section {
            // keywords 为静态 UserDefaults 计算域——indices 枚举域
            // （ForEach(Binding) 无 [String] 一致性，wave-16）。
            ForEach(Self.keywords.indices, id: \.self) { offset in
                AppThemeSettingsLabel(
                    Self.keywords[offset],
                    systemImage: "textformat")
            }
            .onDelete { offsets in
                // closure #2 域 L118 确证：按下标删除关键词。
                var current = Self.keywords
                current.remove(atOffsets: offsets)
                Self.keywords = current
                persist()
            }
            HStack {
                Image(systemName: "textformat")
                    .foregroundStyle(.secondary)
                TextField("添加关键词", text: $newKeyword)
                    .onSubmit {
                        // closure 域 L3351 确证：提交即添加。
                        addKeyword(settings: settings)
                    }
                if !trimmedNewKeyword.isEmpty {
                    Button {
                        addKeyword(settings: settings)
                    } label: {
                        AppThemeSettingsLabel(
                            "添加关键词",
                            systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("关键词")
        } footer: {
            Text("按关键词过滤书签源内容")
        }
    }

    // MARK: 备选域（alternateSection 0x10050227c L320-333 域确证：
    // 双 numberPickerRow '竖排数量'/'横滑数量'）

    private func alternateSection(settings: ReadingSettings) -> some View {
        Section {
            numberPickerRow(
                "竖排数量", systemImage: "list.number",
                selection: intBinding("reader_explore_alt_vertical"),
                range: 3...20)
            numberPickerRow(
                "横滑数量", systemImage: "rectangle.split.2x1",
                selection: intBinding("reader_explore_alt_horizontal"),
                range: 2...10)
        } header: {
            Text("书签缓存")
        }
    }

    // MARK: 辅助（0x100506590 / 0x100506384 / 0x10050135c 域确证）

    /// trimmedNewKeyword getter（0x100506590 L335-337 签名域）。
    private var trimmedNewKeyword: String {
        newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// addKeyword(settings:)（0x100506384 L339-347 签名域：trim +
    /// 去重 + 追加 + 清空输入）。
    private func addKeyword(settings: ReadingSettings) {
        let keyword = trimmedNewKeyword
        guard !keyword.isEmpty,
              !Self.keywords.contains(keyword) else {
            return
        }
        Self.keywords.append(keyword)
        newKeyword = ""
        persist()
    }

    /// launchSourceDisplayName getter（0x10050135c L350-354 域确证：
    /// candidates.first(where: id 匹配)?.name ?? '不启用'）。
    private var launchSourceDisplayName: String {
        Self.launchCandidates(from: sourceService.bookSources)
            .first(where: { $0.id == Self.launchSourceID })?
            .name ?? "不启用"
    }

    /// persist（还原桥：ReadingSettings.save()）。
    private func persist() {
        settings.save()
    }

    /// explore 域 UserDefaults 还原桥（键与 ReadingSettings.CodingKeys
    /// 的 reader_* 习惯一致）。
    private func intBinding(_ key: String) -> Binding<Int> {
        Binding(
            get: { UserDefaults.standard.integer(forKey: key) },
            set: {
                UserDefaults.standard.set($0, forKey: key)
                persist()
            })
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: key) },
            set: {
                UserDefaults.standard.set($0, forKey: key)
                persist()
            })
    }

    private var layoutOption: LayoutOption {
        get {
            LayoutOption(
                rawValue: UserDefaults.standard.integer(
                    forKey: "reader_explore_layout")) ?? .grid
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue, forKey: "reader_explore_layout")
            persist()
        }
    }

    private static var launchSourceID: String {
        get {
            UserDefaults.standard.string(
                forKey: "reader_explore_launch_source") ?? ""
        }
        set {
            UserDefaults.standard.set(
                newValue, forKey: "reader_explore_launch_source")
        }
    }

    private static var keywords: [String] {
        get {
            UserDefaults.standard.stringArray(
                forKey: "reader_explore_keywords") ?? []
        }
        set {
            UserDefaults.standard.set(
                newValue, forKey: "reader_explore_keywords")
        }
    }

    /// numberPickerRow(_:systemImage:selection:range:)
    /// （0x100500238 L357-366 域确证：ForEach(range) tag(value) +
    /// AppThemeSettingsLabel 标签）。
    private func numberPickerRow(
        _ title: String, systemImage: String,
        selection: Binding<Int>, range: ClosedRange<Int>
    ) -> some View {
        Picker(selection: selection) {
            ForEach(Array(range), id: \.self) { value in
                Text("\(value)").tag(value)
            }
        } label: {
            AppThemeSettingsLabel(title: title, systemImage: systemImage)
        }
    }

    /// launchCandidates(from:)（0x1004fcd78 closure #1/#2 域确证：
    /// filter 启用探索源 + map 候选）。
    static func launchCandidates(from sources: [BookSource])
        -> [LaunchSourceCandidate] {
        sources
            .filter { source in
                // closure #1 域确证：启用且探索开关开启。
                source.enabled && source.enabledExplore
            }
            .map { source in
                // closure #2 域确证：url 作 id，sourceName 作显示名。
                LaunchSourceCandidate(
                    id: source.bookSourceUrl,
                    name: source.bookSourceName,
                    url: source.bookSourceUrl)
            }
    }
}

/// 启动源选择器（body 0x100508ed8 L385-413 + row 0x10050a3f4 L419-432
/// 域确证：'书签设置' 导航标题 inline + '不启用' 工具栏 + checkmark
/// 选中态）。
struct ExploreLaunchSourcePicker: View {

    let candidates: [ExploreSettingsSheet.LaunchSourceCandidate]
    @Binding var selectedID: String
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    /// filtered getter（0x1005085b4 L379-383 域确证：搜索词过滤）。
    private var filtered: [ExploreSettingsSheet.LaunchSourceCandidate] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            // closure #1 域确证：名称/URL 双匹配。
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { candidate in
                        row(
                            name: candidate.name, url: candidate.url,
                            isSelected: candidate.id == selectedID)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索书源")
            .navigationTitle("书签设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // '不启用' L8146 域确证：清空选择并关闭。
                    Button("不启用") {
                        selectedID = ""
                        dismiss()
                    }
                }
            }
        }
    }

    /// row(name:url:isSelected:)（0x10050a3f4 L419-432 域确证：
    /// 名称 + URL 双行 + 选中 'checkmark' L8728）。
    private func row(
        name: String, url: String, isSelected: Bool
    ) -> some View {
        Button {
            selectedID = url
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .lineLimit(1)
                    Text(url)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
