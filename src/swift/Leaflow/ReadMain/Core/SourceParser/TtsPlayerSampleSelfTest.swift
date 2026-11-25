// T-1602：播放页辅助函数与定时策略运行生产实现，测试替换驱动和音频会话。
import SwiftUI
import Observation

enum TtsPlayerSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let defaults = UserDefaults(suiteName: "tts-player-selftest-\(UUID())")!
        let preferences = ReadAloudPreferences(defaults: defaults)
        let factory = TtsSampleDriverFactory()
        let coordinator = ReadAloudCoordinator(factory: factory, preferences: preferences,
            audioPlayback: TtsSamplePlayback(), errorPresenter: TtsSampleErrors(),
            buildQueue: { ReadAloudQueueBuilder.build(from: $0, includeChapterTitle: true) })
        let vm = TtsSampleOwner(coordinator: coordinator, preferences: preferences)
        vm.position = 1
        let progress = ttsProgress(vm: vm)
        emit("tts_player_model_progress", ["样本第一章", "2/2", "0.50", "测试作者"],
            [progress.headline, progress.tail, String(format: "%.2f", progress.ratio), vm.ttsBookAuthor ?? "缺失"])
        ttsSetUserSpeed(vm: vm, speed: 1.4)
        preferences.selectEngine(.http(sourceID: 42))
        ttsSetUserSpeed(vm: vm, speed: 2.5)
        let httpRange = ttsUserSpeedRange(vm: vm)
        emit("tts_player_engine_speed", ["1.4", "2.5", "0.5", "3.0"],
            [String(format: "%.1f", preferences.systemRate), String(format: "%.1f", ttsUserSpeed(vm: vm)),
             String(format: "%.1f", httpRange.lowerBound), String(format: "%.1f", httpRange.upperBound)])
        preferences.removeHTTPSelection()

        ttsTogglePlayPause(vm: vm)
        await until { coordinator.isSpeaking }
        ttsTogglePlayPause(vm: vm)
        let paused = coordinator.isPaused
        ttsTogglePlayPause(vm: vm)
        emit("tts_player_controls", ["true", "true", "true"],
            [String(paused), String(coordinator.isSpeaking), String(coordinator.owns(vm))])
        ttsNextChapter(vm: vm)
        await until { vm.chapter == 1 && coordinator.isSpeaking }
        ttsPrevChapter(vm: vm)
        await until { vm.chapter == 0 && coordinator.isSpeaking }
        emit("tts_player_chapter_controls", ["0", "true"], [String(vm.chapter), String(factory.drivers.count >= 3)])
        ttsStopSpeech(vm: vm)

        var clock = Date(timeIntervalSince1970: 1000)
        let timer = TtsSleepTimer(now: { clock }, schedulesTimer: false)
        timer.bind(to: vm)
        timer.setMinutes(1)
        clock = clock.addingTimeInterval(15)
        timer.refresh()
        emit("tts_timer_countdown", ["45", "1", "false"],
            [String(Int(timer.remaining)), String(timer.configuredMinutes), String(timer.shouldStop)])
        ttsTogglePlayPause(vm: vm)
        await until { coordinator.isSpeaking }
        clock = clock.addingTimeInterval(90)
        timer.refresh()
        emit("tts_timer_background_expiry", ["0", "true", "true"],
            [String(Int(timer.remaining)), String(timer.shouldStop), String(coordinator.state == .idle)])
        emit("tts_timer_expiry_not_chapter_policy", ["false"], [String(timer.consumeChapterEndIfNeeded())])
        timer.setMinutes(500)
        let clamped = timer.configuredMinutes
        timer.cancel()
        clock = clock.addingTimeInterval(20_000)
        timer.refresh()
        emit("tts_timer_cancel_bounds", ["180", "true", "false"],
            [String(clamped), String(timer.mode == .off), String(timer.shouldStop)])
        timer.setChapterEnd()
        ttsTogglePlayPause(vm: vm)
        await until { coordinator.isSpeaking }
        factory.drivers.last?.onEvent?(.finished)
        await until { coordinator.state == .idle }
        emit("tts_timer_chapter_boundary", ["0", "true", "false"],
            [String(vm.chapter), String(coordinator.state == .idle), String(timer.consumeChapterEndIfNeeded())])

        let other = TtsSampleOwner(coordinator: coordinator, preferences: preferences)
        timer.bind(to: vm)
        timer.setMinutes(1)
        ttsTogglePlayPause(vm: other)
        await until { coordinator.isSpeaking }
        clock = clock.addingTimeInterval(61)
        timer.refresh()
        emit("tts_timer_owner_isolation", ["true", "true"],
            [String(coordinator.owns(other)), String(coordinator.isSpeaking)])
        coordinator.stop()

        let anchor = ReadAloudAnchor(location: .init(pageIndex: 0, chapterIndex: 1),
            rangeInPage: .init(location: 0, length: 2), rangeInChapter: .init(location: 3, length: 2),
            startUTF16Offset: 7, isChapterTitle: false)
        let resolved = ReadAloudAnchorResolver.resolve(anchor, in: [
            fixturePage(chapter: 0, page: 0, content: "错误章节", start: 0),
            fixturePage(chapter: 1, page: 0, content: "甲乙丙", start: 0),
            fixturePage(chapter: 1, page: 1, content: "丁戊己", start: 3)])
        emit("tts_anchor_chapter_repagination", ["1", "1", "0", "2", "7"],
            [String(resolved?.location.chapterIndex ?? -1), String(resolved?.pageIndex ?? -1),
             String(resolved?.rangeInPage.location ?? -1), String(resolved?.rangeInPage.length ?? -1),
             String(resolved?.startUTF16Offset ?? -1)])
        vm.pages = []
        emit("tts_player_empty_progress", ["0/0", "0.0"], [ttsProgress(vm: vm).tail, String(ttsProgress(vm: vm).ratio)])
    }

    @MainActor private static func until(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    static func fixturePage(chapter: Int, page: Int, content: String, start: Int) -> PageData {
        PageData(chapterIndex: chapter, pageIndex: page, content: content,
            contentRangeInChapter: .init(location: start, length: content.utf16.count),
            imageSourceUrl: nil, imageSourceStorageKind: nil, imageBaseUrl: nil, imageStyle: nil,
            chapterTitle: chapter == 0 ? "样本第一章" : "样本第二章", isFirstPageOfChapter: page == 0,
            continuesParagraphOnNextPage: false, chapterTotalPages: 2, isLoadingPlaceholder: false,
            isErrorPlaceholder: false, extraLineSpacing: 0, continuationLineFillRatio: 0,
            continuationTailPreview: "", bodyHeight: 100, charCount: content.utf16.count, comments: [])
    }

    @MainActor static func fixtureVM() -> ReaderViewModel {
        let vm = ReaderViewModel()
        var book = Book()
        book.name = "固定朗读样本"
        book.author = "测试作者"
        book.bookUrl = "https://sample.invalid/tts-ui"
        vm.currentBook = book
        vm.bookName = book.name
        vm.totalChapters = 2
        let content = "固定的朗读正文，用于模拟器布局检查。"
        vm.pages = [fixturePage(chapter: 0, page: 0, content: content, start: 0),
            fixturePage(chapter: 0, page: 1, content: "第二页正文。", start: content.utf16.count)]
        return vm
    }
}

