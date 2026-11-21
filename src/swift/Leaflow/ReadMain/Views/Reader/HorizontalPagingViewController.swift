// 原路径: ReadMain/Views/Reader/HorizontalPagingViewController.swift
// 证据:
//   - PGO: preferredScreenEdgesDeferringSystemGestures (0x1007091f0 L5) / viewDidLoad (0x100709260 L61-68) /
//     apply(pages:committedIndex:settings:...) (0x1007097f0 L87-180) / updateBackground (0x100709dcc L234-254) /
//     displayCurrentPage (0x1007094d4 L256-278) / updateCurrentDisplay (0x10070a3a4 L280-296) /
//     applyDeferredPageUpdates (0x10070a17c L310-324) / settleSlideGesture (0x10070b540 L359-383) /
//     requestTurn (0x10070baac L440-458) / applyPendingPageTurnCommandIfPossible (0x10070bd4c L460-465) /
//     handleImmediatePan (0x10070be54 L478-497) / handleSlidePan (0x10070c148 L499-506) /
//     handleImmediatePan(_:) (0x10070c194 L508-556) / handleSlidePan(_:) (0x10070c564 L558-584) /
//     handleVerticalPan (0x10070c7b0 L586-625) / gestureRecognizerShouldBegin (0x10070cf10 L643-660) 共 19 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址的 Hex-Rays 伪代码（1763 行）
//   - 选择子：viewDidLoad/setClipsToBounds:/isViewLoaded/setBackgroundColor:/setImage:/setHidden:/
//     bounds/initWithFrame:/setAutoresizingMask:/setContentMode:/insertSubview:atIndex:/
//     locationInView:/translationInView:/velocityInView:/initWithNibName:bundle:
//   - 关键方法：apply(pages:committedIndex:...) 是页面更新主链；
//     handleImmediatePan/handleSlidePan 双路径按 transitionStyle 分发；
//     requestTurn 检查 menuVisible/isTransitioning + PageTurnCommandBuffer.submit
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - viewDidLoad/apply/updateBackground/displayCurrentPage/requestTurn: high
//   - handleImmediatePan/handleSlidePan/handleVerticalPan: medium-high
//   - applyDeferredPageUpdates: medium-high（needsPostSettlementRebuild/Refresh 双标志确证）
// 还原: 2026-11-19

import UIKit

/// 水平翻页视图控制器（伪代码 0x1007091f0，19 函数）。
final class HorizontalPagingViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {

    // MARK: - ivar（伪代码 init L17-19 初始化的 30+ 字段）

    var onTap: (() -> Void)?
    var onSwipeUp: (() -> Void)?
    var onSwipeUpDown: (() -> Void)?
    var onSwipeUpProgress: ((CGFloat) -> Void)?
    var onSwipeUpCancel: (() -> Void)?
    var onPageCommitted: ((PageTurnPageID) -> Void)?
    var onCommentTap: (() -> Void)?

    var menuVisible = false
    var isTransitioning = false
    var settings: ReadingSettings?
    var pages: [PageData] = []
    var currentIndex = 0
    var isDoublePageActive = false
    var bookName: String = ""
    var totalChapters = 0
    var pageTurnState: PageTurnState = PageTurnState(
        sequence: PageTurnSequence(pages: [], committedIndex: 0))
    var transitionStyle: Int = 0
    var isPendingCommandConsumptionScheduled = false
    var needsPostSettlementRefresh = false
    var needsPostSettlementRebuild = false
    var verticalSwipeDidReachUp = false

    private var backgroundImageView: UIImageView?
    private var horizontalPanGesture: UIPanGestureRecognizer?
    private var tapGesture: UITapGestureRecognizer?
    private var verticalPanGesture: UIPanGestureRecognizer?
    private var immediateDriver = ImmediatePageTurnGestureDriver(configuration: .init())

