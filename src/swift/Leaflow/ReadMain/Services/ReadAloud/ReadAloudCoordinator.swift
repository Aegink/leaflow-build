// 原路径: ReadMain/Services/ReadAloud/ReadAloudCoordinator.swift
// 证据: index/swift_types_dump.txt:5187（依赖、弱属主、代次与队列）。
// 伪代码 ReadAloudCoordinator.c：0x10089641c L67-78 toggle；
// 0x1008964e4 L80-92 start；其余 PGO 签名见 index/task_functions.csv T-801-08。
// 本批恢复对象身份、正文队列和事件闭环；完整原版分支仍以 T-1602 门禁验收。
import Foundation
import Combine

@MainActor
final class ReadAloudCoordinator: ObservableObject {
    @Published private(set) var state: ReadAloudPlaybackState = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var visibleLocation: ReadAloudLocation?
    @Published private(set) var currentAnchor: ReadAloudAnchor?
    var isSpeaking: Bool { state.isPlaying }
    var isPaused: Bool { state.isPaused }
    var isPreparing: Bool { owner != nil && state == .preparing }

    private let preferences: ReadAloudPreferences
    private let factory: ReadAloudDriverFactory
    private let audioPlayback: AppAudioPlaybackCoordinating
    private let activityTracker: DefaultReadAloudActivityTracker
    private let errorPresenter: ReadAloudErrorPresenting
    private let buildQueue: ([PageData]) async -> [ReadAloudSegment]
    private weak var owner: ReadAloudSessionOwner?
    private var driver: ReadAloudDriver?
    private var lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease?
    private var audioRequestID: UUID?
    private var transitionTask: Task<Void, Never>?
    private var generation = 0
    private var segmentQueue: [ReadAloudSegment] = []
    private var queueSnapshot: ReadAloudQueueSnapshot?
    private var resumeAfterInterruption = false

    init(
        factory: ReadAloudDriverFactory,
        preferences: ReadAloudPreferences,
        audioPlayback: AppAudioPlaybackCoordinating? = nil,
        errorPresenter: ReadAloudErrorPresenting? = nil,
        buildQueue: @escaping ([PageData]) async -> [ReadAloudSegment] = {
            await ReadAloudQueueBuilder.buildOffMain(from: $0, includeChapterTitle: true)
        }
    ) {
        self.factory = factory
        self.preferences = preferences
        self.audioPlayback = audioPlayback ?? AppAudioPlaybackCoordinator(
            audioSession: ReadAloudAudioSessionController(),
            nowPlaying: ReadAloudNowPlayingController())
        self.activityTracker = DefaultReadAloudActivityTracker()
        self.errorPresenter = errorPresenter ?? DefaultReadAloudErrorPresenter {
            message, _ in AppErrorPresenter.shared.warning(message)
        }
        self.buildQueue = buildQueue
    }

    func owns(_ candidate: ReadAloudSessionOwner) -> Bool { owner === candidate }

    func start(owner candidate: ReadAloudSessionOwner) {
        stop()
        owner = candidate
        startFromCurrentPage()
    }

    func stop(owner candidate: ReadAloudSessionOwner) {
        guard owns(candidate) else { return }
        stop()
    }

    func stop() {
        generation += 1
        cancelTransition()
        discardDriver(keeping: .idle)
        owner?.readAloudSaveProgress()
        owner?.readAloudSessionDidFinish()
        owner = nil
        segmentQueue = []
        queueSnapshot = nil
        currentAnchor = nil
        visibleLocation = nil
        progress = 0
        resumeAfterInterruption = false
        activityTracker.end()
        releaseAudioPlayback()
    }

    func toggle(owner candidate: ReadAloudSessionOwner) {
        guard owns(candidate), state.isActive else { start(owner: candidate); return }
        if isPaused { resume() } else { pause() }
    }

    func pause() {
        guard state.isActive, !isPaused else { return }
        generation += 1
        cancelTransition()
        // 驱动回调重新绑定到暂停代次，已排队的旧事件不能改变暂停态。
        if let driver { bind(driver, generation: generation); driver.pause() }
        state = .paused
        owner?.readAloudSaveProgress()
        activityTracker.pause()
        updateNowPlaying(state: state)
    }

    func resume() {
        guard isPaused, owner != nil else { return }
        if let driver {
            state = .playing
            driver.resume()
            activityTracker.resume()
            updateNowPlaying(state: state)
        } else {
            startFromCurrentPage()
        }
    }

