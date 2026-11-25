// 原路径: ReadMain/Services/ReadAloud/SystemReadAloudDriver.swift
// 证据: SystemReadAloudDriver.c PGO init/start/seek/pause/resume/stop、入队与看门狗。
// index/swift_types_dump.txt:5360-5397：请求 UUID、段索引、已发布锚点与启动重试字段。
// 本批恢复请求身份、UTF-16 锚点与事件链；真机发声仍需待验清单证据。
import AVFoundation

final class SystemReadAloudDriver: ReadAloudDriver {
    var onEvent: ((ReadAloudDriverEvent) -> Void)?
    private var output: SystemSpeechOutput?
    private let voiceIdentifier: String
    private let rate: Float
    private let pitch: Float
    private let queueAhead: Int
    private let startTimeoutNanoseconds: UInt64
    private let makeOutput: () -> SystemSpeechOutput
    private var segments: [ReadAloudSegment] = []
    private var requestIndices: [UUID: Int] = [:]
    private var publishedAnchorIndices: [UUID: Int] = [:]
    private var nextIndex = 0
    private var generation = 0
    private var isPlaying = false
    private var isPaused = false
    private var didReceiveStart = false
    private var didRetryWithFallbackVoice = false
    private var activeVoiceIdentifier: String
    private var startWatchdog: Task<Void, Never>?

    init(output: SystemSpeechOutput?, voiceIdentifier: String,
        rate: Float, pitch: Float, queueAhead: Int, startTimeoutNanoseconds: UInt64,
        makeOutput: @escaping () -> SystemSpeechOutput = {
            AVSystemSpeechOutput(synthesizer: AVSpeechSynthesizer())
        }) {
        self.output = output
        self.voiceIdentifier = voiceIdentifier
        self.activeVoiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.queueAhead = max(0, queueAhead)
        self.startTimeoutNanoseconds = startTimeoutNanoseconds
        self.makeOutput = makeOutput
    }

    deinit { startWatchdog?.cancel(); output?.stop() }

    private func bindOutput() {
        let token = generation
        output?.onEvent = { [weak self] event in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.handle(event)
            }
        }
    }

    func start(segments: [ReadAloudSegment]) {
        stop()
        self.segments = segments
        activeVoiceIdentifier = voiceIdentifier
        didReceiveStart = false
        didRetryWithFallbackVoice = false
        isPlaying = true
        if output == nil { replaceOutput() } else { bindOutput() }
        enqueueMore()
        scheduleStartWatchdog()
    }

    func seek(segments: [ReadAloudSegment]) { start(segments: segments) }
    func pause() { isPaused = true; output?.pause(); startWatchdog?.cancel() }
    func resume() {
        guard isPlaying else { return }
        isPaused = false
        output?.resume()
        enqueueMore()
        if !didReceiveStart { scheduleStartWatchdog() }
    }

    func stop() {
        generation += 1
        isPlaying = false
        isPaused = false
        segments = []
        nextIndex = 0
        startWatchdog?.cancel()
        resetPlayback(rebindOutput: false)
    }

    private func enqueueMore() {
        guard isPlaying, !isPaused, let output else { return }
        // 当前请求加预读段数，预读为 0 时也必须启动一段。
        while requestIndices.count < queueAhead + 1 && nextIndex < segments.count {
            let index = nextIndex
            nextIndex += 1
            let text = segments[index].playbackText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                onEvent?(.segmentSkipped(segmentIndex: index, message: "朗读段没有正文"))
                continue
            }
            let request = SystemSpeechRequest(text: text, voiceIdentifier: activeVoiceIdentifier,
                rate: rate, pitch: pitch)
            requestIndices[request.id] = index
            output.enqueue(request)
        }
        if nextIndex == segments.count && requestIndices.isEmpty {
            isPlaying = false
            startWatchdog?.cancel()
            onEvent?(.finished)
        }
    }

    private func handle(_ event: SystemSpeechOutputEvent) {
        guard isPlaying else { return }
        switch event {
        case .started(let id):
            guard let index = requestIndices[id] else { return }
            didReceiveStart = true
            startWatchdog?.cancel()
            onEvent?(.started(segmentIndex: index))
            publishAnchor(requestID: id, index: index, offset: 0)
        case .rangeChanged(let id, let range):
            guard let index = requestIndices[id], !isPaused else { return }
            publishAnchor(requestID: id, index: index, offset: range.location)
        case .finished(let id):
            guard requestIndices.removeValue(forKey: id) != nil else { return }
            publishedAnchorIndices.removeValue(forKey: id)
            enqueueMore()
        case .cancelled(let id):
            guard requestIndices.removeValue(forKey: id) != nil else { return }
            publishedAnchorIndices.removeValue(forKey: id)
            stop()
            onEvent?(.failed(message: "系统朗读请求被取消"))
        }
    }

    private func publishAnchor(requestID: UUID, index: Int, offset: Int) {
        let segment = segments[index]
        let absoluteOffset = max(0, offset) + segment.playbackStartUTF16Offset
        guard let anchorIndex = segment.anchors.indices.last(where: {
            $0 >= segment.playbackStartAnchorIndex
                && segment.anchors[$0].startUTF16Offset <= absoluteOffset
        }), publishedAnchorIndices[requestID] != anchorIndex else { return }
        publishedAnchorIndices[requestID] = anchorIndex
        onEvent?(.anchorChanged(segmentIndex: index, anchor: segment.anchors[anchorIndex]))
    }

    private func replaceOutput() { output = makeOutput(); bindOutput() }
    private func replaceQueue(with segments: [ReadAloudSegment]) { start(segments: segments) }

    private func resetPlayback(rebindOutput: Bool) {
        requestIndices.removeAll()
        publishedAnchorIndices.removeAll()
        output?.onEvent = nil
        output?.stop()
        if rebindOutput { replaceOutput() }
    }

    private func scheduleStartWatchdog() {
        startWatchdog?.cancel()
        let token = generation
        startWatchdog = Task { @MainActor [weak self] in
            guard let delay = self?.startTimeoutNanoseconds else { return }
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled, self.generation == token,
                  self.isPlaying, !self.isPaused, !self.didReceiveStart else { return }
            if self.didRetryWithFallbackVoice {
                self.stop()
                self.onEvent?(.failed(message: "系统朗读启动超时"))
                return
            }
            self.didRetryWithFallbackVoice = true
            self.activeVoiceIdentifier = ""
            self.nextIndex = self.requestIndices.values.min() ?? self.nextIndex
            self.generation += 1
            self.resetPlayback(rebindOutput: true)
            self.enqueueMore()
            self.scheduleStartWatchdog()
        }
    }
}
