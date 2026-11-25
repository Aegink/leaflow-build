// 原路径: ReadMain/Services/ReadAloud/HttpReadAloudDriver.swift
// 证据: HttpReadAloudDriver.c 的 prepare/schedule/startQueue、播放窗口与启动看门狗 PGO 域。
// DefaultReadAloudDriverFactory.c L322-358 交叉确证代次、已完成/已发布段和调度完成字段。
// 本批恢复全队列有界调度、播放与事件；段内音频时间轴仍按 T-1602 继续核原版。
import AVFoundation

final class HttpReadAloudDriver: ReadAloudDriver {
    var onEvent: ((ReadAloudDriverEvent) -> Void)?
    private let source: HttpTts
    private let speechRate: Float
    private let downloadAhead: Int
    private let tailTrimMilliseconds: Int
    private let synthesizer: HttpTtsSynthesizing
    private let decoder: HttpTtsAudioDecoding
    private let audioCache: HttpTtsAudioCache
    private let startupTimeoutNanoseconds: UInt64
    private let makeOutput: () -> HttpTtsAudioOutput
    private var output: HttpTtsAudioOutput?
    private var generation = 0
    private var segmentQueue: [ReadAloudSegment] = []
    private var scheduledIndices: Set<Int> = []
    private var lastCompletedSegmentIndex = -1
    private var lastPublishedSegmentIndex = -1
    private var didScheduleAllSegments = false
    private var isPlaying = false
    private var isPaused = false
    private var didStartPlayback = false
    private var producerTask: Task<Void, Never>?
    private var startupWatchdog: Task<Void, Never>?

    init(source: HttpTts, speechRate: Float, downloadAhead: Int,
        tailTrimMilliseconds: Int, synthesizer: HttpTtsSynthesizing,
        decoder: HttpTtsAudioDecoding, audioCache: HttpTtsAudioCache,
        startupTimeoutNanoseconds: UInt64,
        makeOutput: @escaping () -> HttpTtsAudioOutput = { AVHttpTtsAudioOutput() }) {
        self.source = source
        self.speechRate = speechRate
        self.downloadAhead = max(1, downloadAhead)
        self.tailTrimMilliseconds = max(0, tailTrimMilliseconds)
        self.synthesizer = synthesizer
        self.decoder = decoder
        self.audioCache = audioCache
        self.startupTimeoutNanoseconds = startupTimeoutNanoseconds
        self.makeOutput = makeOutput
    }

    deinit { producerTask?.cancel(); startupWatchdog?.cancel(); output?.stop() }

    func start(segments: [ReadAloudSegment]) {
        stop()
        segmentQueue = segments
        isPlaying = true
        output = makeOutput()
        startQueue(segments)
        scheduleStartupWatchdog(generation: generation)
    }

    func seek(segments: [ReadAloudSegment]) { start(segments: segments) }
    func pause() { isPaused = true; output?.pause(); startupWatchdog?.cancel() }
    func resume() {
        guard isPlaying else { return }
        isPaused = false
        do {
            if !scheduledIndices.isEmpty {
                try output?.play()
                publishCurrentSliceIfNeeded()
            }
            if !didStartPlayback { scheduleStartupWatchdog(generation: generation) }
        } catch { fail(error.localizedDescription) }
    }

    func stop() {
        generation += 1
        isPlaying = false
        isPaused = false
        producerTask?.cancel()
        producerTask = nil
        startupWatchdog?.cancel()
        segmentQueue = []
        resetPlayback(releaseOutput: true)
    }

