// 原路径: ReadMain/Views/Source/SourceManageView.swift
// 证据:
//   - PGO: 277 条记录（index/task_functions.csv T-401-07 /
//     SourceManageView.swift；伪代码域 13140 行）。关键地址：
//     scheduleRebuildCache(delay:) 0x100cbd8f4 L62-69 / rebuildCacheAsync
//     0x100cbdd54 L72-140 / body 0x100cbf118 L142-174 /
//     sourceManageContent 0x100cbe8f4 L177-201 / switchSourceView(toRemote:
//     forceRefresh:) 0x100cbf468 L337-364 / quickActionBar 0x100cc4bc0
//     L366-456 / sourceRow 0x100ccceb4 L517-567 / listGroupSection
//     0x100ccc5d8 L571-581 / groupHeader 0x100ce5ddc L584-694 /
//     toolbarContent 0x100cbf828 L698-810 / selectionToolbar 0x100cbfb44
//     L813-856 / enterSelectMode 0x100ce4fbc L868-877 / selectAll
//     0x100cd7a88 L879-886 / toggleGroup 0x100ccf2e4 L888-894 /
//     selectGroupSources 0x100cd2af8 L896-899 / enableGroupSources
//     0x100cd226c L901-907 / disableGroupSources 0x100cd26dc L909-915 /
//     deleteGroupSources 0x100cd31a8 L917-925 / toggleSourceEnabled
//     0x100ce4f74 L940-944 / updateCachedSource(id:enabled:)
//     0x100cd858c 域 L947-963 / deleteSource 0x100ce510c L965-976 /
//     copySource 0x100ccdc94 L978-984 / enableSelected 0x100cd7adc
//     L986-991 / disableSelected 0x100cd7c74 L993-998 / deleteSelected
//     0x100cd858c L1000-1010 / enableAllSources 0x100cd656c L1012-1017 /
//     disableAllSources 0x100cd6814 L1019-1024 / deleteDisabledSources
//     0x100cd6b3c L1026-1033 / importFromClipboard 0x100cd5480 L1035-1046 /
//     importFromFile 0x100cd9bec L1059-1076 / getSourcesForExport
//     0x100ce27c4 L1096-1101 / getSourcesForBatchTest 0x100cc6640
//     L1103-1108 / moveSelectedToGroup 0x100cd7ca4 L1113-1124 /
//     confirmRenameGroup 0x100cbfdbc L1127-1134 / sheetContent
//     0x100cc0b40 L204-276 / isViewingRemote backing（L55）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceManageView.c
//     （13140 行）
//   - 字符串确证（位模式/IPA 指针）："配置管理"（L567 标题）/"未分组"
//     （L1233）/"checkmark"/"chevron."/"folder.fill"/"list.bullet"（图标域）/
//     "加载配置..."（L6454）/"载远程配置..." @ptr（'正在加载远程配置'）/
//     "没有配置"（L6552 空态）/"重命名分组"（L8693）/"新分组名"（Modifiers
//     L462）/"操作不可撤销。" @ptr（Modifiers L590）/"+ 导入配置文件"
//     @ptr L8755/"已启用 N 个配置"（L8899/L8905）/"已禁用 N"（L9040）/
//     "选择该分组"/"导出该分组"/"删除该分组"（L9158/9179/9329）/"新建配置"
//     （L9918）/"批量操作"（L9947）/"文本导入"（L10187）/"URL 导入"（L10266）/
//     "源/替换规则）" @ptr L10234（混合识别域）/"远程后端"（L10458）/
//     "批量测试"（L10490）/"删除已禁用"（L10719）/"doc.text.below.ecg"
//     @ptr L10857/"正在识别并导入..." @ptr L10891/"testtube.2"（L10958）/
//     "导出样式文件" @ptr L10993/"trash.fill"（L11026）/"正在导入本地书籍"
//     @ptr L11049/"导入配置文件" @ptr L11117/"件选择失败: " @ptr L11130/
//     "启用全部"/"禁用全部"（L11604/11625）/"ellipsis"（L11668）/
//     "暂无登录头信息" @ptr L12275/" 个禁用配置" @ptr L12500/
//     "剪贴板为空"（L12507）/" 个配置的分组改为「" @ptr L12555/
//     "读取文件失败：" @ptr L12564/" 个配置合并到「" @ptr L13122/
//     "本地文件导入" @ptr L2393/", forceRefresh="/"currentTotal="（诊断域）/
//     "sourceManageViewingRemote" @ptr L2806（AppStorage 键确证）/
//     "程同步完成: cached=" @ptr L4000（远端同步域）
//   - 事实：isViewingRemote 经 AppStorage("sourceManageViewingRemote")
//     键控（@ptr 确证）；rebuildCacheAsync 缓存重建（", currentTotal="/
//     ", forceRefresh=" 诊断域确证）；分组六动作（选择/导出/删除/启用/
//     禁用/重命名 位模式确证）；批量选择域（enableSelected/disableSelected/
//     deleteSelected/moveSelectedToGroup）；导入三入口（剪贴板/文件/URL）；
//     混合识别域（"源/替换规则）"）；远端同步域（"程同步完成: cached="）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 管理动作/分组/选择域: high（地址 + 位模式确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
//   - 远端同步: medium（域串确证；写回随 T-501-01 交叉）
// 还原: 2026-11-20

