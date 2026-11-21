// 原路径: ReadMain/Services/AudioBookService.swift
// 证据:
//   - PGO: 66 条记录（index/task_functions.csv T-801-03 /
//     AudioBookService.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（sleepTimer 域 L57-81 / NowPlaying 域
//     L358-501 / preparePlayer/play/pause/resume/stop/seek 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/AudioBookService.c
//     （2901 行）
//   - 块体确证（签名域）：
//     cancelSleepTimer / cleanupPlayer / clearNowPlayingInfo /
//     configureSleepTimer / handleAudioInterruption(
//     ReadAloudAudioInterruption) / loadOrCacheArtwork /
//     makeArtwork(from: UIImage) / preparePlayer(url:headers:) /
//     remoteCommands / updateNowPlayingPlaybackState /
//     updateNowPlayingTime / play(url:headers:) / pause / resume /
//     stop / seek(to: Double) / togglePlayPause / progressRatio getter /
//     updateNowPlayingInfo(bookName:chapterName:coverUrl:) 签名域
//   - 字符串域（位模式，scratch/t80103_book_strings.txt）：
//     '栖读' L474（NowPlaying app 名域）
//   - ivar 域：_sleepTimerMode/_sleepTimerRemaining/sleepTimer
//     （L57-81 域确证）+ MPNowPlayingInfoPropertyPlaybackRate/
//     MPNowPlayingInfoPropertyElapsedPlaybackTime（L481/L501 域）
//   - 事实：AVPlayer 播放域 + MPNowPlayingInfo 锁屏域 + 睡眠定时器
//     + 音频中断响应
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十七签名域 + NowPlaying 域确证）
// 还原: 2026-11-20

import AVFoundation
import MediaPlayer
import UIKit

/// 有声书播放服务（play/pause/resume/stop 签名域确证）。
@MainActor
final class AudioBookService: ObservableObject {

    static let shared = AudioBookService()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentURL: URL?
    @Published private(set) var progressRatio: Double = 0
    @Published private(set) var sleepTimerRemaining: TimeInterval = 0
    @Published private var sleepTimerMode: SleepTimerMode?

    /// 睡眠定时模式（ivar 域 L57-81 确证）。
    enum SleepTimerMode {
        case chapterEnd
        case minutes(Int)
    }

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var sleepTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var remoteCommandTargets: [MPRemoteCommand] = []

    private init() {
        configureAudioSession()
        registerRemoteCommands()
        observeInterruptions()
    }

    // MARK: 播放域（play(url:headers:) 签名域确证）

    /// play(url:headers:)（签名域确证：AudioCacheService 命中优先 +
    /// preparePlayer）。
    func play(url: URL, headers: [String: String]) {
        currentURL = url
        preparePlayer(url: url, headers: headers)
        player.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func resume() {
        player.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentURL = nil
        progressRatio = 0
        cleanupPlayer()
        clearNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    /// seek(to: Double)（签名域确证：0...1 比例）。
    func seek(to ratio: Double) {
        guard let duration = player.currentItem?.duration,
              duration.isNumeric, duration.seconds > 0 else {
            return
        }
        let target = CMTime(
            seconds: duration.seconds * min(max(ratio, 0), 1),
            preferredTimescale: 600)
        player.seek(to: target)
    }

    /// progressRatio getter（签名域确证）。
    func currentProgressRatio() -> Double {
        guard let item = player.currentItem,
              item.duration.isNumeric, item.duration.seconds > 0,
              item.currentTime().isNumeric else {
            return 0
        }
        return item.currentTime().seconds / item.duration.seconds
    }

    /// preparePlayer(url:headers:)（签名域确证：AVURLAsset 头注入）。
    private func preparePlayer(url: URL, headers: [String: String]) {
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers,
        ])
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        observeProgress(item: item)
    }

