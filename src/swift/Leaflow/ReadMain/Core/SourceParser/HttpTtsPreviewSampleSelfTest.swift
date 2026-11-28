// T-1602：生产试听播放器的取消、租约、驱动事件与文件导入边界。
import AVFoundation

enum HttpTtsPreviewSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let source = HttpTts(numericId: 42, name: "试听样本", url: "https://sample.invalid/tts")
        let playback = PreviewSamplePlayback()
        let errors = PreviewSampleErrors()
        let synthesizer = PreviewSampleSynthesizer()
        var drivers: [PreviewSampleDriver] = []
        let player = HttpTtsPreviewPlayer(synthesizer: synthesizer, audioPlayback: playback, errorPresenter: errors,
            makeDriver: { _, passedSynthesizer in
                let driver = PreviewSampleDriver()
                driver.receivedSynthesizer = passedSynthesizer === synthesizer
                drivers.append(driver)
                return driver
            })
        player.play(source: source, text: " \n\u{200b} ")
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_empty_no_audio_lease", ["0", "0", "试听文本为空"],
            [String(playback.acquires), String(drivers.count), player.lastError ?? ""])
        player.play(source: source, text: " 甲\n乙 ")
        await ReadAloudSampleSelfTest.until { drivers.count == 1 }
        guard let first = drivers.first else { emit("tts_preview_setup", ["成功"], ["未创建驱动"]); return }
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_clean_text_and_driver_started", ["甲 乙", "true", "true", "false"],
            [first.segments.first?.text ?? "", String(first.receivedSynthesizer), String(player.isPlaying), String(player.isPreparing)])
        let staleEvent = first.onEvent
        let stalePreempt = playback.preempt
        first.onEvent?(.finished)
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_finish_releases_lease", ["1", "1", "false"],
            [String(playback.releases.count), String(first.stops), String(player.isPlaying)])
        player.play(source: source, text: "新请求")
        await ReadAloudSampleSelfTest.until { drivers.count == 2 }
        staleEvent?(.failed(message: "旧错误"))
        stalePreempt?()
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_stale_event_and_preempt_ignored", ["true", "true", "1"],
            [String(player.isPlaying), String(player.lastError == nil), String(playback.releases.count)])
        drivers.last?.onEvent?(.failed(message: "固定合成错误"))
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_error_stops_and_surfaces", ["false", "固定合成错误", "固定合成错误", "2"],
            [String(player.isPlaying), player.lastError ?? "", errors.messages.last ?? "", String(playback.releases.count)])
        player.play(source: source, text: "中断样本")
        await ReadAloudSampleSelfTest.until { drivers.count == 3 }
        playback.interruption?(.began)
        await ReadAloudSampleSelfTest.settle()
        playback.interruption?(.endedShouldResume)
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_interruption_no_autoresume", ["false", "3"],
            [String(player.isPlaying), String(playback.releases.count)])

        playback.delay = true
        player.play(source: source, text: "取消样本")
        await ReadAloudSampleSelfTest.until { !playback.pending.isEmpty }
        player.stop()
        playback.resolveFirst()
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_cancel_late_lease_released", ["3", "4", "false"],
            [String(drivers.count), String(playback.releases.count), String(player.isPreparing)])
        player.play(source: source, text: "旧排队")
        await ReadAloudSampleSelfTest.until { playback.pending.count == 1 }
        player.play(source: source, text: "新排队")
        await ReadAloudSampleSelfTest.until { playback.pending.count == 2 }
        playback.resolveFirst()
        playback.resolveFirst()
        await ReadAloudSampleSelfTest.until { drivers.count == 4 }
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_latest_request_only", ["4", "新排队", "5", "true"],
            [String(drivers.count), drivers.last?.segments.first?.text ?? "", String(playback.releases.count), String(player.isPlaying)])
        player.stop()
        emit("tts_preview_idempotent_stop", ["6", "6"], [String(playback.releases.count), {
            player.stop(); return String(playback.releases.count)
        }()])

        let output = PreviewSampleOutput()
        playback.delay = false
        let real = HttpTtsPreviewPlayer(synthesizer: synthesizer, audioPlayback: playback, errorPresenter: errors,
            makeDriver: { source, synthesizer in
                HttpReadAloudDriver(source: source, speechRate: 1, downloadAhead: 1, tailTrimMilliseconds: 0,
                    synthesizer: synthesizer, decoder: PreviewSampleDecoder(), audioCache: HttpTtsAudioCache(),
                    startupTimeoutNanoseconds: 5_000_000_000, makeOutput: { output })
            })
        real.play(source: source, text: "实际驱动样本")
        await ReadAloudSampleSelfTest.until { output.completion != nil }
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_real_driver_prepares_audio", ["实际驱动样本", "1", "true"],
            [synthesizer.text, String(output.playCount), String(real.isPlaying)])
        output.completion?()
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_real_driver_finish", ["false", "7"], [String(real.isPlaying), String(playback.releases.count)])
        await verifyLoopback(emit: emit)
        emit("tts_preview_setup", ["成功"], ["成功"])
    }

    @MainActor
    private static func verifyLoopback(emit: (String, [String], [String]) -> Void) async {
        let suite = "tts-preview-loopback-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        guard let raw = ProcessInfo.processInfo.environment["T1602_WS_PORT"],
              let port = Int(raw), (1...65535).contains(port) else {
            emit("tts_preview_loopback_setup", ["成功"], ["缺少回环端口"]); return
        }
        let source = HttpTts(numericId: 1602004, name: "真实WAV试听", url: "http://127.0.0.1:\(port)/preview.wav",
            header: #"{"X-T1602":"fixed"}"#)
        let transport = PreviewLoopbackTransport()
        let synthesizer = HttpTtsSynthesizer(transport: transport, webSocketTransport: URLSessionHttpTtsWebSocketTransport(),
            runtimeStore: HttpTtsRuntimeStore(defaults: defaults))
        let cache = HttpTtsAudioCache(), output = PreviewSampleOutput(), playback = PreviewSamplePlayback()
        let errors = PreviewSampleErrors()
        let player = HttpTtsPreviewPlayer(synthesizer: synthesizer, audioPlayback: playback, errorPresenter: errors,
            makeDriver: { source, synthesizer in
                HttpReadAloudDriver(source: source, speechRate: 1, downloadAhead: 1, tailTrimMilliseconds: 0,
                    synthesizer: synthesizer, decoder: HttpTtsAudioDecoder(), audioCache: cache,
                    startupTimeoutNanoseconds: 5_000_000_000, makeOutput: { output })
            })
        defer { player.stop() }
        player.play(source: source, text: HttpTtsPreviewPlayer.defaultText)
        await ReadAloudSampleSelfTest.until { output.completion != nil || player.lastError != nil }
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_loopback_real_wav_decode", ["1", "2400", "24000", "true", "true"],
            [String(transport.requests), String(output.frames), String(Int(output.sampleRate)),
             String(output.nonzeroPCM), String(player.isPlaying)])
        output.completion?()
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_loopback_completion_releases", ["false", "1", "0"],
            [String(player.isPlaying), String(playback.releases.count), String(errors.messages.count)])
        output.completion = nil
        player.play(source: source, text: HttpTtsPreviewPlayer.defaultText)
        await ReadAloudSampleSelfTest.until { output.completion != nil || player.lastError != nil }
        await ReadAloudSampleSelfTest.settle()
        emit("tts_preview_loopback_audio_cache_reuse", ["1", "2", "1"],
            [String(transport.requests), String(output.playCount), String(cache.count)])
        emit("tts_preview_loopback_setup", ["成功"], [player.lastError ?? "成功"])
    }
}

