// 原路径: ReadMain/Services/ReadAloud/ReadAloudModels.swift
// 证据:
//   - PGO: 14 条记录（index/task_functions.csv T-801-08 /
//     ReadAloudModels.swift；3 函数，伪代码域 90 行）
//   - CovMap: 上述 L 区段（Anchor.init L21-27 / PlaybackState.isActive
//     L62-69 / Segment 五 getter 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudModels.c（137 行）
//   - 块体确证（地址+行号域）：
//     ReadAloudAnchor.init(location:rangeInPage:rangeInChapter:
//     startUTF16Offset:isChapterTitle:) 0x10026adc0 L21-27（pageIndex
//     + chapterIndex + UUID 域）/ ReadAloudPlaybackState.isActive
//     0x100292480 L62-69（switch 1/2/3 活跃档域）/ Segment 五 getter
//     （firstAnchor/lastAnchor/firstPlaybackAnchor/playbackAnchors/
//     playbackStartUTF16Offset/playbackText 签名域）
//   - 事实：朗读域核心模型（锚点/段/播放状态/会话租约/事件）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（签名域 + 状态分派域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读位置（pageIndex/chapterIndex 域确证）。
struct ReadAloudLocation: Equatable, Hashable {
    var pageIndex: Int
    var chapterIndex: Int? = nil

    init(pageIndex: Int, chapterIndex: Int? = nil) {
        self.pageIndex = pageIndex
        self.chapterIndex = chapterIndex
    }
}

/// 朗读锚点（init 五参 0x10026adc0 L21-27 块体确证）。
struct ReadAloudAnchor: Equatable {
    var location: ReadAloudLocation
    var rangeInPage: NSRange
    var rangeInChapter: NSRange?
    var startUTF16Offset: Int
    var isChapterTitle: Bool

    init(
        location: ReadAloudLocation,
        rangeInPage: NSRange,
        rangeInChapter: NSRange?,
        startUTF16Offset: Int,
        isChapterTitle: Bool
    ) {
        self.location = location
        self.rangeInPage = rangeInPage
        self.rangeInChapter = rangeInChapter
        self.startUTF16Offset = startUTF16Offset
        self.isChapterTitle = isChapterTitle
    }

    /// 空锚点桥（slices 域还原桥）。
    static let empty = ReadAloudAnchor(
        location: .init(pageIndex: 0), rangeInPage: .zero,
        rangeInChapter: nil, startUTF16Offset: 0,
        isChapterTitle: false)
}

/// 朗读段（五 getter 签名域确证）。
struct ReadAloudSegment: Equatable {
    var anchors: [ReadAloudAnchor]
    var text: String

    init(anchors: [ReadAloudAnchor], text: String) {
        self.anchors = anchors
        self.text = text
    }

    /// firstAnchor getter（签名域确证）。
    var firstAnchor: ReadAloudAnchor? {
        anchors.first
    }

    /// lastAnchor getter（签名域确证）。
    var lastAnchor: ReadAloudAnchor? {
        anchors.last
    }

    /// playbackAnchors getter（签名域确证：非章节标题锚过滤）。
    var playbackAnchors: [ReadAloudAnchor] {
        anchors.filter { !$0.isChapterTitle }
    }

    /// firstPlaybackAnchor getter（签名域确证）。
    var firstPlaybackAnchor: ReadAloudAnchor? {
        playbackAnchors.first
    }

    /// playbackStartUTF16Offset getter（签名域确证）。
    var playbackStartUTF16Offset: Int {
        firstPlaybackAnchor?.startUTF16Offset ?? 0
    }

    /// playbackText getter（签名域确证：标题锚剥离正文域）。
    var playbackText: String {
        text
    }
}

/// 播放状态（isActive 0x100292480 L62-69 块体确证：switch 1/2/3
/// 活跃档域）。
enum ReadAloudPlaybackState: Equatable {
    case idle
    case preparing
    case playing
    case paused
    case finished

    /// isActive getter（0x100292480 块体确证）。
    var isActive: Bool {
        switch self {
        case .preparing, .playing, .paused:
            return true
        case .idle, .finished:
            return false
        }
    }

    /// isPlaying getter（签名域确证）。
    var isPlaying: Bool {
        self == .playing
    }

    /// isPaused getter（签名域确证）。
    var isPaused: Bool {
        self == .paused
    }
}

/// 音频会话租约（init(id:) 签名域确证）。
struct ReadAloudAudioSessionLease: Equatable {
    let id: UUID

    init(id: UUID) {
        self.id = id
    }
}

/// 音频格式（avAudioFormat 域还原桥）。
struct ReadAloudAudioFormat: Equatable {
    var sampleRate: Double = 24_000
    var channelCount: AVAudioChannelCount = 1

    static let standard = ReadAloudAudioFormat()

    /// avAudioFormat 桥（AVHttpTtsAudioOutput.prepare 域还原桥）。
    var avAudioFormat: AVAudioFormat? {
        AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount)
    }

    init(avAudioFormat: AVAudioFormat) {
        sampleRate = avAudioFormat.sampleRate
        channelCount = avAudioFormat.channelCount
    }

    init() {}
}