import SwiftUI

/// 书源管理主视图。
@MainActor
struct SourceManageView: View {

    /// 远程/本地视图切换（AppStorage "sourceManageViewingRemote" @ptr
    /// L2806 确证）。
    @AppStorage("sourceManageViewingRemote") var isViewingRemote = true

    // 列表态（rebuildCacheAsync 缓存域确证）。
    @State var groups: [SourceGroup] = []
    @State var ungrouped: [BookSource] = []
    @State var searchText: String = ""
    @State var filterOption: String = "全部"
    @State var isRefreshing = false
    @State var cacheTotal: Int = 0

    // 选择态（selectionToolbar/enterSelectMode 域确证）。
    @State var selectionMode = false
    @State var selection: Set<String> = []
    @State var selectionScope: String = ""

    // 分组/重命名/合并态（confirmRenameGroup 域确证）。
    @State var renamingGroup: String?
    @State var renameText: String = ""
    @State var showRenameDialog = false

    // Sheet 态（sourceManageSheetContent 域确证）。
    @State var activeSheet: SourceManageSheet?
    @State var showURLImport = false
    @State var importStatus: String = ""
    @State var showImporter = false
    @State var batchTestSources: [BookSource] = []
    @State var exportSources: [BookSource] = []
    @State var mergeTarget: String?
    @State var mergeSourceGroup: String = ""
    @State var showMergeSheet = false
    /// E-1c：列表 → 详情 →（编辑/测试）链（SourceDetailView 签名域）。
    @State var detailSource: BookSource?
    /// E-1c：context menu「编辑配置」直入编辑器（SourceEditView 域）。
    @State var editSource: BookSource?

    @ObservedObject var sourceService = SourceService.shared

