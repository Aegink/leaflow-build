// 原路径: ReadMain/Views/Reader/ReaderTwoPageRenderer.swift
// 证据:
//   - PGO: 12 个主函数（index/task_functions.csv T-301-10 / ReaderTwoPageRenderer.swift），
//     地址：install(in:) 0x1008437bc L103-122 / setCurrentViewController 0x100843acc
//     L124-129 / prepare(transition:incoming:) 0x100843b78 L134-144 /
//     updateTransition 0x10084377c L146-149 / render(progress:) 0x100843be4 L151-160 /
//     animateSettlement(completes:velocity:) 0x100843c1c L166-196（+闭包
//     0x100844a98/0x100844b38 L190-195）/ finishSettlement(committed:) 0x100844130
//     L199-216 / clear 0x10084372c L226-233 / replaceViewController 0x100844510
//     L238-251 / removeViewController 0x100844bac L253-257
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderTwoPageRenderer.c（1205 行）
//   - 关键选择子：addSubview:/setBackgroundColor:(blackColor)/setAlpha:/
//     setAutoresizingMask:/setClipsToBounds:/setUserInteractionEnabled:/
//     addChildViewController:/didMoveToParentViewController:/setFrame:/bounds/
//     willMoveToParentViewController:/removeFromParentViewController/
//     removeFromParentViewController/parentViewController/
//     animateWithDuration:delay:options:animations:completion:
//   - 事实：install —— 容器装配（黑底/clipsToBounds/非交互，确证）；
//     prepare/updateTransition/render(progress:) —— 过渡渲染主链；
//     animateSettlement —— animateWithDuration 落定（双 completion 闭包确证）；
//     finishSettlement(committed:) -> Bool；replace/removeViewController ——
//     嵌入/脱离子 VC 全链（确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（选择子链/生命周期全确证；动画参数待真机对照）
// 还原: 2026-11-19

import UIKit

/// 双页过渡渲染器：承载当前/到来 VC 的位移过渡与落定。
@MainActor
final class ReaderTwoPageRenderer {

    private let containerView = UIView()
    private var currentViewController: UIViewController?
    private var incomingViewController: UIViewController?
    private var transition: PageTurnTransition?
    private var isAnimatingSettlement = false

    /// 伪代码 0x1008437bc（L103-122）：容器装配
    ///（黑底/clipsToBounds/非交互/autoresizing 确证）。
    func install(in parent: UIViewController) {
        containerView.backgroundColor = .black
        containerView.alpha = 0
        containerView.clipsToBounds = true
        containerView.isUserInteractionEnabled = false
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.frame = parent.view.bounds
        parent.view.addSubview(containerView)
    }

    /// 伪代码 0x100843acc（L124-129）：设置当前 VC。
    func setCurrentViewController(_ viewController: UIViewController) {
        if let existing = currentViewController {
            removeViewController(existing)
        }
        currentViewController = replaceViewController(viewController)
    }

    /// 伪代码 0x100843b78（L134-144）：准备过渡（到来 VC 嵌入）。
    func prepare(transition newTransition: PageTurnTransition, incoming: UIViewController) {
        self.transition = newTransition
        incomingViewController = replaceViewController(incoming)
        containerView.alpha = 1
        render(progress: 0)
    }

    /// 伪代码 0x10084377c（L146-149）：更新过渡。
    func updateTransition(_ newTransition: PageTurnTransition) {
        transition = newTransition
    }

    /// 伪代码 0x100843be4（L151-160）：按进度渲染位移。
    func render(progress: Double) {
        guard let transition else { return }
        let offset = containerView.bounds.width * CGFloat(progress)
        if transition.direction == .next {
            incomingViewController?.view.frame.origin.x = offset
            currentViewController?.view.frame.origin.x = offset - containerView.bounds.width
        } else {
            incomingViewController?.view.frame.origin.x = -containerView.bounds.width + offset
            currentViewController?.view.frame.origin.x = offset
        }
    }

    /// 伪代码 0x100843c1c（L166-196）+ 双 completion 闭包（0x100844a98/0x100844b38）：
    /// 落定动画（animateWithDuration 确证）。
    func animateSettlement(completes: Bool, velocity: CGFloat, completion: @escaping (Bool) -> Void) {
        guard !isAnimatingSettlement else { return }
        isAnimatingSettlement = true
        let targetProgress: Double = completes ? 1.0 : 0.0
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: {
                self.render(progress: targetProgress)
            },
            completion: { finished in
                self.isAnimatingSettlement = false
                completion(finished && completes)
            })
        _ = velocity
    }

    /// 伪代码 0x100844130（L199-216）：落定收尾（@MainActor 确证）。
    @discardableResult
    func finishSettlement(committed: Bool) -> Bool {
        if committed, let incoming = incomingViewController {
            setCurrentViewController(incoming)
        } else if let incoming = incomingViewController {
            removeViewController(incoming)
        }
        incomingViewController = nil
        transition = nil
        containerView.alpha = 0
        return committed
    }

    /// 伪代码 0x10084372c（L226-233）：清空渲染器。
    func clear() {
        if let current = currentViewController {
            removeViewController(current)
        }
        if let incoming = incomingViewController {
            removeViewController(incoming)
        }
        currentViewController = nil
        incomingViewController = nil
        transition = nil
        containerView.alpha = 0
    }

    /// 伪代码 0x100844510（L238-251）：嵌入子 VC（全链确证）。
    @discardableResult
    private func replaceViewController(_ viewController: UIViewController) -> UIViewController {
        viewController.willMove(toParent: nil)
        viewController.removeFromParent()
        parent?.addChild(viewController)
        viewController.view.frame = containerView.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(viewController.view)
        viewController.didMove(toParent: parent)
        return viewController
    }
    private weak var parent: UIViewController?

    /// 伪代码 0x100844bac（L253-257）：脱离子 VC（全链确证）。
    private func removeViewController(_ viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }

    /// install 时记录宿主（replaceViewController 的 addChild 目标）。
    func attachParent(_ parent: UIViewController) {
        self.parent = parent
    }
}