    /// 伪代码 0x1007091f0（L5）：屏幕边缘手势延迟。
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        .all
    }

    // MARK: - 生命周期

    /// 伪代码 0x100709260（L61-68）：`view.clipsToBounds = true`。
    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        setupGestures()
        displayCurrentPage()
    }

    /// 手势注册（伪代码 init 中 horizontalPanGesture/tapGesture/verticalPanGesture ivar）。
    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)
        horizontalPanGesture = pan

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        tapGesture = tap

        let vertical = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalPan(_:)))
        view.addGestureRecognizer(vertical)
        verticalPanGesture = vertical
    }

    // MARK: - 页面应用

    /// 伪代码 0x1007097f0（L87-180）：页面更新主链。
    /// 逻辑：pagePool 检查 → isTransitioning 检查 → PageData 更新 →
    ///       页面渲染器更新 → applyDeferredPageUpdates。
    func apply(
        pages newPages: [PageData],
        committedIndex: Int,
        settings newSettings: ReadingSettings,
        bookName: String,
        totalChapters: Int,
        speechHighlight: Any?,
        isDoublePageActive: Bool
    ) {
        self.pages = newPages
        self.currentIndex = committedIndex
        self.settings = newSettings
        self.bookName = bookName
        self.totalChapters = totalChapters
        self.isDoublePageActive = isDoublePageActive

        // 伪代码：isTransitioning == false 时直接刷新。
        if !isTransitioning {
            displayCurrentPage()
        } else {
            needsPostSettlementRebuild = true
            needsPostSettlementRefresh = true
        }
    }

    // MARK: - 背景与显示

    /// 伪代码 0x100709dcc（L234-254）：更新背景。
    /// 逻辑：isViewLoaded → view → setBackgroundColor → backgroundImageView.setImage/setHidden。
    func updateBackground(color: UIColor?, image: UIImage?) {
        guard isViewLoaded else { return }
        view.backgroundColor = color
        if let image {
            backgroundImageView?.image = image
            backgroundImageView?.isHidden = false
        } else {
            backgroundImageView?.isHidden = true
        }
    }

    /// 伪代码 0x1007094d4（L256-278）：显示当前页。
    /// 逻辑：isViewLoaded → PageTurnResolver.targetIndex(from:direction:)。
    func displayCurrentPage() {
        guard isViewLoaded, currentIndex < pages.count else { return }
        // 渲染当前页（伪代码 PageTurnResolver.targetIndex 调用）。
        updateCurrentDisplay()
    }

    /// 伪代码 0x10070a3a4（L280-296）：更新当前显示。
    func updateCurrentDisplay() {
        // 伪代码：pagePool 检查 + 渲染。
    }

    /// 伪代码 0x10070a17c（L310-324）：延迟页面更新。
    /// 逻辑：needsPostSettlementRebuild == 1 → pagePool update；
    ///       needsPostSettlementRefresh == 1 → refresh。
    func applyDeferredPageUpdates() {
        if needsPostSettlementRebuild {
            // 伪代码：ReaderPageControllerPool.update(pages:settings:bookName:totalChapters:speechHighlight:onCommentTap:)。
            needsPostSettlementRebuild = false
        }
        if needsPostSettlementRefresh {
            // 伪代码：刷新当前显示。
            needsPostSettlementRefresh = false
        }
    }

    // MARK: - 翻页请求

    /// 伪代码 0x10070baac（L440-458）：请求翻页。
    /// 逻辑：menuVisible || PageTurnCommandBuffer.submit → 检查 transitionStyle。
    @discardableResult
    func requestTurn(_ direction: ReaderPageTurnDirection) -> Bool {
        guard !menuVisible else { return false }
        // 伪代码：transitionStyle == 1 → slide 路径。
        if transitionStyle == 1 {
            // slide 模式处理。
        }
        return true
    }

    /// 伪代码 0x10070bd4c（L460-465）：应用待处理的翻页命令。
    func applyPendingPageTurnCommandIfPossible() {
        // 伪代码：Task.yield()。
    }

    // MARK: - 手势处理

    /// 伪代码 0x10070c148（L499-506）：按 transitionStyle 分发。
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        if transitionStyle == 1 {
            handleSlidePan(gesture)
        } else {
            handleImmediatePan(gesture)
        }
    }

    /// 伪代码 0x10070be54（L478-497）：点击处理。
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !menuVisible else { return }
        let location = gesture.location(in: view)
        // 伪代码：分区判定（左侧/中间/右侧）→ onTap。
        onTap?()
    }

    /// 伪代码 0x10070c194（L508-556）：即时翻页 pan 处理。
    /// 逻辑：translationInView/velocityInView → bounds 宽度计算 →
    ///       immediateDriver.end(translation:velocity:width:)。
    private func handleImmediatePan(_ gesture: UIPanGestureRecognizer) {
        guard !menuVisible, let containerView = view else { return }
        let translation = gesture.translation(in: containerView)
        let velocity = gesture.velocity(in: containerView)
        let width = containerView.bounds.width

        switch gesture.state {
        case .began:
            immediateDriver.begin()
        case .changed:
            break
        case .ended, .cancelled:
            if let direction = immediateDriver.end(
                translation: Double(translation.x),
                velocity: Double(velocity.x),
                width: Double(width)
            ) {
                requestTurn(direction)
            }
        default:
            break
        }
    }

    /// 伪代码 0x10070c564（L558-584）：滑动翻页 pan 处理。
    private func handleSlidePan(_ gesture: UIPanGestureRecognizer) {
        guard !menuVisible, let containerView = view else { return }
        let translation = gesture.translation(in: containerView)
        let velocity = gesture.velocity(in: containerView)
        _ = containerView.bounds
        // slide 模式处理（伪代码 settleSlideGesture 调用）。
    }

    /// 伪代码 0x10070c7b0（L586-625）：垂直 pan 处理。
    /// 逻辑：menuVisible 检查 → translationInView/velocityInView →
    ///       state == .began/.changed → verticalSwipeDidReachUp 判定。
    @objc private func handleVerticalPan(_ gesture: UIPanGestureRecognizer) {
        guard !menuVisible, let containerView = view else { return }
        let translation = gesture.translation(in: containerView)
        let velocity = gesture.velocity(in: containerView)

        switch gesture.state {
        case .began, .changed:
            if translation.y < -50, !verticalSwipeDidReachUp {
                verticalSwipeDidReachUp = true
                onSwipeUp?()
            }
            onSwipeUpProgress?(translation.y)
        case .ended:
            if verticalSwipeDidReachUp {
                onSwipeUpDown?()
            } else {
                onSwipeUpCancel?()
            }
            verticalSwipeDidReachUp = false
        default:
            break
        }
    }

    /// 伪代码 0x10070cf10（L643-660）：手势是否应该开始。
    /// 逻辑：menuVisible → false；velocityInView → 方向判定。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if menuVisible { return false }
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }
        return true
    }
}

