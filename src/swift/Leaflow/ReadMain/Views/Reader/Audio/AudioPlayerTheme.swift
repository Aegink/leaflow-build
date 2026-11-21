// 原路径: ReadMain/Views/Reader/Audio/AudioPlayerTheme.swift
// 证据:
//   - PGO: 4 条记录（index/task_functions.csv T-801-11 /
//     AudioPlayerTheme.swift；1 函数，伪代码 27 行）
//   - CovMap: 上述 L 区段（next getter 0x1005e7668 L24-28 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Audio/
//     AudioPlayerTheme.c（27 行）
//   - 块体确证（地址+行号域）：
//     AudioPlayerSkin.next getter 0x1005e7668 L24-28（AppStorage 域 +
//     result==2 → 0 环绕域：两档循环 classic → apple → classic）
//   - 事实：皮肤两档枚举（id/displayName/icon getter 签名域）+
//     AppStorage 环绕切换
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（next 环绕域确证）
// 还原: 2026-11-20

import SwiftUI

/// 音频播放器皮肤（next 0x1005e7668 L24-28 块体确证：两档循环）。
enum AudioPlayerSkin: String, CaseIterable, Identifiable {

    case classic
    case apple

    var id: String {
        rawValue
    }

    /// next getter（0x1005e7668 块体确证：循环环绕域）。
    var next: AudioPlayerSkin {
        switch self {
        case .classic:
            return .apple
        case .apple:
            return .classic
        }
    }

    /// displayName getter（签名域确证）。
    var displayName: String {
        switch self {
        case .classic:
            return "经典"
        case .apple:
            return "苹果"
        }
    }

    /// icon getter（签名域确证）。
    var icon: String {
        switch self {
        case .classic:
            return "square.stack.3d.up"
        case .apple:
            return "circle.grid.2x1"
        }
    }
}
