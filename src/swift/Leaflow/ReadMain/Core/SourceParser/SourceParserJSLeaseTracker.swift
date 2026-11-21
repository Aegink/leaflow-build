// 原路径: ReadMain/Core/SourceParser/SourceParserJSLeaseTracker.swift
// 证据:
//   - PGO: nextID (0x100014e58 L18-23) / acquire(kind:id:) (0x10016b52c L25-36) 等 9 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - processInfo/systemUptime；JS 租约追踪
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// JS 租约追踪器。
enum SourceParserJSLeaseTracker {

    private static var counter: UInt64 = 0
    /// 租约表（静态域：acquire/release/snapshotExtraParts 共享——T-1401-09
    /// snapshotExtraParts 域确证静态访问）。
    private static var leases: [UInt64: (kind: String, acquiredAt: Double)] = [:]
    private static let lock = NSLock()

    /// 伪代码 0x100014e58（L18-23）。
    static func nextID() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return counter
    }

    /// 伪代码 0x10016b52c（L25-36）。
    static func acquire(kind: String, id: UInt64, timeout: Double) {
        lock.lock()
        defer { lock.unlock() }
        leases[id] = (kind, ProcessInfo.processInfo.systemUptime)
    }

    static func release(id: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        leases.removeValue(forKey: id)
    }
}

extension SourceParserJSLeaseTracker {

    /// 伪代码 0x10016bb0c（L45-65）：额外部分快照——租约表按前缀过滤域
    ///（kind#uptime 串档；表为静态域与 acquire/release 对齐）。
    static func snapshotExtraParts(prefix: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return leases.values
            .map { "\($0.kind)#\(Int($0.acquiredAt))" }
            .filter { $0.hasPrefix(prefix) }
    }
}

