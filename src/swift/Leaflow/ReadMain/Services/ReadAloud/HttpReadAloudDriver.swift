// 原路径: ReadMain/Services/ReadAloud/HttpReadAloudDriver.swift
// 证据:
//   - PGO: 88 条记录（index/task_functions.csv T-801-05 /
//     HttpReadAloudDriver.swift；伪代码域 260 行）
//   - CovMap: 上述 L 区段（init 九参/prepare/schedule/startQueue/
//     waitForPlaybackWindow/publish/markSegmentSettled/resetPlayback/
//     watchdog/pause/resume/stop/seek 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpReadAloudDriver.c（1631 行）
//   - 块体确证（签名域）：
//     init(source: HttpTts, speechRate: Float, downloadAhead: Int,
//     tailTrimMilliseconds: Int, synthesizer: HttpTtsSynthesizing,
//     decoder: HttpTtsAudioDecoding, audioCache: HttpTtsAudioCache,
//     startupTimeoutNanoseconds: UInt64, makeOutput: ...) /
//     start(segments:) / seek(segments:) / pause / resume / stop /
//     prepare(_: ReadAloudSegment, targetFormat: ReadAloudAudioFormat?)
//     async / schedule(slices:) / startQueue(_:) /
//     waitForPlaybackWindow(index:generation:) async /
//     publishCurrentSliceIfNeeded / didCompleteSlice(generation:) /
//     markSegmentSettled(Int) / resetPlayback(releaseOutput: Bool) /
//     scheduleStartupWatchdog(generation: Int)
//   - ivar 域（DefaultReadAloudDriverFactory.c L322-L358 交叉确证）：
//     playbackContinuation/generation/lastCompletedSegmentIndex/
//     lastPublishedSegmentIndex/didScheduleAllSegments
//   - 字符串域（位模式，scratch/t80105_driver_strings.txt）：
//     ' 段已缓存' L479（缓存命中域）
//   - 事实：分段合成 + 切片调度 + 播放窗口门 + 启动看门狗
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十五签名域 + ivar 交叉确证）
// 还原: 2026-11-20

import AVFoundation

/// HTTP 朗读驱动（init 九参签名域确证）。
final class HttpReadAloudDriver: ReadAloudDriver {

    private let source: HttpTts
    private let speechRate: Float
    private let downloadAhead: Int
    private let tailTrimMilliseconds: Int
    private let synthesizer: HttpTtsSynthesizing
    private let decoder: HttpTtsAudioDecoding
    private let audioCache: HttpTtsAudioCache
    private let startupTimeoutNanoseconds: UInt64
    private let makeOutput: () -> AVHttpTtsAudioOutput

    /// ivar 域（factory L322-L358 交叉确证）。
    private var generation = 0
    private var lastCompletedSegmentIndex = -1
    private var lastPublishedSegmentIndex = -1
    private var didScheduleAllSegments = false
    private var playbackContinuation:
        CheckedContinuation<Void, Never>?
    private var output: AVHttpTtsAudioOutput?
    private var segmentQueue: [ReadAloudSegment] = []
    private var queueIndex = 0
    private var isPlaying = false
    private var startupWatchdog: Task<Void, Never>?

    /// init 九参（签名域确证）。
    init(
        source: HttpTts,
        speechRate: Float,
        downloadAhead: Int,
        tailTrimMilliseconds: Int,
        synthesizer: HttpTtsSynthesizing,
        decoder: HttpTtsAudioDecoding,
        audioCache: HttpTtsAudioCache,
        startupTimeoutNanoseconds: UInt64,
        makeOutput: @escaping () -> AVHttpTtsAudioOutput = {
            AVHttpTtsAudioOutput()
        }
    ) {
        self.source = source
        self.speechRate = speechRate
        self.downloadAhead = downloadAhead
        self.tailTrimMilliseconds = tailTrimMilliseconds
        self.synthesizer = synthesizer
        self.decoder = decoder
        self.audioCache = audioCache
        self.startupTimeoutNanoseconds = startupTimeoutNanoseconds
        self.makeOutput = makeOutput
    }

    /// start(segments:)（签名域确证：新代次启动）。
    func start(segments: [ReadAloudSegment]) {
        stop()
        generation += 1
        segmentQueue = segments
        queueIndex = 0
        lastCompletedSegmentIndex = -1
        lastPublishedSegmentIndex = -1
        didScheduleAllSegments = false
        isPlaying = true
        output = makeOutput()
        scheduleStartupWatchdog(generation: generation)
        startQueue(segments)
    }

