// 原路径: ReadMain/Views/Reader/TtsPlayerView.swift
// PGO: 倍速/控制 L257-309；类型表 11875-11948：定时器、进度条与音量字段。
// ttsProgress 的 0x1008bd388 标签与块体冲突，进度公式仍需原版对照，不计全量完成。
import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
func ttsUserSpeed<A: TtsPlayable>(vm: A) -> Float {
    switch vm.readAloudPreferences.selectedEngine {
    case .http: return vm.readAloudPreferences.httpRate
    case .system: return vm.readAloudPreferences.systemRate
    }
}

@MainActor
func ttsSetUserSpeed<A: TtsPlayable>(vm: A, speed: Float) {
    switch vm.readAloudPreferences.selectedEngine {
    case .http: vm.readAloudPreferences.setHTTPRate(speed)
    case .system: vm.readAloudPreferences.setSystemRate(speed)
    }
    if vm.readAloudCoordinator.owns(vm) { vm.readAloudCoordinator.settingsDidChange() }
}

@MainActor
func ttsUserSpeedRange<A: TtsPlayable>(vm: A) -> ClosedRange<Float> {
    switch vm.readAloudPreferences.selectedEngine {
    case .http: return 0.5...3
    case .system: return 0.1...2
    }
}

struct TtsProgress: Equatable {
    var headline: String
    var tail: String
    var ratio: Double
    var summary: String { tail.isEmpty ? headline : "\(headline) · \(tail)" }
}

@MainActor
func ttsProgress<A: TtsPlayable>(vm: A) -> TtsProgress {
    let pages = vm.readAloudPages
    let index = vm.readAloudCurrentPageIndex
    guard pages.indices.contains(index) else { return .init(headline: "本章", tail: "0/0", ratio: 0) }
    let current = pages[index]
    let chapterPages = pages.filter {
        $0.chapterIndex == current.chapterIndex && ReadAloudQueueBuilder.isReadable($0)
    }.sorted { $0.pageIndex < $1.pageIndex }
    guard let ordinal = chapterPages.firstIndex(where: { $0.pageIndex == current.pageIndex }) else {
        return .init(headline: current.chapterTitle, tail: "0/0", ratio: 0)
    }
    var ratio = Double(ordinal) / Double(max(1, chapterPages.count))
    // 活跃属主才可消费播放位置，不能把另一书的进度显示到当前页。
    if vm.readAloudCoordinator.owns(vm),
       vm.readAloudCoordinator.currentAnchor?.location.chapterIndex == current.chapterIndex {
        ratio = vm.readAloudCoordinator.progress
    }
    return .init(headline: current.chapterTitle.isEmpty ? vm.ttsChapterName(at: current.chapterIndex) : current.chapterTitle,
        tail: "\(ordinal + 1)/\(chapterPages.count)", ratio: min(1, max(0, ratio)))
}

@MainActor
func ttsTogglePlayPause<A: TtsPlayable>(vm: A) { vm.readAloudCoordinator.toggle(owner: vm) }

@MainActor
func ttsPrevChapter<A: TtsPlayable>(vm: A) { ttsChangeChapter(vm: vm, delta: -1) }

@MainActor
func ttsNextChapter<A: TtsPlayable>(vm: A) { ttsChangeChapter(vm: vm, delta: 1) }

@MainActor
private func ttsChangeChapter<A: TtsPlayable>(vm: A, delta: Int) {
    if vm.readAloudCoordinator.owns(vm), vm.readAloudCoordinator.state.isActive {
        vm.readAloudCoordinator.changeChapter(by: delta)
    } else {
        Task { @MainActor in _ = await vm.readAloudChangeChapter(by: delta) }
    }
}

@MainActor
func ttsStopSpeech<A: TtsPlayable>(vm: A) { vm.readAloudCoordinator.stop(owner: vm) }

func systemTtsMultiplierToRate(_ multiplier: Float) -> Float { AVSpeechUtteranceDefaultSpeechRate * multiplier }
func systemTtsRateToMultiplier(_ rate: Float) -> Float { rate / AVSpeechUtteranceDefaultSpeechRate }

enum SleepTimerMode: Equatable {
    case off
    case endOfChapter
    case minutes(Int)
}

// configure 0x1008b9f88 L120-142 确证 1 秒 Timer；截止时间避免后台停调后倒计时变慢。
@Observable @MainActor
final class TtsSleepTimer {
    private(set) var mode: SleepTimerMode = .off
    private(set) var remaining: TimeInterval = 0
    private(set) var shouldStop = false
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var deadline: Date?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let schedulesTimer: Bool
    @ObservationIgnored private var onStop: (() -> Void)?

    init(now: @escaping () -> Date = Date.init, schedulesTimer: Bool = true) {
        self.now = now
        self.schedulesTimer = schedulesTimer
    }
    deinit { timer?.invalidate() }

    var configuredMinutes: Int { if case .minutes(let minutes) = mode { return minutes }; return 0 }
    var countdownText: String? { remaining > 0 ? audioFormatTime(remaining) : nil }
    var timerLabel: String {
        switch mode {
        case .off: return "定时"
        case .endOfChapter: return "本章结束"
        case .minutes: return countdownText ?? "定时"
        }
    }

    func bind<A: TtsPlayable>(to vm: A) {
        onStop = { [weak vm] in
            guard let vm else { return }
            vm.readAloudCoordinator.stop(owner: vm)
        }
        vm.readAloudCoordinator.setChapterEndPolicy(owner: vm) { [weak self] in
            self?.consumeChapterEndIfNeeded() ?? false
        }
    }

    func setMinutes(_ value: Int) {
        let minutes = min(180, max(0, value))
        mode = minutes == 0 ? .off : .minutes(minutes)
        configure()
    }
    func setChapterEnd() { mode = .endOfChapter; configure() }
    func adjustMinutes(by delta: Int) { setMinutes(configuredMinutes + delta) }
    func cancel() { mode = .off; configure() }

    func notifyChapterEnd() {
        if mode == .endOfChapter { shouldStop = true }
    }
    @discardableResult
    func consumeChapterEndIfNeeded() -> Bool {
        guard mode == .endOfChapter else { return false }
        notifyChapterEnd()
        guard shouldStop else { return false }
        mode = .off
        deadline = nil
        remaining = 0
        timer?.invalidate()
        timer = nil
        shouldStop = false
        return true
    }

    private func configure() {
        timer?.invalidate()
        timer = nil
        shouldStop = false
        deadline = nil
        remaining = 0
        guard case .minutes(let minutes) = mode else { return }
        remaining = Double(minutes * 60)
        deadline = now().addingTimeInterval(remaining)
        guard schedulesTimer else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard let deadline else { return }
        remaining = max(0, deadline.timeIntervalSince(now()))
        guard remaining == 0 else { return }
        self.deadline = nil
        timer?.invalidate()
        timer = nil
        mode = .off
        shouldStop = true
        onStop?()
    }
}

struct TtsSleepTimerMenu<Label: View>: View {
    @Bindable var sleepTimer: TtsSleepTimer
    @ViewBuilder let label: () -> Label
    var body: some View {
        Menu {
            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                Button("\(minutes) 分钟") { sleepTimer.setMinutes(minutes) }
            }
            Button("本章结束") { sleepTimer.setChapterEnd() }
            Button("取消定时", role: .destructive) { sleepTimer.cancel() }
        } label: { label() }
    }
}

struct TtsVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsRouteButton = false
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) { uiView.tintColor = .label }
}