    private func prepare(_ segment: ReadAloudSegment,
        targetFormat: ReadAloudAudioFormat?) async throws -> ReadAloudAudioBuffer {
        let data: Data
        if let cached = audioCache.data(source: source, text: segment.playbackText, speechRate: speechRate) {
            data = cached
        } else {
            data = try await synthesizer.synthesize(source: source, text: segment.playbackText, speechRate: speechRate)
            try Task.checkCancellation()
            audioCache.insert(data, source: source, text: segment.playbackText, speechRate: speechRate)
        }
        try Task.checkCancellation()
        let buffer = try await decoder.decode(data, targetFormat: targetFormat?.avAudioFormat)
        let trim = AVAudioFrameCount(buffer.pcmBuffer.format.sampleRate * Double(tailTrimMilliseconds) / 1000)
        if buffer.pcmBuffer.frameLength > trim { buffer.pcmBuffer.frameLength -= trim }
        return buffer
    }

    private func startQueue(_ segments: [ReadAloudSegment]) {
        let token = generation
        producerTask = Task { @MainActor [weak self] in
            guard let self, let output = self.output else { return }
            do {
                try output.prepare(format: .standard)
                for (index, segment) in segments.enumerated() {
                    await self.waitForPlaybackWindow(index: index, generation: token)
                    guard self.generation == token, !Task.isCancelled else { return }
                    guard !segment.playbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        self.markSegmentSettled(index)
                        self.onEvent?(.segmentSkipped(segmentIndex: index, message: "朗读段没有正文"))
                        continue
                    }
                    let buffer = try await self.prepare(segment, targetFormat: .standard)
                    guard self.generation == token, !Task.isCancelled else { return }
                    self.scheduledIndices.insert(index)
                    output.schedule(buffer) { [weak self] in
                        self?.didCompleteSlice(index: index, generation: token)
                    }
                    if !self.isPaused {
                        try output.play()
                        self.publishCurrentSliceIfNeeded()
                    }
                }
                guard self.generation == token, !Task.isCancelled else { return }
                self.didScheduleAllSegments = true
                self.finishIfSettled()
            } catch is CancellationError {
                return
            } catch {
                guard self.generation == token else { return }
                self.fail(error.localizedDescription)
            }
        }
    }

    private func waitForPlaybackWindow(index: Int, generation token: Int) async {
        while generation == token, !Task.isCancelled,
            scheduledIndices.count >= downloadAhead {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func didCompleteSlice(index: Int, generation token: Int) {
        guard token == generation, isPlaying, scheduledIndices.remove(index) != nil else { return }
        markSegmentSettled(index)
        publishCurrentSliceIfNeeded()
        finishIfSettled()
    }

    private func publishCurrentSliceIfNeeded() {
        guard !isPaused, let index = scheduledIndices.min(), lastPublishedSegmentIndex != index else { return }
        lastPublishedSegmentIndex = index
        didStartPlayback = true
        startupWatchdog?.cancel()
        onEvent?(.started(segmentIndex: index))
        if let anchor = segmentQueue[index].firstPlaybackAnchor {
            onEvent?(.anchorChanged(segmentIndex: index, anchor: anchor))
        }
    }

    private func markSegmentSettled(_ index: Int) { lastCompletedSegmentIndex = max(lastCompletedSegmentIndex, index) }

    private func finishIfSettled() {
        guard isPlaying, didScheduleAllSegments, scheduledIndices.isEmpty else { return }
        isPlaying = false
        startupWatchdog?.cancel()
        onEvent?(.finished)
    }

    private func resetPlayback(releaseOutput: Bool) {
        output?.stop()
        if releaseOutput { output = nil }
        scheduledIndices.removeAll()
        lastCompletedSegmentIndex = -1
        lastPublishedSegmentIndex = -1
        didScheduleAllSegments = false
        didStartPlayback = false
    }

    private func fail(_ message: String) { stop(); onEvent?(.failed(message: message)) }

    private func scheduleStartupWatchdog(generation token: Int) {
        startupWatchdog?.cancel()
        startupWatchdog = Task { @MainActor [weak self] in
            guard let delay = self?.startupTimeoutNanoseconds else { return }
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled, self.generation == token,
                self.isPlaying, !self.isPaused, !self.didStartPlayback else { return }
            self.fail("在线朗读启动超时")
        }
    }
}