    /// seek(segments:)（签名域确证：重定位新代次）。
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
        try? output?.play()
    }

    /// stop（签名域确证：代次失效 + 输出释放）。
    func stop() {
        generation += 1
        isPlaying = false
        segmentQueue = []
        queueIndex = 0
        didScheduleAllSegments = false
        resetPlayback(releaseOutput: true)
        startupWatchdog?.cancel()
    }

    /// prepare(_:targetFormat:)（签名域确证：缓存命中 → 合成 → 解码）。
    private func prepare(
        _ segment: ReadAloudSegment,
        targetFormat: ReadAloudAudioFormat?
    ) async throws -> ReadAloudAudioBuffer {
        // ' 段已缓存' L479 域确证：缓存优先。
        if let cached = audioCache.data(
            source: source, text: segment.playbackText,
            speechRate: speechRate) {
            return try await decoder.decode(
                cached, targetFormat: targetFormat?.avAudioFormat)
        }
        let data = try await synthesizer.synthesize(
            source: source, text: segment.playbackText,
            speechRate: speechRate)
        audioCache.insert(
            data, source: source, text: segment.playbackText,
            speechRate: speechRate)
        return try await decoder.decode(
            data, targetFormat: targetFormat?.avAudioFormat)
    }

    /// startQueue(_:)（签名域确证：预取 + 切片调度链）。
    private func startQueue(_ segments: [ReadAloudSegment]) {
        Task { [weak self] in
            guard let self else { return }
            let output = output
            do {
                try await output?.prepare(
                    format: ReadAloudAudioFormat.standard)
            } catch {
                return
            }
            let prefetchLimit = min(downloadAhead, segments.count)
            for (index, segment) in segments.prefix(
                prefetchLimit).enumerated() {
                guard generationCurrent(index: index) else { return }
                await scheduleSegment(segment, index: index)
            }
            await waitForPlaybackWindow(index: 0, generation: generation)
        }
    }

    private func generationCurrent(index: Int) -> Bool {
        queueIndex <= index && isPlaying
    }

    /// scheduleSegment 桥（schedule(slices:) 域还原桥）。
    private func scheduleSegment(_ segment: ReadAloudSegment, index: Int) {
        Task { [weak self] in
            guard let self else { return }
            let buffer: ReadAloudAudioBuffer
            do {
                buffer = try await prepare(
                    segment, targetFormat: ReadAloudAudioFormat.standard)
            } catch {
                markSegmentSettled(index)
                return
            }
            output?.schedule(buffer) { [weak self] in
                Task { @MainActor in
                    self?.didCompleteSlice(generation: self?.generation ?? 0)
                }
            }
        }
    }

    /// schedule(slices:)（签名域确证）。
    private func schedule(slices: [ReadAloudAudioBuffer]) {
        for slice in slices {
            output?.schedule(slice) { [weak self] in
                Task { @MainActor in
                    self?.didCompleteSlice(generation: self?.generation ?? 0)
                }
            }
        }
    }

    /// waitForPlaybackWindow(index:generation:)（签名域确证：
    /// 播放窗口门）。
    private func waitForPlaybackWindow(index: Int, generation: Int) async {
        while queueIndex <= index && isPlaying && self.generation == generation {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    /// didCompleteSlice(generation:)（签名域确证：代次守卫）。
    private func didCompleteSlice(generation: Int) {
        guard generation == self.generation else { return }
        lastCompletedSegmentIndex += 1
        publishCurrentSliceIfNeeded()
        // 预取下一批（downloadAhead 域确证）。
        let nextIndex = lastCompletedSegmentIndex + downloadAhead
        if nextIndex < segmentQueue.count {
            scheduleSegment(segmentQueue[nextIndex], index: nextIndex)
        } else if lastCompletedSegmentIndex >= segmentQueue.count - 1 {
            didScheduleAllSegments = true
        }
    }

    /// publishCurrentSliceIfNeeded（签名域确证：进度发布门）。
    private func publishCurrentSliceIfNeeded() {
        guard lastPublishedSegmentIndex < lastCompletedSegmentIndex else {
            return
        }
        lastPublishedSegmentIndex = lastCompletedSegmentIndex
    }

    /// markSegmentSettled(Int)（签名域确证）。
    private func markSegmentSettled(_ index: Int) {
        if index >= lastCompletedSegmentIndex {
            lastCompletedSegmentIndex = index
        }
    }

    /// resetPlayback(releaseOutput:)（签名域确证）。
    private func resetPlayback(releaseOutput: Bool) {
        output?.stop()
        if releaseOutput {
            output = nil
        }
        lastCompletedSegmentIndex = -1
        lastPublishedSegmentIndex = -1
    }

    /// scheduleStartupWatchdog(generation:)（签名域确证：启动超时域）。
    private func scheduleStartupWatchdog(generation: Int) {
        startupWatchdog?.cancel()
        startupWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?
                .startupTimeoutNanoseconds ?? 8_000_000_000)
            guard !Task.isCancelled, let self,
                  self.generation == generation,
                  lastCompletedSegmentIndex < 0 else {
                return
            }
            // 启动超时：重置当前代次。
            resetPlayback(releaseOutput: false)
        }
    }
}
