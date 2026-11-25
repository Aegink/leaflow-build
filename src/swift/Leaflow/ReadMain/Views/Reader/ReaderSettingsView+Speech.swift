// 原路径: ReadMain/Views/Reader/ReaderSettingsView.swift
// 拆分归属见 tools/restoration_gate_checks.py；仍计入同一个原始文件。
import SwiftUI

extension ReaderSettingsView {
    // MARK: - 朗读

    /// speechSettings getter（PGO 签名确证）。
    var speechSettings: some View {
        Form {
            systemTtsSettings
            httpTtsSettings
            Section {
                Button("恢复默认朗读设置") {
                    resetSpeechSettings()
                }
                .foregroundStyle(.red)
            }
        }
    }

    /// systemTtsSettings getter（PGO 签名确证）。
    private var systemTtsSettings: some View {
        Section("系统朗读") {
            Picker("朗读引擎", selection: Binding(
                get: { preferences.selectedEngine },
                set: { preferences.selectEngine($0) })) {
                Text("系统 TTS").tag(ReadAloudEngineSelection.system(voiceIdentifier: preferences.systemVoiceIdentifier))
                ForEach(TtsSourceStore.loadSources()) { source in
                    Text(source.name).tag(ReadAloudEngineSelection.http(sourceID: source.id))
                }
            }
            LabeledContent(
                "当前音色",
                value: preferences.systemVoice?.name ?? "系统默认")
            adjustmentSlider(
                "语速",
                value: Binding(
                    get: { Double(preferences.systemRate) },
                    set: { preferences.setSystemRate(Float($0)) }),
                range: 0.5...2.0, step: 0.05,
                unit: "x")
            adjustmentSlider(
                "音调",
                value: Binding(
                    get: { Double(preferences.systemPitch) },
                    set: { preferences.setSystemPitch(Float($0)) }),
                range: 0.5...2.0, step: 0.05)
            Stepper(
                "预读段数 \(preferences.systemQueueAhead)",
                value: Binding(
                    get: { preferences.systemQueueAhead },
                    set: { preferences.setSystemQueueAhead($0) }),
                in: 0...8)
        }
    }

    /// httpTtsSettings getter（PGO 签名确证）。
    private var httpTtsSettings: some View {
        Section("在线朗读") {
            adjustmentSlider(
                "在线语速",
                value: Binding(
                    get: { Double(preferences.httpRate) },
                    set: { preferences.setHTTPRate(Float($0)) }),
                range: 0.5...2.0, step: 0.05,
                unit: "x")
            Stepper(
                "预下载段数 \(preferences.httpDownloadAhead)",
                value: Binding(
                    get: { preferences.httpDownloadAhead },
                    set: { preferences.setHTTPDownloadAhead($0) }),
                in: 0...8)
            Stepper(
                "尾部裁剪 \(preferences.httpTailTrimMilliseconds)ms",
                value: Binding(
                    get: { preferences.httpTailTrimMilliseconds },
                    set: { preferences.setHTTPTailTrim(milliseconds: $0) }),
                in: 0...2000, step: 50)
        }
    }

    /// resetSpeechSettings（PGO 签名确证）。
    private func resetSpeechSettings() {
        preferences.setSystemRate(1.0)
        preferences.setSystemPitch(1.0)
        preferences.setSystemQueueAhead(2)
        preferences.setHTTPRate(1.0)
        preferences.setHTTPDownloadAhead(2)
        preferences.setHTTPTailTrim(milliseconds: 0)
        preferences.selectEngine(.system(voiceIdentifier: ""))
    }
}
