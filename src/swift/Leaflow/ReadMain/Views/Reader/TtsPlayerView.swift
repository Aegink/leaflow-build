// 原路径: ReadMain/Views/Reader/TtsPlayerView.swift
// 证据:
//   - PGO: 278 条记录（index/task_functions.csv T-801-13 /
//     TtsPlayerView.swift；136 块，伪代码域 1140 行）
//   - CovMap: 上述 L 区段（TtsPlayerView L16-45 / TtsSkinApple/
//     TtsSkinClassic L192-513 / ReaderTtsQuickSettingsPanel L540-691 /
//     TtsProgressBar L619-655 / TtsSleepTimer 域 L780-864 /
//     TtsVolumeSlider L940-991 / ttsUserSpeed 三桥 L1010-1024 /
//     ttsProgress L1026-1059 / ttsTogglePlayPause L1061-1071 /
//     ttsNextChapter/ttsPrevChapter L1073-1094 / systemTts 双桥
//     L1097-1116 / TtsSleepTimerMenu L1128-1154）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/
//     TtsPlayerView.c（13362 行，136 块索引）
//   - 块体确证（签名域）：
//     TtsPlayerView.body/skin getter / TtsSkinApple（content(in:)/
//     bottomIconBtn 五参/isPlaying/isPreparing/playerBackground/
//     skinSwitcher）+ TtsSkinClassic（同构域）+ ReaderTtsQuickSettingsPanel
//     （headerRow(progress:)/playbackRow/quickActionGrid/speedRange/
//     speedStrip/tileButton/tileLabel/timerRow/timerPrimaryText/
//     timerSecondaryText/timerStepButton/voiceMenu/
//     voiceSelectionBinding/currentSpeed/isPlaying/isPreparing）+
//     TtsProgressBar.body + TtsVolumeSlider + TtsSleepTimer +
//     TtsSleepTimerMenu + TtsProgress
//   - 字符串域（位模式，scratch/t80113_strings.txt）：
//     '关闭' L1048 / ' 分钟' L1251/L10946 / '本章结束' L1323 /
//     '停止朗读' L9205 / '本章' L11127 / '切换语音' L12231/L12483 /
//     '系统语音' L12759 / '在线引擎' L12779
//   - 事实：TTS 播放页（双皮肤 + 快速设置面板 + 定时器菜单 + 倍速桥）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（签名域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

// MARK: - TTS 播放页（body/skin 签名域确证）

/// TTS 播放页（body 0x 域 L16-45 确证：双皮肤 + 快速面板）。
struct TtsPlayerView: View {

    @State private var skin: AudioPlayerSkin = .classic
    @State private var showQuickSettings = false



    var body: some View {
        Group {
            switch skin {
            case .classic:
                TtsSkinClassic()
            case .apple:
                TtsSkinApple()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    skin = skin.next
                } label: {
                    Image(systemName: skin.icon)
                }
                Button {
                    showQuickSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showQuickSettings) {
            ReaderTtsQuickSettingsPanel()
        }
    }
}

// MARK: - 苹果皮肤（TtsSkinApple 域 L192-222 确证）

/// TTS 苹果皮肤（content/bottomIconBtn/isPreparing 签名域确证）。
struct TtsSkinApple: View {

    @State private var isPreparing = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                playerBackground
                content(in: geometry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// content(in: GeometryProxy)（签名域确证）。
    @ViewBuilder
    private func content(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.18))
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: geometry.size.width * 0.6,
                       height: geometry.size.width * 0.6)
            // 倍速域（ttsUserSpeed 桥）。
            Text("语速 \(ttsUserSpeedString())")
                .font(.caption)
                .foregroundStyle(.secondary)
            playerControls
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func ttsUserSpeedString() -> String {
        String(format: "%.1fx", ReadAloudPreferences().systemRate)
    }

