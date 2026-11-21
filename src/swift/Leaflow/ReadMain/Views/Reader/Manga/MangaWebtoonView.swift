// 原路径: ReadMain/Views/Reader/Manga/MangaWebtoonView.swift
// 证据:
//   - PGO: 7 个主函数（index/task_functions.csv T-304-05 / MangaWebtoonView.swift），
//     地址：makeCoordinator 0x100636430 L8-10 / makeUIViewController
//     0x100636594 L12-33 / updateUIViewController 0x10063666c L35-63
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/MangaWebtoonView.c
//   - 事实：webtoon Representable（reloadData/appendPages/scrollToPage 联动确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（Representable 链确证）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// webtoon 竖排 Representable。
struct MangaWebtoonView: UIViewControllerRepresentable {

    var pages: [MangaPage]
    var onCenterTap: () -> Void
    var onVisiblePageChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            pages: pages, onCenterTap: onCenterTap,
            onVisiblePageChange: onVisiblePageChange)
    }

    func makeUIViewController(context: Context) -> MangaWebtoonViewController {
        // 伪代码 0x100636594（L12-33）。
        let controller = MangaWebtoonViewController()
        controller.onCenterTap = onCenterTap
        controller.onVisiblePageChange = onVisiblePageChange
        controller.reloadData(pages: pages)
        return controller
    }

    func updateUIViewController(
        _ controller: MangaWebtoonViewController, context: Context
    ) {
        // 伪代码 0x10063666c（L35-63）：差量追加/全量刷新。
        context.coordinator.pages = pages
        controller.reloadData(pages: pages)
    }

    @MainActor
    final class Coordinator {

        var pages: [MangaPage]
        let onCenterTap: () -> Void
        let onVisiblePageChange: (Int) -> Void

        init(
            pages: [MangaPage],
            onCenterTap: @escaping () -> Void,
            onVisiblePageChange: @escaping (Int) -> Void
        ) {
            self.pages = pages
            self.onCenterTap = onCenterTap
            self.onVisiblePageChange = onVisiblePageChange
        }
    }
}
