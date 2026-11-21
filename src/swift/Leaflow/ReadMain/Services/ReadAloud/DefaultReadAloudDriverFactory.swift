// 原路径: ReadMain/Services/ReadAloud/DefaultReadAloudDriverFactory.swift
// 证据:
//   - PGO: 12 条记录（index/task_functions.csv T-801-04 /
//     DefaultReadAloudDriverFactory.swift；伪代码域 120 行）
//   - CovMap: 上述 L 区段（makeDriver 域 L239-360）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     DefaultReadAloudDriverFactory.c（416 行）
//   - 块体确证（签名域）：
//     init(preferences: ReadAloudPreferences, sources:
//     HttpTtsSourceRepository, synthesizer: HttpTtsSynthesizing) /
//     makeDriver(for: ReadAloudEngineSelection) throws ->
//     ReadAloudDriver L239-360（HttpReadAloudDriver 分派域 L322-
//     L358：playbackContinuation/generation/lastCompletedSegmentIndex/
//     lastPublishedSegmentIndex/didScheduleAllSegments ivar 域）
//   - 事实：引擎选择分派（http 引擎 → HttpReadAloudDriver；
//     system 引擎 → SystemReadAloudDriver）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双签名域 + 分派域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读驱动工厂（init 三参 + makeDriver 签名域确证）。
final class DefaultReadAloudDriverFactory {

    private let preferences: ReadAloudPreferences
    private let sources: HttpTtsSourceRepository
    private let synthesizer: HttpTtsSynthesizing

    /// init(preferences:sources:synthesizer:)（签名域确证）。
    init(
        preferences: ReadAloudPreferences,
        sources: HttpTtsSourceRepository,
        synthesizer: HttpTtsSynthesizing
    ) {
        self.preferences = preferences
        self.sources = sources
        self.synthesizer = synthesizer
    }

    /// makeDriver(for:)（0x 域 L239-360 块体确证：引擎分派域）。
    /// 双构造按真实 init 全参装配——偏好值取自 preferences（wave-16）。
    /// HTTP 源缺失时抛 invalidPayload（仓库错误域）。
    func makeDriver(for selection: ReadAloudEngineSelection) throws
        -> ReadAloudDriver {
        switch selection {
        case .http:
            // HttpReadAloudDriver 分派域 L322-L358 确证。
            guard let source = sources.sources.first else {
                throw HttpTtsSourceRepository.HttpTtsSourceRepositoryError
                    .invalidPayload
            }

            return HttpReadAloudDriver(
                source: source,
                speechRate: preferences.httpRate,
                downloadAhead: preferences.httpDownloadAhead,
                tailTrimMilliseconds: preferences.httpTailTrimMilliseconds,
                synthesizer: synthesizer,
                decoder: HttpTtsAudioDecoder(),
                audioCache: HttpTtsAudioCache(),
                startupTimeoutNanoseconds: 8_000_000_000)
        case .system:
            return SystemReadAloudDriver(
                output: nil,
                voiceIdentifier: "",
                rate: preferences.systemRate,
                pitch: preferences.systemPitch,
                queueAhead: preferences.systemQueueAhead,
                startTimeoutNanoseconds: 8_000_000_000)
        }
    }
}
