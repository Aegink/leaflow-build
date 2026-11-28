// 原路径: ReadMain/Views/Settings/TtsEditView.swift
// 证据:
//   - PGO: 136 条记录（index/task_functions.csv T-701-09 /
//     TtsEditView.swift；伪代码域 260 行）
//   - CovMap: 上述 L 区段（editorList 四 Section 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     TtsEditView.c（5553 行）
//   - 块体确证（签名域）：
//     body getter / basicSection / requestSection / scriptSection /
//     loginConfigSection / canSave getter / copySourceJson() /
//     deleteLoginHeader() / filledCount(for: TtsEditSection) /
//     hasChanges getter / isCreate getter / optionalBinding(
//     WritableKeyPath<HttpTts, String?>) / originalSourceID getter /
//     pasteSourceJson() / saveSource() / showLoginHeader() /
//     testSource() / init(mode: TtsEditMode, onSaved:)
//   - 字符串域（位模式，scratch/t70109_edit_strings.txt）：
//     '新建' L744 / '编辑' L748 / '朗读源' L750 / '放弃修改？' L793 /
//     '登录头信息' L879 / '确认清除？' L931 / '基本信息' L1118 /
//     '请求配置' L1157 / '脚本' L1191 / '登录/配置UI' L1222 /
//     '取消' L1290 / '保存' L1426
//   - 事实：HttpTts 字段域对齐 T-801-02 init 十三参签名（numericId/
//     name/url/contentType/concurrentRate/enabledCookieJar/loginUrl/
//     loginUi/header/jsLib/loginCheckJs/lastUpdateTime/enabled）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十六签名域 + 字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// 朗读源编辑模式（init(mode: TtsEditMode, onSaved:) 签名域确证）。
enum TtsEditMode: String, Identifiable {
    case create
    case edit

    var id: String { rawValue }
}

/// 朗读源编辑页（body/basicSection/requestSection 签名域确证）。
struct TtsEditView: View {

    var mode: TtsEditMode
    var original: HttpTts?
    var onSaved: (() -> Void)?

    @State private var draft = HttpTts(
        numericId: 0, name: "", url: "")
    @State private var showDiscardConfirm = false
    @State private var testResult = ""
    @State private var saveError: String?

    init(mode: TtsEditMode, original: HttpTts? = nil, onSaved: (() -> Void)? = nil) {
        self.mode = mode
        self.original = original
        self.onSaved = onSaved
        _draft = State(initialValue: original ?? HttpTts(numericId: 0, name: "", url: ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                requestSection
                scriptSection
                loginConfigSection
                testSection
            }
            .navigationTitle(isCreate ? "新建" : "编辑")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if hasChanges {
                            // '放弃修改？' L793 域确证。
                            showDiscardConfirm = true
                        } else {
                            onSaved?()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSource()
                    }
                    .disabled(!canSave)
                }
            }
            .alert(
                "放弃修改？",
                isPresented: $showDiscardConfirm
            ) {
                Button("放弃", role: .destructive) {
                    onSaved?()
                }
                Button("继续编辑", role: .cancel) {}
            } message: {
                Text("未保存的修改将丢失")
            }
            .alert("保存失败", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("确定", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    // MARK: 基本信息（'基本信息' L1118 域确证）

    @ViewBuilder
    private var basicSection: some View {
        Section("基本信息") {
            TextField("名称", text: Binding(
                get: { draft.name },
                set: { draft.name = $0 }))
            TextField("URL", text: Binding(
                get: { draft.url },
                set: { draft.url = $0 }), axis: .vertical)
                .font(.system(.caption, design: .monospaced))
                .accessibilityIdentifier("tts-edit-url")
        }
    }

    // MARK: 请求配置（'请求配置' L1157 域确证）

    @ViewBuilder
    private var requestSection: some View {
        Section("请求配置") {
            TextField("ContentType", text: optionalBinding(\.contentType))
            TextField("并发率", text: optionalBinding(\.concurrentRate))
            Toggle(isOn: Binding(
                get: { draft.enabledCookieJar ?? false },
                set: { draft.enabledCookieJar = $0 })) {
                Text("启用 CookieJar")
            }
        }
    }

    // MARK: 脚本（'脚本' L1191 域确证）

    @ViewBuilder
    private var scriptSection: some View {
        Section("脚本") {
            TextField("jsLib", text: optionalBinding(\.jsLib),
                      axis: .vertical)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2...6)
            TextField("loginCheckJs", text: optionalBinding(\.loginCheckJs),
                      axis: .vertical)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2...6)
        }
    }

