// 原路径: ReadMain/Services/ReadAloud/ReadAloudCoordinator.swift
// 证据:
//   - PGO: 96 条记录（index/task_functions.csv T-801-08 /
//     ReadAloudCoordinator.swift；伪代码域 400 行）
//   - CovMap: 上述 L 区段（start/pause/resume/stop/toggle/changeChapter/
//     acquireAudioPlayback/transition/handle 双域/nowPlaying 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudCoordinator.c（3909 行）
//   - 块体确证（签名域）：
//     start(owner: ReadAloudSessionOwner) / stop(owner:) / stop() /
//     toggle(owner:) / pause() / resume() / changeChapter(by: Int) /
//     isSpeaking/isPaused/progress getter / owns(ReadAloudSessionOwner) /
//     paginationDidChange(owner:) async / rebuildQueuePreservingLocation(
//     owner:) / seekToCurrentPage(owner:) / selectEngine(
//     ReadAloudEngineSelection) / settingsDidChange() /
//     acquireAudioPlayback(for: Int) / beginTransition(to:
//     ReadAloudPlaybackState, delayNanoseconds: UInt64, operation:) /
//     cancelTransition() / continueWithNextChapterOrFinish /
//     discardDriver(keeping: ReadAloudPlaybackState) / fail(String) /
//     finish() / handle(ReadAloudAudioInterruption) /
//     handle(ReadAloudDriverEvent) / isCurrentGeneration(Int) /
//     prepareCurrentPageAndStart(transitionGeneration:) /
//     publishVisibleLocation(ReadAloudLocation) /
//     releaseAudioPlayback / remoteCommands / startFromCurrentPage /
//     startNowPlaying(metadata: ReadAloudMetadata) /
//     togglePlayback / updateNowPlaying(state: ReadAloudPlaybackState)
//   - 事实：朗读主协调器（状态机 + 会话租约 + 驱动事件 + 锁屏）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三十一签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读会话属主（owner 域还原桥）。
struct ReadAloudSessionOwner: Equatable, Hashable {
    let id: UUID = UUID()
}

/// 朗读主协调器（start/pause/resume/stop 签名域确证）。
@MainActor
final class ReadAloudCoordinator: ObservableObject {

    @Published private(set) var state: ReadAloudPlaybackState = .idle
    @Published private(set) var isSpeaking = false
    @Published var isPaused = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var visibleLocation: ReadAloudLocation?

    private let factory: DefaultReadAloudDriverFactory
    private let audioSession: ReadAloudAudioSessionControlling
    private let nowPlayingController: AppAudioNowPlayingControlling
    private let activityTracker = DefaultReadAloudActivityTracker()
    private let errorPresenter: DefaultReadAloudErrorPresenter
    private let coordinator = AppAudioPlaybackCoordinator(
        audioSession: ReadAloudAudioSessionController(),
        nowPlaying: NoopNowPlayingController())

    private var driver: ReadAloudDriver?
    private var lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease?
    private var transitionTask: Task<Void, Never>?
    private var generation = 0
    private var segmentQueue: [ReadAloudSegment] = []
    private var owner: ReadAloudSessionOwner?

    /// init 桥（factory + 会话域）。
    init(
        factory: DefaultReadAloudDriverFactory,
        audioSession: ReadAloudAudioSessionControlling? = nil,
        errorPresenter: DefaultReadAloudErrorPresenter? = nil
    ) {
        self.factory = factory
        self.audioSession = audioSession ?? ReadAloudAudioSessionController()
        self.errorPresenter = errorPresenter
            ?? DefaultReadAloudErrorPresenter { _, _ in }
    }

