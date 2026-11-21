// 原路径: ReadMain/Services/ReadAloud/HttpTtsRequestRateLimiter.swift
// 证据:
//   - PGO: 42 条记录（index/task_functions.csv T-801-06 /
//     HttpTtsRequestRateLimiter.swift；伪代码域 300 行）
//   - CovMap: 上述 L 区段（RateLimitConfiguration.init L9-120 /
//     limiter(for:) / waitForPermission 域 L493）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsRequestRateLimiter.c（1363 行）
//   - 块体确证（地址+行号域）：
//     HttpTtsRateLimitConfiguration.init(rate:) 0x 域 L9-120（'/' 分割
//     0x2F L62 + trim 域 + Int 十进制解析域）/ limiter(for: HttpTts)
//     / remove(sourceID: Int64) / HttpTtsRequestRateLimiter.init(rate:)
//     0x1336 域 / waitForPermission() 域 L493
//   - 事实：'count/seconds' 速率串解析（如 '5/60'）→ 每秒窗口限流
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（配置域 + 等待域确证）
// 还原: 2026-11-20

import Foundation

/// 速率限制配置（init(rate:) 0x 域 L9-120 确证：'count/seconds'
/// 解析，无效返回 nil）。
struct HttpTtsRateLimitConfiguration {
    let maxRequests: Int
    let windowSeconds: Int

    /// init(rate:)（0x 域确证：'/' 分割 + trim + 十进制解析）。
    init?(rate: String) {
        let trimmed = rate.trimmingCharacters(
            in: .whitespacesAndNewlines)
        // '/' 分割域 L62 确证。
        let parts = trimmed.split(separator: "/")
        guard parts.count == 2,
              let count = Int(parts[0].trimmingCharacters(
                in: .whitespaces)),
              let seconds = Int(parts[1].trimmingCharacters(
                in: .whitespaces)),
              count > 0, seconds > 0 else {
            return nil
        }
        maxRequests = count
        windowSeconds = seconds
    }
}

/// 朗读源请求限流器（init(rate:) / waitForPermission 签名域确证）。
final class HttpTtsRequestRateLimiter {

    private let maxRequests: Int
    private let windowSeconds: Int
    private var timestamps: [Date] = []
    private let lock = NSLock()

    /// init(rate:)（0x1336 域确证）。
    init(rate: String) {
        if let config = HttpTtsRateLimitConfiguration(rate: rate) {
            maxRequests = config.maxRequests
            windowSeconds = config.windowSeconds
        } else {
            maxRequests = Int.max
            windowSeconds = 60
        }
    }

    /// waitForPermission（0x 域 L493 确证：窗口内计数等待）。
    func waitForPermission() async throws {
        while true {
            let waitInterval = try acquireSlot()
            if waitInterval == 0 {
                return
            }
            try await Task.sleep(nanoseconds: waitInterval)
        }
    }

    private func acquireSlot() throws -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        // 窗口清理域（windowSeconds 确证）。
        timestamps = timestamps.filter {
            now.timeIntervalSince($0) < Double(windowSeconds)
        }
        guard timestamps.count >= maxRequests else {
            timestamps.append(now)
            return 0
        }
        // 最早记录滑出窗口的剩余等待域。
        if let earliest = timestamps.first {
            let elapsed = now.timeIntervalSince(earliest)
            let remaining = Double(windowSeconds) - elapsed
            return UInt64(max(remaining, 0.1) * 1_000_000_000)
        }
        return 1_000_000_000
    }
}

/// 限流器注册表（limiter(for:)/remove 签名域确证：按源缓存）。
final class HttpTtsRateLimiterRegistry {

    static let shared = HttpTtsRateLimiterRegistry()

    private var limiters: [Int64: HttpTtsRequestRateLimiter] = [:]
    private let lock = NSLock()

    /// limiter(for: HttpTts)（签名域确证：源并发率串 → 限流器）。
    func limiter(for source: HttpTts) -> HttpTtsRequestRateLimiter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = limiters[source.id] {
            return existing
        }
        let limiter = HttpTtsRequestRateLimiter(
            rate: source.concurrentRate ?? "")
        limiters[source.id] = limiter
        return limiter
    }

    /// remove(sourceID:)（签名域确证）。
    func remove(sourceID: Int64) {
        lock.lock()
        defer { lock.unlock() }
        limiters.removeValue(forKey: sourceID)
    }
}
