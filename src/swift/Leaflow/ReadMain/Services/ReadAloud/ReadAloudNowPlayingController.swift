// 原路径: ReadMain/Services/ReadAloud/ReadAloudNowPlayingController.swift
// 证据:
//   - PGO: 48 条记录（index/task_functions.csv T-801-09 /
//     ReadAloudNowPlayingController.swift；伪代码域 200 行）
//   - CovMap: 上述 L 区段（configureCommands 域 L659-1160 /
//     register 域 L1160 / publish/loadArtwork/makeArtwork/remove 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudNowPlayingController.c（1702 行）
//   - 块体确证（签名域）：
//     init() / start(metadata: ReadAloudMetadata) / publish(info:) /
//     update(state: ReadAloudPlaybackState) / stop() / configureCommands(
//     AppAudioRemoteCommands)（closure #10 L1125-1144 域）/
//     register(_: MPRemoteCommand, action:) L1160 /
//     removeCommandTargets / loadArtworkIfNeeded(from: String?) /
//     makeArtwork(UIImage)
//   - 事实：锁屏控制器（MPRemoteCommandCenter 共享域 L659）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十签名域 + 命令域确证）
// 还原: 2026-11-20

import MediaPlayer
import UIKit

/// 锁屏控制（init/start/publish/update/stop 签名域确证）。
final class ReadAloudNowPlayingController: AppAudioNowPlayingControlling {

    private var currentMetadata = ReadAloudMetadata()
    private var registeredCommands: [MPRemoteCommand] = []

    init() {}

    /// start(metadata:)（签名域确证）。
    func start(metadata: ReadAloudMetadata) {
        currentMetadata = metadata
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.bookName,
            MPMediaItemPropertyArtist: metadata.author,
            MPMediaItemPropertyAlbumTitle: metadata.chapterName,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        loadArtworkIfNeeded(from: nil)
    }

    /// publish(info:)（签名域确证）。
    func publish(info: [String: Any]) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// update(state: ReadAloudPlaybackState)（签名域确证）。
    func update(state: ReadAloudPlaybackState) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] =
            state.isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// loadArtworkIfNeeded(from:)（签名域确证）。
    private func loadArtworkIfNeeded(from coverUrl: String?) {
        guard let coverUrl, let url = URL(string: coverUrl) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                let artwork = self.makeArtwork(from: image)
                var info = MPNowPlayingInfoCenter
                    .default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }.resume()
    }

    /// makeArtwork(UIImage)（签名域确证）。
    private func makeArtwork(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    /// AppAudioNowPlayingControlling 桥（metadata 域）。
    func publish(metadata: ReadAloudMetadata) {
        start(metadata: metadata)
    }

    func clear() {
        stop()
    }

    /// stop（签名域确证）。
    func stop() {
        removeCommandTargets()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// configureCommands(AppAudioRemoteCommands)
    /// （0x 域 L1125-1144 确证：MPRemoteCommandCenter.shared L659 +
    /// closure #10 事件域）。
    func configureCommands(
        _ commands: AppAudioPlaybackCoordinator.AppAudioRemoteCommands
    ) {
        let center = MPRemoteCommandCenter.shared()
        removeCommandTargets()
        if let onPlay = commands.onPlay {
            register(center.playCommand) { onPlay() }
        }
        if let onPause = commands.onPause {
            register(center.pauseCommand) { onPause() }
        }
        if let onToggle = commands.onTogglePlayPause {
            register(center.togglePlayPauseCommand) { onToggle() }
        }
        if let onForward = commands.onSeekForward {
            register(center.nextTrackCommand) { onForward() }
        }
        if let onBackward = commands.onSeekBackward {
            register(center.previousTrackCommand) { onBackward() }
        }
    }

    /// register(_:action:)（0x 域 L1160 确证）。
    private func register(
        _ command: MPRemoteCommand,
        action: @escaping () -> Void
    ) {
        let handler = command.addTarget { _ in
            action()
            return .success
        }
        registeredCommands.append(command)
        _ = handler
    }

    /// removeCommandTargets（签名域确证）。
    private func removeCommandTargets() {
        for command in registeredCommands {
            command.removeTargets()
        }
        registeredCommands.removeAll()
    }
}

extension ReadAloudNowPlayingController {

    /// 伪代码 0x100254780（L16-18）：远程命令安装（MPRemoteCommandCenter 域）。
    func install() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in .success }
        center.pauseCommand.addTarget { _ in .success }
        center.togglePlayPauseCommand.addTarget { _ in .success }
    }
}

