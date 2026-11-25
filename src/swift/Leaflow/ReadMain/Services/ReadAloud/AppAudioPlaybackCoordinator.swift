// 原路径: ReadMain/Services/ReadAloud/AppAudioPlaybackCoordinator.swift
// 证据:
//   - PGO: 74 条记录（index/task_functions.csv T-801-04 /
//     AppAudioPlaybackCoordinator.swift；伪代码域 260 行）
//   - CovMap: 上述 L 区段（acquire L99-101 / activate / suspend /
//     resume / release / nowPlaying 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     AppAudioPlaybackCoordinator.c（2694 行）
//   - 块体确证（签名域）：
//     init(audioSession: ReadAloudAudioSessionControlling,
//     nowPlaying: AppAudioNowPlayingControlling) / acquire(client:
//     AppAudioPlaybackClient, onPreempt: () -> Void, onInterruption:
//     (ReadAloudAudioInterruption) -> Void, remoteCommands:
//     AppAudioRemoteCommands) async throws -> AppAudioPlaybackLease
//     L99-101 / activate(_: AppAudioPlaybackLease, requestGeneration:
//     Int, action: String) / suspend(lease) / resume(lease) async /
//     release(lease) / startNowPlaying(metadata: ReadAloudMetadata,
//     for: lease) / publishNowPlaying(_:) / clearNowPlaying(for:) /
//     reconfigureMixing() async / installRemoteCommands(for:commands:) /
//     logSession(_:lease:) / SessionState.backendLease getter
//   - 事实：租约抢占协调器（客户端租约 → 会话激活 → 遥控安装 →
//     锁屏发布四段链；ReadAloudAudioInterruption → T-801-08 分册）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十二签名域确证）
// 还原: 2026-11-20

import Foundation
import MediaPlayer

/// 音频播放协调器（acquire 0x 域 L99-101 确证：租约抢占链）。
@MainActor
final class AppAudioPlaybackCoordinator: AppAudioPlaybackCoordinating {

    /// 播放客户端（AppAudioPlaybackClient 签名域确证）。
    struct AppAudioPlaybackClient: Hashable {
        let name: String
        let isPreview: Bool
    }

    /// 远程命令集（AppAudioRemoteCommands 签名域确证）。
    struct AppAudioRemoteCommands {
        var onPlay: (() -> Void)?
        var onPause: (() -> Void)?
        var onTogglePlayPause: (() -> Void)?
        var onSeekForward: (() -> Void)?
        var onSeekBackward: (() -> Void)?
    }

    /// 播放租约（AppAudioPlaybackLease.init(id:client:) 签名域确证）。
    struct AppAudioPlaybackLease: Identifiable {
        let id: UUID
        let client: AppAudioPlaybackClient

        init(id: UUID, client: AppAudioPlaybackClient) {
            self.id = id
            self.client = client
        }
    }

    /// 会话状态（SessionState.backendLease getter 签名域确证）。
    private struct SessionState {
        var activeLease: AppAudioPlaybackLease?
        var backendLease: ReadAloudAudioSessionLease?
        var generation = 0
        var isSuspended = false
    }

    private let audioSession: ReadAloudAudioSessionControlling
    private let nowPlaying: AppAudioNowPlayingControlling
    private var state = SessionState()
    private var preemptHandlers: [UUID: () -> Void] = [:]
    private var interruptionHandlers: [UUID:
        (ReadAloudAudioInterruption) -> Void] = [:]
    private var remoteCommandsByLease:
        [UUID: AppAudioRemoteCommands] = [:]
    private var interruptionObserver: NSObjectProtocol?

    /// init(audioSession:nowPlaying:)（签名域确证）。
    init(
        audioSession: ReadAloudAudioSessionControlling,
        nowPlaying: AppAudioNowPlayingControlling
    ) {
        self.audioSession = audioSession
        self.nowPlaying = nowPlaying
        observeInterruptions()
    }

    /// acquire(client:onPreempt:onInterruption:remoteCommands:)
    /// （0x100 域 L99-101 确证：抢占现租约 → 激活新租约）。
    func acquire(
        client: AppAudioPlaybackClient,
        onPreempt: @escaping () -> Void,
        onInterruption: @escaping (ReadAloudAudioInterruption) -> Void,
        remoteCommands: AppAudioRemoteCommands
    ) async throws -> AppAudioPlaybackLease {
        // 抢占现租约（onPreempt 域确证）。
        if let current = state.activeLease {
            preemptHandlers[current.id]?()
            release(current)
        }
        state.generation += 1
        let lease = AppAudioPlaybackLease(
            id: UUID(), client: client)
        state.activeLease = lease
        // 会话激活（activate 域确证）。
        let token = state.generation
        do {
            try await activate(lease, requestGeneration: token, action: "acquire")
        } catch {
            release(lease)
            throw error
        }
        guard state.generation == token, state.activeLease?.id == lease.id else {
            throw CancellationError()
        }
        preemptHandlers[lease.id] = onPreempt
        interruptionHandlers[lease.id] = onInterruption
        remoteCommandsByLease[lease.id] = remoteCommands
        installRemoteCommands(for: client, commands: remoteCommands)
        logSession("acquire", lease: lease)
        return lease
    }