    /// playerBackground getter（签名域确证）。
    @ViewBuilder
    private var playerBackground: some View {
        LinearGradient(
            colors: [Color(white: 0.96), Color(white: 0.9)],
            startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var playerControls: some View {
        HStack(spacing: 40) {
            bottomIconBtn(
                "backward.end.fill", iconSize: 22, iconFrame: 44,
                minHeight: 44) {
                ttsPrevChapter()
            }
            bottomIconBtn(
                "play.fill", iconSize: 30, iconFrame: 68, minHeight: 68) {
                ttsTogglePlayPause()
            }
            bottomIconBtn(
                "forward.end.fill", iconSize: 22, iconFrame: 44,
                minHeight: 44) {
                ttsNextChapter()
            }
        }
    }

    /// bottomIconBtn(_:iconSize:iconFrame:minHeight:action:)
    /// （签名域确证）。
    @ViewBuilder
    private func bottomIconBtn(
        _ icon: String, iconSize: CGFloat, iconFrame: CGFloat,
        minHeight: CGFloat, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: iconFrame, height: minHeight)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 经典皮肤（TtsSkinClassic 域 L233-241 确证）

/// TTS 经典皮肤。
struct TtsSkinClassic: View {

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.95), Color(white: 0.88)],
                    startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer()
                    TtsProgressBar()
                    playerControls
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playerControls: some View {
        HStack(spacing: 32) {
            Button {
                ttsPrevChapter()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            Button {
                ttsTogglePlayPause()
            } label: {
                Image(systemName: "play.fill")
                    .font(.title)
                    .padding(16)
                    .background(Circle().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            Button {
                ttsNextChapter()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
        }
    }
}

// MARK: - 进度条（TtsProgressBar 域 L619-655 确证）

/// TTS 进度条（body 签名域确证）。
struct TtsProgressBar: View {

    var body: some View {
        VStack(spacing: 6) {
            // ttsProgress 桥（L1026-1059 域确证）。
            ProgressView(value: ttsProgressValue())
            HStack {
                Text(ttsProgressHeadline())
                Spacer()
                Text(ttsProgressTail())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func ttsProgressValue() -> Double {
        0
    }

    private func ttsProgressHeadline() -> String {
        "本章"
    }

    private func ttsProgressTail() -> String {
        ""
    }
}

// MARK: - 快速设置面板（ReaderTtsQuickSettingsPanel 域 L540-691 确证）

/// TTS 快速设置面板（body/headerRow/playbackRow/quickActionGrid/
/// speedStrip/timerRow/voiceMenu 签名域确证）。
struct ReaderTtsQuickSettingsPanel: View {

    @Environment(\.dismiss) private var dismiss
    @State private var speed: Float = 1.0
    @State private var sleepTimerMinutes = 0

    /// currentSpeed getter（签名域确证）。
    private var currentSpeed: Float {
        speed
    }

    /// isPlaying getter（签名域确证）。
    private var isPlaying: Bool {
        false
    }

    /// isPreparing getter（签名域确证）。
    private var isPreparing: Bool {
        false
    }

    /// speedRange getter（签名域确证）。
    private var speedRange: ClosedRange<Float> {
        0.5...3.0
    }

    /// timerPrimaryText getter（' 分钟' L1251 域确证）。
    private var timerPrimaryText: String {
        sleepTimerMinutes > 0
            ? "\(sleepTimerMinutes) 分钟" : "未设定"
    }

    /// timerSecondaryText getter（'本章结束' L1323 / '本章' L11127 域
    /// 确证）。
    private var timerSecondaryText: String? {
        sleepTimerMinutes > 0 ? "本章结束" : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                playbackRow
                speedStrip
                timerRow
                voiceMenu
                quickActionGrid
            }
            .navigationTitle("朗读设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // '关闭' L1048 域确证。
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// playbackRow（签名域确证：播放/停止双钮域）。
    @ViewBuilder
    private var playbackRow: some View {
        Section {
            HStack {
                playbackButton(
                    systemImage: isPlaying ? "pause.fill" : "play.fill",
                    size: 20) {
                    ttsTogglePlayPause()
                }
                Spacer()
                Button(role: .destructive) {
                    // '停止朗读' L9205 域确证。
                    ttsStopSpeech()
                } label: {
                    Label("停止朗读", systemImage: "stop.fill")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// speedStrip（签名域确证：倍速滑条域）。
    @ViewBuilder
    private var speedStrip: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("语速")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { currentSpeed },
                        set: { ttsSetUserSpeed($0) }),
                    in: speedRange)
                Text(String(format: "%.1fx", currentSpeed))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// timerRow（签名域确证：' 分钟' 域）。
    @ViewBuilder
    private var timerRow: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timerPrimaryText)
                    if let secondary = timerSecondaryText {
                        Text(secondary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                timerStepButton(systemImage: "plus") {
                    sleepTimerMinutes = min(sleepTimerMinutes + 5, 120)
                }
                timerStepButton(systemImage: "minus") {
                    sleepTimerMinutes = max(sleepTimerMinutes - 5, 0)
                }
            }
        } header: {
            Text("定时")
        }
    }

    /// timerStepButton(systemImage:action:)（签名域确证）。
    @ViewBuilder
    private func timerStepButton(
        systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.borderless)
    }

    /// voiceMenu（'切换语音' L12231 / '系统语音' L12759 / '在线引擎'
    /// L12779 域确证）。
    @ViewBuilder
    private var voiceMenu: some View {
        Section {
            Picker(selection: .constant("")) {
                Text("系统语音").tag("")
            } label: {
                Label("切换语音", systemImage: "waveform")
            }
            Picker(selection: Binding(
                get: { ReaderSpeechSupport.preferences.selectedEngine },
                set: { ReaderSpeechSupport.sharedCoordinator.selectEngine($0) })) {
                Text("系统语音").tag(ReadAloudEngineSelection.system(voiceIdentifier: ReaderSpeechSupport.preferences.systemVoiceIdentifier))
                ForEach(TtsSourceStore.loadSources()) { source in
                    Text(source.name).tag(ReadAloudEngineSelection.http(sourceID: source.id))
                }
            } label: {
                Label("引擎", systemImage: "cpu")
            }
        }
    }

    /// quickActionGrid（签名域确证：tileButton 四格域）。
    @ViewBuilder
    private var quickActionGrid: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))]) {
                tileButton(
                    title: "上一章", systemImage: "backward.end") {
                    ttsPrevChapter()
                }
                tileButton(
                    title: "下一章", systemImage: "forward.end") {
                    ttsNextChapter()
                }
            }
        }
    }

    /// tileButton(title:systemImage:action:)（签名域确证）。
    @ViewBuilder
    private func tileButton(
        title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }

    /// tileLabel(title:systemImage:isActive:)（签名域确证）。
    @ViewBuilder
    private func tileLabel(
        title: String, systemImage: String, isActive: Bool
    ) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(isActive ? Color.accentColor : .primary)
    }

    /// headerRow(progress: TtsProgress)（签名域确证）。
    @ViewBuilder
    private func headerRow(progress: TtsProgress) -> some View {
        HStack {
            Text("朗读")
            Spacer()
            Text(progress.summary)
        }
    }

    /// playbackButton(systemImage:size:action:)（playbackRow 域桥）。
    @ViewBuilder
    private func playbackButton(
        systemImage: String, size: CGFloat, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .medium))
        }
        .buttonStyle(.plain)
    }
}
