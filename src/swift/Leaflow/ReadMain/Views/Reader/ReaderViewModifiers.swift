// 原路径: ReadMain/Views/Reader/ReaderViewModifiers.swift
// 证据:
//   - PGO: 64 个主函数（index/task_functions.csv T-301-11 / ReaderViewModifiers.swift），
//     地址：ReaderSystemChromeState.reading 0x100896cd8 L12-24 /
//     ReaderSystemChromeModifier.body 0x10089745c L32-50（+closure 0x100897778，L44-46：
//     defaultCenter 确证）/ ReaderLifecycleModifier.body 0x1008981fc L72-259
//     （closure #2 双 Bool 0x10089872c L88-94 / #3 PageMode 0x100898ad0 L95-107 /
//     #4-#6 Int 对 0x100898b28-899144 / #7/#9/#10/#11 Notification 0x100899478-89a208 /
//     #12 ColorScheme 0x10089a670 L214-231）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderViewModifiers.c（7071 行）
//   - 事实：ReaderSystemChromeModifier —— 状态栏/菜单联动（NotificationCenter 确证）；
//     ReaderLifecycleModifier —— onChange 闭包族（双 Bool/PageMode/Int 对/Notification ×4/
//     ColorScheme）+ onAppear/onDisappear 生命周期装配
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 修饰器结构/onChange 族: high（builder + 调用确证）
//   - 通知名与分支细节: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 系统状态栏状态（伪代码 0x100896cd8，L12-24）。
struct ReaderSystemChromeState {
    var showStatusBar: Bool
    var showMenu: Bool
    var statusBarHidden: Bool

    /// reading 构造（确证）。
    static func reading(showStatusBar: Bool, showMenu: Bool) -> ReaderSystemChromeState {
        ReaderSystemChromeState(
            showStatusBar: showStatusBar,
            showMenu: showMenu,
            statusBarHidden: !showStatusBar && !showMenu)
    }
}

/// 系统状态栏修饰（伪代码 0x10089745c，L32-50）。
struct ReaderSystemChromeModifier: ViewModifier {
    let state: ReaderSystemChromeState

    func body(content: Content) -> some View {
        content
            .statusBarHidden(state.statusBarHidden)
            .onChange(of: state.showMenu) { _, _ in
                // 伪代码 L44-46：NotificationCenter 通知（名字待真机对照）。
                NotificationCenter.default.post(
                    name: .readerSystemChromeDidChange, object: nil)
            }
    }
}

extension Notification.Name {
    static let readerSystemChromeDidChange =
        Notification.Name("leafflow.readerSystemChromeDidChange")
}

/// 生命周期修饰（伪代码 0x1008981fc，L72-259；onChange 闭包族确证）。
struct ReaderLifecycleModifier: ViewModifier {
    @ObservedObject var coordinatorHolder: ReaderLifecycleCoordinator

    func body(content: Content) -> some View {
        content
            .onChange(of: coordinatorHolder.isLoading, initial: false) { old, new in
                // closure #2（0x10089872c，L88-94）：加载态双 Bool。
                _ = (old, new)
            }
            .onChange(of: coordinatorHolder.pageMode, initial: false) { old, new in
                // closure #3（0x100898ad0，L95-107）：PageMode 切换。
                _ = (old, new)
            }
            .onChange(of: coordinatorHolder.currentPageIndex, initial: false) { old, new in
                // closure #4（0x100898b28，L108-126）：页序变化。
                _ = (old, new)
            }
            .onChange(of: coordinatorHolder.currentChapterIndex, initial: false) { old, new in
                // closure #5（0x100898f78，L127-133）：章节变化。
                _ = (old, new)
            }
            .onChange(of: coordinatorHolder.colorVersion, initial: false) { old, new in
                // closure #6（0x100899144，L134-143）：配色版本变化。
                _ = (old, new)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // closure #7（0x100899478，L144-152）。
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                // closure #9（0x10089964c，L161-174）。
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // closure #10（0x10089970c，L175-202）。
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // closure #11（0x10089a208，L203-213）。
            }
            .onChange(of: coordinatorHolder.colorScheme, initial: false) { old, new in
                // closure #12（0x10089a670，L214-231）：配色方案变化。
                _ = (old, new)
            }
            .onAppear {
                coordinatorHolder.activate()
            }
            .onDisappear {
                coordinatorHolder.deactivate()
            }
    }
}

/// 生命周期协调器（onChange 域的可观察载体）。
@MainActor
final class ReaderLifecycleCoordinator: ObservableObject {
    @Published var isLoading = false
    @Published var pageMode: ReadingSettings.PageMode = .horizontal
    @Published var currentPageIndex = 0
    @Published var currentChapterIndex = 0
    @Published var colorVersion = 0
    @Published var colorScheme: ColorScheme = .light

    func activate() {}
    func deactivate() {}
}

extension View {

    /// 伪代码 0x100846048（L702-729）：阅读器辅助呈现集合——sheet/fullScreen
    /// Cover 多挂点链（块体为计数器桩，按签名语义还原）。
    @ViewBuilder
    func readerAuxiliaryPresentations(
        isPresented: Binding<Bool>, content: @escaping () -> some View
    ) -> some View {
        sheet(isPresented: isPresented, content: content)
    }
}