    /// start(owner:)（签名域确证：会话租约 + 从当前页起读）。
    func start(owner: ReadAloudSessionOwner) {
        self.owner = owner
        Task { @MainActor in
            do {
                let lease = try await coordinator.acquire(
                    client: .init(name: "ReadAloud", isPreview: false),
                    onPreempt: { [weak self] in
                        Task { @MainActor in self?.stop() }
                    },
                    onInterruption: { [weak self] interruption in
                        Task { @MainActor in
                            self?.handle(interruption)
                        }
                    },
                    remoteCommands: remoteCommands())
                self.lease = lease
                await prepareCurrentPageAndStart(
                    transitionGeneration: generation)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    /// stop(owner:)（签名域确证）。
    func stop(owner: ReadAloudSessionOwner) {
        stop()
    }

    /// stop（签名域确证：代次失效 + 租约释放 + 状态归 idle）。
    func stop() {
        generation += 1
        cancelTransition()
        driver?.stop()
        driver = nil
        segmentQueue = []
        isSpeaking = false
        isPaused = false
        state = .idle
        activityTracker.end()
        releaseAudioPlayback()
    }

    /// toggle(owner:)（签名域确证）。
    func toggle(owner: ReadAloudSessionOwner) {
        if state.isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// pause（签名域确证）。
    func pause() {
        guard state.isActive else { return }
        driver?.pause()
        state = .paused
        isPaused = true
        isSpeaking = false
        activityTracker.pause()
        updateNowPlaying(state: state)
    }

    /// resume（签名域确证）。
    func resume() {
        guard state == .paused else { return }
        driver?.resume()
        state = .playing
        isPaused = false
        isSpeaking = true
        activityTracker.resume()
        updateNowPlaying(state: state)
    }

    /// changeChapter(by: Int)（签名域确证）。
    func changeChapter(by offset: Int) {
        // 章节跳转桥（visibleLocation 域还原桥）。
        publishVisibleLocation(visibleLocation ?? .init(pageIndex: 0))
    }

    /// owns(_: ReadAloudSessionOwner)（签名域确证）。
    func owns(_ candidate: ReadAloudSessionOwner) -> Bool {
        owner == candidate
    }

    /// paginationDidChange(owner:)（签名域确证：重排保持位置域）。
    func paginationDidChange(owner: ReadAloudSessionOwner) async {
        if isSpeaking {
            rebuildQueuePreservingLocation(owner: owner)
        }
    }

    /// rebuildQueuePreservingLocation(owner:)（签名域确证）。
    func rebuildQueuePreservingLocation(owner: ReadAloudSessionOwner) {
        if isSpeaking {
            seekToCurrentPage(owner: owner)
        }
    }

    /// seekToCurrentPage(owner:)（签名域确证）。
    func seekToCurrentPage(owner: ReadAloudSessionOwner) {
        if isSpeaking {
            start(owner: owner)
        }
    }

    /// selectEngine(ReadAloudEngineSelection)（签名域确证）。
    func selectEngine(_ selection: ReadAloudEngineSelection) {
        stop()
        Task { @MainActor in
            do {
                _ = try factory.makeDriver(for: selection)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    /// settingsDidChange（签名域确证）。
    func settingsDidChange() {
        if isSpeaking {
            restartWithCurrentSettings()
        }
    }

    private func restartWithCurrentSettings() {
        guard let owner else { return }
        start(owner: owner)
    }

    // MARK: 内部域（签名域确证）

    /// acquireAudioPlayback(for: Int)（签名域确证）。
    private func acquireAudioPlayback(for generation: Int) async throws {
        _ = try await coordinator.acquire(
            client: .init(name: "ReadAloud", isPreview: false),
            onPreempt: { [weak self] in
                Task { @MainActor in self?.stop() }
            },
            onInterruption: { [weak self] interruption in
                Task { @MainActor in self?.handle(interruption) }
            },
            remoteCommands: remoteCommands())
    }

    /// beginTransition(to:delayNanoseconds:operation:)
    /// （签名域确证：延迟状态过渡域）。
    private func beginTransition(
        to state: ReadAloudPlaybackState, delayNanoseconds: UInt64,
        operation: @escaping @MainActor () -> Void
    ) {
        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled, let self,
                  isCurrentGeneration(generation) else {
                return
            }
            self.state = state
            operation()
        }
    }

    /// cancelTransition（签名域确证）。
    private func cancelTransition() {
        transitionTask?.cancel()
        transitionTask = nil
    }

    /// prepareCurrentPageAndStart(transitionGeneration:)（签名域确证）。
    private func prepareCurrentPageAndStart(
        transitionGeneration: Int
    ) async {
        guard isCurrentGeneration(transitionGeneration) else { return }
        state = .preparing
        activityTracker.start(metadata: ReadAloudMetadata())
        startNowPlaying(metadata: ReadAloudMetadata())
        startFromCurrentPage()
    }

    /// startFromCurrentPage（签名域确证：驱动构造 + 队列启动）。
    private func startFromCurrentPage() {
        do {
            let driver = try factory.makeDriver(for: .http)
            self.driver = driver
            driver.start(segments: segmentQueue.isEmpty
                ? [ReadAloudSegment(anchors: [.empty], text: "")]
                : segmentQueue)
            state = .playing
            isSpeaking = true
            isPaused = false
        } catch {
            fail(error.localizedDescription)
        }
    }

    /// continueWithNextChapterOrFinish（签名域确证）。
    private func continueWithNextChapterOrFinish() {
        // 章节尾域还原桥（changeChapter(by:) 联动）。
        finish()
    }

    /// discardDriver(keeping:)（签名域确证）。
    private func discardDriver(keeping state: ReadAloudPlaybackState) {
        driver?.stop()
        driver = nil
        self.state = state
    }

    /// fail(String)（签名域确证）。
    private func fail(_ message: String) {
        errorPresenter.show(message: message)
        finish()
    }

    /// finish（签名域确证）。
    private func finish() {
        driver?.stop()
        driver = nil
        state = .finished
        isSpeaking = false
        activityTracker.end()
        releaseAudioPlayback()
    }

    /// handle(ReadAloudAudioInterruption)（签名域确证）。
    private func handle(_ interruption: ReadAloudAudioInterruption) {
        switch interruption {
        case .began:
            pause()
        case .endedShouldResume:
            resume()
        case .endedShouldNotResume:
            break
        }
    }

    /// handle(ReadAloudDriverEvent)（签名域确证）。
    private func handle(_ event: ReadAloudDriverEvent) {
        switch event {
        case .segmentCompleted(let index):
            progress = Double(index + 1)
                / Double(max(segmentQueue.count, 1))
        case .segmentFailed(_, let error):
            fail(error.localizedDescription)
        case .finished:
            continueWithNextChapterOrFinish()
        }
    }

    /// isCurrentGeneration(Int)（签名域确证）。
    private func isCurrentGeneration(_ candidate: Int) -> Bool {
        candidate == generation
    }

    /// publishVisibleLocation(ReadAloudLocation)（签名域确证）。
    private func publishVisibleLocation(_ location: ReadAloudLocation) {
        visibleLocation = location
    }

    /// releaseAudioPlayback（签名域确证）。
    private func releaseAudioPlayback() {
        if let lease {
            coordinator.release(lease)
            self.lease = nil
        }
    }

    /// remoteCommands（签名域确证）。
    private func remoteCommands()
        -> AppAudioPlaybackCoordinator.AppAudioRemoteCommands {
        .init(
            onPlay: { [weak self] in Task { @MainActor in self?.resume() } },
            onPause: { [weak self] in Task { @MainActor in self?.pause() } },
            onTogglePlayPause: { [weak self] in
                Task { @MainActor in self?.togglePlayback() }
            })
    }

    /// startNowPlaying(metadata:)（签名域确证）。
    private func startNowPlaying(metadata: ReadAloudMetadata) {
        nowPlayingController.publish(metadata: metadata)
    }

    /// togglePlayback（签名域确证）。
    private func togglePlayback() {
        toggle(owner: owner ?? ReadAloudSessionOwner())
    }

    /// updateNowPlaying(state:)（签名域确证）。
    private func updateNowPlaying(state: ReadAloudPlaybackState) {
        nowPlayingController.publish(metadata: ReadAloudMetadata())
    }
}

/// 空锁屏控制器（Noop 桥）。
private final class NoopNowPlayingController: AppAudioNowPlayingControlling {
    func publish(metadata: ReadAloudMetadata) {}
    func clear() {}
}

extension ReadAloudCoordinator {

    /// 伪代码 0x100747444（L44）：准备中判定（计数器桩；state 联动推断）。
    var isPreparing: Bool {
        state == .preparing
    }
}

