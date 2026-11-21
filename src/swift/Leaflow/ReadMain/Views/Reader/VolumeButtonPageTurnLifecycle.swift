// 原路径: ReadMain/Views/Reader/VolumeButtonPageTurnLifecycle.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-12 / VolumeButtonPageTurnLifecycle.swift），
//     地址：VolumeButtonPageTurnEligibilityState.allowsMonitoringInReader
//     0x1008dd058 L12-18（isOtherAudioPlaying/secondaryAudioShouldBeSilencedHint/
//     sharedInstance 确证）+ closure 0x1008dcf44 L16（applicationState 确证）/
//     VolumeButtonPageTurnRuntimeState.allowsMonitoring 0x1008dd140 L23-25（defaultCenter
//     确证）/ isAudioPlaybackActive 0x1008dd4dc L27-32（+closure 0x1008dd690 L31）/
//     VolumeButtonPageTurnLifecycleModifier.body 0x1008ddb4c L40-60（+closure #1-#5
//     0x1008dd5f0-8ddda4）/ 第二段 body 0x1008ddda4 L62-70
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/VolumeButtonPageTurnLifecycle.c（589 行）
//   - 事实：资格状态 —— 无其他音频播放（isOtherAudioPlaying/
//     secondaryAudioShouldBeSilencedHint）且应用前台（applicationState）才允许音量键翻页；
//     运行时状态 —— 音频播放活动（isAudioPlaybackActive）+ NotificationCenter；
//     生命周期修饰 —— onChange(资格状态) + 通知 ×3 + onAppear/onDisappear
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（资格链/通知链确证）
// 还原: 2026-11-19

import AVFAudio
import SwiftUI
import UIKit

/// 音量键翻页资格状态（伪代码 0x1008dd058，L12-18）。
enum VolumeButtonPageTurnEligibilityState {

    /// 无其他音频 + 应用前台（确证）。
    static var allowsMonitoringInReader: Bool {
        let session = AVAudioSession.sharedInstance()
        if session.isOtherAudioPlaying {
            return false
        }
        if session.secondaryAudioShouldBeSilencedHint {
            return false
        }
        return UIApplication.shared.applicationState == .active
    }
}

/// 音量键翻页运行时状态（伪代码 0x1008dd140/0x1008dd4dc，L23-32）。
enum VolumeButtonPageTurnRuntimeState {

    static var allowsMonitoring: Bool {
        VolumeButtonPageTurnEligibilityState.allowsMonitoringInReader
    }

    /// 音频播放活动判定（确证）。
    static var isAudioPlaybackActive: Bool {
        AVAudioSession.sharedInstance().isOtherAudioPlaying
    }
}

/// 音量键翻页生命周期修饰（伪代码 0x1008ddb4c，L40-60 + 第二段 L62-70）。
struct VolumeButtonPageTurnLifecycleModifier: ViewModifier {
    @State private var isMonitoringAllowed = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isMonitoringAllowed, initial: true) { _, allowed in
                // closure #1（0x1008dd5f0，L42-44）：资格变化。
                // setEnabled 无独立域——资格启停经 start/stop 对（wave-16）。
                if allowed {
                    VolumeButtonPageTurnMonitor.shared.start(onTurn: { _ in })
                } else {
                    VolumeButtonPageTurnMonitor.shared.stop(restoreVolume: true)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: AVAudioSession.interruptionNotification)) { _ in
                // closure #2（0x1008ddb78，L45-47）：音频中断。
                isMonitoringAllowed = VolumeButtonPageTurnRuntimeState.allowsMonitoring
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification)) { _ in
                // closure #3（0x1008dd7b0，L48-50）：回前台。
                isMonitoringAllowed = VolumeButtonPageTurnRuntimeState.allowsMonitoring
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification)) { _ in
                // closure #4（0x1008dd8c4，L51-53）：失活。
                isMonitoringAllowed = false
            }
            .onAppear {
                // closure #5（0x1008dcec8，L54-56）。
                isMonitoringAllowed = VolumeButtonPageTurnRuntimeState.allowsMonitoring
            }
    }
}
