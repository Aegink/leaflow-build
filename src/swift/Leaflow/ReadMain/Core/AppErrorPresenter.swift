// 原路径: ReadMain/Core/AppErrorPresenter.swift
// 证据:
//   - PGO: 12 个主函数（index/task_functions.csv T-101-02 / AppErrorPresenter.swift），
//     地址：ToastLevel.icon 0x100171058 L13-20 / ToastLevel.tintColor 0x100171170
//     L22-29（Color.blue 确证）/ ToastItem.==（pgo_only）/ queue 变量初始化
//     0x10017a29c L63 / show 0x100171778 L71-83（UUID.init 确证）/
//     warning 0x100736694 L96-98 / dismiss 0x100171f70 L106-120（+closure #1/#2，
//     UUID.== 匹配移除确证）/ present 0x10017242c L124（+closure）/ scheduleDismiss
//     0x100172744 L131（+closure）；pgo_only：success/error/present(AppError)
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/AppErrorPresenter.c（502 行）
//   - 事实：ToastLevel —— icon/tintColor 展示属性；ToastItem —— UUID id + level +
//     duration（show L71-83 构造确证）；AppErrorPresenter —— 单例（queue 队列
//     L63 确证）；show → 入队 + present + scheduleDismiss(after: duration)；
//     dismiss → 按 id 匹配移除（UUID.== 确证）；success/warning/error 为
//     show 的级别便捷入口
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 队列/展示/移除链: high（UUID/queue/闭包确证）
//   - icon/tintColor 文案: medium（Color.blue 一处确证；其余待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 提示级别。
enum ToastLevel {
    case info
    case success
    case warning
    case error

    /// 伪代码 0x100171058（L13-20）：图标符号名。
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    /// 伪代码 0x100171170（L22-29）：色（Color.blue 一处确证）。
    var tintColor: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

/// 提示条目（show 构造链确证）。
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let level: ToastLevel
    let duration: Double

    /// pgo_only ==（字段相等）。
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 提示展示器（单例；queue 队列确证）。
@MainActor
final class AppErrorPresenter: ObservableObject {

    static let shared = AppErrorPresenter()

    /// 伪代码 0x10017a29c（L63）：待展示队列。
    @Published private(set) var queue: [ToastItem] = []

    /// 伪代码 0x100171778（L71-83）：构造 ToastItem 入队并调度。
    func show(
        _ message: String, level: ToastLevel, duration: Double = 2.5
    ) {
        let item = ToastItem(
            message: message, level: level, duration: duration)
        present(item)
        scheduleDismiss(after: duration)
    }

    /// pgo_only 便捷入口（签名确证）。
    func success(_ message: String, duration: Double = 2.0) {
        show(message, level: .success, duration: duration)
    }

    /// 伪代码 0x100736694（L96-98）。
    func warning(_ message: String, duration: Double = 2.5) {
        show(message, level: .warning, duration: duration)
    }

    /// pgo_only。
    func error(_ message: String, duration: Double = 3.0) {
        show(message, level: .error, duration: duration)
    }

    /// pgo_only present(AppError)。
    func present(_ error: AppError) {
        show(error.errorDescription ?? "未知错误", level: .error)
    }

    /// 伪代码 0x100171f70（L106-120 + closure #1/#2，UUID.== 匹配移除确证）。
    func dismiss() {
        guard let current = queue.first else { return }
        queue.removeAll { $0.id == current.id }
    }

    /// 伪代码 0x10017242c（L124 + closure）：上屏（挂到当前 toast 宿主）。
    private func present(_ item: ToastItem) {
        // GlobalToastOverlay 域消费（T-101-05）。
        queue.append(item)
        if queue.count > 3 {
            queue.removeFirst()
        }
    }

    /// 伪代码 0x100172744（L131 + closure）：定时移除。
    private func scheduleDismiss(after duration: Double) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.dismiss()
        }
    }
}
