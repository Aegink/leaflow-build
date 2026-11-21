// 原路径: ReadMain/Core/SourceParser/SourceParserIdleCleanupCoordinator.swift
// 证据:
//   - PGO: State/queue 初始化 (0x100169738/0x1001699e0) / notePoolStateChanged(reason:) (0x1001693a8 L38-62) / schedule(LL) (0x10016a0e0 L64-110) 等 7 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 诊断 idleCandidate=/reason=/residentDelta=
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// 解析器空闲清理协调器。
final class SourceParserIdleCleanupCoordinator {

    private var cleanupScheduled = false
    private let lock = NSLock()
    private static let idleDelay: TimeInterval = 30.0

    /// 伪代码 0x1001693a8（L38-62）。
    func notePoolStateChanged(reason: String) {
        lock.lock()
        defer { lock.unlock() }
        if cleanupScheduled { return }
        cleanupScheduled = true
        Logger.log("[IdleCleanup] idleCandidate= reason=\(reason)", level: .warning)
        schedule()
    }

    /// 伪代码 0x10016a0e0（L64-110）。
    private func schedule() {
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.idleDelay) { [weak self] in
            guard let self else { return }
            let before = MemoryTrace.currentProcessFootprintBytes()
            JSContextPool.drain()
            AnalyzeRule.clearIdleRuntimeCaches()
            AnalyzeUrl.clearIdleRuntimeCaches()
            let after = MemoryTrace.currentProcessFootprintBytes()
            MemoryTrace.logDelta(reason: "idleCleanup", before: before, after: after)
            self.lock.lock()
            self.cleanupScheduled = false
            self.lock.unlock()
        }
    }

    static let shared = SourceParserIdleCleanupCoordinator()
}