// 仅显式 -smokeTtsPlayer/-smokeTtsQuick 启动；不伪造网络书或用户真机证据。
struct TtsPlayerSmokeView: View {
    @State private var vm = TtsPlayerSampleSelfTest.fixtureVM()
    @State private var isPresented = true
    @State private var showChapterList = false
    @State private var showSettings = false
    @State private var timer = TtsSleepTimer()
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-smokeTtsQuick") {
            ScrollView {
                ReaderTtsQuickSettingsPanel(vm: vm, sleepTimer: timer,
                    onOpenPlayer: {}, onSettings: {}, onStop: {}, coordinator: vm.readAloudCoordinator,
                    preferences: vm.readAloudPreferences).padding()
            }
        } else {
            TtsPlayerView(vm: vm, isPresented: $isPresented, showChapterList: $showChapterList,
                showSettings: $showSettings, sleepTimer: timer)
        }
    }
}

@Observable @MainActor
private final class TtsSampleOwner: TtsPlayable {
    @ObservationIgnored let readAloudCoordinator: ReadAloudCoordinator
    @ObservationIgnored let readAloudPreferences: ReadAloudPreferences
    var chapter = 0
    var position = 0
    var pages = [TtsPlayerSampleSelfTest.fixturePage(chapter: 0, page: 0, content: "甲乙丙丁", start: 0),
        TtsPlayerSampleSelfTest.fixturePage(chapter: 0, page: 1, content: "戊己庚辛", start: 4)]
    init(coordinator: ReadAloudCoordinator, preferences: ReadAloudPreferences) {
        readAloudCoordinator = coordinator
        readAloudPreferences = preferences
    }
    var readAloudPages: [PageData] { pages }
    var readAloudCurrentPageIndex: Int { position }
    var readAloudMetadata: ReadAloudMetadata { .init(bookName: "固定样本", chapterName: "样本第\(chapter + 1)章", author: "测试作者") }
    var ttsCoverUrl: String? { nil }
    var ttsCoverBook: Book? { nil }
    var ttsBookAuthor: String? { readAloudMetadata.author }
    var ttsChapterCount: Int { 2 }
    var ttsBookFingerprint: String { "tts-player-selftest" }
    func ttsChapterName(at index: Int) -> String { "样本第\(index + 1)章" }
    func readAloudShow(location: ReadAloudLocation) {
        position = pages.firstIndex { $0.chapterIndex == location.chapterIndex && $0.pageIndex == location.pageIndex } ?? 0
    }
    func readAloudSaveProgress() {}
    func readAloudSessionDidFinish() {}
    func readAloudAdvanceChapter() async -> ReadAloudChapterAdvanceResult { await readAloudChangeChapter(by: 1) }
    func readAloudChangeChapter(by delta: Int) async -> ReadAloudChapterChangeResult {
        guard (0..<2).contains(chapter + delta) else { return .exhausted }
        chapter += delta
        position = 0
        pages = [TtsPlayerSampleSelfTest.fixturePage(chapter: chapter, page: 0, content: "换章正文", start: 0)]
        return .advanced
    }
}

