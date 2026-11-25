// T-1602：直接运行生产队列、协调器和驱动，只替换系统输出、网络和音频 I/O。
import AVFoundation

enum ReadAloudSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let pages = [page(chapter: 0, index: 0, text: " 甲😀 \r\n乙\n", start: 100)]
        let segments = ReadAloudQueueBuilder.build(from: pages, includeChapterTitle: true)
        let segment = segments[0]
        emit("readaloud_queue_utf16", ["第一章\n甲😀\n乙\n", "1:3", "7:1", "101", "4", "8"],
            [segment.text, range(segment.anchors[1].rangeInPage), range(segment.anchors[2].rangeInPage),
             String(segment.anchors[1].rangeInChapter?.location ?? -1),
             String(segment.anchors[1].startUTF16Offset), String(segment.anchors[2].startUTF16Offset)])
        let snapshot = ReadAloudQueueSnapshot(chapterIndex: 0, segments: segments)
        var partial = segment
        partial.playbackStartAnchorIndex = 2
        emit("readaloud_queue_location", ["0", "1", "乙\n", "1"],
            [String(snapshot.segments(startingAt: .init(pageIndex: 0, chapterIndex: 1)).count),
             String(snapshot.segments(startingAt: .init(pageIndex: 0, chapterIndex: 0)).count),
             partial.playbackText, String(partial.playbackAnchors.count)])

        let defaults = UserDefaults(suiteName: "readaloud-selftest-\(UUID())")!
        let preferences = ReadAloudPreferences(defaults: defaults)
        preferences.selectEngine(.http(sourceID: 42))
        preferences.setSystemQueueAhead(0)
        preferences.setHTTPTailTrim(milliseconds: 0)
        let reloaded = ReadAloudPreferences(defaults: defaults)
        emit("readaloud_preferences_roundtrip", ["http", "42", "0", "0"],
            [reloaded.selectedEngine.rawValue, String(reloaded.selectedHTTPSourceID ?? -1),
             String(reloaded.systemQueueAhead), String(reloaded.httpTailTrimMilliseconds)])
        preferences.removeHTTPSelection()

        let output = SampleSpeechOutput()
        let system = SystemReadAloudDriver(output: output, voiceIdentifier: "voice-test",
            rate: 0.5, pitch: 1, queueAhead: 1, startTimeoutNanoseconds: 10_000_000_000)
        var systemEvents: [ReadAloudDriverEvent] = []
        system.onEvent = { systemEvents.append($0) }
        system.start(segments: [segment, segment])
        let first = output.requests[0]
        let second = output.requests[1]
        output.onEvent?(.started(requestID: first.id))
        output.onEvent?(.rangeChanged(requestID: first.id, range: .init(location: 8, length: 1)))
        await settle()
        output.onEvent?(.finished(requestID: first.id))
        output.onEvent?(.finished(requestID: first.id))
        await settle()
        let prematureFinish = finishedCount(systemEvents)
        output.onEvent?(.finished(requestID: second.id))
        await settle()
        emit("readaloud_system_identity", ["true", "voice-test", "0", "1", "7:1"],
            [String(first.id != second.id), first.voiceIdentifier,
             String(prematureFinish), String(finishedCount(systemEvents)),
             systemEvents.compactMap { event -> String? in
                 if case .anchorChanged(_, let anchor) = event { return range(anchor.rangeInPage) }
                 return nil
             }.last ?? "缺失"])
        system.start(segments: [segment])
        let stale = output.onEvent
        let staleID = output.requests.last!.id
        system.stop()
        system.start(segments: [segment])
        systemEvents = []
        stale?(.started(requestID: staleID))
        stale?(.finished(requestID: staleID))
        await settle()
        emit("readaloud_system_stale_event", ["0"], [String(systemEvents.count)])
        system.stop()

        let factory = SampleDriverFactory()
        let playback = SamplePlayback()
        let errors = SampleErrorPresenter()
        let coordinator = ReadAloudCoordinator(factory: factory, preferences: preferences,
            audioPlayback: playback, errorPresenter: errors,
            buildQueue: { ReadAloudQueueBuilder.build(from: $0, includeChapterTitle: true) })
        let owner = SampleOwner()
        let stranger = SampleOwner()
        coordinator.start(owner: owner)
        await until { factory.drivers.count == 1 && coordinator.isSpeaking }
        let driver = factory.drivers[0]
        let oldDriverEvent = driver.onEvent
        coordinator.stop(owner: stranger)
        emit("readaloud_owner_isolation", ["true", "true", "false"],
            [String(coordinator.isSpeaking), String(coordinator.owns(owner)), String(coordinator.owns(stranger))])
        coordinator.pause()
        oldDriverEvent?(.anchorChanged(segmentIndex: 0, anchor: segment.anchors[1]))
        await settle()
        let held = coordinator.isPaused
        coordinator.resume()
        driver.onEvent?(.anchorChanged(segmentIndex: 0, anchor: segment.anchors[1]))
        await settle()
        emit("readaloud_pause_resume", ["true", "true", "1", "true"],
            [String(held), String(coordinator.isSpeaking), String(driver.resumeCount), String(owner.saveCount > 0)])
        driver.onEvent?(.finished)
        await until { factory.drivers.count == 2 && coordinator.isSpeaking }
        let next = factory.drivers[1]
        oldDriverEvent?(.finished)
        await settle()
        let chapterAfterStale = owner.chapter
        next.onEvent?(.finished)
        await until { coordinator.state == .idle }
        emit("readaloud_chapter_finish", ["1", "2", "idle", "true"],
            [String(chapterAfterStale), String(factory.drivers.count),
             coordinator.state == .idle ? "idle" : "未结束", String(owner.finishCount > 0)])

        coordinator.start(owner: owner)
        await until { coordinator.isSpeaking }
        let oldPreempt = playback.preempt
        coordinator.start(owner: stranger)
        await until { coordinator.isSpeaking }
        oldPreempt?()
        await settle()
        emit("readaloud_lease_stale_preempt", ["true", "true"],
            [String(coordinator.isSpeaking), String(coordinator.owns(stranger))])
        playback.preempt?()
        await settle()
        emit("readaloud_lease_preempt", ["true", "true"],
            [String(coordinator.state == .idle), String(playback.releaseCount > 0)])

        let audio = SampleHttpOutput()
        let synth = SampleSynthesizer()
        let http = HttpReadAloudDriver(source: HttpTts(numericId: 42, name: "固定朗读", url: "https://sample.invalid"),
            speechRate: 1, downloadAhead: 1, tailTrimMilliseconds: 0,
            synthesizer: synth, decoder: SampleAudioDecoder(), audioCache: HttpTtsAudioCache(),
            startupTimeoutNanoseconds: 10_000_000_000, makeOutput: { audio })
        var httpEvents: [ReadAloudDriverEvent] = []
        http.onEvent = { httpEvents.append($0) }
        http.start(segments: (0..<3).map { index in
            ReadAloudSegment(anchors: segment.anchors, text: "固定正文\(index)")
        })
        await until { audio.completions.count == 1 }
        let oldCompletion = audio.completions[0]
        http.pause()
        let pauseCount = audio.pauseCount
        http.resume()
        for index in 0..<3 {
            await until { audio.completions.count > index }
            audio.completions[index]()
        }
        await until { finishedCount(httpEvents) == 1 }
        emit("readaloud_http_full_queue", ["3", "3", "1", "true", "1"],
            [String(synth.count), String(audio.completions.count), String(pauseCount),
             String(audio.playCount > 0), String(finishedCount(httpEvents))])
        http.stop()
        httpEvents = []
        oldCompletion()
        await settle()
        emit("readaloud_http_stale_completion", ["0"], [String(httpEvents.count)])

        factory.shouldFail = true
        coordinator.start(owner: owner)
        await until { !coordinator.state.isActive }
        emit("readaloud_factory_failure", ["true", "true"],
            [String(!coordinator.state.isActive), String(!errors.messages.isEmpty)])

        let delayedPlayback = SamplePlayback()
        delayedPlayback.delaysAcquire = true
        let delayedFactory = SampleDriverFactory()
        let delayed = ReadAloudCoordinator(factory: delayedFactory, preferences: preferences,
            audioPlayback: delayedPlayback, errorPresenter: errors,
            buildQueue: { ReadAloudQueueBuilder.build(from: $0, includeChapterTitle: true) })
        delayed.start(owner: owner)
        await until { delayedPlayback.continuation != nil }
        delayed.stop()
        delayedPlayback.continuation?.resume()
        delayedPlayback.continuation = nil
        await settle()
        emit("readaloud_acquire_after_stop", ["0", "1", "true"],
            [String(delayedFactory.drivers.count), String(delayedPlayback.releaseCount), String(delayed.state == .idle)])
    }

    static func range(_ range: NSRange) -> String { "\(range.location):\(range.length)" }
    static func finishedCount(_ events: [ReadAloudDriverEvent]) -> Int {
        events.filter { if case .finished = $0 { return true }; return false }.count
    }
    @MainActor static func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    @MainActor static func until(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    static func page(chapter: Int, index: Int, text: String, start: Int = 0) -> PageData {
        PageData(chapterIndex: chapter, pageIndex: index, content: text,
            contentRangeInChapter: .init(location: start, length: text.utf16.count),
            imageSourceUrl: nil, imageSourceStorageKind: nil, imageBaseUrl: nil, imageStyle: nil,
            chapterTitle: "第一章", isFirstPageOfChapter: index == 0, continuesParagraphOnNextPage: false,
            chapterTotalPages: 1, isLoadingPlaceholder: false, isErrorPlaceholder: false,
            extraLineSpacing: 0, continuationLineFillRatio: 0, continuationTailPreview: "",
            bodyHeight: 100, charCount: text.utf16.count, comments: [])
    }
}

