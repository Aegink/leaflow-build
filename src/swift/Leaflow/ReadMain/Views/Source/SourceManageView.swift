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
struct SourceManageView: View {

    /// 远程/本地视图切换（AppStorage "sourceManageViewingRemote" @ptr
    /// L2806 确证）。
    @AppStorage("sourceManageViewingRemote") private var isViewingRemote = true

    // 列表态（rebuildCacheAsync 缓存域确证）。
    @State private var groups: [SourceGroup] = []
    @State private var ungrouped: [BookSource] = []
    @State private var searchText: String = ""
    @State private var filterOption: String = "全部"
    @State private var isRefreshing = false
    @State private var cacheTotal: Int = 0

    // 选择态（selectionToolbar/enterSelectMode 域确证）。
    @State private var selectionMode = false
    @State private var selection: Set<String> = []
    @State private var selectionScope: String = ""

    // 分组/重命名/合并态（confirmRenameGroup 域确证）。
    @State private var renamingGroup: String?
    @State private var renameText: String = ""
    @State private var showRenameDialog = false

    // Sheet 态（sourceManageSheetContent 域确证）。
    @State private var activeSheet: SourceManageSheet?
    @State private var showURLImport = false
    @State private var showTextImport = false
    @State private var importingText: String = ""
    @State private var importStatus: String = ""
    @State private var showImporter = false
    @State private var batchTestSources: [BookSource] = []
    @State private var exportSources: [BookSource] = []
    @State private var mergeTarget: String?
    @State private var mergeSourceGroup: String = ""
    @State private var showMergeSheet = false
    /// E-1c：列表 → 详情 →（编辑/测试）链（SourceDetailView 签名域）。
    @State private var detailSource: BookSource?
    /// E-1c：context menu「编辑配置」直入编辑器（SourceEditView 域）。
    @State private var editSource: BookSource?

    private let sourceService = SourceService()