private final class PreviewLoopbackTransport: HttpTtsTransporting {
    var requests = 0
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests += 1
        return try await URLSession.shared.data(for: request)
    }
}

private final class PreviewSampleDriver: ReadAloudDriver {
    var onEvent: ((ReadAloudDriverEvent) -> Void)?
    var receivedSynthesizer = false
    var segments: [ReadAloudSegment] = []
    var stops = 0
    func start(segments: [ReadAloudSegment]) { self.segments = segments; onEvent?(.started(segmentIndex: 0)) }
    func seek(segments: [ReadAloudSegment]) { start(segments: segments) }
    func pause() {}
    func resume() {}
    func stop() { stops += 1 }
}

private final class PreviewSamplePlayback: AppAudioPlaybackCoordinating {
    var acquires = 0
    var releases: [UUID] = []
    var delay = false
    var pending: [CheckedContinuation<Void, Never>] = []
    var preempt: (() -> Void)?
    var interruption: ((ReadAloudAudioInterruption) -> Void)?
    func acquire(client: AppAudioPlaybackCoordinator.AppAudioPlaybackClient, onPreempt: @escaping () -> Void,
        onInterruption: @escaping (ReadAloudAudioInterruption) -> Void,
        remoteCommands: AppAudioPlaybackCoordinator.AppAudioRemoteCommands) async throws -> AppAudioPlaybackCoordinator.AppAudioPlaybackLease {
        acquires += 1
        preempt = onPreempt
        interruption = onInterruption
        if delay { await withCheckedContinuation { pending.append($0) } }
        return .init(id: UUID(), client: client)
    }
    func resolveFirst() { if !pending.isEmpty { pending.removeFirst().resume() } }
    func release(_ lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease) { releases.append(lease.id) }
    func publishNowPlaying(_ metadata: ReadAloudMetadata) {}
    func updateNowPlaying(state: ReadAloudPlaybackState) {}
}

private final class PreviewSampleErrors: ReadAloudErrorPresenting {
    var messages: [String] = []
    func present(_ error: Error) { show(message: error.localizedDescription) }
    func show(message: String) { messages.append(message) }
}

private final class PreviewSampleSynthesizer: HttpTtsSynthesizing {
    var text = ""
    func synthesize(source: HttpTts, text: String, speechRate: Float) async throws -> Data {
        self.text = text
        return Data([1])
    }
}

private final class PreviewSampleDecoder: HttpTtsAudioDecoding {
    func decode(_ data: Data, targetFormat: AVAudioFormat?) async throws -> ReadAloudAudioBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat!, frameCapacity: 2400)!
        buffer.frameLength = 2400
        return ReadAloudAudioBuffer(buffer)
    }
}

private final class PreviewSampleOutput: HttpTtsAudioOutput {
    var completion: (@MainActor @Sendable () -> Void)?
    var playCount = 0
    var frames: UInt32 = 0
    var sampleRate: Double = 0
    var nonzeroPCM = false
    func prepare(format: ReadAloudAudioFormat) throws {}
    func schedule(_ buffer: ReadAloudAudioBuffer, completion: @escaping @MainActor @Sendable () -> Void) {
        self.completion = completion
        frames = buffer.pcmBuffer.frameLength
        sampleRate = buffer.pcmBuffer.format.sampleRate
        if let channel = buffer.pcmBuffer.floatChannelData?[0] {
            nonzeroPCM = (0..<Int(frames)).contains { abs(channel[$0]) > 0.001 }
        }
    }
    func play() throws { playCount += 1 }
    func pause() {}
    func stop() {}
}
