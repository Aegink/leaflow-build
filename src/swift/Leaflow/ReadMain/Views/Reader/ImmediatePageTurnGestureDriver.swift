// 原路径: ReadMain/Views/Reader/ImmediatePageTurnGestureDriver.swift。
// 0x10070d5e4结束、0x10070d7e8方向；0x100fc3430/3440配置为0.06/18/32/500/8。
struct ImmediatePageTurnGestureDriver {
    struct Configuration {
        var activationWidthRatio = 0.06
        var minimumActivationDistance = 18.0
        var maximumActivationDistance = 32.0
        var flickVelocityThreshold = 500.0
        var flickMinimumDistance = 8.0
    }

    private let configuration: Configuration
    private var isTracking = false

    init(configuration: Configuration = .init()) { self.configuration = configuration }

    mutating func begin() { isTracking = true }
    mutating func cancel() { isTracking = false }

    mutating func end(translation: Double, velocity: Double, width: Double) -> ReaderPageTurnDirection? {
        defer { isTracking = false }
        guard isTracking, width > 0, width.isFinite, translation.isFinite, velocity.isFinite else { return nil }
        if abs(velocity) > configuration.flickVelocityThreshold,
           abs(translation) > configuration.flickMinimumDistance {
            return direction(for: velocity)
        }
        guard abs(translation) >= activationDistance(for: width) else { return nil }
        return direction(for: translation)
    }

    private func direction(for translation: Double) -> ReaderPageTurnDirection? {
        if translation > 0 { return .previous }
        if translation < 0 { return .next }
        return nil
    }

    func activationDistance(for width: Double) -> Double {
        min(max(width * configuration.activationWidthRatio, configuration.minimumActivationDistance),
            configuration.maximumActivationDistance)
    }
}