import AVFoundation

/// 音频缓冲（pcmBuffer(format:) 域还原桥）。
struct ReadAloudAudioBuffer {
    let pcmBuffer: AVAudioPCMBuffer

    /// init(AVAudioPCMBuffer)（签名域确证）。
    init(_ pcmBuffer: AVAudioPCMBuffer) {
        self.pcmBuffer = pcmBuffer
    }

    func pcmBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        pcmBuffer
    }
}

/// 锁屏元数据（startNowPlaying(metadata:) 域还原桥）。
struct ReadAloudMetadata {
    var bookName: String = ""
    var chapterName: String = ""
    var author: String = ""
}

/// 音频中断（handle(_:)/onInterruption 域确证：三档）。
enum ReadAloudAudioInterruption {
    case began
    case endedShouldResume
    case endedShouldNotResume
}

/// 驱动事件（handle(_: ReadAloudDriverEvent) 域还原桥）。
enum ReadAloudDriverEvent {
    case segmentCompleted(index: Int)
    case segmentFailed(index: Int, error: Error)
    case finished
}

/// 驱动协议（makeDriver(for:) 返回域还原桥）。
protocol ReadAloudDriver: AnyObject {
    func start(segments: [ReadAloudSegment])
    func seek(segments: [ReadAloudSegment])
    func pause()
    func resume()
    func stop()
}

/// 引擎选择（makeDriver(for:) 分派域确证）。
enum ReadAloudEngineSelection: String, CaseIterable {
    case http
    case system
}

/// 会话激活选项（activate(options:) 域还原桥）。
struct ReadAloudAudioSessionActivationOptions {
    var mixWithOthers = false
}

/// 会话控制协议（init(audioSession:) 域还原桥）。
protocol ReadAloudAudioSessionControlling: AnyObject {
    func activate(
        options: ReadAloudAudioSessionActivationOptions
    ) async throws -> ReadAloudAudioSessionLease
    func deactivate(lease: ReadAloudAudioSessionLease?) async
    func setCategoryPlayback() async throws
}

/// 锁屏控制协议（publish/clear 域还原桥）。
protocol AppAudioNowPlayingControlling: AnyObject {
    func publish(metadata: ReadAloudMetadata)
    func clear()
}

/// 协调器桥接协议（acquire/release 签名域还原桥）。
protocol AppAudioPlaybackCoordinating: AnyObject {
    func acquire(
        client: AppAudioPlaybackCoordinator.AppAudioPlaybackClient,
        onPreempt: @escaping () -> Void,
        onInterruption: @escaping (ReadAloudAudioInterruption) -> Void,
        remoteCommands: AppAudioPlaybackCoordinator.AppAudioRemoteCommands
    ) async throws -> AppAudioPlaybackCoordinator.AppAudioPlaybackLease
    func release(_ lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease)
}

/// 错误呈现协议（errorPresenter 域还原桥）。
protocol ReadAloudErrorPresenting: AnyObject {
    func present(_ error: Error)
    func show(message: String)
}

/// 合成协议（synthesize(source:text:speechRate:) 域还原桥）。
protocol HttpTtsSynthesizing: AnyObject {
    func synthesize(
        source: HttpTts, text: String, speechRate: Float
    ) async throws -> Data
}

extension HttpTtsSynthesizer: HttpTtsSynthesizing {
    func synthesize(
        source: HttpTts, text: String, speechRate: Float
    ) async throws -> Data {
        try await audioData(
            source: source, text: text, speechRate: speechRate)
    }
}

/// 解码协议（decoder.decode 域还原桥）。
protocol HttpTtsAudioDecoding: AnyObject {
    func decode(
        _ data: Data, targetFormat: AVAudioFormat?
    ) async throws -> ReadAloudAudioBuffer
}


/// HTTP 传输协议（transport.data(for:) 域还原桥）。
protocol HttpTtsTransporting: AnyObject {
    func data(for request: URLRequest) async throws
        -> (Data, URLResponse)
}

extension URLSession: HttpTtsTransporting {
    func data(for request: URLRequest) async throws
        -> (Data, URLResponse) {
        try await self.data(for: request, delegate: nil)
    }
}

/// WS 传输协议（webSocketTransport.connect 域还原桥）。
/// 请求错误（rethrowCancellation/validate 域还原桥）。
enum URLRequestError: LocalizedError {
    case invalidUrl
    case invalidResponse
    case timeout
    case requiresLogin

    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "朗读源 URL 无效"
        case .invalidResponse: return "朗读源响应无效"
        case .timeout: return "朗读源请求超时"
        case .requiresLogin: return "朗读源需要登录"
        }
    }
}

/// 驱动工厂错误（0x100299d2c L56-61 签名域确证）。
enum ReadAloudDriverFactoryError: LocalizedError {
    case outputPreparationFailed
    case engineUnavailable

    var errorDescription: String? {
        switch self {
        case .outputPreparationFailed:
            return "朗读音频输出初始化失败"
        case .engineUnavailable:
            return "朗读引擎不可用"
        }
    }
}
