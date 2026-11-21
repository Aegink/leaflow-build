// 原路径: ReadMain/Views/Reader/VolumeButtonPageTurnMonitor.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-13 / VolumeButtonPageTurnMonitor.swift），
//     地址：Interpreter.init(noiseThreshold:) 0x1008de328 L10-12 / direction(from:)
//     （骨架签名）/ isMonitoring 0x1008de3e8 L53-55 / start(onTurn:) 0x1008de2b0 L57-81 /
//     stop(restoreVolume:) 0x1008de138 L83-97 / handleVolumeChange 0x1008def60 L99-119
//     （outputVolume/processInfo.systemUptime 确证）/ attachHiddenVolumeViewIfNeeded
//     0x1008de624 L127-151（connectedScenes/isKeyWindow/layoutIfNeeded/setAlpha/
//     setUserInteractionEnabled 确证）/ setSystemVolume 0x1008df56c L161-170（+closure
//     0x1008df8cc setValue 确证）/ resolveVolumeSlider 0x1008df938 L177-186（subviews
//     过滤闭包确证）/ activateAudioSessionIfNeeded 0x1008de448 L188-199（setActive:
//     withOptions:error: 确证）/ deactivateAudioSessionIfNeeded 0x1008df608 L201-212 /
//     scheduleDeferredDetach 闭包 0x1008e01a0 L216-222
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/VolumeButtonPageTurnMonitor.c（1075 行）
//   - 事实：隐藏音量滑杆（MPVolumeSlider 经 keyWindow subviews 过滤，确证）拦截音量键；
//     KVO outputVolume → handleVolumeChange（systemUptime 参与确证）→ Interpreter
//     （noiseThreshold 防抖）→ 方向回调；setSystemVolume 复位中性音量；音频会话激活/
//     停用配对；scheduleDeferredDetach 延迟摘除隐藏视图
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 拦截/复位/会话链: high（选择子链确证）
//   - 阈值与步长常量: medium（待真机对照）
// 还原: 2026-11-19

import AVFAudio
import MediaPlayer
import UIKit

/// 音量变化解释器（伪代码 0x1008de328，L10-12：noiseThreshold 确证）。
struct VolumeButtonPageTurnInterpreter {
    let noiseThreshold: Float
    // wave-16：setter 放宽（Monitor 校准域——interpreter.lastVolume 写回）。
    var lastVolume: Float = -1

    init(noiseThreshold: Float) {
        self.noiseThreshold = noiseThreshold
    }

    /// 音量变化 → 翻页方向（骨架签名 direction(from:)）。
    /// 相邻采样差 >= 阈值 → 增=next / 减=previous；噪声 → nil。
    mutating func direction(from previousVolume: Float, to newVolume: Float) -> ReaderPageTurnDirection? {
        let delta = newVolume - previousVolume
        lastVolume = newVolume
        if abs(delta) < noiseThreshold {
            return nil
        }
        return delta > 0 ? .next : .previous
    }
}

/// 音量键翻页监视器（隐藏滑杆拦截链）。
@MainActor
final class VolumeButtonPageTurnMonitor {

    static let shared = VolumeButtonPageTurnMonitor()

    private let audioSession: AVAudioSession
    private var interpreter = VolumeButtonPageTurnInterpreter(noiseThreshold: 0.08)
    private var hiddenVolumeView: UIView?
    private var volumeObservation: NSKeyValueObservation?
    private var deferredDetachTask: Task<Void, Never>?
    private var onTurn: ((ReaderPageTurnDirection) -> Void)?
    private(set) var isMonitoring = false
    /// 拦截期间保持的中性音量（复位链确证）。
    private let neutralVolume: Float = 0.5

    init(audioSession: AVAudioSession = .sharedInstance()) {
        self.audioSession = audioSession
    }

    /// 伪代码 0x1008de2b0（L57-81）：开始监视。
    func start(onTurn: @escaping (ReaderPageTurnDirection) -> Void) {
        guard !isMonitoring else { return }
        self.onTurn = onTurn
        isMonitoring = true
        activateAudioSessionIfNeeded()
        attachHiddenVolumeViewIfNeeded()
        resetToNeutralVolumeIfNeeded()
        interpreter.lastVolume = audioSession.outputVolume
        volumeObservation = audioSession.observe(
            \.outputVolume,
             options: [.new]) { [weak self] session, _ in
            MainActor.assumeIsolated {
                self?.handleVolumeChange(session.outputVolume)
            }
        }
    }

