// 原路径: ReadMain/Services/ReadAloud/HttpTtsPreviewPlayer.swift
// 证据:
//   - PGO: 20 条记录（index/task_functions.csv T-801-06 /
//     HttpTtsPreviewPlayer.swift；伪代码域 130 行）
//   - CovMap: 上述 L 区段（init/play/stop/startDriver/handle 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsPreviewPlayer.c（510 行）
//   - 块体确证（签名域）：
//     init(synthesizer: HttpTtsSynthesizing, audioPlayback:
//     AppAudioPlaybackCoordinating, errorPresenter:
//     ReadAloudErrorPresenting, makeDriver: ...) / play(source:
//     HttpTts, text: String) / stop() / startDriver(source: HttpTts,
//     spokenText: String, generation: Int) / handle(
//     ReadAloudAudioInterruption)
//   - 事实：试听播放器（驱动代次 + 会话租约 + 错误呈现域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（五签名域确证）
// 还原: 2026-11-20

import Foundation
import Combine

/// 朗读源试听播放器（init/play/stop 签名域确证）。
@MainActor
final class HttpTtsPreviewPlayer: ObservableObject {
    // 0x100b0bbfc/0x1012795a0：管理页与编辑页的原版固定试听文本。
    static let defaultText = "这是一段测试文本，用于验证在线朗读源是否正常工作"
    @Published private(set) var isPlaying = false
    @Published private(set) var isPreparing = false
    @Published private(set) var lastError: String?

    private let synthesizer: HttpTtsSynthesizing
    private let audioPlayback: AppAudioPlaybackCoordinating
    private let errorPresenter: ReadAloudErrorPresenting
    private let makeDriver: (HttpTts, HttpTtsSynthesizing) -> ReadAloudDriver

    private var driver: ReadAloudDriver?
    private var generation = 0
    private var lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease?
    private var preparationTask: Task<Void, Never>?

    /// init(synthesizer:audioPlayback:errorPresenter:makeDriver:)
    /// （签名域确证）。
    init(
        synthesizer: HttpTtsSynthesizing,
        audioPlayback: AppAudioPlaybackCoordinating,
        errorPresenter: ReadAloudErrorPresenting,
        makeDriver: @escaping (HttpTts, HttpTtsSynthesizing) -> ReadAloudDriver
    ) {
        self.synthesizer = synthesizer
        self.audioPlayback = audioPlayback
        self.errorPresenter = errorPresenter
        self.makeDriver = makeDriver
    }

    /// play(source:text:)（签名域确证：新代次租约 + 驱动启动）。
    func play(source: HttpTts, text: String) {
        stop()
        lastError = nil
        let spokenText = ReadAloudTextSanitizer.clean(text)
        guard !spokenText.isEmpty else {
            lastError = "试听文本为空"
            errorPresenter.show(message: "试听文本为空")
            return
        }
        isPreparing = true
        let currentGeneration = generation
        preparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let lease = try await audioPlayback.acquire(
                    client: .init(name: "TtsPreview", isPreview: true),
                    onPreempt: { [weak self] in
                        Task { @MainActor in
                            guard self?.generation == currentGeneration else { return }
                            self?.stop()
                        }
                    },
                    onInterruption: { [weak self] interruption in
                        Task { @MainActor in
                            guard self?.generation == currentGeneration else { return }
                            self?.handle(interruption)
                        }
                    },
                    remoteCommands: .init())
                guard generation == currentGeneration, !Task.isCancelled else {
                    audioPlayback.release(lease)
                    return
                }
                self.lease = lease
                startDriver(
                    source: source, spokenText: spokenText,
                    generation: currentGeneration)
            } catch {
                guard generation == currentGeneration, !Task.isCancelled else { return }
                stop()
                lastError = error.localizedDescription
                errorPresenter.present(error)
            }
        }
    }

    /// startDriver(source:spokenText:generation:)（签名域确证）。
    private func startDriver(
        source: HttpTts, spokenText: String, generation: Int
    ) {
        guard self.generation == generation else { return }
        let driver = makeDriver(source, synthesizer)
        self.driver = driver
        driver.onEvent = { [weak self] event in
            Task { @MainActor in self?.consume(event, generation: generation) }
        }
        // 试听段（单段 + 章节标题域）。ReadAloudLocation 为结构体
        // （pageIndex/chapterIndex 域）——零页锚点 + isChapterTitle 标志
        // （wave-16）。
        let anchor = ReadAloudAnchor(
            location: ReadAloudLocation(pageIndex: 0),
            rangeInPage: NSRange(location: 0, length: 0),
            rangeInChapter: nil, startUTF16Offset: 0,
            isChapterTitle: true)
        let segment = ReadAloudSegment(
            anchors: [anchor], text: spokenText)
        driver.start(segments: [segment])
    }

    /// stop（签名域确证：租约释放 + 驱动停转）。
    func stop() {
        generation += 1
        preparationTask?.cancel()
        preparationTask = nil
        driver?.onEvent = nil
        driver?.stop()
        driver = nil
        isPlaying = false
        isPreparing = false
        if let lease {
            audioPlayback.release(lease)
            self.lease = nil
        }
    }

    private func consume(_ event: ReadAloudDriverEvent, generation: Int) {
        guard self.generation == generation else { return }
        switch event {
        case .started:
            isPreparing = false
            isPlaying = true
        case .finished:
            stop()
        case .failed(let message):
            stop()
            lastError = message
            errorPresenter.show(message: message)
        default: break
        }
    }

    /// handle(ReadAloudAudioInterruption)（签名域确证：打断停转）。
    func handle(_ interruption: ReadAloudAudioInterruption) {
        switch interruption {
        case .began:
            stop()
        case .endedShouldResume, .endedShouldNotResume:
            break
        }
    }
}
