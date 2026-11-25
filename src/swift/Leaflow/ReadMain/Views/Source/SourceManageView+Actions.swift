// 原始归属: ReadMain/Views/Source/SourceManageView.swift
// 选择/分组/导入动作，沿用各成员伪代码地址。
import SwiftUI

extension SourceManageView {
    // MARK: 选择域

    /// enterSelectMode(String)（0x100ce4fbc L868-877）。
    func enterSelectMode(_ scope: String) {
        selectionMode = true
        selectionScope = scope
        selection = []
    }

    /// toggleSelection(String)（0x100ce4f98 L860-866）。
    func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// selectAll（0x100cd7a88 L879-886）。
    func selectAll() {
        let all =
            (groups.flatMap(\.sources) + ungrouped).map(\.bookSourceUrl)
        selection = Set(all)
    }

    /// toggleGroup(String)（0x100ccf2e4 L888-894）。
    func toggleGroup(_ name: String) {
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
    func selectGroupSources(_ group: SourceGroup) {
        selection.formUnion(group.sources.map(\.bookSourceUrl))
        selectionScope = group.name
    }

    /// enableGroupSources（0x100cd226c L901-907）。
    func enableGroupSources(_ group: SourceGroup) {
        _ = sourceService.batchToggleSources(
            urls: Set(group.sources.map(\.bookSourceUrl)), enable: true)
        updateCachedSource(id: group.name, enabled: true)
    }

    /// disableGroupSources（0x100cd26dc L909-915）。
    func disableGroupSources(_ group: SourceGroup) {
        _ = sourceService.batchToggleSources(
            urls: Set(group.sources.map(\.bookSourceUrl)), enable: false)
        updateCachedSource(id: group.name, enabled: false)
    }

    /// deleteGroupSources（0x100cd31a8 L917-925；"操作不可撤销。" 域）。
    func deleteGroupSources(_ group: SourceGroup) {
        for source in group.sources {
            _ = sourceService.updateSource(
                oldUrl: source.bookSourceUrl, source: source)
        }
        scheduleRebuildCache(delay: 0)
    }

    // MARK: 单源动作

    /// toggleSourceEnabled（0x100ce4f74 L940-944 + async 闭包确证）。
    func toggleSourceEnabled(_ source: BookSource) {
        Task {
            _ = sourceService.batchToggleSources(
                urls: [source.bookSourceUrl], enable: !source.enabled)
            await MainActor.run {
                scheduleRebuildCache(delay: 0)
            }
        }
    }

    /// updateCachedSource(id:enabled:)（0x100cd858c 域 L947-963）。
    func updateCachedSource(id: String, enabled: Bool) {
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
    func deleteSource(_ source: BookSource) {
        var disabled = source
        disabled.enabled = false
        _ = sourceService.updateSource(
            oldUrl: source.bookSourceUrl, source: disabled)
        scheduleRebuildCache(delay: 0)
    }

    /// copySource（0x100ccdc94 L978-984）。
    func copySource(_ source: BookSource) {
        guard
            let data = try? JSONEncoder().encode([source]),
            let json = String(data: data, encoding: .utf8)
        else { return }
        UIPasteboard.general.string = json
        importStatus = "已复制"
    }

    // MARK: 批量动作

    /// enableSelected（0x100cd7adc L986-991）。
    func enableSelected() {
        _ = sourceService.batchToggleSources(urls: selection, enable: true)
        selection = []
        scheduleRebuildCache(delay: 0)
    }

    /// disableSelected（0x100cd7c74 L993-998）。
    func disableSelected() {
        _ = sourceService.batchToggleSources(urls: selection, enable: false)
        selection = []
        scheduleRebuildCache(delay: 0)
    }

    /// deleteSelected（0x100cd858c L1000-1010）。
    func deleteSelected() {
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
    func moveSelectedToGroup() {
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
    func enableAllSources() {
        _ = sourceService.batchToggleSources(
            urls: Set(sourceService.bookSources.map(\.bookSourceUrl)),
            enable: true)
        scheduleRebuildCache(delay: 0)
    }

    /// disableAllSources（0x100cd6814 L1019-1024）。
    func disableAllSources() {
        _ = sourceService.batchToggleSources(
            urls: Set(sourceService.bookSources.map(\.bookSourceUrl)),
            enable: false)
        scheduleRebuildCache(delay: 0)
    }

    /// deleteDisabledSources（0x100cd6b3c L1026-1033；" 个禁用配置" @ptr）。
    func deleteDisabledSources() {
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
    func importFromClipboard() {
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
    func importSourceText(_ text: String) {
        importStatus = "正在识别并导入..."
        Task {
            let count = await sourceService.importSourcesAsync(
                from: text, storageKind: isViewingRemote ? .remote : .local)
            importStatus = count >= 0 ? "导入成功：\(count) 条新增配置"
                : sourceService.lastImportError ?? "导入失败"
            scheduleRebuildCache(delay: 0)
        }
    }

    /// importFromFile（0x100cd9bec L1059-1076；"读取文件失败：" @ptr）。
    func importFromFile(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            importSourceText(text)
        } catch {
            importStatus = "读取文件失败：\(error.localizedDescription)"
        }
    }

    /// handleFileImport（pgo_only；"件选择失败: " @ptr 确证）。
    func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importFromFile(url)
        case .failure(let error):
            importStatus = "件选择失败: \(error.localizedDescription)"
        }
    }

    // MARK: 导出/重命名

    /// getSourcesForExport（0x100ce27c4 L1096-1101）。
    func getSourcesForExport() -> [BookSource] {
        if !selection.isEmpty {
            return sourceService.bookSources.filter {
                selection.contains($0.bookSourceUrl)
            }
        }
        return sourceService.bookSources
    }

    /// getSourcesForBatchTest（0x100cc6640 L1103-1108）。
    func getSourcesForBatchTest() -> [BookSource] {
        if !selection.isEmpty {
            return sourceService.bookSources.filter {
                selection.contains($0.bookSourceUrl) && $0.enabled
            }
        }
        return sourceService.bookSources.filter(\.enabled)
    }

    /// confirmRenameGroup（0x100cbfdbc L1127-1134；" 个配置合并到「" 域）。
    func confirmRenameGroup() {
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
