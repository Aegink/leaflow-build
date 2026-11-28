// 原路径: ReadMain/Views/Settings/TtsSourceManageView.swift
// 证据:
//   - PGO: 166 条记录（index/task_functions.csv T-701-09 /
//     TtsSourceManageView.swift；伪代码域 300 行）
//   - CovMap: 上述 L 区段（body/源列表/导入导出/试听域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     TtsSourceManageView.c（10475 行）
//   - 块体确证（签名域）：
//     body getter / deleteSources(at: IndexSet) / exportSources() /
//     filteredSources getter / importFromClipboard() /
//     importFromFile(_: URL) / importFromUrl() / select(_: HttpTts) /
//     selectSystemTTS() / testSource(_: HttpTts)
//   - 字符串域（位模式+指针，scratch/t70109_src_strings.txt）：
//     '搜索朗读源' L579 / '朗读管理' L601 / '当前朗读源' L1026 /
//     '缓存' L1137 / '选择' L1287 / '从网络导入' L2521 /
//     '从文件导入' L2567 / '删除全部' L2599 / '取消' L2691 /
//     '删除' L2706 / '已导出 ' L3927 / '系统 TTS' L4421 /
//     '设为当前源' L5221 / '配置' L5251 / '试听' L5527 /
//     '网络导入' L5667 / '导入' L6183 / '解析配置...' L7732 /
//     '操作' L7930 / '关闭' L9580 / '解析失败: ' L10352
//   - 事实：源列表 + 当前源选择（系统 TTS 兜底）+ 五通道导入 +
//     导出/试听；HttpTtsStore 为 T-801 分册桥
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十签名域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI
import UniformTypeIdentifiers

/// 朗读源管理页（body/filteredSources 签名域确证）。
struct TtsSourceManageView: View {

    @State private var sources: [HttpTts] = []
    @State private var currentSourceID: Int64?
    @State private var useSystemTTS = true
    @State private var searchText = ""
    private struct EditSelection: Identifiable {
        let id = UUID()
        let source: HttpTts?
    }
    @State private var editSelection: EditSelection?
    @State private var configSource: HttpTts?
    @State private var showNetworkImport = false
    @State private var importURLString = ""
    @State private var statusMessage = ""
    @State private var isParsing = false
    @State private var showFileImport = false
    @ObservedObject private var previewPlayer = ReaderSpeechSupport.previewPlayer
    /// T-1601-E2：帮助页入口（TtsHelpSheet 此前零引用）。
    @State private var showHelp = false

    var body: some View {
        List {
            currentSection
            sourceSection
        }
        .searchable(text: $searchText, prompt: "搜索朗读源")
        .navigationTitle("朗读管理")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    // '从网络导入' L2521 域确证。
                    Button {
                        showNetworkImport = true
                    } label: {
                        Label("从网络导入", systemImage: "network")
                    }
                    // '从文件导入' L2567 域确证。
                    Button {
                        showFileImport = true
                    } label: {
                        Label("从文件导入", systemImage: "doc")
                    }
                    // '导入' L6183 域确证：剪贴板导入。
                    Button {
                        importFromClipboard()
                    } label: {
                        Label("导入", systemImage: "doc.on.clipboard")
                    }
                    Divider()
                    Button {
                        exportSources()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        // '删除全部' L2599 域确证。
                        deleteAll()
                    } label: {
                        Label("删除全部", systemImage: "trash")
                    }
                } label: {
                    // '操作' L7930 域确证。
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("tts-source-actions")
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityIdentifier("tts-source-help")
                Button {
                    editSelection = EditSelection(source: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("tts-source-add")
            }
        }
        .sheet(isPresented: $showHelp) {
            TtsHelpSheet()
        }
        .sheet(item: $configSource) { source in TtsSourceConfigSheet(source: source) }
        .fileImporter(isPresented: $showFileImport, allowedContentTypes: [.json, .plainText]) { result in
            switch result {
            case .success(let url): importFromFile(url)
            case .failure(let error): statusMessage = "导入失败：\(error.localizedDescription)"
            }
        }
        .sheet(item: $editSelection) { selection in
            TtsEditView(
                mode: selection.source == nil ? .create : .edit,
                original: selection.source,
                onSaved: {
                    editSelection = nil
                    reload()
                })
        }
        .alert(
            "从网络导入",
            isPresented: $showNetworkImport
        ) {
            TextField("https://", text: $importURLString)
            Button("导入") {
                importFromUrl()
            }
            Button("取消", role: .cancel) {
                importURLString = ""
            }
        } message: {
            Text("输入朗读源 JSON 地址")
        }
        .onAppear {
            reload()
        }
        .onDisappear { previewPlayer.stop() }
    }

