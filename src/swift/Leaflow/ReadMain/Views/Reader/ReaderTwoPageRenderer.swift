// 原路径: ReadMain/Views/Reader/ReaderTwoPageRenderer.swift。
// 类型表11306-11328：两个PageSlot、独立遮暗层、弱宿主和动画代际。
// 0x1008437bc装配、0x100844510嵌入、0x100844bac脱离、0x1008442dc复位。
// 动画视觉参数尚未原版逐页对照，见docs/11/待验清单.md T1602-D01。
import UIKit

@MainActor
final class ReaderTwoPageRenderer {
    private final class PageSlot {
        let container = UIView()
        var viewController: UIViewController?
    }

    private let firstSlot = PageSlot()
    private let secondSlot = PageSlot()
    private let dimmingOverlay = UIView()
    private weak var hostViewController: UIViewController?
    private var currentSlot: PageSlot
    private var incomingSlot: PageSlot
    private var transition: PageTurnTransition?
    private var progress: Double = 0
    private var animationGeneration = 0
    var transitionStyle = PageTransitionStyle.slide

    init() {
        currentSlot = firstSlot
        incomingSlot = secondSlot
    }

    var currentViewController: UIViewController? { currentSlot.viewController }

    func install(in parent: UIViewController) {
        guard hostViewController == nil else { return }
        hostViewController = parent
        for slot in [firstSlot, secondSlot] {
            slot.container.frame = parent.view.bounds
            slot.container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            slot.container.clipsToBounds = true
            parent.view.addSubview(slot.container)
        }
        dimmingOverlay.frame = parent.view.bounds
        dimmingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimmingOverlay.backgroundColor = .black
        dimmingOverlay.isUserInteractionEnabled = false
        parent.view.addSubview(dimmingOverlay)
        resetVisuals()
    }

    func setCurrentViewController(_ controller: UIViewController) {
        animationGeneration += 1
        transition = nil
        if incomingSlot.viewController === controller { removeViewController(from: incomingSlot) }
        replaceViewController(in: currentSlot, with: controller)
        removeViewController(from: incomingSlot)
        resetVisuals()
    }

    func prepare(transition: PageTurnTransition, incoming: UIViewController) {
        animationGeneration += 1
        self.transition = transition
        replaceViewController(in: incomingSlot, with: incoming)
        incomingSlot.container.isHidden = false
        switch transitionStyle.layerOrder(for: transition.direction) {
        case .currentAboveDimming:
            hostViewController?.view.bringSubviewToFront(incomingSlot.container)
            hostViewController?.view.bringSubviewToFront(dimmingOverlay)
            hostViewController?.view.bringSubviewToFront(currentSlot.container)
        case .incomingAboveDimming:
            hostViewController?.view.bringSubviewToFront(currentSlot.container)
            hostViewController?.view.bringSubviewToFront(dimmingOverlay)
            hostViewController?.view.bringSubviewToFront(incomingSlot.container)
        case .incomingAboveCurrent:
            hostViewController?.view.bringSubviewToFront(dimmingOverlay)
            hostViewController?.view.bringSubviewToFront(currentSlot.container)
            hostViewController?.view.bringSubviewToFront(incomingSlot.container)
        }
        render(progress: 0)
    }

    func updateTransition(_ transition: PageTurnTransition) {
        self.transition = transition
        render(progress: progress)
    }

    func render(progress: Double) {
        guard let transition else { return }
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        let width = hostViewController?.view.bounds.width ?? 0
        let state = transitionStyle.visualState(direction: transition.direction, progress: self.progress)
        currentSlot.container.transform = CGAffineTransform(translationX: width * CGFloat(state.currentTranslation), y: 0)
        incomingSlot.container.transform = CGAffineTransform(translationX: width * CGFloat(state.incomingTranslation), y: 0)
        dimmingOverlay.alpha = CGFloat(state.dimmingAlpha)
        currentSlot.container.layer.cornerRadius = state.roundsCurrent ? deviceCornerRadius : 0
        incomingSlot.container.layer.cornerRadius = state.roundsIncoming ? deviceCornerRadius : 0
    }

