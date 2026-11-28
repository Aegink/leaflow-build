// 原路径: ReadMain/Views/Settings/TtsSourceManageView.swift
// 类型表12875...12985及0x100b17e34/185a8/18704：原配置表单、选项、按钮动作与保存。
import SwiftUI

struct TtsRowUi: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let viewName: String?
    let chars: [String]
    let action: String?
    let defaultValue: String?

    var displayName: String {
        guard let viewName, viewName.count >= 2, viewName.first == "'", viewName.last == "'" else { return name }
        return String(viewName.dropFirst().dropLast())
    }

    static func parse(_ json: String) throws -> [TtsRowUi] {
        guard let data = json.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AppError.parsing("朗读配置必须是数组")
        }
        return array.map { row in
            TtsRowUi(name: LegadoJSONLiteral.stringValue(row["name"]) ?? "",
                type: LegadoJSONLiteral.stringValue(row["type"]) ?? "text",
                viewName: LegadoJSONLiteral.stringValue(row["viewName"]),
                chars: (row["chars"] as? [Any] ?? []).compactMap(LegadoJSONLiteral.stringValue),
                action: LegadoJSONLiteral.stringValue(row["action"]),
                defaultValue: LegadoJSONLiteral.stringValue(row["default"]))
        }
    }

    static func selections(rows: [TtsRowUi], stored: [String: String]) -> [String: String] {
        var result = stored
        for row in rows where ["text", "select", "toggle"].contains(row.type) && !row.name.isEmpty {
            if let current = result[row.name], !current.isEmpty || row.type == "text" { continue }
            result[row.name] = row.defaultValue ?? (row.type == "text" ? "" : row.chars.first ?? "")
        }
        return result
    }
}

struct TtsSourceConfigSheet: View {
    let source: HttpTts
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [TtsRowUi] = []
    @State private var selections: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if isLoading { ProgressView("正在加载配置") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                ForEach(rows.filter { ["text", "select", "toggle"].contains($0.type) }) { row in
                    rowView(row)
                }
                ForEach(rows.filter { $0.type == "button" }) { row in
                    Button(row.displayName) { executeButtonAction(row) }
                        .accessibilityIdentifier("tts-config-action-" + row.name)
                }
                if !isLoading && rows.isEmpty && errorMessage == nil { Text("此朗读源未提供配置项") }
                if let toastMessage { Text(toastMessage).accessibilityIdentifier("tts-config-result") }
            }
            .navigationTitle(source.name)
            .disabled(isLoading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveAndDismiss() }.disabled(isLoading || errorMessage != nil)
                }
            }
        }
        .task { await parseLoginUi() }
    }

    @ViewBuilder
    private func rowView(_ row: TtsRowUi) -> some View {
        switch row.type {
        case "select":
            Picker(row.displayName, selection: Binding(get: { selections[row.name] ?? "" }, set: { value in
                selections[row.name] = value
                if row.action?.isEmpty == false { executeButtonAction(row) }
            })) {
                ForEach(Array(row.chars.enumerated()), id: \.offset) { _, value in Text(value).tag(value) }
            }.accessibilityIdentifier("tts-config-select-" + row.name)
        case "toggle":
            Button { toggleValue(for: row) } label: {
                HStack { Text(row.displayName); Spacer(); Text(selections[row.name] ?? "") }
            }.accessibilityIdentifier("tts-config-toggle-" + row.name)
        default:
            LabeledContent(row.displayName) {
                TextField(row.chars.first ?? "", text: Binding(
                    get: { selections[row.name] ?? "" }, set: { selections[row.name] = $0 }))
                    .multilineTextAlignment(.trailing).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("tts-config-text-" + row.name)
            }
        }
    }

    private func parseLoginUi() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let store = ReaderSpeechSupport.runtimeStore
            let source = source
            let parsed = try await Task.detached {
                let evaluator = HttpTtsLoginConfigurationEvaluator(store: store)
                try evaluator.prepareDefaultsIfNeeded(for: source, store: store)
                guard let raw = source.loginUi, !raw.isEmpty,
                      let json = try evaluator.evaluate(raw, source: source) else { return [TtsRowUi]() }
                return try TtsRowUi.parse(json)
            }.value
            guard !Task.isCancelled else { return }
            rows = parsed
            selections = TtsRowUi.selections(rows: parsed, stored: store.loginInfoMap(sourceID: source.id))
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func toggleValue(for row: TtsRowUi) {
        guard !row.chars.isEmpty else { return }
        let current = row.chars.firstIndex(of: selections[row.name] ?? "") ?? -1
        selections[row.name] = row.chars[(current + 1) % row.chars.count]
        if row.action?.isEmpty == false { executeButtonAction(row) }
    }

    private func saveAndDismiss() {
        ReaderSpeechSupport.runtimeStore.setLoginInfoMap(selections, sourceID: source.id)
        ReaderSpeechSupport.sources.audioCache.remove(sourceID: source.id)
        dismiss()
    }

    private func executeButtonAction(_ row: TtsRowUi) {
        guard !isLoading, let action = row.action, !action.isEmpty else { return }
        isLoading = true
        let values = selections, source = source
        let store = ReaderSpeechSupport.runtimeStore, cache = ReaderSpeechSupport.sources.audioCache
        Task {
            defer { isLoading = false }
            do {
                let message = try await Task.detached {
                    try LoginCheckExecutor.executeTTSConfigurationAction(action, source: source,
                        values: values, runtimeStore: store, audioCache: cache)
                }.value
                selections = TtsRowUi.selections(rows: rows, stored: store.loginInfoMap(sourceID: source.id))
                toastMessage = message ?? "操作完成"
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