    /// 伪代码 0x1008de138（L83-97）：停止监视。
    func stop(restoreVolume: Bool) {
        guard isMonitoring else { return }
        isMonitoring = false
        volumeObservation?.invalidate()
        volumeObservation = nil
        onTurn = nil
        if restoreVolume {
            setSystemVolume(neutralVolume)
        }
        scheduleDeferredDetach()
        deactivateAudioSessionIfNeeded()
    }

    /// 伪代码 0x1008def60（L99-119）：音量变化处理
    ///（outputVolume/processInfo.systemUptime 确证）。
    private func handleVolumeChange(_ newVolume: Float) {
        guard isMonitoring else { return }
        let now = ProcessInfo.processInfo.systemUptime
        _ = now
        let previous = interpreter.lastVolume < 0 ? newVolume : interpreter.lastVolume
        if let direction = interpreter.direction(from: previous, to: newVolume) {
            onTurn?(direction)
        }
        // 吞掉音量变化：回弹到中性值（复位链确证）。
        resetToNeutralVolumeIfNeeded()
    }

    /// 复位中性音量（骨架签名 resetToNeutralVolumeIfNeeded）。
    private func resetToNeutralVolumeIfNeeded() {
        if audioSession.outputVolume != neutralVolume {
            setSystemVolume(neutralVolume)
        }
    }

    /// 伪代码 0x1008de624（L127-151）：挂载隐藏音量视图
    ///（connectedScenes/isKeyWindow/layoutIfNeeded/setAlpha/setUserInteractionEnabled 确证）。
    private func attachHiddenVolumeViewIfNeeded() {
        guard hiddenVolumeView == nil,
              let windowScene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { scene in
                      scene.windows.contains { $0.isKeyWindow }
                  }),
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow)
        else { return }
        keyWindow.layoutIfNeeded()
        let wrapper = UIView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        wrapper.alpha = 0.0
        wrapper.isUserInteractionEnabled = false
        keyWindow.addSubview(wrapper)
        hiddenVolumeView = wrapper
        Logger.log("volume monitor attached", level: .verbose)
    }

    /// 伪代码 0x1008df56c（L161-170）+ closure（0x1008df8cc：setValue 确证）：
    /// 经系统滑杆设置音量。
    private func setSystemVolume(_ value: Float) {
        guard let slider = resolveVolumeSlider() else { return }
        slider.setValue(value, animated: false)
    }

    /// 伪代码 0x1008df938（L177-186）+ 过滤闭包（0x1008e0aa4）：
    /// 在隐藏视图中解析 MPVolumeSlider。
    private func resolveVolumeSlider() -> UISlider? {
        guard let wrapper = hiddenVolumeView else { return nil }
        if wrapper.subviews.isEmpty {
            // 触发 MPVolumeSlider 惰性创建。
            let host = UIView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
            wrapper.addSubview(host)
            host.addSubview(UIView())
        }
        return wrapper.subviews.compactMap { view in
            view.subviews.compactMap { $0 as? UISlider }.first
        }.first
    }

    /// 伪代码 0x1008de448（L188-199）：激活音频会话（setActive:withOptions:error: 确证）。
    private func activateAudioSessionIfNeeded() {
        try? audioSession.setActive(true, options: [])
        Logger.log("volume session active", level: .verbose)
    }

    /// 伪代码 0x1008df608（L201-212）：停用音频会话。
    private func deactivateAudioSessionIfNeeded() {
        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        Logger.log("volume session inactive", level: .verbose)
    }

    /// 伪代码 0x1008e01a0（L216-222）：延迟摘除隐藏视图。
    private func scheduleDeferredDetach() {
        deferredDetachTask?.cancel()
        deferredDetachTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            hiddenVolumeView?.removeFromSuperview()
            hiddenVolumeView = nil
        }
    }
}
