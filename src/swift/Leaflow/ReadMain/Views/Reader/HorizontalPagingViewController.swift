// 原路径: ReadMain/Views/Reader/HorizontalPagingViewController.swift。
// 类型表9551；0x1007097f0应用、0x10070baac请求、0x10070b540落定、
// 0x10070c194滑动、0x10070c564即时、0x10070cf10手势准入。
// 原版视觉、左侧点击偏好和垂直退出设置仍见docs/11/待验清单.md T1602-D01。
import UIKit

final class HorizontalPagingViewController: UIViewController, UIGestureRecognizerDelegate {
    var onTap: (() -> Void)?
    var onSwipeUp: (() -> Void)?
    var onSwipeUpDown: (() -> Void)?
    var onSwipeUpProgress: ((CGFloat) -> Void)?
    var onSwipeUpCancel: (() -> Void)?
    var onPageCommitted: ((ReaderPageCommit) -> Void)?
    var onCommentTap: (() -> Void)?

    var menuVisible = false {
        didSet { if !menuVisible { schedulePendingCommandConsumption() } }
    }
    private(set) var isTransitioning = false
    private(set) var settings: ReadingSettings?
    private(set) var pages: [PageData] = []
    private(set) var currentIndex = 0
    private(set) var isDoublePageActive = false
    private var bookName = ""
    private var totalChapters = 0
    private(set) var pageTurnState = PageTurnState(sequence: PageTurnSequence(pages: [], isDoublePage: false))
    var transitionStyle = PageTransitionStyle.slide
    private var isPendingCommandConsumptionScheduled = false
    private var needsPostSettlementRefresh = false
    private var verticalSwipeDidReachUp = false
    private var backgroundImageView: UIImageView?
    private var horizontalPanGesture: UIPanGestureRecognizer?
    private var verticalPanGesture: UIPanGestureRecognizer?
    private var immediateDriver = ImmediatePageTurnGestureDriver()
    private var slideDriver = SlidePageTurnGestureDriver()
    private var commandBuffer = ReaderPageTurnCommandBuffer()
    private var pagePool: ReaderPageControllerPool?
    private let renderer = ReaderTwoPageRenderer()
    private var speechHighlight = ReaderSpeechHighlight.none

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        renderer.install(in: self)
        setupGestures()
        displayCurrentPage()
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        horizontalPanGesture = pan
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        let vertical = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalPan(_:)))
        vertical.delegate = self
        view.addGestureRecognizer(vertical)
        verticalPanGesture = vertical
    }

    func apply(pages newPages: [PageData], committedIndex: Int, settings newSettings: ReadingSettings,
               bookName: String, totalChapters: Int, speechHighlight: ReaderSpeechHighlight,
               isDoublePageActive: Bool) {
        let sequence = PageTurnSequence(pages: newPages.map {
            .init(id: PageTurnPageID(chapterIndex: $0.chapterIndex, pageIndex: $0.pageIndex),
                isLoadingPlaceholder: $0.isLoadingPlaceholder, isErrorPlaceholder: $0.isErrorPlaceholder)
        }, isDoublePage: isDoublePageActive)
        let rebase = pageTurnState.replaceSequence(sequence, committedIndex: committedIndex)
        pages = newPages
        currentIndex = pageTurnState.currentIndex
        settings = newSettings
        self.bookName = bookName
        self.totalChapters = totalChapters
        self.isDoublePageActive = isDoublePageActive
        self.speechHighlight = speechHighlight
        if pagePool == nil {
            pagePool = ReaderPageControllerPool(settings: newSettings, bookName: bookName,
                totalChapters: totalChapters, speechHighlight: speechHighlight,
                usesTransparentPageBackground: transitionStyle.usesTransparentPageBackground)
        }
        if isViewLoaded {
            updateBackground(color: newSettings.readerBackgroundUIColor, image: newSettings.backgroundUIImage)
        }
        switch rebase {
        case .preserved(let transition):
            // 动画中的控制器不能被池更新按新索引换成别页，落定后才刷新内容。
            renderer.updateTransition(transition)
            needsPostSettlementRefresh = true
        case .cancelled, .updated:
            if isTransitioning {
                _ = renderer.finishSettlement(committed: false)
                isTransitioning = false
                _ = slideDriver.cancel()
                immediateDriver.cancel()
            }
            updatePool()
            displayCurrentPage()
        }
        schedulePendingCommandConsumption()
    }

    private func updatePool() {
        guard let settings else { return }
        pagePool?.update(pages: pages, settings: settings, bookName: bookName,
            totalChapters: totalChapters, speechHighlight: speechHighlight,
            onCommentTap: { [weak self] _, _ in self?.onCommentTap?() })
    }

    func updateBackground(color: UIColor?, image: UIImage?) {
        guard isViewLoaded else { return }
        view.backgroundColor = color
        if let image {
            if backgroundImageView == nil {
                let imageView = UIImageView(frame: view.bounds)
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                view.insertSubview(imageView, at: 0)
                backgroundImageView = imageView
            }
            backgroundImageView?.image = image
            backgroundImageView?.isHidden = false
        } else { backgroundImageView?.isHidden = true }
    }

    func displayCurrentPage() {
        guard isViewLoaded else { return }
        updateCurrentDisplay()
    }

    func updateCurrentDisplay() {
        guard let controller = pagePool?.viewController(for: currentIndex, isDoublePage: isDoublePageActive)
        else { renderer.clear(); return }
        renderer.setCurrentViewController(controller)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func applyDeferredPageUpdates() {
        if needsPostSettlementRefresh {
            updatePool()
            needsPostSettlementRefresh = false
        }
        displayCurrentPage()
    }

    @discardableResult
    private func prepareTurn(_ direction: ReaderPageTurnDirection) -> Bool {
        guard !menuVisible, !isTransitioning, isViewLoaded,
              let transition = pageTurnState.beginTurn(direction) else { return false }
        guard let incoming = pagePool?.viewController(for: transition.targetIndex, isDoublePage: isDoublePageActive)
        else { _ = pageTurnState.finishTurn(committed: false); return false }
        isTransitioning = true
        renderer.transitionStyle = transitionStyle
        renderer.prepare(transition: transition, incoming: incoming)
        return true
    }

    @discardableResult
    func requestTurn(_ direction: ReaderPageTurnDirection) -> Bool {
        guard prepareTurn(direction) else { return false }
        if transitionStyle.settlesImmediately { finishSettlement(committed: true) }
        else { settle(completes: true, velocity: direction == .next ? -800 : 800) }
        return true
    }

    private func settle(completes: Bool, velocity: CGFloat) {
        renderer.animateSettlement(completes: completes, velocity: velocity) { [weak self] committed in
            self?.finishSettlement(committed: committed)
        }
    }

    func finishSettlement(committed: Bool) {
        guard let result = pageTurnState.finishTurn(committed: committed) else { return }
        let didCommit: Bool
        if case .committed = result { didCommit = true } else { didCommit = false }
        _ = renderer.finishSettlement(committed: didCommit)
        isTransitioning = false
        currentIndex = result.index
        applyDeferredPageUpdates()
        if didCommit {
            onPageCommitted?(ReaderPageCommit(index: currentIndex, pages: pages, isDoublePage: isDoublePageActive))
        }
        schedulePendingCommandConsumption()
    }

    func submitPageTurnCommand(_ command: ReaderPageTurnCommand?) {
        commandBuffer.submit(command)
        schedulePendingCommandConsumption()
    }

    private func schedulePendingCommandConsumption() {
        guard !isPendingCommandConsumptionScheduled, commandBuffer.pendingCommand != nil else { return }
        isPendingCommandConsumptionScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.isPendingCommandConsumptionScheduled = false
            self.applyPendingPageTurnCommandIfPossible()
        }
    }

    func applyPendingPageTurnCommandIfPossible() {
        guard !menuVisible, !isTransitioning, isViewLoaded, !pages.isEmpty,
              let command = commandBuffer.take() else { return }
        requestTurn(command.direction)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = Double(gesture.translation(in: view).x)
        let velocity = Double(gesture.velocity(in: view).x)
        handleHorizontalPan(state: gesture.state, translation: translation, velocity: velocity,
            width: Double(view.bounds.width))
    }

    // 与识别器共用入口，固定样本可以验证取消而不伪造UIKit手势状态。
    func handleHorizontalPan(state: UIGestureRecognizer.State, translation: Double, velocity: Double, width: Double) {
        if state == .cancelled || state == .failed {
            immediateDriver.cancel()
            settleSlideGesture(slideDriver.cancel(), velocity: 0)
            return
        }
        guard !menuVisible else { return }
        if transitionStyle.settlesImmediately {
            switch state {
            case .began: if !isTransitioning { immediateDriver.begin() }
            case .ended:
                if let direction = immediateDriver.end(translation: translation, velocity: velocity, width: width) {
                    requestTurn(direction)
                }
            default: break
            }
        } else {
            switch state {
            case .began: if !isTransitioning { slideDriver.begin() }
            case .changed:
                switch slideDriver.update(translation: translation, width: width) {
                case .begin(let direction, let progress):
                    if prepareTurn(direction) { renderer.render(progress: progress) }
                    else { _ = slideDriver.cancel() }
                case .progress(_, let progress): renderer.render(progress: progress)
                case .none: break
                }
            case .ended:
                settleSlideGesture(slideDriver.end(translation: translation, velocity: velocity, width: width),
                    velocity: CGFloat(velocity))
            default: break
            }
        }
    }

    private func settleSlideGesture(_ result: SlidePageTurnGestureSettlement, velocity: CGFloat) {
        switch result {
        case .none: break
        case .cancel(let direction):
            if pageTurnState.transition?.direction == direction { settle(completes: false, velocity: velocity) }
        case .commit(let direction):
            if pageTurnState.transition != nil || prepareTurn(direction) { settle(completes: true, velocity: velocity) }
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !menuVisible, !isTransitioning else { return }
        let handler = pagePool?.activeSelectionHandler(in: renderer.currentViewController)
        if ReaderTextSelectionGestureSupport.consumeTapIfNeeded(gesture, in: view, activeSelectionHandler: handler) { return }
        let x = gesture.location(in: view).x
        if x < view.bounds.width * 0.3 { requestTurn(.previous) }
        else if x > view.bounds.width * 0.7 { requestTurn(.next) }
        else { onTap?() }
    }

    @objc private func handleVerticalPan(_ gesture: UIPanGestureRecognizer) {
        guard !menuVisible else { return }
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .began, .changed:
            if translation.y < -50, !verticalSwipeDidReachUp {
                verticalSwipeDidReachUp = true
                onSwipeUp?()
            }
            onSwipeUpProgress?(translation.y)
        case .ended:
            if verticalSwipeDidReachUp { onSwipeUpDown?() } else { onSwipeUpCancel?() }
            verticalSwipeDidReachUp = false
        case .cancelled, .failed:
            onSwipeUpCancel?()
            verticalSwipeDidReachUp = false
        default: break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !menuVisible, !isTransitioning else { return false }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        if pan === horizontalPanGesture { return abs(velocity.x) > 1.5 * abs(velocity.y) }
        if pan === verticalPanGesture {
            return velocity.y < 0 && abs(velocity.y) > 0.9 * abs(velocity.x)
                && pan.location(in: view).y >= view.bounds.height * 0.75
        }
        return true
    }
}