    /// activate(_:requestGeneration:action:)
    /// （签名域确证：后端会话租约 + 混音配置）。
    private func activate(
        _ lease: AppAudioPlaybackLease, requestGeneration: Int,
        action: String
    ) async throws {
        let options = ReadAloudAudioSessionActivationOptions()
        let backendLease = try await audioSession.activate(options: options)
        guard state.generation == requestGeneration, state.activeLease?.id == lease.id else {
            await audioSession.deactivate(lease: backendLease)
            throw CancellationError()
        }
        state.backendLease = backendLease
        try await reconfigureMixing()
    }

    /// reconfigureMixing（签名域确证：听书/播放模式混音）。
    func reconfigureMixing() async throws {
        try await audioSession.setCategoryPlayback()
    }

    /// suspend(lease)（签名域确证）。
    func suspend(_ lease: AppAudioPlaybackLease) {
        guard state.activeLease?.id == lease.id else { return }
        state.isSuspended = true
        nowPlaying.clear()
    }

    /// resume(lease)（签名域确证：重新激活）。
    func resume(_ lease: AppAudioPlaybackLease) async throws {
        guard state.activeLease?.id == lease.id else { return }
        try await activate(
            lease, requestGeneration: state.generation,
            action: "resume")
        state.isSuspended = false
    }

    /// release(lease)（签名域确证：去激活 + 清锁屏）。
    func release(_ lease: AppAudioPlaybackLease) {
        guard state.activeLease?.id == lease.id else { return }
        let backendLease = state.backendLease
        state.generation += 1
        Task {
            if let backendLease { await audioSession.deactivate(lease: backendLease) }
        }
        state.backendLease = nil
        state.activeLease = nil
        preemptHandlers.removeValue(forKey: lease.id)
        interruptionHandlers.removeValue(forKey: lease.id)
        remoteCommandsByLease.removeValue(forKey: lease.id)
        clearNowPlaying(for: lease)
        logSession("release", lease: lease)
    }

    // MARK: 锁屏域（startNowPlaying/publishNowPlaying/clearNowPlaying
    // 签名域确证）

    /// startNowPlaying(metadata:for:)（签名域确证）。
    func startNowPlaying(
        metadata: ReadAloudMetadata, for lease: AppAudioPlaybackLease
    ) {
        nowPlaying.publish(metadata: metadata)
    }

    /// publishNowPlaying(_:)（签名域确证：进度更新域）。
    func publishNowPlaying(_ metadata: ReadAloudMetadata) {
        nowPlaying.publish(metadata: metadata)
    }

    func updateNowPlaying(state: ReadAloudPlaybackState) {
        (nowPlaying as? ReadAloudNowPlayingController)?.update(state: state)
    }

    /// clearNowPlaying(for:)（签名域确证）。
    func clearNowPlaying(for lease: AppAudioPlaybackLease) {
        nowPlaying.clear()
    }

    // MARK: 内部域（installRemoteCommands/logSession 签名域确证）

    /// installRemoteCommands(for:commands:)（签名域确证）。
    private func installRemoteCommands(
        for client: AppAudioPlaybackClient,
        commands: AppAudioRemoteCommands
    ) {
        let center = MPRemoteCommandCenter.shared()
        (nowPlaying as? ReadAloudNowPlayingController)?.configureCommands(commands)
        center.playCommand.isEnabled = commands.onPlay != nil
        center.pauseCommand.isEnabled = commands.onPause != nil
        center.togglePlayPauseCommand.isEnabled =
            commands.onTogglePlayPause != nil
        center.nextTrackCommand.isEnabled = commands.onSeekForward != nil
        center.previousTrackCommand.isEnabled = commands.onSeekBackward != nil
    }

    /// logSession(_:lease:)（签名域确证：诊断域）。
    private func logSession(_ action: String, lease: AppAudioPlaybackLease) {
        Logger.log("音频会话操作=\(action)，客户端=\(lease.client.name)，租约=\(lease.id)", level: .verbose)
    }

    /// 中断观察（onInterruption 域确证：转发现租约处理器）。
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
            let interruption: ReadAloudAudioInterruption
            if type == .began {
                interruption = .began
            } else {
                let optionRaw = userInfo[
                    AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: optionRaw)
                interruption = options.contains(.shouldResume)
                    ? .endedShouldResume : .endedShouldNotResume
            }
            if let lease = state.activeLease,
               let handler = interruptionHandlers[lease.id] {
                handler(interruption)
            }
        }
    }
}

import AVFoundation

// MARK: - T-1401-15/16 逐域补齐（音频会话域）

extension AppAudioPlaybackCoordinator {

    /// 伪代码 0x1002568e0（L195-198）：Now Playing 信息刷新域。
    func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo =
            MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    }
}

/// 音频播放错误（errorDescription 0x10025a2d4 L296-303 域；容器缺失还原）。
enum AppAudioPlaybackError: LocalizedError {
    case sessionActivationFailed
    case routeUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionActivationFailed:
            return "音频会话激活失败"
        case .routeUnavailable:
            return "音频输出路由不可用"
        }
    }
}

