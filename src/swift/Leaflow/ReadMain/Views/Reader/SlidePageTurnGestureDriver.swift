// 原路径: ReadMain/Views/Reader/SlidePageTurnGestureDriver.swift
// 证据:
//   - PGO: 8 个主函数（index/task_functions.csv T-301-12 / SlidePageTurnGestureDriver.swift），
//     地址：Configuration 变量初始化 0x1008b7fc4/0x1008b8010 L21-22 /
//     update(translation:width:) 0x1008b76b0 L49-81 / end(translation:velocity:width:)
//     0x1008b7874 L87-117 / pendingDirection 0x1008b7c50 L133-140 /
//     direction(for:) 0x1008b7bb0 L142-146 / activationDistance 0x1008b7a54 L148-153 /
//     isCompletingFlick(direction:velocity:) 0x1008b7d30 L167-170
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/SlidePageTurnGestureDriver.c（273 行）
//   - 事实：update —— width <= 0 → nil；phase 2（idle）→ nil；phase 3（active）→
//     |translation| 与激活距离 clamp（v7/v8/v9 = 下限/上限）后 direction(for:) 定向；
//     end —— width <= 0 或 idle → 复位（optional tag 128 = nil）；
//     active → pendingDirection 命中 → 提交（|0x40 = some tag），否则 nil；
//     |translation| >= activationDistance || isCompletingFlick → 提交
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（相位字节/阈值链确证）
// 还原: 2026-11-19

import UIKit

/// 滑动翻页手势驱动器（与 ImmediatePageTurnGestureDriver 同域，slide 路径）。
struct SlidePageTurnGestureDriver {

    /// 配置（Configuration 变量初始化确证；常量值待真机对照）。
    struct Configuration {
        var activationRatio: CGFloat = 0.28
        var minimumDistance: CGFloat = 12.0
        var flickVelocity: CGFloat = 600.0
        /// 伪代码 0x1008b7fc4（L21）：甩动速度阈值 varinit（计数器桩）。
        var flickVelocityThreshold: CGFloat = 600.0
        /// 伪代码 0x1008b8010（L22）：甩动最小距离 varinit（计数器桩）。
        var flickMinimumDistance: CGFloat = 24.0
    }

    /// 手势相位（update/end 的 phase 字节确证）。
    private enum Phase: Int {
        case idle = 2
        case active = 3
    }

    /// 落定结果（optional tag 语义确证：nil = 不翻页）。
    enum SlidePageTurnGestureSettlement: Equatable {
        case none
        case turn(ReaderPageTurnDirection)
    }

    private let configuration: Configuration
    private var phase: Phase = .idle
    private var direction: ReaderPageTurnDirection?
    private var startX: CGFloat = 0

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// 激活距离（伪代码 0x1008b7a54，L148-153：宽度比例 clamp 确证）。
    private func activationDistance(width: CGFloat) -> CGFloat {
        let distance = width * configuration.activationRatio
        return min(max(distance, configuration.minimumDistance), width / 2)
    }

    /// 方向判定（伪代码 0x1008b7bb0，L142-146）。
    private func direction(for translation: CGFloat) -> ReaderPageTurnDirection? {
        if translation > 0 {
            return .next
        }
        if translation < 0 {
            return .previous
        }
        return nil
    }

    /// 完成甩动判定（伪代码 0x1008b7d30，L167-170）。
    private func isCompletingFlick(direction: ReaderPageTurnDirection?, velocity: CGFloat) -> Bool {
        guard let direction else { return false }
        let signedVelocity = direction == .next ? velocity : -velocity
        return signedVelocity > configuration.flickVelocity
    }

    /// 伪代码 0x1008b76b0（L49-81）：拖动更新。
    /// width <= 0 / idle → nil；active → 激活距离 clamp + 定向。
    mutating func update(translation: CGFloat, width: CGFloat) -> ReaderPageTurnDirection? {
        guard width > 0, phase == .active else { return nil }
        let distance = min(
            max(abs(translation), configuration.minimumDistance),
            activationDistance(width: width))
        guard distance <= abs(translation),
              let resolved = direction(for: translation) else { return nil }
        self.direction = resolved
        return resolved
    }

    /// 待定方向（伪代码 0x1008b7c50，L133-140）。
    private func pendingDirection(
        translation: CGFloat, velocity: CGFloat, width: CGFloat
    ) -> ReaderPageTurnDirection? {
        guard abs(translation) >= activationDistance(width: width) else { return nil }
        return direction(for: translation)
    }

    /// 伪代码 0x1008b7874（L87-117）：手势结束。
    /// width <= 0 / idle → 复位并返回 none；
    /// active → pendingDirection || isCompletingFlick 提交方向，否则 none。
    mutating func end(
        translation: CGFloat, velocity: CGFloat, width: CGFloat
    ) -> SlidePageTurnGestureSettlement {
        defer {
            phase = .idle
            direction = nil
        }
        guard width > 0, phase == .active else { return .none }
        if let pending = pendingDirection(translation: translation, velocity: velocity, width: width) {
            return .turn(pending)
        }
        if isCompletingFlick(direction: direction, velocity: velocity) {
            return .turn(direction ?? .next)
        }
        return .none
    }
}
