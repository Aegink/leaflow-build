// 原路径: ReadMain/Views/Reader/SlidePageTurnGestureDriver.swift。
// 类型表11855-11873；0x1008b76b0更新、0x1008b7874结束、0x1008b7c04方向进度。
// 原常量0x100fc3430/0x100fcd180/190：0.06/18/32/0.3/500/8。
enum SlidePageTurnGestureUpdate: Equatable {
    case none
    case begin(ReaderPageTurnDirection, progress: Double)
    case progress(ReaderPageTurnDirection, progress: Double)
}

enum SlidePageTurnGestureSettlement: Equatable {
    case none
    case cancel(ReaderPageTurnDirection)
    case commit(ReaderPageTurnDirection)
}

struct SlidePageTurnGestureDriver {
    struct Configuration {
        var activationWidthRatio = 0.06
        var minimumActivationDistance = 18.0
        var maximumActivationDistance = 32.0
        var completionProgress = 0.3
        var flickVelocityThreshold = 500.0
        var flickMinimumDistance = 8.0
    }

    private enum Phase {
        case dragging(ReaderPageTurnDirection)
        case idle
        case recognizing
    }

    private let configuration: Configuration
    private var phase: Phase = .idle

    init(configuration: Configuration = .init()) { self.configuration = configuration }
    mutating func begin() { phase = .recognizing }

    mutating func cancel() -> SlidePageTurnGestureSettlement {
        defer { phase = .idle }
        if case .dragging(let direction) = phase { return .cancel(direction) }
        return .none
    }

    mutating func update(translation: Double, width: Double) -> SlidePageTurnGestureUpdate {
        guard width > 0, width.isFinite, translation.isFinite else { return .none }
        switch phase {
        case .idle: return .none
        case .recognizing:
            guard abs(translation) >= activationDistance(for: width),
                  let direction = direction(for: translation) else { return .none }
            phase = .dragging(direction)
            return .begin(direction, progress: progress(direction: direction, translation: translation, width: width))
        case .dragging(let direction):
            return .progress(direction, progress: progress(direction: direction, translation: translation, width: width))
        }
    }

    mutating func end(translation: Double, velocity: Double, width: Double) -> SlidePageTurnGestureSettlement {
        guard width > 0, width.isFinite, translation.isFinite, velocity.isFinite else { return cancel() }
        defer { phase = .idle }
        switch phase {
        case .idle: return .none
        case .recognizing:
            guard let direction = pendingDirection(translation: translation, velocity: velocity, width: width)
            else { return .none }
            return .commit(direction)
        case .dragging(let direction):
            if progress(direction: direction, translation: translation, width: width) > configuration.completionProgress
                || isCompletingFlick(direction: direction, velocity: velocity) {
                return .commit(direction)
            }
            return .cancel(direction)
        }
    }

    private func activationDistance(for width: Double) -> Double {
        min(max(width * configuration.activationWidthRatio, configuration.minimumActivationDistance),
            configuration.maximumActivationDistance)
    }

    private func pendingDirection(translation: Double, velocity: Double, width: Double) -> ReaderPageTurnDirection? {
        if abs(velocity) > configuration.flickVelocityThreshold,
           abs(translation) > configuration.flickMinimumDistance { return direction(for: velocity) }
        return abs(translation) >= activationDistance(for: width) ? direction(for: translation) : nil
    }

    private func direction(for translation: Double) -> ReaderPageTurnDirection? {
        if translation < 0 { return .next }
        if translation > 0 { return .previous }
        return nil
    }

    private func progress(direction: ReaderPageTurnDirection, translation: Double, width: Double) -> Double {
        min(max((direction == .next ? -translation : translation) / width, 0), 1)
    }

    private func isCompletingFlick(direction: ReaderPageTurnDirection, velocity: Double) -> Bool {
        abs(velocity) > configuration.flickVelocityThreshold && (direction == .next ? velocity < 0 : velocity > 0)
    }
}