    // 0x100844c6c：窗口圆角优先，否则按顶部安全区及设备种类夹定。
    private var deviceCornerRadius: CGFloat {
        guard let view = hostViewController?.view else { return 0 }
        if let radius = view.window?.layer.cornerRadius, radius > 0 { return radius }
        let top = max(view.window?.safeAreaInsets.top ?? 0, view.safeAreaInsets.top)
        guard top > 20 else { return 0 }
        return view.traitCollection.userInterfaceIdiom == .pad
            ? min(max(top - 3, 18), 28) : min(max(top - 3, 38), 56)
    }

    // 0x100843c40：速度须朝向落定终点，反向速度不能加速完成或取消。
    static func settlementDuration(progress: Double, completes: Bool, direction: ReaderPageTurnDirection,
                                   velocity: CGFloat, width: CGFloat) -> Double {
        let current = progress.isFinite ? min(max(progress, 0), 1) : 0
        let target: Double = completes ? 1 : 0
        let signedSpeed = width > 0 && velocity.isFinite
            ? Double(velocity / width) * (direction == .next ? -1 : 1) : 0
        let towardsTarget = target >= current ? signedSpeed : -signedSpeed
        return abs(target - current) / max(1 / 0.28, towardsTarget)
    }

    func animateSettlement(completes: Bool, velocity: CGFloat, completion: @escaping (Bool) -> Void) {
        guard let transition else { completion(false); return }
        animationGeneration += 1
        let generation = animationGeneration
        let target: Double = completes ? 1 : 0
        let width = hostViewController?.view.bounds.width ?? 0
        let duration = Self.settlementDuration(progress: progress, completes: completes,
            direction: transition.direction, velocity: velocity, width: width)
        UIView.animate(withDuration: duration, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.render(progress: target)
        } completion: { [weak self] finished in
            guard let self, generation == self.animationGeneration else { return }
            completion(finished && completes)
        }
    }

    @discardableResult
    func finishSettlement(committed: Bool) -> Bool {
        animationGeneration += 1
        if committed, incomingSlot.viewController != nil {
            let previous = currentSlot
            currentSlot = incomingSlot
            incomingSlot = previous
        }
        removeViewController(from: incomingSlot)
        transition = nil
        resetVisuals()
        return committed
    }

    func clear() {
        animationGeneration += 1
        removeViewController(from: firstSlot)
        removeViewController(from: secondSlot)
        transition = nil
        resetVisuals()
    }

    func attachParent(_ parent: UIViewController) { install(in: parent) }

    private func resetVisuals() {
        progress = 0
        for slot in [firstSlot, secondSlot] {
            slot.container.layer.removeAllAnimations()
            slot.container.transform = .identity
            slot.container.layer.cornerRadius = 0
        }
        currentSlot.container.isHidden = currentSlot.viewController == nil
        incomingSlot.container.isHidden = true
        dimmingOverlay.alpha = 0
        if let hostViewController {
            hostViewController.view.bringSubviewToFront(currentSlot.container)
            hostViewController.view.bringSubviewToFront(dimmingOverlay)
        }
    }

    private func replaceViewController(in slot: PageSlot, with controller: UIViewController) {
        guard let hostViewController else { return }
        if slot.viewController !== controller { removeViewController(from: slot) }
        if controller.parent !== hostViewController {
            if controller.parent != nil {
                controller.willMove(toParent: nil)
                controller.view.removeFromSuperview()
                controller.removeFromParent()
            }
            hostViewController.addChild(controller)
            controller.view.frame = slot.container.bounds
            controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            slot.container.addSubview(controller.view)
            controller.didMove(toParent: hostViewController)
        } else if controller.view.superview !== slot.container {
            controller.view.removeFromSuperview()
            slot.container.addSubview(controller.view)
        }
        controller.view.frame = slot.container.bounds
        slot.viewController = controller
    }

    private func removeViewController(from slot: PageSlot) {
        guard let controller = slot.viewController else { return }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        slot.viewController = nil
    }
}
