// 原路径: ReadMain/Services/ReadAloud/AVSystemSpeechOutput.swift
// 证据:
//   - PGO: 26 条记录（index/task_functions.csv T-801-04 /
//     AVSystemSpeechOutput.swift；伪代码域 260 行）
//   - CovMap: 上述 L 区段（delegate 四回调 L192-260 / enqueue 域 /
//     pause/resume/stop 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     AVSystemSpeechOutput.c（297 行）
//   - 块体确证（签名域）：
//     init(synthesizer: AVSpeechSynthesizer) / handle(
//     AVSystemSpeechDelegateEvent) / enqueue(SystemSpeechRequest) /
//     pause / resume / stop / speechSynthesizer(_:didStart:) L192 /
//     speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)
//     L215-217 / speechSynthesizer(_:didFinish:) /
//     speechSynthesizer(_:didCancel:) / __deallocating_deinit
//   - 事实：AVSpeechSynthesizer 委托链（start/willSpeak/finish/cancel
//     四回调 → handle 事件域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十签名域 + 四回调确证）
// 还原: 2026-11-20

import AVFoundation

/// 系统朗读输出（init(synthesizer:) + delegate 四回调签名域确证）。
final class AVSystemSpeechOutput: NSObject, AVSpeechSynthesizerDelegate {

    /// 代理事件域（handle(AVSystemSpeechDelegateEvent) 签名确证）。
    enum DelegateEvent {
        case started(SystemSpeechRequest)
        case willSpeak(
            SystemSpeechRequest, range: NSRange,
            progress: Double)
        case finished(SystemSpeechRequest)
        case cancelled(SystemSpeechRequest)
    }

    private let synthesizer: AVSpeechSynthesizer
    private var queue: [SystemSpeechRequest] = []
    private var activeRequest: SystemSpeechRequest?
    var onEvent: ((DelegateEvent) -> Void)?

    /// init(synthesizer:)（签名域确证）。
    init(synthesizer: AVSpeechSynthesizer) {
        self.synthesizer = synthesizer
        super.init()
        synthesizer.delegate = self
    }

    deinit {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// enqueue(SystemSpeechRequest)（签名域确证：utterance 入队）。
    func enqueue(_ request: SystemSpeechRequest) {
        queue.append(request)
        if activeRequest == nil {
            speakNext()
        }
    }

    /// 在途队列长度（SystemReadAloudDriver.enqueueMore 消费域确证，
    /// wave-16 补桥）。
    var pendingCount: Int {
        queue.count
    }

    private func speakNext() {
        guard let request = queue.first else { return }
        activeRequest = request
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.rate = request.rate
        utterance.pitchMultiplier = request.pitch
        utterance.volume = request.volume
        if let language = request.language {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        synthesizer.speak(utterance)
    }

    private func finishCurrent(removeFromQueue: Bool) {
        if removeFromQueue, !queue.isEmpty {
            queue.removeFirst()
        }
        activeRequest = nil
        speakNext()
    }

    /// pause（签名域确证）。
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    /// resume（签名域确证）。
    func resume() {
        synthesizer.continueSpeaking()
    }

    /// stop（签名域确证）。
    func stop() {
        queue.removeAll()
        activeRequest = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// handle(_: DelegateEvent)（签名域确证：事件转发桥）。
    func handle(_ event: DelegateEvent) {
        onEvent?(event)
    }

    // MARK: AVSpeechSynthesizerDelegate（四回调签名域确证）

    /// speechSynthesizer(_:didStart:)（L192-193 域确证）。
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        guard let request = activeRequest else { return }
        handle(.started(request))
    }

    /// speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)
    /// （L215-217 域确证）。
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        guard let request = activeRequest else { return }
        let total = Double(utterance.speechString.count)
        let progress = total > 0
            ? Double(characterRange.location) / total : 0
        handle(.willSpeak(request, range: characterRange,
                          progress: progress))
    }

    /// speechSynthesizer(_:didFinish:)（签名域确证）。
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        guard let request = activeRequest else { return }
        handle(.finished(request))
        finishCurrent(removeFromQueue: true)
    }

    /// speechSynthesizer(_:didCancel:)（签名域确证）。
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        guard let request = activeRequest else { return }
        handle(.cancelled(request))
        finishCurrent(removeFromQueue: true)
    }
}

/// 系统朗读输出命名桥（SystemReadAloudDriver init(synthesizer:) 域确证）。
typealias SystemSpeechOutput = AVSystemSpeechOutput
