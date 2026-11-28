// 原路径: ReadMain/Services/ReadAloud/ReadAloudPreferences.swift
// 证据:
//   - PGO: 62 条记录（index/task_functions.csv T-801-09 /
//     ReadAloudPreferences.swift；伪代码域 260 行）
//   - CovMap: 上述 L 区段（init(defaults:)/reload/normalized 六件/
//     set 六件/voice 双桥域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudPreferences.c（2146 行）
//   - 块体确证（签名域）：
//     init(defaults: NSUserDefaults) / reload / selectedEngine getter /
//     normalizedHTTPDownloadAhead(Int)/normalizedHTTPRate(Float)/
//     normalizedHTTPTailTrim(Int)/normalizedSystemPitch(Float)/
//     normalizedSystemQueueAhead(Int)/normalizedSystemRate(Float)/
//     setHTTPDownloadAhead(Int)/setHTTPRate(Float)/
//     setHTTPTailTrim(milliseconds: Int)/setSystemPitch(Float)/
//     setSystemQueueAhead(Int)/setSystemRate(Float)/
//     systemMultiplierToRate(Float)/systemRateToMultiplier(Float)/
//     voiceDisplayName(ReadAloudVoice) / migrateLegacySourceSelection(
//     using: ...) / ReadAloudVoice.init(voice: AVSpeechSynthesisVoice)
//   - 事实：朗读偏好域（引擎选择 + HTTP 三参 + 系统三参 + 归一化）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十八签名域确证）
// 还原: 2026-11-20

import AVFoundation
import Foundation

/// 系统朗读音色（init(voice:) 签名域确证）。
struct ReadAloudVoice: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String
    let avVoice: AVSpeechSynthesisVoice?

    /// init(voice:)（签名域确证）。
    init(voice: AVSpeechSynthesisVoice) {
        self.id = voice.identifier
        self.name = voice.name
        self.language = voice.language
        self.avVoice = voice
    }

    var systemVoice: AVSpeechSynthesisVoice? { avVoice }
}

/// 朗读偏好（init(defaults:) + normalized/set 签名域确证）。
@MainActor
final class ReadAloudPreferences: ObservableObject {

    private let defaults: UserDefaults

    @Published private(set) var selectedHTTPSourceID: Int64?
    @Published private(set) var systemVoiceIdentifier: String
    var selectedEngine: ReadAloudEngineSelection {
        if let selectedHTTPSourceID { return .http(sourceID: selectedHTTPSourceID) }
        return .system(voiceIdentifier: systemVoiceIdentifier)
    }
    var systemVoice: ReadAloudVoice? {
        AVSpeechSynthesisVoice(identifier: systemVoiceIdentifier).map(ReadAloudVoice.init)
    }
    var availableSystemVoices: [ReadAloudVoice] {
        AVSpeechSynthesisVoice.speechVoices().map(ReadAloudVoice.init)
    }
    @Published var systemRate: Float
    @Published var systemPitch: Float
    @Published var systemQueueAhead: Int
    @Published var httpRate: Float
    @Published var httpDownloadAhead: Int
    @Published var httpTailTrimMilliseconds: Int

    private static let engineKey = "reader_readaloud_engine"
    private static let httpSourceKey = "reader_readaloud_http_source_id"
    private static let systemVoiceKey = "reader_readaloud_voice"
    private static let systemRateKey = "reader_readaloud_system_rate"
    private static let systemPitchKey = "reader_readaloud_system_pitch"
    private static let systemQueueKey = "reader_readaloud_system_queue"
    private static let httpRateKey = "reader_readaloud_http_rate"
    private static let httpAheadKey = "reader_readaloud_http_ahead"
    private static let httpTrimKey = "reader_readaloud_http_trim"