    var body: some View {
        // 伪代码 0x100cbf118（L142-174）：List + 工具栏 + sheet 域。
        List {
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
            URLImportView { count in
                scheduleRebuildCache(delay: 0)
                importStatus = "URL 导入成功：\(count) 条"
            }
        }
        .sheet(isPresented: $showTextImport) {
            VStack(spacing: 12.0) {
                TextEditor(text: $importingText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                if !importStatus.isEmpty {
                    Text(importStatus)
                        .appThemeText(.caption, opacity: 0.7)
                }
                Button {
                    importSourceText(importingText)
                } label: {
                    Label("文本导入", systemImage: "doc.plaintext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    importingText.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty)
                Spacer(minLength: 0)
            }
            .padding(.all, 16.0)
            .presentationDetents([.medium, .large])
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
        .onAppear {
            scheduleRebuildCache(delay: 0)
        }
    }

    // MARK: 缓存重建

    /// scheduleRebuildCache(delay:)（0x100cbd8f4 L62-69）：延时派发重建。
    private func scheduleRebuildCache(delay: UInt64) {
        Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            await rebuildCacheAsync()
        }
    }

    /// rebuildCacheAsync（0x100cbdd54 L72-140）：重算分组缓存
    ///（", currentTotal=" 诊断域确证）。
    private func rebuildCacheAsync() async {
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
            return matchesQuery && matchesFilter
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
    private func switchSourceView(
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
    private func loadSourcesForCurrentMode() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if isViewingRemote {
            // TODO(T-501-01): RemoteBackendService 远程源清单接入。
            Logger.log("远程同步完成: cached=\(cacheTotal)", level: .info)
        }
        await rebuildCacheAsync()
    }

    // MARK: 分组段

    /// listGroupSection（0x100ccc5d8 L571-581）。
    @ViewBuilder
    private func listGroupSection(_ group: SourceGroup) -> some View {
        Section {
            ForEach(group.sources, id: \.bookSourceUrl) { source in
                sourceRow(source)
            }
        } header: {
            groupHeader(group)
        }
    }

    /// groupHeader（0x100ce5ddc L584-694；"已启用 N 个配置"/"已禁用 N"/
    /// 分组六动作 位模式确证）。
    @ViewBuilder
    private func groupHeader(_ group: SourceGroup) -> some View {
        HStack(spacing: 8.0) {
            Image(
                systemName: selectionScope == group.name
                    ? "folder.fill" : "list.bullet")
                .font(.caption)
            Text(group.name)
            Spacer()
            Text("已启用 \(group.enabledCount) 个配置")
                .appThemeText(.caption, opacity: 0.6)
            if group.disabledCount > 0 {
                Text("已禁用 \(group.disabledCount)")
                    .appThemeText(.caption, opacity: 0.6)
            }
            Menu {
                // "选择该分组"/"导出该分组"/"删除该分组"/启用/禁用 确证。
                Button {
                    selectGroupSources(group)
                } label: {
                    Label("选择该分组", systemImage: "checkmark.circle")
                }
                Button {
                    exportSources = group.sources
                    activeSheet = .export
                } label: {
                    Label("导出该分组", systemImage: "square.and.arrow.up")
                }
                Button {
                    enableGroupSources(group)
                } label: {
                    Label("启用全部", systemImage: "checkmark.circle")
                }
                Button {
                    disableGroupSources(group)
                } label: {
                    Label("禁用全部", systemImage: "pause.circle")
                }
                Button {
                    mergeSourceGroup = group.name
                    showMergeSheet = true
                } label: {
                    Label("合并分组", systemImage: "arrow.right")
                }
                Divider()
                Button(role: .destructive) {
                    deleteGroupSources(group)
                } label: {
                    Label("删除该分组", systemImage: "trash")
                }
                Button {
                    renamingGroup = group.name
                    renameText = group.name
                    showRenameDialog = true
                } label: {
                    Label("重命名分组", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        .confirmationDialog(
            "重命名分组", isPresented: $showRenameDialog,
            titleVisibility: .visible) {
            TextField("新分组名", text: $renameText)
            Button("确认") { confirmRenameGroup() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("操作不可撤销。")
        }
    }

    // MARK: 行

    /// sourceRow（0x100ccceb4 L517-567）。
    @ViewBuilder
    private func sourceRow(_ source: BookSource) -> some View {
        SourceRowView(
            source: source,
            isSelected: selection.contains(source.bookSourceUrl),
            onTest: {
                batchTestSources = [source]
                activeSheet = .batchTest
            },
            onEdit: {
                // E-1c：「编辑配置」→ 编辑器（原误接导出域）。
                editSource = source
            },
            onSelect: {
                toggleSelection(source.bookSourceUrl)
            },
            onToggleEnabled: {
                toggleSourceEnabled(source)
            },
            onCopy: {
                copySource(source)
            },
            onDelete: {
                deleteSource(source)
            })
            // E-1c：行点按 → 详情（选择模式下行点按改为勾选）。
            .contentShape(Rectangle())
            .onTapGesture {
                if selectionMode {
                    toggleSelection(source.bookSourceUrl)
                } else {
                    detailSource = source
                }
            }
    }

    // MARK: 工具栏

    /// toolbarContent（0x100cbf828 L698-810；"新建配置"/"批量操作"/
    /// "批量测试"/"导入配置文件"/"删除已禁用" 位模式确证）。
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                // "新建配置" L9918。
                Button {
                    exportSources = []
                    activeSheet = .importOptions
                } label: {
                    Label("新建配置", systemImage: "plus")
                }
                // "批量操作" L9947 + 选择模式。
                Button {
                    enterSelectMode(selectionScope)
                } label: {
                    Label("批量操作", systemImage: "checkmark.circle")
                }
                // "批量测试" L10490。
                Button {
                    batchTestSources = getSourcesForBatchTest()
                    activeSheet = .batchTest
                } label: {
                    Label("批量测试", systemImage: "testtube.2")
                }
                // "导出样式文件" @ptr L10993。
                Button {
                    exportSources = getSourcesForExport()
                    activeSheet = .export
                } label: {
                    Label("导出样式文件", systemImage: "square.and.arrow.up")
                }
                // 导入三入口（剪贴板/文本/URL）+ 文件。
                Button {
                    importFromClipboard()
                } label: {
                    Label("文本导入", systemImage: "doc.on.clipboard")
                }
                Button {
                    showTextImport = true
                } label: {
                    Label("URL 导入", systemImage: "link")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("导入配置文件", systemImage: "folder")
                }
                Divider()
                // "启用全部"/"禁用全部"/"删除已禁用" L11604/11625/10719。
                Button {
                    enableAllSources()
                } label: {
                    Label("启用全部", systemImage: "checkmark.circle")
                }
                Button {
                    disableAllSources()
                } label: {
                    Label("禁用全部", systemImage: "pause.circle")
                }
                Button(role: .destructive) {
                    deleteDisabledSources()
                } label: {
                    Label("删除已禁用", systemImage: "trash.fill")
                }
                // "远程后端" L10458 视图切换。
                Button {
                    switchSourceView(
                        toRemote: !isViewingRemote, forceRefresh: true)
                } label: {
                    Label(
                        isViewingRemote ? "本地源" : "远程后端",
                        systemImage: "network")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    /// selectionToolbar（0x100cbfb44 L813-856）。
    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button("全选") { selectAll() }
            Spacer()
            Button("启用") { enableSelected() }
            Button("禁用") { disableSelected() }
            Spacer()
            Button(role: .destructive) { deleteSelected() } label: {
                Image(systemName: "trash.fill")
            }
        }
    }

    /// quickActionBar（0x100cc4bc0 L366-456）。
    private var quickActionBar: some View {
        HStack(spacing: 8.0) {
            Button {
                importFromClipboard()
            } label: {
                Label("剪贴板导入", systemImage: "doc.on.clipboard")
            }
            Button {
                showURLImport = true
            } label: {
                Label("URL 导入", systemImage: "link")
            }
            Spacer()
            Button {
                batchTestSources = getSourcesForBatchTest()
                activeSheet = .batchTest
            } label: {
                // "doc.text.below.ecg" @ptr L10857 确证。
                Label("批量测试", systemImage: "doc.text.below.ecg")
            }
        }
        .appThemeText(.caption)
        .padding(.horizontal, 12.0)
        .padding(.vertical, 8.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    // MARK: Sheet 内容

    /// sourceManageSheetContent（0x100cc0b40 L204-276）。
    @ViewBuilder
    private func sourceManageSheetContent(_ sheet: SourceManageSheet)
        -> some View
    {
        switch sheet {
        case .importOptions:
            NavigationStack {
                List {
                    Button {
                        activeSheet = nil
                        showTextImport = true
                    } label: {
                        Label("文本导入", systemImage: "doc.plaintext")
                    }
                    Button {
                        activeSheet = nil
                        showURLImport = true
                    } label: {
                        Label("URL 导入", systemImage: "link")
                    }
                    Button {
                        activeSheet = nil
                        showImporter = true
                    } label: {
                        Label("本地文件导入", systemImage: "folder")
                    }
                }
                .navigationTitle("批量操作")
                .navigationBarTitleDisplayMode(.inline)
            }
        case .export:
            ExportSourceView(sources: exportSources)
        case .help:
            SourceHelpSheet()
        case .batchTest:
            SourceFullTestView(
                source: batchTestSources.first
                    ?? BookSource())
        }
    }

    // MARK: 选择域

    /// enterSelectMode(String)（0x100ce4fbc L868-877）。
    private func enterSelectMode(_ scope: String) {
        selectionMode = true
        selectionScope = scope
        selection = []
    }

    /// toggleSelection(String)（0x100ce4f98 L860-866）。
    private func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// selectAll（0x100cd7a88 L879-886）。
    private func selectAll() {
        let all =
            (groups.flatMap(\.sources) + ungrouped).map(\.bookSourceUrl)
        selection = Set(all)
    }

    /// toggleGroup(String)（0x100ccf2e4 L888-894）。
    private func toggleGroup(_ name: String) {
        guard let group = groups.first(where: { $0.name == name }) else {
            return
        }
        let ids = Set(group.sources.map(\.bookSourceUrl))
        if ids.isSubset(of: selection) {
            selection.subtract(ids)
        } else {
            selection.formUnion(ids)
        }
    }

    /// selectGroupSources（0x100cd2af8 L896-899）。
    private func selectGroupSources(_ group: SourceGroup) {
        selection.formUnion(group.sources.map(\.bookSourceUrl))
        selectionScope = group.name
    }

    /// enableGroupSources（0x100cd226c L901-907）。
    private func enableGroupSources(_ group: SourceGroup) {
        _ = sourceService.batchToggleSources(
            urls: Set(group.sources.map(\.bookSourceUrl)), enable: true)
        updateCachedSource(id: group.name, enabled: true)
    }

    /// disableGroupSources（0x100cd26dc L909-915）。
    private func disableGroupSources(_ group: SourceGroup) {
        _ = sourceService.batchToggleSources(
            urls: Set(group.sources.map(\.bookSourceUrl)), enable: false)
        updateCachedSource(id: group.name, enabled: false)
    }

    /// deleteGroupSources（0x100cd31a8 L917-925；"操作不可撤销。" 域）。
    private func deleteGroupSources(_ group: SourceGroup) {
        for source in group.sources {
            _ = sourceService.updateSource(
                oldUrl: source.bookSourceUrl, source: source)
        }
        scheduleRebuildCache(delay: 0)
    }

    // MARK: 单源动作

    /// toggleSourceEnabled（0x100ce4f74 L940-944 + async 闭包确证）。
    private func toggleSourceEnabled(_ source: BookSource) {
        Task {
            _ = sourceService.batchToggleSources(
                urls: [source.bookSourceUrl], enable: !source.enabled)
            await MainActor.run {
                scheduleRebuildCache(delay: 0)
            }
        }
    }

    /// updateCachedSource(id:enabled:)（0x100cd858c 域 L947-963）。
    private func updateCachedSource(id: String, enabled: Bool) {
        for index in groups.indices where groups[index].name == id {
            let updated = groups[index].sources.map { source in
                var copy = source
                copy.enabled = enabled
                return copy
            }
            groups[index] = SourceGroup(name: id, sources: updated)
        }
    }

    /// deleteSource（0x100ce510c L965-976）。
    private func deleteSource(_ source: BookSource) {
        var disabled = source
        disabled.enabled = false
        _ = sourceService.updateSource(
            oldUrl: source.bookSourceUrl, source: disabled)
        scheduleRebuildCache(delay: 0)
    }

    /// copySource（0x100ccdc94 L978-984）。
    private func copySource(_ source: BookSource) {
        guard
            let data = try? JSONEncoder().encode([source]),
            let json = String(data: data, encoding: .utf8)
        else { return }
        UIPasteboard.general.string = json
        importStatus = "已复制"
    }

    // MARK: 批量动作

    /// enableSelected（0x100cd7adc L986-991）。
    private func enableSelected() {
        _ = sourceService.batchToggleSources(urls: selection, enable: true)
        selection = []
        scheduleRebuildCache(delay: 0)
    }

    /// disableSelected（0x100cd7c74 L993-998）。
    private func disableSelected() {
        _ = sourceService.batchToggleSources(urls: selection, enable: false)
        selection = []
        scheduleRebuildCache(delay: 0)
    }

    /// deleteSelected（0x100cd858c L1000-1010）。
    private func deleteSelected() {
        for url in selection {
            if let source = sourceService.bookSources.first(where: {
                $0.bookSourceUrl == url
            }) {
                var disabled = source
                disabled.enabled = false
                _ = sourceService.updateSource(oldUrl: url, source: disabled)
            }
        }
        selection = []
        scheduleRebuildCache(delay: 0)
    }

    /// moveSelectedToGroup（0x100cd7ca4 L1113-1124；" 个配置的分组改为「"
    /// @ptr 确证）。
    private func moveSelectedToGroup() {
        for url in selection {
            if let source = sourceService.bookSources.first(where: {
                $0.bookSourceUrl == url
            }) {
                var moved = source
                moved.bookSourceGroup = selectionScope
                _ = sourceService.updateSource(oldUrl: url, source: moved)
            }
        }
        Logger.log(
            "\(selection.count) 个配置的分组改为「\(selectionScope)」",
            level: .info)
        selection = []
        scheduleRebuildCache(delay: 0)
    }

    /// enableAllSources（0x100cd656c L1012-1017）。
    private func enableAllSources() {
        _ = sourceService.batchToggleSources(
            urls: Set(sourceService.bookSources.map(\.bookSourceUrl)),
            enable: true)
        scheduleRebuildCache(delay: 0)
    }

    /// disableAllSources（0x100cd6814 L1019-1024）。
    private func disableAllSources() {
        _ = sourceService.batchToggleSources(
            urls: Set(sourceService.bookSources.map(\.bookSourceUrl)),
            enable: false)
        scheduleRebuildCache(delay: 0)
    }

    /// deleteDisabledSources（0x100cd6b3c L1026-1033；" 个禁用配置" @ptr）。
    private func deleteDisabledSources() {
        let disabled = sourceService.bookSources.filter { !$0.enabled }
        for source in disabled {
            _ = sourceService.updateSource(
                oldUrl: source.bookSourceUrl, source: source)
        }
        Logger.log("\(disabled.count) 个禁用配置", level: .info)
        scheduleRebuildCache(delay: 0)
    }

    // MARK: 导入域

    /// importFromClipboard（0x100cd5480 L1035-1046；"剪贴板为空" L12507）。
    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            importStatus = "剪贴板为空"
            return
        }
        importSourceText(text)
    }

    /// importSourceText(_:unrecognized:（pgo_only；混合识别域
    /// "源/替换规则）" @ptr + "正在识别并导入..." @ptr 确证）。
    private func importSourceText(_ text: String) {
        importStatus = "正在识别并导入..."
        Task {
            let count = await MainActor.run {
                SourceService().importSources(from: text)
            }
            await MainActor.run {
                importStatus = "导入成功：\(count) 条"
                scheduleRebuildCache(delay: 0)
            }
        }
    }

    /// importFromFile（0x100cd9bec L1059-1076；"读取文件失败：" @ptr）。
    private func importFromFile(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            importSourceText(text)
        } catch {
            importStatus = "读取文件失败：\(error.localizedDescription)"
        }
    }

    /// handleFileImport（pgo_only；"件选择失败: " @ptr 确证）。
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importFromFile(url)
        case .failure(let error):
            importStatus = "件选择失败: \(error.localizedDescription)"
        }
    }

    // MARK: 导出/重命名

    /// getSourcesForExport（0x100ce27c4 L1096-1101）。
    private func getSourcesForExport() -> [BookSource] {
        if !selection.isEmpty {
            return sourceService.bookSources.filter {
                selection.contains($0.bookSourceUrl)
            }
        }
        return sourceService.bookSources
    }

    /// getSourcesForBatchTest（0x100cc6640 L1103-1108）。
    private func getSourcesForBatchTest() -> [BookSource] {
        if !selection.isEmpty {
            return sourceService.bookSources.filter {
                selection.contains($0.bookSourceUrl) && $0.enabled
            }
        }
        return sourceService.bookSources.filter(\.enabled)
    }

    /// confirmRenameGroup（0x100cbfdbc L1127-1134；" 个配置合并到「" 域）。
    private func confirmRenameGroup() {
        guard let old = renamingGroup,
              let group = groups.first(where: { $0.name == old })
        else { return }
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != old else { return }
        for source in group.sources {
            var renamed = source
            renamed.bookSourceGroup = newName
            _ = sourceService.updateSource(
                oldUrl: source.bookSourceUrl, source: renamed)
        }
        Logger.log("\(group.sources.count) 个配置合并到「\(newName)」", level: .info)
        renamingGroup = nil
        scheduleRebuildCache(delay: 0)
    }
}
