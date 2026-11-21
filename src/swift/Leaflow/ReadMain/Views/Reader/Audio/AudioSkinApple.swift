// 原路径: ReadMain/Views/Reader/Audio/AudioSkinApple.swift
// 证据:
//   - PGO: 90 条记录（index/task_functions.csv T-801-12 /
//     AudioSkinApple.swift；伪代码域 220 行）
//   - CovMap: 上述 L 区段（body/content(in:)/playerBackground/
//     skinSwitcher/bottomIconBtn/timerLabel 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Audio/
//     AudioSkinApple.c（4956 行）
//   - 块体确证（签名域）：
//     body getter / content(in: GeometryProxy) / playerBackground
//     getter / skinSwitcher getter / bottomIconBtn(_: String,
//     iconSize: CGFloat, iconFrame: CGFloat, minHeight: CGFloat,
//     action: () -> Void) / timerLabel getter / isPlaying getter /
//     skin getter
//   - 字符串域（位模式，scratch/t80112_apple.txt）：'苹果' L4579/
//     L4706/L4872 / '经典' L4584/L4711/L4877（切换器双档域）/
//     '换源' L3719
//   - 事实：苹果皮肤（大封面 + 底栏图标 + 皮肤切换 + 换源入口）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（八签名域 + 切换器串确证）
// 还原: 2026-11-20

import SwiftUI

/// 苹果皮肤（body/content/playerBackground 签名域确证）。
struct AudioSkinApple: View {

    @ObservedObject var viewModel: AudioPlayerViewModel
    @ObservedObject private var audioService = AudioBookService.shared
    @Environment(\.colorScheme) private var colorScheme

    /// isPlaying getter（签名域确证）。
    private var isPlaying: Bool {
        audioService.isPlaying
    }

    /// skin getter（签名域确证：固定苹果档）。
    private var skin: AudioPlayerSkin {
        .apple
    }

    /// timerLabel getter（签名域确证：剩余分钟域）。
    private var timerLabel: String {
        let remaining = Int(audioService.sleepTimerRemaining / 60)
        return remaining > 0 ? "\(remaining) 分钟" : ""
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                playerBackground
                content(in: geometry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// content(in: GeometryProxy)（签名域确证：封面 + 控制 + 底栏域）。
    @ViewBuilder
    private func content(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            Spacer()
            coverArea(in: geometry)
            chapterTitle
            playerControls
            bottomIconRow
            skinSwitcher
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var coverArea: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .shadow(radius: 10)
    }

    private var chapterTitle: some View {
        VStack(spacing: 4) {
            Text(bookTitle)
                .font(.headline)
            Text(viewModel.chapterTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
    }

    private var bookTitle: String {
        viewModel.book.name
    }

    /// playerBackground getter（签名域确证：明暗渐变域）。
    @ViewBuilder
    private var playerBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.1), Color(white: 0.05)]
                : [Color(white: 0.96), Color(white: 0.9)],
            startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var playerControls: some View {
        HStack(spacing: 40) {
            bottomIconBtn(
                "backward.end.fill", iconSize: 22, iconFrame: 44,
                minHeight: 44) {
                Task { await viewModel.previousChapter() }
            }
            bottomIconBtn(
                isPlaying ? "pause.fill" : "play.fill", iconSize: 30,
                iconFrame: 68, minHeight: 68) {
                viewModel.togglePlayPause()
            }
            bottomIconBtn(
                "forward.end.fill", iconSize: 22, iconFrame: 44,
                minHeight: 44) {
                Task { await viewModel.nextChapter() }
            }
        }
    }

    private var bottomIconRow: some View {
        HStack(spacing: 28) {
            // '换源' L3719 域确证。
            bottomIconBtn(
                "arrow.triangle.swap", iconSize: 18, iconFrame: 40,
                minHeight: 40) {}
            bottomIconBtn(
                "moon.zzz", iconSize: 18, iconFrame: 40, minHeight: 40) {
                AudioBookService.shared.configureSleepTimer(minutes: 30)
            }
            if !timerLabel.isEmpty {
                Text(timerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// skinSwitcher getter（'苹果'/'经典' L4579/L4584 域确证）。
    @ViewBuilder
    private var skinSwitcher: some View {
        Picker(selection: .constant(AudioPlayerSkin.apple)) {
            Text("经典").tag(AudioPlayerSkin.classic)
            Text("苹果").tag(AudioPlayerSkin.apple)
        } label: {
            Label("皮肤", systemImage: "paintbrush")
        }
        .pickerStyle(.menu)
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