    var body: some View {
        // 伪代码 0x100cbf118（L142-174）：List + 工具栏 + sheet 域。
        List {
            if !importStatus.isEmpty {
                Text(importStatus)
                    .font(.footnote)
                    .accessibilityIdentifier("source-manage-import-result")
            }
            if isRefreshing {
                HStack(spacing: 8.0) {
                    ProgressView()
                    Text(
                        isViewingRemote
                            ? "正在加载远程配置..." : "加载配置...")
                        .appThemeText(.caption, opacity: 0.6)
                }
            }
            // sourceManageContent（0x100cbe8f4 L177-201 域确证）。
            if groups.isEmpty && ungrouped.isEmpty {
                Section {
                    Text("没有配置")
                        .appThemeText(.caption, opacity: 0.6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24.0)
                }
            } else {
                ForEach(groups) { group in
                    listGroupSection(group)
                }
                if !ungrouped.isEmpty {
                    listGroupSection(
                        SourceGroup(name: "未分组", sources: ungrouped))
                }
            }
        }
        .accessibilityIdentifier("source-manage-list")
        .navigationTitle("配置管理")
        .searchable(text: $searchText, prompt: "搜索配置")
        .toolbar { toolbarContent }
        .sourceManageLifecycle(
            searchText: searchText, filterOption: filterOption) {
            scheduleRebuildCache(delay: 0)
        }
        .sheet(item: $activeSheet) { sheet in
            sourceManageSheetContent(sheet)
        }
        // E-1c：列表行 → 详情（详情内工具栏 → 编辑/全链测试）。
        .sheet(item: $detailSource) { source in
            NavigationStack {
                SourceDetailView(source: source)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { detailSource = nil }
                        }
                    }
            }
        }
        // E-1c：行菜单「编辑配置」直入编辑器。
        .sheet(item: $editSource) { source in
            NavigationStack {
                EditableSourceView(
                    source: source, dismissOnSave: true,
                    onSaved: { scheduleRebuildCache(delay: 0) })
            }
        }
        .sheet(isPresented: $showURLImport) {
            URLImportView(sourceService: sourceService, targetRemote: isViewingRemote) { count in
                scheduleRebuildCache(delay: 0)
                importStatus = "URL 导入成功：\(count) 条"
            }
        }
        .sheet(isPresented: $showMergeSheet) {
            if let target = mergeTarget {
                SourceGroupMergeSheet(
                    sourceGroup: mergeSourceGroup, targetGroup: target)
            }
        }
        .copiedFileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .plainText]
        ) { result in
            handleFileImport(result)
        }
        .task {
            await loadSourcesForCurrentMode()
        }
    }

    // MARK: 缓存重建

    /// scheduleRebuildCache(delay:)（0x100cbd8f4 L62-69）：延时派发重建。
    func scheduleRebuildCache(delay: UInt64) {
        Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            await rebuildCacheAsync()
        }
    }

    /// rebuildCacheAsync（0x100cbdd54 L72-140）：重算分组缓存
    ///（", currentTotal=" 诊断域确证）。
    func rebuildCacheAsync() async {
        let all = sourceService.bookSources
        var buckets: [String: [BookSource]] = [:]
        var ungroupedSources: [BookSource] = []
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = all.filter { source in
            let matchesQuery =
                query.isEmpty
                || source.bookSourceName.localizedCaseInsensitiveContains(
                    query)
                || source.bookSourceUrl.localizedCaseInsensitiveContains(query)
            let matchesFilter =
                filterOption == "全部"
                || (filterOption == "启用" && source.enabled)
                || (filterOption == "禁用" && !source.enabled)
            let matchesStorage = isViewingRemote ? source.storageKind == .remote : source.storageKind != .remote
            return matchesQuery && matchesFilter && matchesStorage
        }
        for source in filtered {
            let group = source.bookSourceGroup ?? "未分组"
            if group == "未分组" {
                ungroupedSources.append(source)
            } else {
                buckets[group, default: []].append(source)
            }
        }
        let rebuilt = buckets
            .map { SourceGroup(name: $0.key, sources: $0.value) }
            .sorted { $0.name < $1.name }
        await MainActor.run {
            groups = rebuilt
            ungrouped = ungroupedSources
            cacheTotal = filtered.count
        }
        Logger.log(
            "本地文件导入 cached=\(filtered.count), currentTotal=\(all.count)",
            level: .info)
    }

    // MARK: 视图切换

    /// switchSourceView(toRemote:forceRefresh:)（0x100cbf468 L337-364）。
    func switchSourceView(
        toRemote: Bool, forceRefresh: Bool
    ) {
        isViewingRemote = toRemote
        if forceRefresh {
            Task {
                await loadSourcesForCurrentMode()
            }
        }
        scheduleRebuildCache(delay: 0)
    }

    /// loadSourcesForCurrentMode（0x100cc3a18 L278-298；远端同步域
    /// "程同步完成: cached=" 确证）。
    func loadSourcesForCurrentMode() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if isViewingRemote {
            await sourceService.fetchRemoteSourcesOnly(forceRefresh: true)
        } else {
            await sourceService.loadLocalSources()
        }
        await rebuildCacheAsync()
    }

}
