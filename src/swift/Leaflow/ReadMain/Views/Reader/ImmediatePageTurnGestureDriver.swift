// 原路径: ReadMain/Views/Reader/ImmediatePageTurnGestureDriver.swift
// 证据:
//   - PGO: init(configuration:) (0x100708d48/0x10077ad5c L17-19) / end(translation:velocity:width:) (0x10070d5e4 L31-44) /
//     direction(for:) (0x10070d7e8 L50-54) / activationDistance(for:) (0x10070d710 L56-61) 共 5 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址的 Hex-Rays 伪代码（418 行，完整读完）
//   - 关键常量：activationDistance = 0.06；config 距离阈值 0x4020000000000000 = 8.0；
//     direction: >0 → case 0(.next)、<0 → case 1(.previous)、==0 → case 2(nil)
//   - 关键 ivar 初始化（init L17-19 双副本）：onTap/onSwipeUp/onSwipeUpDown/onSwipeUpProgress/
//     onSwipeUpCancel/onPageCommitted/onCommentTap 闭包；menuVisible/isTransitioning/settings/
//     pages/currentIndex/isDoublePageActive/bookName/totalChapters/speechHighlight/pageTurnState/
//     pagePool/slideGestureDriver(type=2)/immediateGestureDriver(type=0)/turnPerformanceTrace/
//     backgroundImageView/horizontalPanGesture/tapGesture/verticalPanGesture/
//     verticalSwipeDidReachUp/pageTurnCommandBuffer/isPendingCommandConsumptionScheduled/
//     needsPostSettlementRefresh/needsPostSettlementRebuild/transitionStyle/renderer
//   - 第一副本 0x100708d48 末尾有 _assertionFailure("Fatal error") —— 不可达路径
//   - 第二副本 0x10077ad5c 调用 super initWithNibName:bundle: + UIKitReaderPageSettlementAnimator +
//     ReaderTwoPageRenderer
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - end/direction/activationDistance: high（5 函数全部完整读完，判定链确证）
//   - init: high（双副本 ivar 初始化逐一对照）
// 还原: 2026-11-19

import UIKit

/// 即时翻页手势驱动器（伪代码 0x100708d48/0x10077ad5c/0x10070d5e4/0x10070d7e8/0x10070d710）。
struct ImmediatePageTurnGestureDriver {

    /// 伪代码 Configuration（activationDistance = 0.06，距离阈值 8.0）。
    struct Configuration {
        /// 伪代码 0x10070d710（L56-61）：返回 0.06。
        var activationRatio: CGFloat = 0.06
        /// 伪代码 0x4020000000000000 = 8.0。
        var minimumDistance: CGFloat = 8.0
        /// 速度阈值倍数。
        var velocityThreshold: CGFloat = 0.5
    }

    private let configuration: Configuration
    /// 伪代码 `*(v3) != 1`：active 状态标志。
    private var isActive = false

    /// 伪代码 0x100708d48（L17-19）/ 0x10077ad5c（L17-19）：初始化配置。
    /// 第一副本有 `__noreturn`（assertionFailure("Fatal error")）—— 不可达路径。
    /// 第二副本正常返回：初始化全部 ivar 后调用 `initWithNibName:bundle: nil, nil`。
    init(configuration: Configuration) {
        self.configuration = configuration
        // 伪代码：初始化 HorizontalPagingViewController 的 30+ ivar。
        // onTap/onSwipeUp/onSwipeUpDown/onSwipeUpProgress/onSwipeUpCancel/onPageCommitted/onCommentTap = nil
        // menuVisible = false, isTransitioning = false
        // pages = [], currentIndex = 0, isDoublePageActive = false
        // bookName = "", totalChapters = 0
        // slideGestureDriver(type=2), immediateGestureDriver(type=0)
        // needsPostSettlementRefresh = false, needsPostSettlementRebuild = false
    }

    /// 伪代码 0x10070d5e4（L31-44）：手势结束时判定翻页方向。
    /// 逻辑：
    /// 1. `isActive != true || width <= 0` → 返回 nil。
    /// 2. 清除 active 状态。
    /// 3. `fabs(translation)` 与两个阈值比较：
    ///    - 若 `activationDistance >= fabs(velocity) || activationDistance >= fabs(translation)`：
    ///      计算阈值 = max(width * ratio, minimumDistance) → min(阈值, maxRatio)。
    ///      `阈值 <= fabs(translation)` → 返回方向。
    ///      否则 → nil。
    ///    - 否则（速度超过激活距离）→ 直接返回方向。
    mutating func end(
        translation: Double, velocity: Double, width: Double
    ) -> ReaderPageTurnDirection? {
        guard isActive, width > 0.0 else {
            isActive = false
            return nil
        }
        isActive = false

        let absTranslation = abs(translation)
        let absVelocity = abs(velocity)
        let activationDistance = Double(configuration.activationRatio) * width
        let minimumDistance = Double(configuration.minimumDistance)
        let maxDistance = width * Double(configuration.velocityThreshold)

        // 伪代码 L355：`activationDistance >= fabs(velocity) || activationDistance >= fabs(translation)`。
        if activationDistance >= absVelocity || activationDistance >= absTranslation {
            // 距离阈值判定（伪代码 L357-L368）。
            let threshold = max(width * Double(configuration.activationRatio), minimumDistance)
            let clamped = min(threshold, maxDistance)
            if clamped <= absTranslation {
                return direction(for: translation)
            }
            return nil
        }

        // 伪代码 L371-L373：速度超过阈值 → 直接判定方向。
        return direction(for: translation)
    }

    /// 伪代码 0x10070d7e8（L50-54）：translation 正负 → 方向。
    /// 逻辑：> 0 → case 0(.next)；< 0 → case 1(.previous)；== 0 → nil。
    private func direction(for translation: Double) -> ReaderPageTurnDirection? {
        if translation > 0 {
            return .next
        } else if translation < 0 {
            return .previous
        }
        return nil
    }

    /// 伪代码 0x10070d710（L56-61）：激活距离比例。
    /// 逻辑：返回常量 0.06；同时初始化静态配置（距离阈值 8.0）。
    static func activationDistance(for width: Double) -> Double {
        return 0.06
    }

    /// 开始手势（激活状态）。
    mutating func begin() {
        isActive = true
    }
}