private final class TtsSampleDriver: ReadAloudDriver {
    var onEvent: ((ReadAloudDriverEvent) -> Void)?
    func start(segments: [ReadAloudSegment]) { onEvent?(.started(segmentIndex: 0)) }
    func seek(segments: [ReadAloudSegment]) { start(segments: segments) }
    func pause() {}
    func resume() {}
    func stop() {}
}

@MainActor private final class TtsSampleDriverFactory: ReadAloudDriverFactory {
    var drivers: [TtsSampleDriver] = []
    func makeDriver(for selection: ReadAloudEngineSelection) throws -> ReadAloudDriver {
        let driver = TtsSampleDriver()
        drivers.append(driver)
        return driver
    }
}
private final class TtsSamplePlayback: AppAudioPlaybackCoordinating {
    func acquire(client: AppAudioPlaybackCoordinator.AppAudioPlaybackClient, onPreempt: @escaping () -> Void,
        onInterruption: @escaping (ReadAloudAudioInterruption) -> Void,
        remoteCommands: AppAudioPlaybackCoordinator.AppAudioRemoteCommands) async throws -> AppAudioPlaybackCoordinator.AppAudioPlaybackLease {
        .init(id: UUID(), client: client)
    }
    func release(_ lease: AppAudioPlaybackCoordinator.AppAudioPlaybackLease) {}
    func publishNowPlaying(_ metadata: ReadAloudMetadata) {}
    func updateNowPlaying(state: ReadAloudPlaybackState) {}
}
private final class TtsSampleErrors: ReadAloudErrorPresenting {
    func present(_ error: Error) {}
    func show(message: String) {}
}
