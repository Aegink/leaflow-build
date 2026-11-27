// 原路径: ReadMain/Views/Reader/PageTransitionStyle.swift。
// 类型表10317：slide/none；0x100768a5c/0x100768acc。
// Swift调用约定W0=direction、W1=self；视觉结果还包含D0/D1/D2三个浮点返回值。
// IDA默认伪代码漏掉浮点域，须与work/logs/t1602_page_turn_probe.txt汇编互证。

enum PageTransitionStyle {
    case slide
    case none

    func layerOrder(for direction: ReaderPageTurnDirection) -> PageTransitionLayerOrder {
        if self == .none { return .incomingAboveCurrent }
        return direction == .next ? .currentAboveDimming : .incomingAboveDimming
    }

    func visualState(direction: ReaderPageTurnDirection, progress: Double) -> PageTransitionVisualState {
        let amount = progress.isNaN ? 0 : min(max(progress, 0), 1)
        guard self == .slide else { return .identity }
        if direction == .next {
            return PageTransitionVisualState(currentTranslation: -amount,
                incomingTranslation: -0.15 * (1 - amount), dimmingAlpha: 0.3 * (1 - amount),
                roundsCurrent: true, roundsIncoming: false)
        }
        return PageTransitionVisualState(currentTranslation: 0.15 * amount,
            incomingTranslation: -(1 - amount), dimmingAlpha: 0.3 * amount,
            roundsCurrent: false, roundsIncoming: true)
    }

    // HorizontalPagingViewController.c:182-189的样式tag==0传给页面池。
    var usesTransparentPageBackground: Bool { self == .slide }
    var settlesImmediately: Bool { self == .none }
}

// 0x100844708按返回tag执行bringSubviewToFront；命名描述实际层级。
enum PageTransitionLayerOrder: Int {
    case currentAboveDimming = 0
    case incomingAboveDimming = 1
    case incomingAboveCurrent = 2
}

struct PageTransitionVisualState: Equatable {
    let currentTranslation: Double
    let incomingTranslation: Double
    let dimmingAlpha: Double
    let roundsCurrent: Bool
    let roundsIncoming: Bool

    static let identity = PageTransitionVisualState(currentTranslation: 0,
        incomingTranslation: 0, dimmingAlpha: 0, roundsCurrent: false, roundsIncoming: false)
}
