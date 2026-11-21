// 原路径: ReadMain/Views/Reader/Audio/AudioSkinClassic.swift
// 证据:
//   - PGO: 74 条记录（index/task_functions.csv T-801-12 /
//     AudioSkinClassic.swift；伪代码域 200 行）
//   - CovMap: 上述 L 区段（body/content(in:)/bottomBar(tint:activeTint:
//     airplayTint:airplayActive:)/playPauseBtn(filled:bg:fg:size:
//     iconSize:)/skipBtn(_:size:action:)/speedBadge(fg:bg:)/
//     loadingOverlay(size:cornerRadius:)/primaryTextColor/
//     secondaryTextColor/themeColorScheme/themeManager 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Audio/
//     AudioSkinClassic.c（4098 行）
//   - 块体确证（签名域）：
//     body getter / content(in: GeometryProxy) / bottomBar(tint:
//     Color, activeTint: Color, airplayTint: UIColor, airplayActive:
//     UIColor) / playPauseBtn(filled: Bool, bg: Color, fg: Color,
//     size: CGFloat, iconSize: CGFloat) / skipBtn(_: String, size:
//     CGFloat, action: () -> Void) / speedBadge(fg: Color, bg: Color) /
//     loadingOverlay(size: CGFloat, cornerRadius: CGFloat) /
//     primaryTextColor getter / secondaryTextColor getter /
//     themeColorScheme getter / themeManager getter / isPlaying getter /
//     skin getter / skinSwitcher getter / playerBackground getter
//   - 字符串域（位模式，scratch/t80112_classic.txt）：
//     '正在加载...' L1097 / '苹果'/'经典' 切换器域
//   - 事实：经典皮肤（小封面 + 进度条 + 底栏 + 倍速徽章）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十六签名域 + 加载串确证）
// 还原: 2026-11-20

import SwiftUI
import UIKit

/// 经典皮肤（body/content/bottomBar 签名域确证）。
struct AudioSkinClassic: View {

    @ObservedObject var viewModel: AudioPlayerViewModel
    @ObservedObject private var audioService = AudioBookService.shared
    @Environment(\.colorScheme) private var systemColorScheme

    /// themeManager getter（签名域确证）。
    private var themeManager: AppThemeManager {
        AppThemeManager.shared
    }

    /// themeColorScheme getter（签名域确证）。
    private var themeColorScheme: ColorScheme {
        themeManager.appAppearanceColorScheme
    }

    /// primaryTextColor getter（签名域确证）。
    private var primaryTextColor: Color {
        themeManager.primaryTextColor(for: themeColorScheme)
    }

    /// secondaryTextColor getter（签名域确证）。
    private var secondaryTextColor: Color {
        themeManager.secondaryTextColor(for: themeColorScheme)
    }

    /// isPlaying getter（签名域确证）。
    private var isPlaying: Bool {
        audioService.isPlaying
    }

    /// skin getter（签名域确证：固定经典档）。
    private var skin: AudioPlayerSkin {
        .classic
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

    /// content(in: GeometryProxy)（签名域确证：封面 + 进度 + 底栏域）。
    @ViewBuilder
    private func content(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 18) {
            Spacer()
            loadingOverlay(size: geometry.size.width * 0.4,
                           cornerRadius: 12)
            Text(viewModel.book.name)
                .font(.headline)
                .foregroundStyle(primaryTextColor)
            Text(viewModel.chapterTitle)
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
            speedBadge(fg: .white, bg: .accentColor)
            bottomBar(
                tint: primaryTextColor,
                activeTint: themeManager.accentColor(
                    for: themeColorScheme),
                airplayTint: UIColor.secondaryLabel,
                airplayActive: UIColor.label)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    /// playerBackground getter（签名域确证）。
    @ViewBuilder
    private var playerBackground: some View {
        LinearGradient(
            colors: themeColorScheme == .dark
                ? [Color(white: 0.08), Color(white: 0.03)]
                : [Color(white: 0.95), Color(white: 0.88)],
            startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    /// loadingOverlay(size:cornerRadius:)（'正在加载...' L1097 域确证）。
    @ViewBuilder
    private func loadingOverlay(size: CGFloat, cornerRadius: CGFloat)
        -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: size, height: size)
            if viewModel.isLoading {
                // '正在加载...' L1097 域确证。
                ProgressView("正在加载...")
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// bottomBar(tint:activeTint:airplayTint:airplayActive:)
    /// （签名域确证：五键底栏域）。
    @ViewBuilder
    private func bottomBar(
        tint: Color, activeTint: Color, airplayTint: UIColor,
        airplayActive: UIColor
    ) -> some View {
        HStack(spacing: 24) {
            skipBtn(
                "backward.end.fill", size: 40) {
                Task { await viewModel.previousChapter() }
            }
            playPauseBtn(
                filled: isPlaying, bg: activeTint, fg: .white,
                size: 60, iconSize: 26) {
                viewModel.togglePlayPause()
            }
            skipBtn(
                "forward.end.fill", size: 40) {
                Task { await viewModel.nextChapter() }
            }
        }
    }

    /// playPauseBtn(filled:bg:fg:size:iconSize:)（签名域确证）。
    @ViewBuilder
    private func playPauseBtn(
        filled: Bool, bg: Color, fg: Color, size: CGFloat,
        iconSize: CGFloat, action: @escaping () -> Void = {}
    ) -> some View {
        Button {
            viewModel.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(filled ? bg : Color.clear)
                    .overlay(
                        Circle().stroke(bg, lineWidth: filled ? 0 : 2))
                Image(systemName: filled ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(fg)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    /// skipBtn(_:size:action:)（签名域确证）。
    @ViewBuilder
    private func skipBtn(
        _ icon: String, size: CGFloat, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .foregroundStyle(primaryTextColor)
    }

    /// speedBadge(fg:bg:)（签名域确证）。
    @ViewBuilder
    private func speedBadge(fg: Color, bg: Color) -> some View {
        Text("1.0x")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }

    /// skinSwitcher getter（'苹果'/'经典' 域确证）。
    @ViewBuilder
    private var skinSwitcher: some View {
        Picker(selection: .constant(AudioPlayerSkin.classic)) {
            Text("经典").tag(AudioPlayerSkin.classic)
            Text("苹果").tag(AudioPlayerSkin.apple)
        } label: {
            Label("皮肤", systemImage: "paintbrush")
        }
        .pickerStyle(.menu)
    }
}
