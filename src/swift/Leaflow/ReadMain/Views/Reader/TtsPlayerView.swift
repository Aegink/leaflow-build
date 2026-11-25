// 原路径: ReadMain/Views/Reader/TtsPlayerView.swift
// 类型表 11893-11948：泛型阅读模型、外部呈现状态、共享定时器及两套皮肤。
// body 类型树 34778-34785：封面、标题、进度、控制、音量和定时菜单。
// PGO 函数域见 T-801-13；布局细节与原版进度公式仍需真机对照。
import SwiftUI

struct TtsPlayerView<A: TtsPlayable>: View {
    @Bindable var vm: A
    @Binding var isPresented: Bool
    @Binding var showChapterList: Bool
    @Binding var showSettings: Bool
    @State var sleepTimer: TtsSleepTimer
    @AppStorage("tts_player_skin") private var skinRaw = AudioPlayerSkin.classic.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var skin: AudioPlayerSkin { AudioPlayerSkin(rawValue: skinRaw) ?? .classic }

    var body: some View {
        Group {
            switch skin {
            case .classic:
                TtsSkinClassic(vm: vm, skinRaw: $skinRaw, showChapterList: $showChapterList,
                    showSettings: $showSettings, sleepTimer: sleepTimer,
                    onDismiss: { isPresented = false }, onClose: close,
                    coordinator: vm.readAloudCoordinator)
            case .apple:
                TtsSkinApple(vm: vm, skinRaw: $skinRaw, showChapterList: $showChapterList,
                    showSettings: $showSettings, sleepTimer: sleepTimer,
                    onDismiss: { isPresented = false }, onClose: close,
                    coordinator: vm.readAloudCoordinator)
            }
        }
        .onAppear { sleepTimer.bind(to: vm); sleepTimer.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { sleepTimer.refresh() } }
    }

    private func close() { ttsStopSpeech(vm: vm); isPresented = false }
}

struct TtsSkinApple<A: TtsPlayable>: View {
    @Bindable var vm: A
    @Binding var skinRaw: String
    @Binding var showChapterList: Bool
    @Binding var showSettings: Bool
    let sleepTimer: TtsSleepTimer
    let onDismiss: () -> Void
    let onClose: () -> Void
    @ObservedObject var coordinator: ReadAloudCoordinator
    @Environment(\.colorScheme) private var colorScheme

    private var skin: AudioPlayerSkin { .apple }
    private var isPlaying: Bool { coordinator.owns(vm) && coordinator.isSpeaking }
    private var isPreparing: Bool { coordinator.owns(vm) && coordinator.isPreparing }

    var body: some View {
        GeometryReader { geometry in
            ZStack { playerBackground; content(in: geometry) }
        }
    }

