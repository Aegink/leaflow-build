// 原始归属: ReadMain/Views/Source/SourceManageView.swift
// 分组、工具栏与弹层，沿用各成员伪代码地址。
import SwiftUI

extension SourceManageView {
    // MARK: 分组段

    /// listGroupSection（0x100ccc5d8 L571-581）。
    @ViewBuilder
    func listGroupSection(_ group: SourceGroup) -> some View {
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
    func groupHeader(_ group: SourceGroup) -> some View {
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
    func sourceRow(_ source: BookSource) -> some View {
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
    var toolbarContent: some ToolbarContent {
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
                NavigationLink("解析设置") {
                    SourceParserSettingsView()
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
                    activeSheet = .importOptions
                } label: {
                    Label("文本导入", systemImage: "doc.on.clipboard")
                }
                Button {
                    showURLImport = true
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
            .accessibilityIdentifier("source-manage-menu")
        }
    }

    /// selectionToolbar（0x100cbfb44 L813-856）。
    @ToolbarContentBuilder
    var selectionToolbar: some ToolbarContent {
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
    var quickActionBar: some View {
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
    func sourceManageSheetContent(_ sheet: SourceManageSheet)
        -> some View
    {
        switch sheet {
        case .importOptions:
            ImportSourceView(sourceService: sourceService, targetRemote: isViewingRemote) {
                scheduleRebuildCache(delay: 0)
            }
        case .export:
            ExportSourceView(sources: exportSources)
        case .help:
            SourceHelpSheet()
        case .batchTest:
            NavigationStack {
                BatchTestView(sources: batchTestSources)
            }
        }
    }

}
