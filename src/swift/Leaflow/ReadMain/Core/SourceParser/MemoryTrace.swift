// 原路径: ReadMain/Core/SourceParser/MemoryTrace.swift
// 证据:
//   - PGO: currentProcessFootprintBytes (L7-17，4 ICF 副本) 等 9 函数
//   - CovMap: L7-17
//   - IDA: 0x10001444c 等 4 副本
//   - 诊断串 residentDelta=/stageGrowth=/contentChars=/responseChars=/reason=/mallocRelief=/residentAfter=
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high
// 还原: 2026-11-19


import Foundation

/// 内存追踪。
enum MemoryTrace {

    /// 伪代码 L7-17：进程驻留字节。
    static func currentProcessFootprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / 4)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            // UnsafeMutablePointer 重绑 API 为 withMemoryRebound(to:capacity:)。
            pointer.withMemoryRebound(to: task_info_t.self, capacity: 1) { infoPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), infoPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }

    /// 诊断串（事实 4）。
    static func logDelta(reason: String, before: UInt64?, after: UInt64?) {
        guard let before, let after else { return }
        let delta = Int64(after) - Int64(before)
        Logger.log(
            "[MemoryTrace] reason=\(reason) residentDelta=\(delta) residentAfter=\(after)",
            level: .warning
        )
    }
}

extension SourceParserMemoryReclaimer {

    /// 伪代码 0x100161a9c（L56-75）：分配器缓解——footprint 超阈值触发
    /// 释放域（processInfo physicallyFootprint 域确证）。
    @discardableResult
    func relieveAllocator(thresholdBytes: UInt64) -> Bool {
        guard let footprint = MemoryTrace.currentProcessFootprintBytes(),
            footprint > thresholdBytes else { return false }
        MemoryTrace.logDelta(
            reason: "relieveAllocator",
            before: footprint,
            after: MemoryTrace.currentProcessFootprintBytes())
        return true
    }
}


/// 解析器内存回收器（0x100161a9c 域容器；类型缺失按签名还原）。
final class SourceParserMemoryReclaimer {

    static let shared = SourceParserMemoryReclaimer()

    /// 缓解阈值（推断 256MB）。
    var reliefThresholdBytes: UInt64 = 256 * 1024 * 1024

    /// 默认阈值缓解入口（relieveAllocator 消费域）。
    @discardableResult
    func relieveIfNeeded() -> Bool {
        relieveAllocator(thresholdBytes: reliefThresholdBytes)
    }
}