private final class SampleSpeechOutput: SystemSpeechOutput {
    var onEvent: ((SystemSpeechOutputEvent) -> Void)?
    var requests: [SystemSpeechRequest] = []
    func enqueue(_ request: SystemSpeechRequest) { requests.append(request) }
    func pause() {}
    func resume() {}
    func stop() {}
}

@MainActor private final class SampleOwner: ReadAloudSessionOwner {
    var chapter = 0
    var saveCount = 0
    var finishCount = 0
    var readAloudPages: [PageData] { [ReadAloudSampleSelfTest.page(chapter: chapter, index: 0, text: "固定正文")] }
    var readAloudCurrentPageIndex: Int { 0 }
    var readAloudMetadata: ReadAloudMetadata { .init(bookName: "固定书籍", chapterName: "第\(chapter)章", author: "测试作者") }
    func readAloudShow(location: ReadAloudLocation) { chapter = location.chapterIndex }
    func readAloudSaveProgress() { saveCount += 1 }
    func readAloudSessionDidFinish() { finishCount += 1 }
    func readAloudAdvanceChapter() async -> ReadAloudChapterAdvanceResult { await readAloudChangeChapter(by: 1) }
    func readAloudChangeChapter(by delta: Int) async -> ReadAloudChapterChangeResult {
        guard (0..<2).contains(chapter + delta) else { return .exhausted }
        chapter += delta
        return .advanced
    }
}

