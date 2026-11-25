// 原路径: ReadMain/Services/ReadAloud/AVHttpTtsAudioOutput.swift
// 证据:
//   - PGO: 13 条记录（index/task_functions.csv T-801-04 /
//     AVHttpTtsAudioOutput.swift；伪代码域 100 行）
//   - CovMap: 上述 L 区段（engine/player 初始化 L9-46 /
//     schedule 域 L240-248 / prepare/play/pause/stop 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     AVHttpTtsAudioOutput.c（344 行）
//   - 块体确证（签名域）：
//     init() / deinit / prepare(format: ReadAloudAudioFormat) throws /
//     schedule(_: ReadAloudAudioBuffer, completion: @MainActor
//     @Sendable () -> Void) / play() throws / pause() / stop() /
//     engine: AVAudioEngine 初始化域 L9 / player: AVAudioPlayerNode
//     初始化域 L45 / scheduleBuffer:completionCallbackType: 域 L240
//   - 事实：AVAudioEngine + AVAudioPlayerNode 流式播放链
//     （ReadAloudAudioFormat/ReadAloudAudioBuffer → T-801-08
//     ReadAloudModels 分册）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（七签名域 + engine/player 域确证）
// 还原: 2026-11-20

import AVFoundation

/// HTTP TTS AV 音频输出（schedule 0x 域确证：AVAudioEngine +
/// AVAudioPlayerNode 流式调度）。
protocol HttpTtsAudioOutput: AnyObject {
    func prepare(format: ReadAloudAudioFormat) throws
    func schedule(_ buffer: ReadAloudAudioBuffer, completion: @escaping @MainActor @Sendable () -> Void)
    func play() throws
    func pause()
    func stop()
}

final class AVHttpTtsAudioOutput: HttpTtsAudioOutput {

    /// engine/player（variable initialization 域 L9/L45 确证）。
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var isEngineRunning = false
    private var isPaused = false

    init() {
        engine.attach(player)
    }

    deinit {
        engine.stop()
    }

    /// prepare(format:)（签名域确证：引擎启动 + 格式接入）。
    func prepare(format: ReadAloudAudioFormat) throws {
        let target = format.avAudioFormat
        guard let target else {
            throw ReadAloudDriverFactoryError.outputPreparationFailed
        }
        self.format = target
        engine.connect(player, to: engine.mainMixerNode,
                       format: target)
        if !engine.isRunning {
            try engine.start()
            isEngineRunning = true
        }
        isPaused = false
    }

    /// schedule(_:completion:)（0x 域 L240-248 确证：
    /// scheduleBuffer:completionCallbackType:completionHandler:）。
    /// completion @escaping：scheduleBuffer 回调捕获域（wave-16）。
    func schedule(
        _ buffer: ReadAloudAudioBuffer,
        completion: @escaping @MainActor @Sendable () -> Void
    ) {
        guard let format else {
            Task { @MainActor in completion() }
            return
        }
        let pcmBuffer = buffer.pcmBuffer(format: format)
        player.scheduleBuffer(
            pcmBuffer,
            completionCallbackType: .dataPlayedBack
        ) { _ in
            Task { @MainActor in completion() }
        }
    }

    /// play() throws（签名域确证）。
    func play() throws {
        if !engine.isRunning {
            try engine.start()
            isEngineRunning = true
        }
        isPaused = false
        player.play()
    }

    /// pause()（签名域确证）。
    func pause() {
        player.pause()
        isPaused = true
    }

    /// stop()（签名域确证：队列清空 + 引擎停转）。
    func stop() {
        player.stop()
        engine.stop()
        isEngineRunning = false
        isPaused = false
    }
}