// MARK: - 主呈现层（类型树 L11773-11783）

/// 阅读器主呈现层：目录/设置/浏览器设置/高亮/章节标题/TTS/换源。
struct ReaderPrimarySheetsModifier: ViewModifier {
    let vm: ReaderViewModel
    @Binding var showChapterList: Bool
    @Binding var showSettings: Bool
    @Binding var readerSettingsInitialTabOverride: Int?
    @Binding var showBrowserSettings: Bool
    @Binding var showHighlightSettings: Bool
    @Binding var showChapterTitleSettings: Bool
    @Binding var showTtsPlayer: Bool
    @Binding var showChangeSource: Bool

    @State private var fallbackSettings = ReadingSettings.load()
    @State private var ttsSleepTimer = TtsSleepTimer()

    private var settingsBinding: Binding<ReadingSettings> {
        Binding(
            get: { vm.settings ?? fallbackSettings },
            set: { newValue in
                fallbackSettings = newValue
                vm.settings = newValue
            })
    }

    private var chapterList: [ReaderChapterListChapter] {
        vm.chapterContents.enumerated().map { index, _ in
            ReaderChapterListChapter(
                index: index, title: "第\(index + 1)章")
        }
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showChapterList) {
                ReaderChapterListView(
                    chapters: .constant(chapterList),
                    currentChapterIndex: .constant(
                        vm.currentChapterIndex),
                    onPickChapter: { index in
                        vm.jumpToChapter(index, pageIndex: nil)
                    })
            }
            .sheet(isPresented: $showSettings) {
                ReaderSettingsView(
                    settings: settingsBinding,
                    onDismiss: { showSettings = false })
            }
            .sheet(isPresented: $showBrowserSettings) {
                ReaderBrowserSettingsView(
                    presentation: Binding(
                        get: {
                            settingsBinding.wrappedValue
                                .paragraphCommentBrowser
                        },
                        set: {
                            settingsBinding.wrappedValue
                                .paragraphCommentBrowser = $0
                        }))
            }
            .sheet(isPresented: $showHighlightSettings) {
                HighlightRulesView(settings: settingsBinding)
            }
            .sheet(isPresented: $showChapterTitleSettings) {
                ChapterTitleStyleSettingsView(settings: settingsBinding)
            }
            .sheet(isPresented: $showTtsPlayer) {
                TtsPlayerView(vm: vm, isPresented: $showTtsPlayer, showChapterList: $showChapterList,
                    showSettings: $showSettings, sleepTimer: ttsSleepTimer)
            }
            .sheet(isPresented: $showChangeSource) {
                ContentUnavailableView(
                    "换源", systemImage: "arrow.triangle.2.circlepath",
                    description: Text("需要书籍上下文后可用"))
            }
    }
}

// MARK: - 辅助呈现层（类型树 L11748-11771）

/// 阅读器辅助呈现层：搜索/书评/详情/书签/支付/登录/浏览器。
struct ReaderAuxiliaryPresentationModifier: ViewModifier {
    let vm: ReaderViewModel
    let openableUrl: String?
    let dismissReader: () -> Void
    let commentBrowserSheet: (JSBrowserRequest, BookSource) -> AnyView
    @Binding var showSettings: Bool
    @Binding var loginSource: BookSource?
    @Binding var currentBrowserRequest: JSBrowserRequest?
    @Binding var lastBrowserRequest: JSBrowserRequest?
    @Binding var showSearch: Bool
    @Binding var showReview: Bool
    @Binding var showBookDetail: Bool
    @Binding var showBookmarkList: Bool
    @Binding var showPayConfirm: Bool
    @Binding var payResultUrl: URL?
    @Binding var showPayWebView: Bool

    private var chapters: [ReaderChapterListChapter] {
        vm.chapterContents.enumerated().map { index, _ in
            ReaderChapterListChapter(
                index: index, title: "第\(index + 1)章")
        }
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSearch) {
                FullTextSearchView(
                    chapters: .constant(chapters),
                    chapterContentProvider: { index in
                        vm.chapterContents.indices.contains(index)
                            ? vm.chapterContents[index] : ""
                    },
                    onPickResult: { chapterIndex, _ in
                        vm.jumpToChapter(chapterIndex, pageIndex: nil)
                    })
            }
            .modifier(ReaderReviewPresentationModifier(vm: vm, showReview: $showReview))
            .sheet(isPresented: $showBookmarkList) {
                BookmarkListView()
            }
            .sheet(isPresented: $showBookDetail) {
                ContentUnavailableView(
                    "书籍详情", systemImage: "book",
                    description: Text("详情页待接入"))
            }
            .sheet(isPresented: $showPayConfirm) {
                ContentUnavailableView(
                    "购买确认", systemImage: "cart",
                    description: Text("支付链待接入"))
            }
            .sheet(isPresented: $showPayWebView) {
                ContentUnavailableView(
                    "支付页", systemImage: "creditcard",
                    description: Text("支付链待接入"))
            }
    }
}


