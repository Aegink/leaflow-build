// 原路径: ReadMain/Views/Reader/Audio/AudioPlayerView.swift
// 证据:
//   - PGO: 96 条记录（index/task_functions.csv T-801-11 /
//     AudioPlayerView.swift；skin getter + body 域）
//   - CovMap: 上述 L 区段（init(book:)/skin getter/body getter 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Audio/
//     AudioPlayerView.c（3475 行）
//   - 块体确证（签名域）：
//     AudioPlayerView.init(book: Book) / skin getter（AudioPlayerSkin
//     域） / body getter
//   - 字符串域（位模式+指针，scratch/t80111_view_strings.txt）：
//     '加入书架' L435 / '加入' L1062 / '取消' L1078 / '将「' L1176 /
//     '关闭' L1917 / ' 分钟' L2120 / '本章结束' L2192 / '正在加载…'
//     L1150
//   - 事实：双皮肤（classic/apple）+ 章节列表 + 定时器 + 加书架确认
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三签名域 + 字符串域确证）
// 还原: 2026-11-20

import SwiftUI
import AVKit

/// 有声书播放页（init(book:)/skin/body 签名域确证）。
struct AudioPlayerView: View {

    let book: Book

    @StateObject private var viewModel: AudioPlayerViewModel
    @State private var skin: AudioPlayerSkin = .classic
    @State private var showChapterList = false
    @State private var showAddPrompt = false
    @State private var sleepTimerMinutes = 30

    /// init(book:)（签名域确证）。
    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: AudioPlayerViewModel(
            book: book))
    }


    var body: some View {
        Group {
            switch skin {
            case .classic:
                AudioSkinClassic(viewModel: viewModel)
            case .apple:
                AudioSkinApple(viewModel: viewModel)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // 皮肤切换域（AudioPlayerSkin.next 域确证）。
                Button {
                    skin = skin.next
                } label: {
                    Image(systemName: skin.icon)
                }
                Button {
                    showChapterList = true
                } label: {
                    // '目录规则' L2015 域为书源域交叉；章节列表图标域。
                    Image(systemName: "list.bullet")
                }
                Button {
                    // 睡眠定时器域（' 分钟' L2120 域确证）。
                    AudioBookService.shared.configureSleepTimer(
                        minutes: sleepTimerMinutes)
                } label: {
                    Image(systemName: "moon.zzz")
                }
            }
        }
        .sheet(isPresented: $showChapterList) {
            chapterList
        }
        .alert(
            "加入书架",
            isPresented: $showAddPrompt
        ) {
            // '加入' L1062 / '取消' L1078 / '将「' L1176 域确证。
            Button("加入") {
                viewModel.addBookToBookshelf()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将「\(book.name)」加入书架？")
        }
        .onAppear {
            // shouldPromptAddToBookshelf 域确证。
            if viewModel.shouldPromptAddToBookshelf() {
                showAddPrompt = true
            }
            viewModel.onAppear()
        }
        .onDisappear {
            // '关闭' L1917 域确证：离开页不停止播放。
            viewModel.onDisappear()
        }
        .overlay {
            // '正在加载…' L1150 域确证。
            if viewModel.isLoading {
                ProgressView("正在加载…")
            }
        }
    }

    /// 章节列表（jumpToChapter 域确证）。
    private var chapterList: some View {
        NavigationStack {
            List(viewModel.chapters.indices, id: \.self) { index in
                Button {
                    Task { await viewModel.jumpToChapter(index) }
                } label: {
                    HStack {
                        Text(viewModel.chapters[index].title)
                            .lineLimit(1)
                        Spacer()
                        if index == viewModel.currentChapterIndex {
                            Image(systemName: "speaker.wave.2")
                                .appThemeAccent()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("章节")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // '关闭' L1917 域确证。
                    Button("关闭") {
                        showChapterList = false
                    }
                }
            }
        }
    }
}

// MARK: - T-1401-08 逐域补齐（听书播放 UI 域）

/// 伪代码 0x1005ea650（L99-104）：时间格式化（mm:ss / hh:mm:ss 档位域）。
func audioFormatTime(_ seconds: TimeInterval) -> String {
    let total = Int(max(seconds, 0))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}

/// 伪代码 0x1005ea7f4（L107-111）：倍速标签（rate → "1.0x" 档位域）。
func audioSpeedLabel(_ rate: Float) -> String {
    String(format: "%.1fx", max(rate, 0))
}

/// 伪代码 0x1005eb560（L114-117）：章节展示串（章序 + 标题档位域）。
func audioChapterDisplay(index: Int, title: String) -> String {
    title.isEmpty ? "第 \(index + 1) 章" : "第 \(index + 1) 章 · \(title)"
}

/// AirPlay 路由按钮（makeUIView/updateUIView 0x1005ecfb4/0x1005ed1d0 域
/// 确证：AVRoutePickerView 桥）。
struct AudioAirPlayButton: UIViewRepresentable {

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .label
        picker.activeTintColor = .systemBlue
        return picker
    }

    /// 伪代码 0x1005ed1d0（L207-212）：状态同步（tint 域）。
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = .label
    }
}

extension TtsProgressBar {

    /// 伪代码 0x100601734（L227）：辉光色 varinit（计数器桩；accent 联动
    /// 推断）——二进制容器名 AudioProgressBar，还原形态为 TtsProgressBar
    ///（T-801-12 域）。
    var glowColor: Color {
        Color.accentColor.opacity(0.55)
    }
}

