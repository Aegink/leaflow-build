// 原路径: ReadMain/Views/Reader/TtsPlayerView.swift
// 类型表 11893：泛型模型、共享定时器、打开播放器/设置/停止三个回调。
import SwiftUI

struct ReaderTtsQuickSettingsPanel<A: TtsPlayable>: View {
    @Bindable var vm: A
    let sleepTimer: TtsSleepTimer
    let onOpenPlayer: () -> Void
    let onSettings: () -> Void
    let onStop: () -> Void
    @ObservedObject var coordinator: ReadAloudCoordinator
    @ObservedObject var preferences: ReadAloudPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var usesVerticalLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    private var currentSpeed: Float { ttsUserSpeed(vm: vm) }
    private var isPlaying: Bool { coordinator.owns(vm) && coordinator.isSpeaking }
    private var isPreparing: Bool { coordinator.owns(vm) && coordinator.isPreparing }
    private var speedRange: ClosedRange<Float> { ttsUserSpeedRange(vm: vm) }
    private var timerPrimaryText: String { sleepTimer.timerLabel }
    private var timerSecondaryText: String? { sleepTimer.mode == .endOfChapter ? "本章结束后停止朗读" : nil }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            headerRow(progress: ttsProgress(vm: vm))
            playbackRow
            speedStrip
            timerRow
            voiceMenu
            quickActionGrid
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxHeight: 460)
        .accessibilityIdentifier("tts-quick-settings")
        .onAppear { sleepTimer.bind(to: vm); sleepTimer.refresh() }
    }

    private func headerRow(progress: TtsProgress) -> some View {
        let layout = usesVerticalLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text("朗读").font(.headline)
            if !usesVerticalLayout { Spacer() }
            Text(progress.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
    }
    private var playbackRow: some View {
        let layout = usesVerticalLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
        return layout {
            HStack {
            playbackButton(systemImage: "backward.end.fill", label: "上一章") { ttsPrevChapter(vm: vm) }
            playbackButton(systemImage: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "暂停朗读" : "开始朗读") { ttsTogglePlayPause(vm: vm) }
                .overlay { if isPreparing { ProgressView().allowsHitTesting(false) } }
            playbackButton(systemImage: "forward.end.fill", label: "下一章") { ttsNextChapter(vm: vm) }
            }
            if !usesVerticalLayout { Spacer() }
            Button("停止朗读", role: .destructive) { ttsStopSpeech(vm: vm); onStop() }
                .frame(minHeight: 44)
        }
    }
    private var speedStrip: some View {
        let layout = usesVerticalLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        return layout {
            Text("语速").font(.subheadline)
            Slider(value: Binding(get: { currentSpeed }, set: { ttsSetUserSpeed(vm: vm, speed: $0) }), in: speedRange)
                .accessibilityLabel("朗读语速")
            Text(String(format: "%.1fx", currentSpeed)).font(.caption.monospacedDigit())
        }
    }
    private var timerRow: some View {
        let layout = usesVerticalLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        return layout {
            TtsSleepTimerMenu(sleepTimer: sleepTimer) {
                VStack(alignment: .leading) {
                    Label(timerPrimaryText, systemImage: "moon.zzz")
                    if let timerSecondaryText { Text(timerSecondaryText).font(.caption) }
                }
            }.frame(minHeight: 44)
            if !usesVerticalLayout { Spacer() }
            HStack {
            timerStepButton(systemImage: "minus", label: "减少五分钟") { sleepTimer.adjustMinutes(by: -5) }
            timerStepButton(systemImage: "plus", label: "增加五分钟") { sleepTimer.adjustMinutes(by: 5) }
            }
        }
    }
    private var voiceSelectionBinding: Binding<ReadAloudEngineSelection> {
        Binding(get: { preferences.selectedEngine }, set: {
            preferences.selectEngine($0)
            if coordinator.owns(vm) { coordinator.settingsDidChange() }
        })
    }
    private var voiceMenu: some View {
        Picker(selection: voiceSelectionBinding) {
            Text("系统语音").tag(ReadAloudEngineSelection.system(voiceIdentifier: ""))
            ForEach(preferences.availableSystemVoices) { voice in
                Text(preferences.voiceDisplayName(voice)).tag(ReadAloudEngineSelection.system(voiceIdentifier: voice.id))
            }
            ForEach(vm.httpTtsSources) { source in
                Text(source.name).tag(ReadAloudEngineSelection.http(sourceID: source.id))
            }
        } label: { Label("切换语音", systemImage: "waveform") }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
    }
    private var quickActionGrid: some View {
        let layout = usesVerticalLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        return layout {
            tileButton(title: "播放器", systemImage: "music.note", action: onOpenPlayer)
            if !usesVerticalLayout { Spacer() }
            tileButton(title: "设置", systemImage: "slider.horizontal.3", action: onSettings)
        }
    }
    private func tileButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { tileLabel(title: title, systemImage: systemImage, isActive: false) }
            .frame(minHeight: 44)
    }
    private func tileLabel(title: String, systemImage: String, isActive: Bool) -> some View {
        Label(title, systemImage: systemImage).foregroundStyle(isActive ? Color.accentColor : .primary)
    }
    private func playbackButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: systemImage).font(.title3).frame(minWidth: 44, minHeight: 44) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
    private func timerStepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        playbackButton(systemImage: systemImage, label: label, action: action)
    }
}
