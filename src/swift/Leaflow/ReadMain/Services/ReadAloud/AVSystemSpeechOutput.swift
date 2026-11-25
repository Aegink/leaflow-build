// 原路径: ReadMain/Services/ReadAloud/AVSystemSpeechOutput.swift
// 证据: AVSystemSpeechOutput.c PGO 委托四回调 L192-260；类型表 17700 类约束输出协议。
// 按 utterance 对象身份关联 UUID，停止后旧委托不得关联新请求。
import AVFoundation

enum SystemSpeechOutputEvent {
    case started(requestID: UUID)
    case rangeChanged(requestID: UUID, range: NSRange)
    case finished(requestID: UUID)
    case cancelled(requestID: UUID)
}

protocol SystemSpeechOutput: AnyObject {
    var onEvent: ((SystemSpeechOutputEvent) -> Void)? { get set }
    func enqueue(_ request: SystemSpeechRequest)
    func pause()
    func resume()
    func stop()
}

struct SystemSpeechRequest: Equatable {
    let id: UUID
    let text: String
    let voiceIdentifier: String
    let rate: Float
    let pitch: Float

    init(id: UUID = UUID(), text: String, voiceIdentifier: String, rate: Float, pitch: Float) {
        self.id = id
        self.text = text
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
    }
}

final class AVSystemSpeechOutput: NSObject, SystemSpeechOutput, AVSpeechSynthesizerDelegate {
    private let synthesizer: AVSpeechSynthesizer
    private var requests: [ObjectIdentifier: SystemSpeechRequest] = [:]
    var onEvent: ((SystemSpeechOutputEvent) -> Void)?

    init(synthesizer: AVSpeechSynthesizer) {
        self.synthesizer = synthesizer
        super.init()
        synthesizer.delegate = self
    }

    deinit {
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    func enqueue(_ request: SystemSpeechRequest) {
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.rate = request.rate
        utterance.pitchMultiplier = request.pitch
        if !request.voiceIdentifier.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: request.voiceIdentifier)
        }
        requests[ObjectIdentifier(utterance)] = request
        synthesizer.speak(utterance)
    }

    func pause() { synthesizer.pauseSpeaking(at: .word) }
    func resume() { synthesizer.continueSpeaking() }
    func stop() {
        requests.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
    }

    func handle(_ event: SystemSpeechOutputEvent) { onEvent?(event) }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let request = requests[ObjectIdentifier(utterance)] else { return }
        handle(.started(requestID: request.id))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let request = requests[ObjectIdentifier(utterance)] else { return }
        handle(.rangeChanged(requestID: request.id, range: characterRange))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let request = requests.removeValue(forKey: ObjectIdentifier(utterance)) else { return }
        handle(.finished(requestID: request.id))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard let request = requests.removeValue(forKey: ObjectIdentifier(utterance)) else { return }
        handle(.cancelled(requestID: request.id))
    }
}