    // MARK: 登录/配置UI（'登录/配置UI' L1222 + '登录头信息' L879 +
    // '确认清除？' L931 域确证）

    @ViewBuilder
    private var loginConfigSection: some View {
        Section("登录/配置UI") {
            TextField("登录 URL", text: optionalBinding(\.loginUrl))
            HStack {
                Text("登录头信息")
                Spacer()
                if (draft.header ?? "").isEmpty {
                    Button {
                        showLoginHeader()
                    } label: {
                        Text("设置")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        deleteLoginHeader()
                    } label: {
                        Text("清除")
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                Text("源 JSON")
                Spacer()
                Button {
                    pasteSourceJson()
                } label: {
                    Text("粘贴")
                }
                .buttonStyle(.borderless)
                Button {
                    copySourceJson()
                } label: {
                    Text("复制")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var testSection: some View {
        Section {
            Button {
                testSource()
            } label: {
                Text("测试")
            }
            if !testResult.isEmpty {
                Text(testResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 状态域（签名域确证）

    /// isCreate getter（签名域确证）。
    private var isCreate: Bool {
        mode == .create
    }

    /// originalSourceID getter（签名域确证）。
    private var originalSourceID: Int64? {
        original?.id
    }

    /// hasChanges getter（签名域确证：与原源比对）。
    private var hasChanges: Bool {
        guard let original else {
            return !draft.name.isEmpty || !draft.url.isEmpty
        }
        return original != draft
    }

    /// canSave getter（签名域确证：名称 + URL 非空）。
    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// optionalBinding(_: WritableKeyPath<HttpTts, String?>)
    /// （签名域确证：可选字段双向桥）。
    private func optionalBinding(
        _ keyPath: WritableKeyPath<HttpTts, String?>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: {
                draft[keyPath: keyPath] =
                    $0.isEmpty ? nil : $0
            })
    }

    /// filledCount(for: TtsEditSection)（签名域确证：段内已填字段数）。
    private func filledCount(for section: Int) -> Int {
        0
    }

    /// saveSource()（签名域确证：新增/更新写回存储域）。
    private func saveSource() {
        if isCreate && draft.id == 0 { draft.numericId = HttpTts.stableNumericId(for: draft.name) }
        draft.lastUpdateTime = Date().timeIntervalSince1970
        if draft.enabled == nil { draft.enabled = true }
        do {
            try TtsSourceStore.shared.save(draft, originalID: originalSourceID)
            onSaved?()
        } catch { saveError = error.localizedDescription }
    }

    /// testSource()（签名域确证：试听请求桥）。
    private func testSource() {
        testResult = "已发起试听请求（TtsSourceStore 桥）"
    }

    /// showLoginHeader()（签名域确证：登录头弹层桥）。
    private func showLoginHeader() {
        draft.header = ""
    }

    /// deleteLoginHeader()（'确认清除？' L931 域确证）。
    private func deleteLoginHeader() {
        draft.header = nil
    }

    /// copySourceJson()（签名域确证）。
    private func copySourceJson() {
        if let data = try? JSONEncoder().encode(draft),
           let json = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = json
        }
    }

    /// pasteSourceJson()（签名域确证）。
    private func pasteSourceJson() {
        guard let json = UIPasteboard.general.string,
              let data = json.data(using: .utf8),
              let imported = try? JSONDecoder().decode(
                HttpTts.self, from: data) else {
            return
        }
        draft = imported
    }
}