    private func content(in geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                CachedAsyncImage(url: vm.ttsCoverUrl, book: vm.ttsCoverBook,
                    targetSize: CGSize(width: 320, height: 320))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(320, geometry.size.width * 0.66), height: min(320, geometry.size.width * 0.66))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    .accessibilityHidden(true)
                metadata
                let progress = ttsProgress(vm: vm)
                TtsProgressBar(progress: progress.ratio, progressText: progress.summary)
                playerControls
                TtsVolumeSlider().frame(height: 44)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(minHeight: geometry.size.height, alignment: .top)
        }
    }

    private var header: some View {
        HStack {
            bottomIconBtn("chevron.down", label: "收起播放器", action: onDismiss)
            bottomIconBtn("stop.fill", label: "停止朗读", action: onClose)
            Spacer()
            skinSwitcher
        }
    }
    private var metadata: some View {
        VStack(spacing: 6) {
            Text(vm.readAloudMetadata.bookName).font(.title2.bold()).lineLimit(2)
            Text(vm.ttsBookAuthor ?? "").font(.subheadline).foregroundStyle(.secondary)
            Text(ttsProgress(vm: vm).headline).font(.headline).lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
    private var playerBackground: some View {
        LinearGradient(colors: colorScheme == .dark
            ? [Color(white: 0.1), Color(white: 0.05)] : [Color(white: 0.96), Color(white: 0.9)],
            startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
    private var playerControls: some View {
        HStack(spacing: 32) {
            bottomIconBtn("backward.end.fill", label: "上一章") { ttsPrevChapter(vm: vm) }
            Button { ttsTogglePlayPause(vm: vm) } label: {
                Group {
                    if isPreparing { ProgressView() }
                    else { Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.largeTitle) }
                }.frame(width: 68, height: 68)
            }
            .accessibilityLabel(isPlaying ? "暂停朗读" : "开始朗读")
            .accessibilityValue(isPreparing ? "准备中" : isPlaying ? "播放中" : "已暂停")
            bottomIconBtn("forward.end.fill", label: "下一章") { ttsNextChapter(vm: vm) }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
    private var footer: some View {
        HStack {
            bottomIconBtn("list.bullet", label: "目录") { onDismiss(); showChapterList = true }
            Spacer()
            TtsSleepTimerMenu(sleepTimer: sleepTimer) { Label(sleepTimer.timerLabel, systemImage: "moon.zzz") }
                .frame(minHeight: 44)
            Spacer()
            bottomIconBtn("slider.horizontal.3", label: "朗读设置") { onDismiss(); showSettings = true }
        }
    }
    private var skinSwitcher: some View {
        Button { skinRaw = skin.next.rawValue } label: {
            Label(skin.displayName, systemImage: skin.icon).font(.subheadline)
        }.frame(minHeight: 44).accessibilityLabel("切换到经典皮肤")
    }
    private func bottomIconBtn(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title3).frame(width: 44, height: 44) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct TtsSkinClassic<A: TtsPlayable>: View {
    @Bindable var vm: A
    @Binding var skinRaw: String
    @Binding var showChapterList: Bool
    @Binding var showSettings: Bool
    let sleepTimer: TtsSleepTimer
    let onDismiss: () -> Void
    let onClose: () -> Void
    @ObservedObject var coordinator: ReadAloudCoordinator
    @Environment(\.colorScheme) private var systemColorScheme

    private var skin: AudioPlayerSkin { .classic }
    private var isPlaying: Bool { coordinator.owns(vm) && coordinator.isSpeaking }
    private var isPreparing: Bool { coordinator.owns(vm) && coordinator.isPreparing }
    private var themeColorScheme: ColorScheme { AppThemeManager.shared.effectiveColorScheme(for: systemColorScheme) }
    private var primaryTextColor: Color { AppThemeManager.shared.primaryTextColor(for: themeColorScheme) }
    private var secondaryTextColor: Color { AppThemeManager.shared.secondaryTextColor(for: themeColorScheme) }

    var body: some View {
        GeometryReader { geometry in ZStack { playerBackground; content(in: geometry) } }
    }

    private func content(in geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    bottomBtn("chevron.down", label: "收起播放器", action: onDismiss)
                    bottomBtn("stop.fill", label: "停止朗读", action: onClose)
                    Spacer()
                    skinSwitcher
                }
                CachedAsyncImage(url: vm.ttsCoverUrl, book: vm.ttsCoverBook,
                    targetSize: CGSize(width: 240, height: 300))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(240, geometry.size.width * 0.52), height: min(300, geometry.size.height * 0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text(vm.readAloudMetadata.bookName).font(.title2.bold()).foregroundStyle(primaryTextColor).lineLimit(2)
                    Text(vm.ttsBookAuthor ?? "").font(.subheadline).foregroundStyle(secondaryTextColor)
                    Text(ttsProgress(vm: vm).headline).font(.headline).lineLimit(2)
                }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Text(String(format: "%.1fx", ttsUserSpeed(vm: vm))).font(.subheadline.monospacedDigit())
                let progress = ttsProgress(vm: vm)
                TtsProgressBar(progress: progress.ratio, progressText: progress.summary)
                HStack(spacing: 32) {
                    skipBtn("backward.end.fill", label: "上一章") { ttsPrevChapter(vm: vm) }
                    Button { ttsTogglePlayPause(vm: vm) } label: {
                        Group {
                            if isPreparing { ProgressView().tint(.white) }
                            else { Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.title) }
                        }
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.accentColor)).foregroundStyle(.white)
                    }.accessibilityLabel(isPlaying ? "暂停朗读" : "开始朗读")
                    skipBtn("forward.end.fill", label: "下一章") { ttsNextChapter(vm: vm) }
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                HStack {
                    bottomBtn("list.bullet", label: "目录") { onDismiss(); showChapterList = true }
                    Spacer()
                    TtsSleepTimerMenu(sleepTimer: sleepTimer) { Label(sleepTimer.timerLabel, systemImage: "moon.zzz") }
                        .frame(minHeight: 44)
                    Spacer()
                    bottomBtn("slider.horizontal.3", label: "朗读设置") { onDismiss(); showSettings = true }
                }
            }.padding(24).frame(minHeight: geometry.size.height, alignment: .top)
        }
    }
    private var playerBackground: some View {
        LinearGradient(colors: themeColorScheme == .dark
            ? [Color(white: 0.08), Color(white: 0.03)] : [Color(white: 0.95), Color(white: 0.88)],
            startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
    private var skinSwitcher: some View {
        Button { skinRaw = skin.next.rawValue } label: { Label(skin.displayName, systemImage: skin.icon) }
            .frame(minHeight: 44).accessibilityLabel("切换到苹果皮肤")
    }
    private func skipBtn(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        bottomBtn(icon, label: label, action: action)
    }
    private func bottomBtn(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title3).frame(width: 44, height: 44) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct TtsProgressBar: View {
    let progress: Double
    let progressText: String
    var trackColor: Color = .secondary.opacity(0.2)
    var fillColor: AnyShapeStyle = AnyShapeStyle(Color.accentColor)
    var thumbColor: Color = .accentColor
    var textColor: Color = .secondary
    var trackHeight: CGFloat = 4
    var showThumb = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let ratio = progress.isFinite ? min(1, max(0, progress)) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule().fill(fillColor).frame(width: geometry.size.width * ratio)
                    if showThumb {
                        Circle().fill(thumbColor).frame(width: 10, height: 10)
                            .offset(x: max(0, min(geometry.size.width - 10, geometry.size.width * ratio - 5)))
                    }
                }.frame(height: trackHeight)
            }.frame(height: max(10, trackHeight))
            Text(progressText).font(.caption).foregroundStyle(textColor).lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressText)
        .accessibilityValue("\(Int((progress.isFinite ? min(1, max(0, progress)) : 0) * 100))%")
    }
}
