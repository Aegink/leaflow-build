// 原路径: ReadMain/Services/ReadAloud/HttpTtsAudioPreparer.swift
// 证据:
//   - PGO: 8 条记录（index/task_functions.csv T-801-05 /
//     HttpTtsAudioPreparer.swift；2 函数，伪代码域 130 行）
//   - CovMap: 上述 L 区段（init L25-29 / prepare L36-55 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsAudioPreparer.c（135 行）
//   - 块体确证（地址+行号域）：
//     DefaultHttpTtsAudioPreparer.init(synthesizer:decoder:audioCache:)
//     0x10025f3bc L25-29（AVHttpTtsAudioOutput 元数据域）/
//     prepare(source:text:speechRate:targetFormat:) 0x1002620f4
//     L36-55（缓存门 + 合成 + ReadAloudAudioSessionController.init
//     (backend:mixWithOthers:) 域 + decoder.decode + slices 域）
//   - 事实：合成→解码→切片三段预备链（缓存命中短路）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双签名域 + 会话域确证）
// 还原: 2026-11-20

import AVFoundation

/// 默认朗读音频预备器（init/prepare 签名域确证）。
struct DefaultHttpTtsAudioPreparer {

    private let synthesizer: HttpTtsSynthesizing
    private let decoder: HttpTtsAudioDecoding
    private let audioCache: HttpTtsAudioCache

    /// init(synthesizer:decoder:audioCache:)
    /// （0x10025f3bc L25-29 块体确证）。
    init(
        synthesizer: HttpTtsSynthesizing,
        decoder: HttpTtsAudioDecoding,
        audioCache: HttpTtsAudioCache
    ) {
        self.synthesizer = synthesizer
        self.decoder = decoder
        self.audioCache = audioCache
    }

    /// prepare(source:text:speechRate:targetFormat:)
    /// （0x1002620f4 L36-55 块体确证：缓存门 → 合成 → 解码 → 切片）。
    func prepare(
        source: HttpTts, text: String, speechRate: Float,
        targetFormat: ReadAloudAudioFormat?
    ) async throws -> PreparedHttpTtsAudio {
        // 缓存门（closure #1 in HttpTtsAudioCache.insert 域确证）。
        let data: Data
        if let cached = audioCache.data(
            source: source, text: text, speechRate: speechRate) {
            data = cached
        } else {
            let synthesized = try await synthesizer.synthesize(
                source: source, text: text, speechRate: speechRate)
            audioCache.insert(
                synthesized, source: source, text: text,
                speechRate: speechRate)
            data = synthesized
        }
        // 解码域（decoder.decode 域确证）。
        let buffer = try await decoder.decode(
            data, targetFormat: targetFormat?.avAudioFormat)
        // 会话域（ReadAloudAudioSessionController.init(backend:
        // mixWithOthers:) 域确证）。
        _ = ReadAloudAudioSessionLease(id: UUID())
        return PreparedHttpTtsAudio(
            buffer: buffer, format: targetFormat)
    }
}

/// 预备产物（prepare 返回域还原桥；ReadAloudAudioBuffer → T-801-08）。
struct PreparedHttpTtsAudio {
    let buffer: ReadAloudAudioBuffer
    let format: ReadAloudAudioFormat?
}
