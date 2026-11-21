// 原路径: ReadMain/Core/SourceParser/DebugCapture.swift
// 证据:
//   - PGO: ParseDiagnostic.estimatedCharacterCount closure (0x1000d43b8 L42) / State 初始化 (0x1000d442c L62) / Snapshot.extraParts (0x1000d472c L85-95) 等 17 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 调试捕获（ParseDiagnostic 快照）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// 调试捕获（解析诊断快照）。
final class DebugCapture {

    struct Snapshot {
        var extra: [String: String] = [:]

        /// 伪代码 0x1000d472c（L85-95）。
        func extraParts(prefix: String) -> [String] {
            extra.keys.filter { $0.hasPrefix(prefix) }.sorted()
        }
    }

    private(set) var snapshots: [Snapshot] = []
    /// 捕获开关（setEnabled 域）。
    private var enabled = true
    /// 最近原始响应（consumeLastRawResponse 消费域）。
    private var lastRawResponse: String?
    private let lock = NSLock()

    func capture(_ snapshot: Snapshot) {
        lock.lock()
        defer { lock.unlock() }
        snapshots.append(snapshot)
    }

    static let shared = DebugCapture()
}

/// 解析诊断（executeRule 的 ParseDiagnostic 载体）。
struct ParseDiagnostic {
    var kind: Int
    var characterCount: Int
    var elapsed: Double

    var estimatedCharacterCount: Int {
        characterCount
    }
}

// MARK: - T-1401-13 逐域补齐（捕获域）

extension DebugCapture {

    /// 伪代码 0x1000d4888（L104-116）：捕获开关（快照容量域联动）。
    func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.enabled = enabled
        if !enabled {
            snapshots.removeAll()
        }
    }

    /// 伪代码 0x1000d4a3c（L122-134）：快照导出（副本域）。
    func snapshot() -> [Snapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }

    /// 伪代码 0x1000d4284（L155-170）：JS 日志追加（extra 域）。
    func appendJsLog(_ message: String, prefix: String = "js.") {
        capture(Snapshot(extra: [prefix + String(Int(Date().timeIntervalSince1970)): message]))
    }

    /// 伪代码 0x10011e2cc（L173-179）：最近原始响应消费（取走即清域）。
    func consumeLastRawResponse() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let last = lastRawResponse else { return nil }
        lastRawResponse = nil
        return last
    }
}

