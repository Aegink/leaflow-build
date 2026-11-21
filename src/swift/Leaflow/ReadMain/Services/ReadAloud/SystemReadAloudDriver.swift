// 原路径: ReadMain/Services/ReadAloud/SystemReadAloudDriver.swift
// 证据:
//   - PGO: 40 条记录（index/task_functions.csv T-801-10 /
//     SystemReadAloudDriver.swift；伪代码域 240 行）
//   - CovMap: 上述 L 区段（init 七参/start/seek/pause/resume/stop/
//     enqueueMore/handle/rebind/queue/watchdog 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     SystemReadAloudDriver.c（855 行）
//   - 块体确证（签名域）：
//     init(output: SystemSpeechOutput?, voiceIdentifier: String,
//     rate: Float, pitch: Float, queueAhead: Int,
//     startTimeoutNanoseconds: UInt64, makeOutput: ...) /
//     start(segments:) / seek(segments:) / pause / resume / stop /
//     bindOutput() / enqueueMore() / handle(SystemSpeechOutputEvent) /
//     replaceOutput() / replaceQueue(with:) /
//     resetPlayback(rebindOutput: Bool) / scheduleStartWatchdog
//   - 事实：系统朗读驱动（AVSpeechSynthesizer 队列域 + 看门狗）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十四签名域确证）
// 还原: 2026-11-20

import AVFoundation

/// 系统朗读驱动（init 七参签名域确证）。
final class SystemReadAloudDriver: ReadAloudDriver {

    private var output: SystemSpeechOutput?
    private let voiceIdentifier: String
    private let rate: Float
    private let pitch: Float
    private let queueAhead: Int
    private let startTimeoutNanoseconds: UInt64
    private let makeOutput: () -> SystemSpeechOutput

    private var segments: [ReadAloudSegment] = []
    private var nextIndex = 0
    private var generation = 0
    private var isPlaying = false
    private var startWatchdog: Task<Void, Never>?

    /// init 七参（签名域确证）。
    init(
        output: SystemSpeechOutput?,
        voiceIdentifier: String,
        rate: Float,
        pitch: Float,
        queueAhead: Int,
        startTimeoutNanoseconds: UInt64,
        makeOutput: @escaping () -> SystemSpeechOutput = {
            SystemSpeechOutput(synthesizer: AVSpeechSynthesizer())
        }
    ) {
        self.output = output
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.queueAhead = queueAhead
        self.startTimeoutNanoseconds = startTimeoutNanoseconds
        self.makeOutput = makeOutput
        bindOutput()
    }

    deinit {
        output?.stop()
    }

    /// bindOutput（签名域确证：事件链桥）。
    private func bindOutput() {
        output?.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    /// start(segments:)（签名域确证：新代次启动）。
    func start(segments: [ReadAloudSegment]) {
        stop()
        generation += 1
        self.segments = segments
        nextIndex = 0
        isPlaying = true
        if output == nil {
            replaceOutput()
        } else {
            bindOutput()
        }
        scheduleStartWatchdog()
        enqueueMore()
    }

    /// seek(segments:)（签名域确证）。
    func seek(segments: [ReadAloudSegment]) {
        start(segments: segments)
    }

    /// pause（签名域确证）。
    func pause() {
        isPlaying = false
        output?.pause()
    }

    /// resume（签名域确证）。
    func resume() {
        isPlaying = true
        output?.resume()
        enqueueMore()
    }

    /// stop（签名域确证）。
    func stop() {
        generation += 1
        isPlaying = false
        segments = []
        nextIndex = 0
        resetPlayback(rebindOutput: false)
        startWatchdog?.cancel()
    }

    /// enqueueMore（签名域确证：queueAhead 预入队域）。
    /// 队列长度经 pendingCount 桥（queue 私有域，wave-16）。
    private func enqueueMore() {
        guard isPlaying, let output else { return }
        let enqueued = output.pendingCount
        let inFlight = activeRequest == nil ? 0 : 1
        let target = queueAhead - enqueued - inFlight
        for _ in 0..<max(target, 0) {
            guard nextIndex < segments.count else { return }
            let segment = segments[nextIndex]
            nextIndex += 1
            let request = SystemSpeechRequest(
                text: segment.playbackText, rate: rate, pitch: pitch)
            output.enqueue(request)
        }
    }

    private var activeRequest: SystemSpeechRequest?

    /// handle(SystemSpeechOutputEvent)（签名域确证：事件分派域）。
    private func handle(_ event: SystemSpeechOutput.DelegateEvent) {
        switch event {
        case .started(let request):
            activeRequest = request
        case .willSpeak:
            break
        case .finished, .cancelled:
            activeRequest = nil
            guard nextIndex < segments.count else {
                isPlaying = false
                return
            }
            enqueueMore()
        }
    }

    /// replaceOutput（签名域确证：输出重建桥）。
    private func replaceOutput() {
        output = makeOutput()
        bindOutput()
    }

    /// replaceQueue(with:)（签名域确证）。
    private func replaceQueue(with segments: [ReadAloudSegment]) {
        self.segments = segments
        nextIndex = 0
        output?.stop()
        enqueueMore()
    }

    /// resetPlayback(rebindOutput:)（签名域确证）。
    private func resetPlayback(rebindOutput: Bool) {
        output?.stop()
        if rebindOutput {
            replaceOutput()
        }
        activeRequest = nil
    }

    /// scheduleStartWatchdog（签名域确证：启动看门狗域）。
    private func scheduleStartWatchdog() {
        startWatchdog?.cancel()
        startWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?
                .startTimeoutNanoseconds ?? 8_000_000_000)
            guard !Task.isCancelled, let self, isPlaying,
                  nextIndex == 0 else {
                return
            }
            // 启动超时：重绑输出域。
            resetPlayback(rebindOutput: true)
            enqueueMore()
        }
    }
}

/// 系统语音请求（enqueue(SystemSpeechRequest) 域还原桥）。
struct SystemSpeechRequest: Equatable {
    let text: String
    let rate: Float
    let pitch: Float
    let language: String?
    let volume: Float

    init(
        text: String, rate: Float, pitch: Float,
        language: String? = nil, volume: Float = 1.0
    ) {
        self.text = text
        self.rate = rate
        self.pitch = pitch
        self.language = language
        self.volume = volume
    }
}