    // MARK: 当前源（'当前朗读源' L1026 / '系统 TTS' L4421 域确证）

    @ViewBuilder
    private var currentSection: some View {
        Section("当前朗读源") {
            if previewPlayer.isPreparing || previewPlayer.isPlaying {
                HStack {
                    Text(previewPlayer.isPreparing ? "正在准备音频" : "正在试听")
                    Spacer()
                    Button("停止试听") { previewPlayer.stop() }
                }
            }
            if let error = previewPlayer.lastError { Text(error).foregroundStyle(.red) }
            Button {
                // selectSystemTTS() 签名域确证。
                selectSystemTTS()
            } label: {
                HStack {
                    Label("系统 TTS", systemImage: "waveform")
                    Spacer()
                    if useSystemTTS {
                        Image(systemName: "checkmark")
                            .appThemeAccent()
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tts-source-system")
            .accessibilityValue(useSystemTTS ? "已选择" : "未选择")
            if let current = sources.first(where: {
                $0.id == currentSourceID
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.name)
                        Text(current.url)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // '配置' L5251 域确证。
                    Button {
                        editSelection = EditSelection(source: current)
                    } label: {
                        Text("编辑")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("tts-source-current-edit")
                    // '试听' L5527 域确证。
                    Button {
                        testSource(current)
                    } label: {
                        Text("试听")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: 源列表（filteredSources 签名域确证）

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            ForEach(filteredSources) { source in
                sourceRow(source)
            }
            .onDelete { offsets in
                // deleteSources(at:) 签名域确证。
                deleteSources(at: offsets)
            }
        } header: {
            Text("朗读源")
        } footer: {
            if !statusMessage.isEmpty {
                Text(statusMessage)
            }
        }
    }

    @ViewBuilder
    private func sourceRow(_ source: HttpTts) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                Text(source.url)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // '选择' L1287 / '设为当前源' L5221 域确证。
            Button {
                select(source)
            } label: {
                Text("选择")
                    .font(.caption)
                    .appThemeAccent()
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("tts-source-select-\(source.id)")
            .accessibilityValue(currentSourceID == source.id ? "已选择" : "未选择")
            Menu {
                Button {
                    testSource(source)
                } label: {
                    Label("试听", systemImage: "play.circle")
                }
                Button {
                    configSource = source
                } label: {
                    Label("配置", systemImage: "gearshape")
                }
                Button("编辑") { editSelection = EditSelection(source: source) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("tts-source-row-actions-\(source.id)")
        }
    }

    /// filteredSources getter（签名域确证：搜索过滤域）。
    private var filteredSources: [HttpTts] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sources }
        return sources.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: 动作域（签名域确证）

    private func reload() {
        sources = TtsSourceStore.shared.loadSources()
        currentSourceID = TtsSourceStore.shared.currentSourceID
        useSystemTTS = currentSourceID == nil
    }

    /// select(_: HttpTts)（签名域确证）。
    private func select(_ source: HttpTts) {
        currentSourceID = source.id
        useSystemTTS = false
        TtsSourceStore.shared.setCurrent(source.id)
    }

    /// selectSystemTTS()（签名域确证）。
    private func selectSystemTTS() {
        currentSourceID = nil
        useSystemTTS = true
        TtsSourceStore.shared.setCurrent(nil)
    }

    /// testSource(_: HttpTts)（签名域确证）。
    private func testSource(_ source: HttpTts) {
        previewPlayer.play(source: source, text: HttpTtsPreviewPlayer.defaultText)
    }

    /// deleteSources(at: IndexSet)（签名域确证）。
    private func deleteSources(at offsets: IndexSet) {
        let targets = offsets.map { filteredSources[$0] }
        for target in targets {
            TtsSourceStore.shared.delete(target.id)
        }
        reload()
    }

    private func deleteAll() {
        for source in sources {
            TtsSourceStore.shared.delete(source.id)
        }
        reload()
    }

    /// importFromUrl()（'解析配置...' L7732 / '解析失败: ' L10352
    /// 域确证）。
    private func importFromUrl() {
        guard let url = URL(string: importURLString) else { return }
        isParsing = true
        statusMessage = "解析配置..."
        Task {
            // 解构元组显式类型（wave-16：可选元组解构域）。
            let result: (Data, URLResponse)? = try? await URLSession.shared
                .data(from: url)
            isParsing = false
            guard let data = result?.0 else {
                statusMessage = "解析失败: 下载失败"
                return
            }
            finishImport(data)
        }
    }

    /// importFromClipboard()（签名域确证）。
    private func importFromClipboard() {
        guard let json = UIPasteboard.general.string,
              let data = json.data(using: .utf8) else {
            statusMessage = "剪贴板为空"
            return
        }
        finishImport(data)
    }

    /// importFromFile(_: URL)（签名域确证）。
    private func importFromFile(_ url: URL) {
        do {
            let count = try TtsSourceStore.shared.importFile(url)
            statusMessage = "已导入 \(count) 条"
            reload()
        } catch { statusMessage = "导入失败：\(error.localizedDescription)" }
    }

    private func finishImport(_ data: Data) {
        let imported = TtsSourceStore.shared.importJSON(data)
        statusMessage = imported > 0
            ? "已导入 \(imported) 条" : "解析失败: 格式无效"
        reload()
    }

    /// exportSources()（'已导出 ' L3927 域确证）。
    private func exportSources() {
        guard let url = TtsSourceStore.shared.exportAll() else { return }
        statusMessage = "已导出 \(sources.count) 条"
        let activity = UIActivityViewController(
            activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow?.rootViewController
            }
            .first?
            .present(activity, animated: true)
    }
}

/// 管理页与播放器共用仓库、偏好和缓存；可注入隔离存储复算操作链。
@MainActor
final class TtsSourceStore {
    static let shared = TtsSourceStore(repository: ReaderSpeechSupport.sources,
        preferences: ReaderSpeechSupport.preferences,
        didChange: { ReaderSpeechSupport.sharedCoordinator.settingsDidChange() })
    private let repository: HttpTtsSourceRepository
    private let preferences: ReadAloudPreferences
    private let didChange: () -> Void

    init(repository: HttpTtsSourceRepository, preferences: ReadAloudPreferences,
         didChange: @escaping () -> Void = {}) {
        self.repository = repository
        self.preferences = preferences
        self.didChange = didChange
        preferences.migrateLegacySourceSelection(using: repository)
    }

    func loadSources() -> [HttpTts] {
        repository.reload()
        return repository.sources
    }

    var currentSourceID: Int64? {
        _ = loadSources()
        return preferences.selectedHTTPSourceID
    }

    func setCurrent(_ id: Int64?) {
        _ = loadSources()
        if let id {
            guard repository.source(id: id) != nil else { return }
            preferences.selectEngine(.http(sourceID: id))
        } else {
            preferences.selectEngine(.system(voiceIdentifier: preferences.systemVoiceIdentifier))
        }
        didChange()
    }

    func save(_ source: HttpTts, originalID: Int64?) throws {
        _ = loadSources()
        if let originalID { try repository.update(id: originalID, with: source) }
        else { try repository.add(source) }
        if preferences.selectedHTTPSourceID == (originalID ?? source.id) { didChange() }
    }

    func delete(_ id: Int64) {
        _ = loadSources()
        repository.delete(id: id)
        if preferences.selectedHTTPSourceID == id {
            setCurrent(nil)
        }
    }

    func importJSON(_ data: Data) -> Int {
        guard let json = String(data: data, encoding: .utf8) else { return 0 }
        _ = loadSources()
        let previous = preferences.selectedHTTPSourceID.flatMap { repository.source(id: $0) }
        let count = repository.importSources(from: json)
        preferences.migrateLegacySourceSelection(using: repository)
        let current = preferences.selectedHTTPSourceID.flatMap { repository.source(id: $0) }
        if previous != current { didChange() }
        return count
    }

    func importFile(_ url: URL) throws -> Int {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let count = importJSON(try Data(contentsOf: url))
        guard count > 0 else { throw HttpTtsSourceRepository.HttpTtsSourceRepositoryError.invalidPayload }
        return count
    }

    func exportAll() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(loadSources()) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_sources.json")
        do { try data.write(to: url, options: .atomic); return url }
        catch { return nil }
    }

}
