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
        if transition.direction == .next {
            hostViewController?.view.bringSubviewToFront(incomingSlot.container)
            hostViewController?.view.bringSubviewToFront(dimmingOverlay)
            hostViewController?.view.bringSubviewToFront(currentSlot.container)
        } else {
            hostViewController?.view.bringSubviewToFront(currentSlot.container)
            hostViewController?.view.bringSubviewToFront(dimmingOverlay)
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
        let amount = CGFloat(self.progress)
        if transition.direction == .next {
            currentSlot.container.transform = CGAffineTransform(translationX: -width * amount, y: 0)
            incomingSlot.container.transform = .identity
        } else {
            currentSlot.container.transform = .identity
            incomingSlot.container.transform = CGAffineTransform(translationX: -width * (1 - amount), y: 0)
        }
    }

    func animateSettlement(completes: Bool, velocity: CGFloat, completion: @escaping (Bool) -> Void) {
        guard transition != nil else { completion(false); return }
        animationGeneration += 1
        let generation = animationGeneration
        let target: Double = completes ? 1 : 0
        let width = hostViewController?.view.bounds.width ?? 0
        let speed = width > 0 && velocity.isFinite ? abs(Double(velocity / width)) : 0
        let duration = abs(target - progress) / max(1 / 0.28, speed)
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
