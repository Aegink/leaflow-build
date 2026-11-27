// 原路径: ReadMain/Services/ReadAloud/ReadAloudInfrastructure.swift
// 证据:
//   - PGO: 21 条记录（index/task_functions.csv T-801-08 /
//     ReadAloudInfrastructure.swift；伪代码域 240 行）
//   - CovMap: 上述 L 区段（AudioSessionController/ActivityTracker/
//     ErrorPresenter 三域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudInfrastructure.c（651 行）
//   - 块体确证（签名域）：
//     ReadAloudAudioSessionController.init(backend:
//     ReadAloudAudioSessionBackend, mixWithOthers: @MainActor
//     @Sendable () -> Bool) / activate(for: Lease) async throws /
//     deactivate(for: Lease) async / handleInterruption(type:options:) /
//     AVReadAloudAudioSessionBackend.deactivate() /
//     DefaultReadAloudActivityTracker.start(metadata:)/pause/resume/
//     end / DefaultReadAloudErrorPresenter.init(postToast:) /
//     show(message:)
//   - 事实：基础设施三件（会话后端/活动追踪/错误呈现）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十四签名域确证）
// 还原: 2026-11-20

import AVFoundation
import UIKit

/// 会话后端协议（backend 域还原桥）。
protocol ReadAloudAudioSessionBackend: AnyObject {
    func activate() throws
    func deactivate() async
    func setCategoryPlayback() throws
}

/// AV 会话后端（deactivate 签名域确证）。
final class AVReadAloudAudioSessionBackend: ReadAloudAudioSessionBackend {

    init() {}

    func activate() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
    }

    /// deactivate（签名域确证）。
    func deactivate() async {
        try? await AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation)
    }

    func setCategoryPlayback() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio)
    }
}

/// 会话控制器（init(backend:mixWithOthers:)/activate/deactivate/
/// handleInterruption 签名域确证）。
@MainActor
final class ReadAloudAudioSessionController:
    ReadAloudAudioSessionControlling {

    private let backend: ReadAloudAudioSessionBackend
    private let mixWithOthers: @MainActor @Sendable () -> Bool
    private var interruptionObserver: NSObjectProtocol?
    private var onInterruption: ((ReadAloudAudioInterruption) -> Void)?
    private(set) var currentLease: ReadAloudAudioSessionLease?

    /// init(backend:mixWithOthers:)（签名域确证：closure #1 默认
    /// 参数域 + 中断观察 closure 域）。
    init(
        backend: ReadAloudAudioSessionBackend = AVReadAloudAudioSessionBackend(),
        mixWithOthers: @escaping @MainActor @Sendable () -> Bool = { false },
        onInterruption: ((ReadAloudAudioInterruption) -> Void)? = nil
    ) {
        self.backend = backend
        self.mixWithOthers = mixWithOthers
        self.onInterruption = onInterruption
        observeInterruptions()
    }

    deinit {
        interruptionObserver.flatMap {
            NotificationCenter.default.removeObserver($0)
        }
    }

    /// activate(for: Lease)（签名域确证）。
    func activate(
        options: ReadAloudAudioSessionActivationOptions
    ) async throws -> ReadAloudAudioSessionLease {
        if options.mixWithOthers || mixWithOthers() {
            try? AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .spokenAudio,
                options: [.mixWithOthers])
        }
        try backend.activate()
        let lease = ReadAloudAudioSessionLease(id: UUID())
        currentLease = lease
        return lease
    }

    func setCategoryPlayback() async throws {
        try backend.setCategoryPlayback()
    }

    /// deactivate(for:)（签名域确证）。
    func deactivate(lease: ReadAloudAudioSessionLease?) async {
        if currentLease?.id == lease?.id || lease == nil {
            await backend.deactivate()
            currentLease = nil
        }
    }

    /// handleInterruption(type:options:)（签名域确证）。
    private func handleInterruption(type: UInt?, options: UInt) {
        guard let type, let handler = onInterruption else { return }
        let interruption: ReadAloudAudioInterruption
        if type == AVAudioSession.InterruptionType.began.rawValue {
            interruption = .began
        } else {
            let opts = AVAudioSession.InterruptionOptions(rawValue: options)
            interruption = opts.contains(.shouldResume)
                ? .endedShouldResume : .endedShouldNotResume
        }
        handler(interruption)
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let type = userInfo[AVAudioSessionInterruptionTypeKey]
                    as? UInt else {
                return
            }
            let options = userInfo[AVAudioSessionInterruptionOptionKey]
                as? UInt ?? 0
            handleInterruption(type: type, options: options)
        }
    }
}

/// 活动追踪器（start/pause/resume/end 四签名域确证）。
@MainActor
final class DefaultReadAloudActivityTracker {

    private var isStarted = false
    private let listening: ListeningDurationTracker
    private let setIdleTimerDisabled: (Bool) -> Void

    init(listening: ListeningDurationTracker = .shared,
         setIdleTimerDisabled: ((Bool) -> Void)? = nil) {
        self.listening = listening
        self.setIdleTimerDisabled = setIdleTimerDisabled ?? { UIApplication.shared.isIdleTimerDisabled = $0 }
    }

    /// start(metadata:)（签名域确证）。
    func start(metadata: ReadAloudMetadata) {
        isStarted = true
        listening.startSession(bookFingerprint: metadata.bookFingerprint, bookName: metadata.bookName)
        setIdleTimerDisabled(true)
    }

    /// pause（签名域确证）。
    func pause() {
        guard isStarted else { return }
        listening.pauseSession()
        setIdleTimerDisabled(false)
    }

    /// resume（签名域确证）。
    func resume() {
        guard isStarted else { return }
        listening.resumeSession()
        setIdleTimerDisabled(true)
    }

    /// end（签名域确证）。
    func end() {
        isStarted = false
        listening.endSession()
        setIdleTimerDisabled(false)
    }
}

/// 错误呈现器（init(postToast:)/show(message:) 签名域确证）。
@MainActor
final class DefaultReadAloudErrorPresenter: ReadAloudErrorPresenting {

    private let postToast: @MainActor @Sendable (String, Bool) -> Void

    /// init(postToast:)（签名域确证：closure #1 默认参数域）。
    init(
        postToast: @escaping @MainActor @Sendable (String, Bool) -> Void
    ) {
        self.postToast = postToast
    }

    /// show(message:)（签名域确证）。
    func show(message: String) {
        postToast(message, false)
    }

    func present(_ error: Error) {
        show(message: error.localizedDescription)
    }
}
