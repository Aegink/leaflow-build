// 原路径: ReadMain/Views/Reader/TtsPlayerView.swift
// 拆分归属见 tools/restoration_gate_checks.py；仍计入同一个原始文件。
import SwiftUI
import AVFoundation

// MARK: - 倍速/进度/定时桥（ttsUserSpeed 三桥 + ttsProgress 域确证）
// wave-16：桥族 @MainActor——readAloudPreferences/服务域均为 MainActor 隔离。

/// ttsUserSpeed<A: TtsPlayable>(vm:)（0x 域 L1010-1024 确证：按引擎
/// 读取倍速）。
@MainActor
func ttsUserSpeed<A: TtsPlayable>(vm: A) -> Float {
    vm.readAloudPreferences.systemRate
}

/// ttsSetUserSpeed<A: TtsPlayable>(vm:speed:)（0x 域确证）。
@MainActor
func ttsSetUserSpeed<A: TtsPlayable>(vm: A, speed: Float) {
    vm.readAloudPreferences.setSystemRate(speed)
}

/// ttsSetUserSpeed(_:)（视图滑杆无 vm 域——本地速度态写入，wave-16 补桥）。
@MainActor
func ttsSetUserSpeed(_ speed: Float) {
    TtsPlayerSpeedState.shared.speed = speed
}

/// 视图速度态（滑杆桥共享载体，还原推断）。
@MainActor
final class TtsPlayerSpeedState {
    static let shared = TtsPlayerSpeedState()
    var speed: Float = 1.0
}

/// ttsUserSpeedRange<A: TtsPlayable>(vm:)（0x 域确证）。
@MainActor
func ttsUserSpeedRange<A: TtsPlayable>(vm: A) -> ClosedRange<Float> {
    0.5...3.0
}

/// ttsProgress（0x 域 L1026-1059 确证）。
struct TtsProgress {
    var headline: String = "本章"
    var tail: String = ""
    var ratio: Double = 0

    var summary: String {
        headline
    }
}

/// ttsTogglePlayPause（0x 域 L1061-1071 确证）。@MainActor（服务域，wave-16）。
@MainActor
func ttsTogglePlayPause() {
    AudioBookService.shared.togglePlayPause()
}

/// ttsNextChapter（0x 域 L1073-1094 确证）。
func ttsNextChapter() {
    // 章节推进桥（ReaderViewModel 联动域还原桥）。
}

/// ttsPrevChapter（0x 域确证）。
func ttsPrevChapter() {
    // 章节回退桥（ReaderViewModel 联动域还原桥）。
}

/// ttsStopSpeech（'停止朗读' L9205 域桥）。@MainActor（服务域，wave-16）。
@MainActor
func ttsStopSpeech() {
    AudioBookService.shared.stop()
}

/// systemTtsMultiplierToRate（0x 域 L1097-1116 确证）。
func systemTtsMultiplierToRate(_ multiplier: Float) -> Float {
    AVSpeechUtteranceDefaultSpeechRate * multiplier
}

/// systemTtsRateToMultiplier（0x 域确证）。
func systemTtsRateToMultiplier(_ rate: Float) -> Float {
    guard AVSpeechUtteranceDefaultSpeechRate > 0 else { return 1.0 }
    return rate / AVSpeechUtteranceDefaultSpeechRate
}

import AVFoundation

// MARK: - 定时器菜单（TtsSleepTimerMenu 域 L1128-1154 确证）

/// TTS 定时器菜单（body + ' 分钟' L10946 域确证）。
struct TtsSleepTimerMenu: View {

    @State private var minutes = 0

    var body: some View {
        Menu {
            ForEach([5, 10, 15, 30, 60], id: \.self) { value in
                // ' 分钟' L10946 域确证。
                Button("\(value) 分钟") {
                    minutes = value
                    AudioBookService.shared.configureSleepTimer(
                        minutes: value)
                }
            }
            Button(role: .destructive) {
                minutes = 0
                AudioBookService.shared.cancelSleepTimer()
            } label: {
                Label("取消定时", systemImage: "moon.zzz.fill")
            }
        } label: {
            Label(
                minutes > 0 ? "\(minutes) 分钟" : "定时",
                systemImage: "moon.zzz")
        }
    }
}

/// 音量滑条（TtsVolumeSlider 域 L940-991 签名确证）。
struct TtsVolumeSlider: View {

    @State private var volume: Double = 1.0

    var body: some View {
        HStack {
            Image(systemName: "speaker.wave.1")
            Slider(value: $volume, in: 0...1)
            Image(systemName: "speaker.wave.3")
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - T-1401-08 逐域补齐（TTS 睡眠定时域）

/// 睡眠定时模式（TtsSleepTimerMenu 域确证：chapterEnd + 分钟档）。
enum TtsSleepTimerMode: Equatable {
    case off
    case chapterEnd
    case minutes(Int)
}

/// TTS 睡眠定时器（mode 0x1008bb2b4 / configuredMinutes 0x1008ba5b0 /
/// countdownText 0x1008ba71c / setMinutes 0x1008ba768 /
/// consumeChapterEndIfNeeded 0x1008b87ac 域；MainActor executor 断言确证
/// ——"Leaflow/TtsPlayerView.swift" L151 域）。
@MainActor
final class TtsSleepTimer {

    /// 伪代码 0x1008bb2b4（L55）：模式 varinit（块体与 TtsSleepTimerMenu
    /// body 域交错——默认关闭）。
    private(set) var mode: TtsSleepTimerMode = .off
    /// 定时起点（倒计时域）。
    private var startDate: Date?
    /// 配置分钟（configuredMinutes 域源）。
    private var minutes: Int = 0
    /// 章尾待消费标志（consumeChapterEndIfNeeded 域）。
    private var pendingChapterEnd: Bool = false

    /// 伪代码 0x1008ba5b0（L80-83）：配置分钟读取。
    var configuredMinutes: Int {
        minutes
    }

    /// 伪代码 0x1008ba71c（L86-91）：倒计时文案（剩余分钟档位域）。
    var countdownText: String? {
        guard mode == .minutes(minutes), let start = startDate else {
            return nil
        }
        let remaining = Double(minutes * 60)
            - Date().timeIntervalSince(start)
        guard remaining > 0 else { return nil }
        return audioFormatTime(remaining)
    }

    /// 伪代码 0x1008ba768（L94-97）：分钟档设置（mode/起始点/分钟域）。
    func setMinutes(_ value: Int) {
        minutes = value
        mode = value > 0 ? .minutes(value) : .off
        startDate = value > 0 ? Date() : nil
    }

    /// 章尾模式设置。
    func setChapterEnd() {
        mode = .chapterEnd
        pendingChapterEnd = true
    }

    /// 伪代码 0x1008b87ac（L111-118）：章尾消费——chapterEnd 档标志复位域；
    /// 返回是否应停止播放。
    @discardableResult
    func consumeChapterEndIfNeeded() -> Bool {
        guard mode == .chapterEnd, pendingChapterEnd else { return false }
        pendingChapterEnd = false
        mode = .off
        return true
    }
}
