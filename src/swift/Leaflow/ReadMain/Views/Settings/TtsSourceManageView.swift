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

/// 朗读源管理页（body/filteredSources 签名域确证）。
struct TtsSourceManageView: View {

    @State private var sources: [HttpTts] = []
    @State private var currentSourceID: Int64?
    @State private var useSystemTTS = true
    @State private var searchText = ""
    @State private var showEdit = false
    @State private var editTarget: HttpTts?
    @State private var showNetworkImport = false
    @State private var importURLString = ""
    @State private var statusMessage = ""
    @State private var isParsing = false

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
                        importFromFile(URL(fileURLWithPath: ""))
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
                Button {
                    editTarget = nil
                    showEdit = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            TtsEditView(
                mode: editTarget == nil ? .create : .edit,
                original: editTarget,
                onSaved: {
                    showEdit = false
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
    }

    // MARK: 当前源（'当前朗读源' L1026 / '系统 TTS' L4421 域确证）

    @ViewBuilder
    private var currentSection: some View {
        Section("当前朗读源") {
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
                        editTarget = current
                        showEdit = true
                    } label: {
                        Text("配置")
                    }
                    .buttonStyle(.borderless)
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
            Menu {
                Button {
                    testSource(source)
                } label: {
                    Label("试听", systemImage: "play.circle")
                }
                Button {
                    editTarget = source
                    showEdit = true
                } label: {
                    Label("配置", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
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
        sources = TtsSourceStore.loadSources()
        currentSourceID = TtsSourceStore.currentSourceID
        useSystemTTS = currentSourceID == nil
    }

    /// select(_: HttpTts)（签名域确证）。
    private func select(_ source: HttpTts) {
        currentSourceID = source.id
        useSystemTTS = false
        TtsSourceStore.setCurrent(source.id)
    }

    /// selectSystemTTS()（签名域确证）。
    private func selectSystemTTS() {
        currentSourceID = nil
        useSystemTTS = true
        TtsSourceStore.setCurrent(nil)
    }

    /// testSource(_: HttpTts)（签名域确证）。
    private func testSource(_ source: HttpTts) {
        TtsSourceStore.preview(source)
    }

    /// deleteSources(at: IndexSet)（签名域确证）。
    private func deleteSources(at offsets: IndexSet) {
        let targets = offsets.map { filteredSources[$0] }
        for target in targets {
            TtsSourceStore.delete(target.id)
        }
        reload()
    }

    private func deleteAll() {
        for source in sources {
            TtsSourceStore.delete(source.id)
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
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json, .plainText])
        UIApplication.shared.connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow?.rootViewController
            }
            .first?
            .present(picker, animated: true)
    }

    private func finishImport(_ data: Data) {
        let imported = TtsSourceStore.importJSON(data)
        statusMessage = imported > 0
            ? "已导入 \(imported) 条" : "解析失败: 格式无效"
        reload()
    }

    /// exportSources()（'已导出 ' L3927 域确证）。
    private func exportSources() {
        guard let url = TtsSourceStore.exportAll() else { return }
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

/// 朗读源存储桥（T-801-02 HttpTts 分册落地时补齐实现）。
enum TtsSourceStore {

    static func loadSources() -> [HttpTts] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "reader_tts_sources"),
              let stored = try? JSONDecoder().decode(
                [HttpTts].self, from: data) else {
            return []
        }
        return stored
    }

    static var currentSourceID: Int64? {
        let raw = UserDefaults.standard.double(
            forKey: "reader_tts_current")
        // double 键 → Int64 归一（Int64? 返回域，wave-16）。
        return raw == 0 ? nil : Int64(raw)
    }

    static func setCurrent(_ id: Int64?) {
        UserDefaults.standard.set(id ?? 0, forKey: "reader_tts_current")
    }

    static func save(_ source: HttpTts, originalID: Int64?) {
        var all = loadSources()
        if let originalID,
           let index = all.firstIndex(where: { $0.id == originalID }) {
            all[index] = source
        } else {
            all.append(source)
        }
        persist(all)
    }

    static func delete(_ id: Int64) {
        var all = loadSources()
        all.removeAll { $0.id == id }
        persist(all)
        if currentSourceID == id {
            setCurrent(nil)
        }
    }

    static func importJSON(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        var count = 0
        if let single = try? decoder.decode(HttpTts.self, from: data) {
            save(single, originalID: nil)
            count = 1
        } else if let list = try? decoder.decode(
            [HttpTts].self, from: data) {
            var all = loadSources()
            for source in list {
                all.removeAll { $0.id == source.id }
                all.append(source)
                count += 1
            }
            persist(all)
        }
        return count
    }

    static func exportAll() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(loadSources()) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_sources.json")
        try? data.write(to: url, options: .atomic)
        return url
    }

    static func preview(_ source: HttpTts) {
        // 试听桥（T-801-05 HttpTtsAudioPreparer 分册落地）。
    }

    private static func persist(_ sources: [HttpTts]) {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(
                data, forKey: "reader_tts_sources")
        }
    }
}
