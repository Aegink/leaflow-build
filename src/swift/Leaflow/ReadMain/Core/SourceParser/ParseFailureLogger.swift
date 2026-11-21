// 原路径: ReadMain/Core/SourceParser/ParseFailureLogger.swift
// 证据:
//   - PGO: clearLogHistory (0x1001642e0 L33-35) / shouldLogJSException (0x100164188 L76-89) 等 5 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 解析失败日志（限频）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// 解析失败日志（限频去重）。
final class ParseFailureLogger {

    private var loggedKeys: [String: Double] = [:]
    private let lock = NSLock()
    private static let throttleWindow: Double = 30.0

    /// 伪代码 0x100164188（L76-89）。
    func shouldLogJSException(_ key: String, now: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let last = loggedKeys[key], now - last < Self.throttleWindow {
            return false
        }
        loggedKeys[key] = now
        return true
    }

    /// 伪代码 0x1001642e0（L33-35）。
    func clearLogHistory() {
        lock.lock()
        defer { lock.unlock() }
        loggedKeys.removeAll()
    }

    static let shared = ParseFailureLogger()
}