    func changeChapter(by offset: Int) {
        guard let owner, state.isActive, offset != 0 else { return }
        let paused = isPaused
        beginTransition(to: .preparing, delayNanoseconds: 0) { [weak self] token in
            guard let self else { return }
            let result = await owner.readAloudChangeChapter(by: offset)
            guard self.isCurrentGeneration(token), self.owns(owner) else { return }
            switch result {
            case .advanced:
                await self.prepareCurrentPageAndStart(transitionGeneration: token, paused: paused)
            case .exhausted:
                self.finish()
            }
        }
    }

    func paginationDidChange(owner candidate: ReadAloudSessionOwner) async {
        guard owns(candidate), state.isActive else { return }
        rebuildQueuePreservingLocation(owner: candidate)
    }

    func rebuildQueuePreservingLocation(owner candidate: ReadAloudSessionOwner) {
        guard owns(candidate), state.isActive else { return }
        let paused = isPaused
        // 重排后页号可能变化，先按章内 UTF-16 位置重新定位属主当前页。
        if let anchor = currentAnchor, let range = anchor.rangeInChapter,
           let page = candidate.readAloudPages.first(where: {
               $0.chapterIndex == anchor.location.chapterIndex
                   && $0.contentRangeInChapter.map { NSLocationInRange(range.location, $0) } == true
           }) {
            candidate.readAloudShow(location: .init(pageIndex: page.pageIndex, chapterIndex: page.chapterIndex))
        }
        startFromCurrentPage(paused: paused)
    }

    func seekToCurrentPage(owner candidate: ReadAloudSessionOwner) {
        guard owns(candidate), state.isActive else { return }
        startFromCurrentPage(paused: isPaused)
    }

    func selectEngine(_ selection: ReadAloudEngineSelection) {
        preferences.selectEngine(selection)
        settingsDidChange()
    }

    func settingsDidChange() {
        guard state.isActive else { return }
        startFromCurrentPage(paused: isPaused)
    }

    private func startFromCurrentPage(paused: Bool = false) {
        beginTransition(to: .preparing, delayNanoseconds: 0) { [weak self] token in
            await self?.prepareCurrentPageAndStart(transitionGeneration: token, paused: paused)
        }
    }

    private func beginTransition(
        to state: ReadAloudPlaybackState, delayNanoseconds: UInt64,
        operation: @escaping @MainActor (Int) async -> Void
    ) {
        generation += 1
        let token = generation
        cancelTransition()
        discardDriver(keeping: state)
        transitionTask = Task { [weak self] in
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            guard let self, !Task.isCancelled, self.isCurrentGeneration(token) else { return }
            await operation(token)
        }
    }

    private func cancelTransition() {
        transitionTask?.cancel()
        transitionTask = nil
    }

    private func acquireAudioPlayback(for token: Int) async throws {
        guard lease == nil else { return }
        let requestID = UUID()
        audioRequestID = requestID
        let acquired = try await audioPlayback.acquire(
            client: .init(name: "ReadAloud", isPreview: false),
            onPreempt: { [weak self] in
                Task { @MainActor in
                    guard let self, self.audioRequestID == requestID else { return }
                    self.stop()
                }
            },
            onInterruption: { [weak self] event in
                Task { @MainActor in
                    guard let self, self.audioRequestID == requestID else { return }
                    self.handle(event)
                }
            }, remoteCommands: remoteCommands())
        guard isCurrentGeneration(token), !Task.isCancelled else {
            audioPlayback.release(acquired)
            throw CancellationError()
        }
        lease = acquired
    }