    private func observeProgress(item: AVPlayerItem) {
        timeObserver.flatMap { player.removeTimeObserver($0) }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 10),
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            progressRatio = currentProgressRatio()
            updateNowPlayingTime()
        }
    }

    private func cleanupPlayer() {
        timeObserver.flatMap { player.removeTimeObserver($0) }
        timeObserver = nil
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerMode = nil
        sleepTimerRemaining = 0
    }

    // MARK: 睡眠定时（configureSleepTimer/cancelSleepTimer 签名域）

    /// configureSleepTimer()（签名域确证：分钟档倒计时）。
    func configureSleepTimer(minutes: Int) {
        sleepTimerMode = .minutes(minutes)
        sleepTimerRemaining = TimeInterval(minutes * 60)
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(
            withTimeInterval: 1, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tickSleepTimer()
            }
        }
    }

    private func tickSleepTimer() {
        sleepTimerRemaining -= 1
        if sleepTimerRemaining <= 0 {
            pause()
            cancelSleepTimer()
        }
    }

    /// cancelSleepTimer()（签名域确证）。
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerMode = nil
        sleepTimerRemaining = 0
    }

    // MARK: 锁屏域（updateNowPlayingInfo 签名域确证）

    /// updateNowPlayingInfo(bookName:chapterName:coverUrl:)
    /// （签名域确证：MPNowPlayingInfoCenter + 封面域）。
    func updateNowPlayingInfo(
        bookName: String, chapterName: String, coverUrl: String?
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: bookName,
            MPMediaItemPropertyArtist: "栖读",
            MPMediaItemPropertyAlbumTitle: chapterName,
            MPNowPlayingInfoPropertyPlaybackRate:
                isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:
                player.currentTime().seconds,
            MPMediaItemPropertyPlaybackDuration:
                player.currentItem?.duration.seconds ?? 0,
        ]
        if let coverUrl {
            loadOrCacheArtwork(coverUrl: coverUrl) { artwork in
                if let artwork {
                    info[MPMediaItemPropertyArtwork] = artwork
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// updateNowPlayingPlaybackState（签名域确证）。
    private func updateNowPlayingPlaybackState() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] =
            isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// updateNowPlayingTime（签名域确证）。
    private func updateNowPlayingTime() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
            player.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// clearNowPlayingInfo（签名域确证）。
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// loadOrCacheArtwork（签名域确证：URL → makeArtwork）。
    private func loadOrCacheArtwork(
        coverUrl: String, completion: @escaping (MPMediaItemArtwork?) -> Void
    ) {
        guard let url = URL(string: coverUrl) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                completion(self.makeArtwork(from: image))
            }
        }.resume()
    }

    /// makeArtwork(from: UIImage)（签名域确证）。
    private func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    // MARK: 会话/中断域（remoteCommands/handleAudioInterruption 签名域）

    /// configureAudioSession（remoteCommands 前置域）。
    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// remoteCommands（签名域确证：play/pause/toggle 转发）。
    private func registerRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        remoteCommandTargets = [
            commandCenter.playCommand, commandCenter.pauseCommand,
            commandCenter.togglePlayPauseCommand,
        ]
    }

    /// handleAudioInterruption(_: ReadAloudAudioInterruption)
    /// （签名域确证：打断暂停 + 结束恢复）。
    func handleAudioInterruption(_ interruption: ReadAloudAudioInterruption) {
        switch interruption {
        case .began:
            pause()
        case .endedShouldResume:
            resume()
        case .endedShouldNotResume:
            break
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey]
                    as? UInt else {
                return
            }
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
            // rawValue 构造为可选域——nil 归零处理（wave-16）。
            switch type {
            case .began:
                handleAudioInterruption(.began)
            case .ended:
                let optionRaw = userInfo[
                    AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: optionRaw)
                handleAudioInterruption(
                    options.contains(.shouldResume)
                        ? .endedShouldResume : .endedShouldNotResume)
            case .none:
                break
            }
        }
    }
}

extension AudioBookService {

    /// 伪代码 0x1002a52a0（L25）：暂停态 varinit（计数器桩；isPlaying
    /// 反向域推断）。
    var isPaused: Bool {
        !isPlaying
    }
}