    /// init(defaults:)（签名域确证）。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        systemVoiceIdentifier = defaults.string(forKey: Self.systemVoiceKey) ?? ""
        selectedHTTPSourceID = (defaults.object(forKey: Self.httpSourceKey) as? NSNumber)?.int64Value
        systemRate = defaults.float(forKey: Self.systemRateKey)
        systemPitch = defaults.float(forKey: Self.systemPitchKey)
        systemQueueAhead = defaults.integer(forKey: Self.systemQueueKey)
        httpRate = defaults.float(forKey: Self.httpRateKey)
        httpDownloadAhead = defaults.integer(forKey: Self.httpAheadKey)
        httpTailTrimMilliseconds = defaults.integer(forKey: Self.httpTrimKey)
        if systemRate == 0 { systemRate = 1.0 }
        if systemPitch == 0 { systemPitch = 1.0 }
        if systemQueueAhead == 0 { systemQueueAhead = 2 }
        if httpRate == 0 { httpRate = 1.0 }
        if httpDownloadAhead == 0 { httpDownloadAhead = 2 }
        if httpTailTrimMilliseconds == 0 { httpTailTrimMilliseconds = 80 }
        reload()
    }

    /// reload（签名域确证）。
    func reload() {
        systemVoiceIdentifier = defaults.string(forKey: Self.systemVoiceKey) ?? ""
        selectedHTTPSourceID = (defaults.object(forKey: Self.httpSourceKey) as? NSNumber)?.int64Value
        systemRate = normalizedSystemRate((defaults.object(forKey: Self.systemRateKey) as? NSNumber)?.floatValue ?? 1)
        systemPitch = normalizedSystemPitch((defaults.object(forKey: Self.systemPitchKey) as? NSNumber)?.floatValue ?? 1)
        systemQueueAhead = normalizedSystemQueueAhead((defaults.object(forKey: Self.systemQueueKey) as? NSNumber)?.intValue ?? 2)
        httpRate = normalizedHTTPRate((defaults.object(forKey: Self.httpRateKey) as? NSNumber)?.floatValue ?? 1)
        httpDownloadAhead = normalizedHTTPDownloadAhead((defaults.object(forKey: Self.httpAheadKey) as? NSNumber)?.intValue ?? 2)
        httpTailTrimMilliseconds = normalizedHTTPTailTrim((defaults.object(forKey: Self.httpTrimKey) as? NSNumber)?.intValue ?? 80)
    }

    // MARK: 归一化域（normalized 六件签名域确证）

    /// normalizedHTTPRate(Float)（签名域确证：0.5...3.0）。
    private func normalizedHTTPRate(_ rate: Float) -> Float {
        min(max(rate, 0.5), 3.0)
    }

    /// normalizedHTTPDownloadAhead(Int)（签名域确证：1...8）。
    private func normalizedHTTPDownloadAhead(_ count: Int) -> Int {
        min(max(count, 1), 8)
    }

    /// normalizedHTTPTailTrim(Int)（签名域确证：0...500）。
    private func normalizedHTTPTailTrim(_ milliseconds: Int) -> Int {
        min(max(milliseconds, 0), 500)
    }

    /// normalizedSystemRate(Float)（签名域确证：0.1...2.0）。
    private func normalizedSystemRate(_ rate: Float) -> Float {
        min(max(rate, 0.1), 2.0)
    }

    /// normalizedSystemPitch(Float)（签名域确证：0.5...2.0）。
    private func normalizedSystemPitch(_ pitch: Float) -> Float {
        min(max(pitch, 0.5), 2.0)
    }

    /// normalizedSystemQueueAhead(Int)（签名域确证：0...5）。
    private func normalizedSystemQueueAhead(_ count: Int) -> Int {
        min(max(count, 0), 5)
    }

    // MARK: 写入域（set 六件签名域确证）

    func setSystemRate(_ rate: Float) {
        systemRate = normalizedSystemRate(rate)
        defaults.set(systemRate, forKey: Self.systemRateKey)
    }

    func setSystemPitch(_ pitch: Float) {
        systemPitch = normalizedSystemPitch(pitch)
        defaults.set(systemPitch, forKey: Self.systemPitchKey)
    }

    func setSystemQueueAhead(_ count: Int) {
        systemQueueAhead = normalizedSystemQueueAhead(count)
        defaults.set(systemQueueAhead, forKey: Self.systemQueueKey)
    }

    func setHTTPRate(_ rate: Float) {
        httpRate = normalizedHTTPRate(rate)
        defaults.set(httpRate, forKey: Self.httpRateKey)
    }

    func setHTTPDownloadAhead(_ count: Int) {
        httpDownloadAhead = normalizedHTTPDownloadAhead(count)
        defaults.set(httpDownloadAhead, forKey: Self.httpAheadKey)
    }

    func setHTTPTailTrim(milliseconds: Int) {
        httpTailTrimMilliseconds = normalizedHTTPTailTrim(milliseconds)
        defaults.set(httpTailTrimMilliseconds, forKey: Self.httpTrimKey)
    }

    func selectEngine(_ selection: ReadAloudEngineSelection) {
        switch selection {
        case .system(let identifier):
            selectedHTTPSourceID = nil
            systemVoiceIdentifier = identifier
            defaults.removeObject(forKey: Self.httpSourceKey)
            defaults.set(identifier, forKey: Self.systemVoiceKey)
        case .http(let sourceID):
            selectedHTTPSourceID = sourceID
            defaults.set(sourceID, forKey: Self.httpSourceKey)
        }
        defaults.set(selection.rawValue, forKey: Self.engineKey)
    }

    // MARK: 语音域（systemMultiplierToRate/systemRateToMultiplier/
    // voiceDisplayName 签名域确证）

    /// systemMultiplierToRate(Float)（签名域确证：倍率 → AVSpeechRate）。
    func systemMultiplierToRate(_ multiplier: Float) -> Float {
        AVSpeechUtteranceDefaultSpeechRate * multiplier
    }

    /// systemRateToMultiplier(Float)（签名域确证）。
    func systemRateToMultiplier(_ rate: Float) -> Float {
        guard AVSpeechUtteranceDefaultSpeechRate > 0 else { return 1.0 }
        return rate / AVSpeechUtteranceDefaultSpeechRate
    }

    /// voiceDisplayName(ReadAloudVoice)（签名域确证）。
    func voiceDisplayName(_ voice: ReadAloudVoice) -> String {
        voice.name.isEmpty ? voice.language : voice.name
    }

    /// migrateLegacySourceSelection(using:)（签名域确证：旧键迁移桥）。
    func migrateLegacySourceSelection(
        using repository: HttpTtsSourceRepository
    ) {
        // 新选择（含显式系统引擎）优先，避免冷启动复活旧HTTP选择。
        guard defaults.object(forKey: Self.engineKey) == nil,
              selectedHTTPSourceID == nil else { return }
        for key in ["reader_tts_current", "reader_tts_selected"] {
            guard let legacy = (defaults.object(forKey: key) as? NSNumber)?.int64Value,
                  legacy != 0, repository.source(id: legacy) != nil else { continue }
            selectEngine(.http(sourceID: legacy))
            defaults.removeObject(forKey: "reader_tts_current")
            defaults.removeObject(forKey: "reader_tts_selected")
            return
        }
    }
}

// MARK: - T-1401-15/16 逐域补齐（语音选择域）

extension ReadAloudPreferences {

    /// 伪代码 0x100296258（L129-135）：系统语音选择（identifier 域——
    /// ReadAloudVoice.init(voice:) 签名域桥）。
    func selectSystemVoice(identifier: String) {
        guard identifier.isEmpty || AVSpeechSynthesisVoice(identifier: identifier) != nil else { return }
        selectEngine(.system(voiceIdentifier: identifier))
    }

    /// 伪代码 0x100295a60（L143-147）：HTTP 语音选择移除。
    func removeHTTPSelection() {
        selectEngine(.system(voiceIdentifier: systemVoiceIdentifier))
    }
}