private final class SampleDriver: ReadAloudDriver {
    var onEvent: ((ReadAloudDriverEvent) -> Void)?
    var resumeCount = 0
    func start(segments: [ReadAloudSegment]) { onEvent?(.started(segmentIndex: 0)) }
    func seek(segments: [ReadAloudSegment]) { start(segments: segments) }
    func pause() {}
    func resume() { resumeCount += 1 }
    func stop() {}
}

@MainActor private final class SampleDriverFactory: ReadAloudDriverFactory {
    var drivers: [SampleDriver] = []
    var shouldFail = false
    func makeDriver(for selection: ReadAloudEngineSelection) throws -> ReadAloudDriver {
        if shouldFail { throw ReadAloudDriverFactoryError.sourceNotFound(42) }
        let driver = SampleDriver()
        drivers.append(driver)
        return driver
    }
}

private final class SamplePlayback: AppAudioPlaybackCoordinating {
    var preempt: (() -> Void)?
    var releaseCount = 0
    var delaysAcquire = false
    var continuation: CheckedContinuation<Void, Never>?
    func acquire(client: AppAudioPlaybackCoordinator.AppAudioPlaybackClient, onPreempt: @escaping () -> Void,
        onInterruption: @escaping (ReadAloudAudioInterruption) -> Void,
        remoteCommands: AppAudioPlaybackCoordinator.AppAudioRemoteCommands) async throws -> AppAudioPlaybackCoordinator.AppAudioPlaybackLease {
        preempt = onPreempt
        if delaysAcquire { await withCheckedContinuation { continuation = $0 } }
        return .init(id: UUID(), client: client)
    }
    func release(_ lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease) { releaseCount += 1 }
    func publishNowPlaying(_ metadata: ReadAloudMetadata) {}
    func updateNowPlaying(state: ReadAloudPlaybackState) {}
}

private final class SampleErrorPresenter: ReadAloudErrorPresenting {
    var messages: [String] = []
    func present(_ error: Error) { show(message: error.localizedDescription) }
    func show(message: String) { messages.append(message) }
}

private final class SampleSynthesizer: HttpTtsSynthesizing {
    var count = 0
    func synthesize(source: HttpTts, text: String, speechRate: Float) async throws -> Data {
        count += 1
        return Data(text.utf8)
    }
}

private final class SampleAudioDecoder: HttpTtsAudioDecoding {
    func decode(_ data: Data, targetFormat: AVAudioFormat?) async throws -> ReadAloudAudioBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat!, frameCapacity: 2400)!
        buffer.frameLength = 2400
        return ReadAloudAudioBuffer(buffer)
    }
}

private final class SampleHttpOutput: HttpTtsAudioOutput {
    var completions: [@MainActor @Sendable () -> Void] = []
    var playCount = 0
    var pauseCount = 0
    func prepare(format: ReadAloudAudioFormat) throws {}
    func schedule(_ buffer: ReadAloudAudioBuffer, completion: @escaping @MainActor @Sendable () -> Void) { completions.append(completion) }
    func play() throws { playCount += 1 }
    func pause() { pauseCount += 1 }
    func stop() {}
}