    private func prepareCurrentPageAndStart(transitionGeneration token: Int, paused: Bool = false) async {
        guard let owner, isCurrentGeneration(token) else { return }
        let allPages = owner.readAloudPages
        let index = owner.readAloudCurrentPageIndex
        guard allPages.indices.contains(index) else { fail("当前阅读页不可朗读"); return }
        let page = allPages[index]
        let pages = allPages.filter { $0.chapterIndex == page.chapterIndex }.sorted { $0.pageIndex < $1.pageIndex }
        let segments = await buildQueue(pages)
        guard isCurrentGeneration(token), owns(owner), !Task.isCancelled else { return }
        queueSnapshot = .init(chapterIndex: page.chapterIndex, segments: segments)
        segmentQueue = queueSnapshot?.segments(startingAt: .init(
            pageIndex: page.pageIndex, chapterIndex: page.chapterIndex)) ?? []
        guard !segmentQueue.isEmpty else { fail("当前章节没有可朗读正文"); return }
        do {
            try await acquireAudioPlayback(for: token)
            guard isCurrentGeneration(token), owns(owner), !Task.isCancelled else { return }
            let driver = try factory.makeDriver(for: preferences.selectedEngine)
            self.driver = driver
            bind(driver, generation: token)
            activityTracker.start(metadata: owner.readAloudMetadata)
            startNowPlaying(metadata: owner.readAloudMetadata)
            driver.start(segments: segmentQueue)
            if paused { driver.pause(); state = .paused; activityTracker.pause() }
            updateNowPlaying(state: state)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentGeneration(token) else { return }
            fail(error.localizedDescription)
        }
    }

    private func bind(_ driver: ReadAloudDriver, generation token: Int) {
        driver.onEvent = { [weak self, weak driver] event in
            Task { @MainActor in
                guard let self, let driver, self.driver === driver,
                      self.isCurrentGeneration(token) else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: ReadAloudDriverEvent) {
        guard owner != nil, state.isActive else { stop(); return }
        switch event {
        case .started(let index):
            if !isPaused { state = .playing }
            progress = Double(index) / Double(max(1, segmentQueue.count))
            updateNowPlaying(state: state)
        case .anchorChanged(let index, let anchor):
            guard !isPaused else { return }
            currentAnchor = anchor
            progress = Double(index) / Double(max(1, segmentQueue.count))
            publishVisibleLocation(anchor.location)
        case .segmentSkipped(let index, let message):
            progress = Double(index + 1) / Double(max(1, segmentQueue.count))
            errorPresenter.show(message: message)
        case .failed(let message): fail(message)
        case .finished:
            if !isPaused { continueWithNextChapterOrFinish() }
        }
    }

    private func continueWithNextChapterOrFinish() {
        guard let owner else { finish(); return }
        beginTransition(to: .preparing, delayNanoseconds: 0) { [weak self] token in
            guard let self else { return }
            let result = await owner.readAloudAdvanceChapter()
            guard self.isCurrentGeneration(token), self.owns(owner) else { return }
            switch result {
            case .advanced: await self.prepareCurrentPageAndStart(transitionGeneration: token)
            case .exhausted: self.finish()
            }
        }
    }

    private func discardDriver(keeping state: ReadAloudPlaybackState) {
        driver?.onEvent = nil
        driver?.stop()
        driver = nil
        self.state = state
    }

    private func fail(_ message: String) {
        stop()
        state = .failed(message: message)
        errorPresenter.show(message: message)
    }

    private func finish() { stop() }
    private func isCurrentGeneration(_ token: Int) -> Bool { generation == token }

    private func publishVisibleLocation(_ location: ReadAloudLocation) {
        visibleLocation = location
        owner?.readAloudShow(location: location)
        owner?.readAloudSaveProgress()
    }

    private func releaseAudioPlayback() {
        audioRequestID = nil
        if let lease { audioPlayback.release(lease); self.lease = nil }
    }

    private func handle(_ interruption: ReadAloudAudioInterruption) {
        switch interruption {
        case .began:
            resumeAfterInterruption = state == .playing || state == .preparing
            pause()
        case .endedShouldResume:
            if resumeAfterInterruption { resume() }
            resumeAfterInterruption = false
        case .endedShouldNotResume: resumeAfterInterruption = false
        }
    }

    private func remoteCommands() -> AppAudioPlaybackCoordinator.AppAudioRemoteCommands {
        .init(onPlay: { [weak self] in Task { @MainActor in self?.resume() } },
            onPause: { [weak self] in Task { @MainActor in self?.pause() } },
            onTogglePlayPause: { [weak self] in Task { @MainActor in self?.togglePlayback() } },
            onSeekForward: { [weak self] in Task { @MainActor in self?.changeChapter(by: 1) } },
            onSeekBackward: { [weak self] in Task { @MainActor in self?.changeChapter(by: -1) } })
    }

    private func togglePlayback() {
        guard let owner else { return }
        toggle(owner: owner)
    }

    private func startNowPlaying(metadata: ReadAloudMetadata) { audioPlayback.publishNowPlaying(metadata) }
    private func updateNowPlaying(state: ReadAloudPlaybackState) { audioPlayback.updateNowPlaying(state: state) }
}
