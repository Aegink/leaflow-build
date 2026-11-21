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

/// 朗读源试听播放器（init/play/stop 签名域确证）。
@MainActor
final class HttpTtsPreviewPlayer {

    private let synthesizer: HttpTtsSynthesizing
    private let audioPlayback: AppAudioPlaybackCoordinating
    private let errorPresenter: ReadAloudErrorPresenting
    private let makeDriver: (HttpTts, Float) -> HttpReadAloudDriver

    private var driver: HttpReadAloudDriver?
    private var generation = 0
    private var lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease?

    /// init(synthesizer:audioPlayback:errorPresenter:makeDriver:)
    /// （签名域确证）。
    init(
        synthesizer: HttpTtsSynthesizing,
        audioPlayback: AppAudioPlaybackCoordinating,
        errorPresenter: ReadAloudErrorPresenting,
        makeDriver: @escaping (HttpTts, Float) -> HttpReadAloudDriver
    ) {
        self.synthesizer = synthesizer
        self.audioPlayback = audioPlayback
        self.errorPresenter = errorPresenter
        self.makeDriver = makeDriver
    }

    /// play(source:text:)（签名域确证：新代次租约 + 驱动启动）。
    func play(source: HttpTts, text: String) {
        stop()
        generation += 1
        let currentGeneration = generation
        Task { @MainActor in
            do {
                let lease = try await audioPlayback.acquire(
                    client: .init(name: "TtsPreview", isPreview: true),
                    onPreempt: { [weak self] in
                        Task { @MainActor in self?.stop() }
                    },
                    onInterruption: { [weak self] interruption in
                        Task { @MainActor in
                            self?.handle(interruption)
                        }
                    },
                    remoteCommands: .init())
                self.lease = lease
                startDriver(
                    source: source, spokenText: text,
                    generation: currentGeneration)
            } catch {
                errorPresenter.present(error)
            }
        }
    }

    /// startDriver(source:spokenText:generation:)（签名域确证）。
    private func startDriver(
        source: HttpTts, spokenText: String, generation: Int
    ) {
        let driver = makeDriver(source, 1.0)
        self.driver = driver
        // 试听段（单段 + 章节标题域）。
        let anchor = ReadAloudAnchor(
            location: .chapterTitle, rangeInPage: NSRange(location: 0,
                                                          length: 0),
            rangeInChapter: nil, startUTF16Offset: 0,
            isChapterTitle: true)
        let segment = ReadAloudSegment(
            anchors: [anchor], text: spokenText)
        driver.start(segments: [segment])
    }

    /// stop（签名域确证：租约释放 + 驱动停转）。
    func stop() {
        driver?.stop()
        driver = nil
        if let lease {
            audioPlayback.release(lease)
            self.lease = nil
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
