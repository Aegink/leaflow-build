// 原路径: ReadMain/Views/Reader/Audio/AudioMiniPlayerOverlay.swift
// 证据:
//   - PGO: 60 条记录（index/task_functions.csv T-801-11 /
//     AudioMiniPlayerOverlay.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（body/coverImage/isActive/miniBar/
//     showsCoverImage 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Audio/
//     AudioMiniPlayerOverlay.c（4319 行）
//   - 块体确证（签名域）：
//     body getter / coverImage getter / isActive getter / miniBar
//     getter / showsCoverImage getter（frame(minWidth:idealWidth:
//     maxWidth:minHeight:idealHeight:maxHeight:alignment:) 域）
//   - 字符串域：无用户字符串（纯迷你条域）
//   - 事实：阅读页迷你播放条（封面 + 播放/暂停 + 关闭）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（五签名域确证）
// 还原: 2026-11-20

import SwiftUI

/// 迷你播放条（body/coverImage/isActive/miniBar 签名域确证）。
struct AudioMiniPlayerOverlay: View {

    @ObservedObject private var service = AudioBookService.shared

    /// isActive getter（签名域确证：播放中显示）。
    private var isActive: Bool {
        service.currentURL != nil
    }

    /// showsCoverImage getter（签名域确证）。
    private var showsCoverImage: Bool {
        true
    }

    var body: some View {
        Group {
            if isActive {
                miniBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }

    /// miniBar getter（签名域确证：封面 + 控制 + 关闭域）。
    @ViewBuilder
    private var miniBar: some View {
        HStack(spacing: 12) {
            if showsCoverImage {
                coverImage
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                    .clipped()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(service.isPlaying ? "正在播放" : "已暂停")
                    .font(.caption.weight(.medium))
                if let url = service.currentURL {
                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                service.togglePlayPause()
            } label: {
                Image(systemName: service.isPlaying
                    ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .appThemeTint(.primary)
            }
            .buttonStyle(.plain)
            Button {
                service.stop()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        )
    }

    /// coverImage getter（签名域确证：封面占位域）。
    @ViewBuilder
    private var coverImage: some View {
        ZStack {
            Rectangle()
                .fill(Color.blue.opacity(0.12))
            Image(systemName: "waveform")
                .foregroundStyle(.blue)
        }
    }
}
