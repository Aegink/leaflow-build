// 原路径: ReadMain/Views/Search/SourceSpeedTracker.swift
// 证据:
//   - PGO: 17 条记录（index/task_functions.csv T-501-08 /
//     SourceSpeedTracker.swift；伪代码域 268 行）。关键地址：
//     record(sourceUrl:time:) 0x10095031c L17-22（inout 字典闭包确证）/
//     save 0x1009504c8 L25-28 / sortBySpeed 0x100950198 L36-41 /
//     speedSnapshot 0x100950208 L44-46 / init / estimatedTime(for:)
//     （签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SourceSpeedTracker.c
//     （268 行）
//   - 字符串确证（指针）："eedTracker.swift" @ptr L145（诊断域确证）
//   - 事实：速度表 [String: Double]（inout 字典闭包确证）——record 记录
//     单次耗时、save 持久化、sortBySpeed 按均值升序、estimatedTime 查询
//   - 消费：T-501-07 SearchViewModel.sortBySearchSpeed 交叉确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + inout 字典闭包确证）
// 还原: 2026-11-20

import Foundation

/// 源搜索速度追踪器。
final class SourceSpeedTracker {

    static let shared = SourceSpeedTracker()

    private let lock = NSLock()
    private var speeds: [String: Double] = [:]
    private let storageKey = "source_search_speeds"

    /// init（签名确证；载入持久化速度表）。
    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(
                [String: Double].self, from: data) {
            speeds = stored
        }
    }

    /// record(sourceUrl:time:)（0x10095031c L17-22 域确证）。
    func record(sourceUrl: String, time: Double) {
        lock.lock()
        let existing = speeds[sourceUrl]
        // 均值平滑（inout 字典闭包域确证）。
        speeds[sourceUrl] = existing == nil
            ? time
            : (existing! * 0.7 + time * 0.3)
        lock.unlock()
        save()
    }

    /// save（0x1009504c8 L25-28 域确证）。
    func save() {
        lock.lock()
        let snapshot = speeds
        lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// sortBySpeed（0x100950198 L36-41 域确证）。
    func sortBySpeed(_ sources: [BookSource]) -> [BookSource] {
        lock.lock()
        let table = speeds
        lock.unlock()
        return sources.sorted { lhs, rhs in
            let lhsTime = table[lhs.bookSourceUrl] ?? .infinity
            let rhsTime = table[rhs.bookSourceUrl] ?? .infinity
            return lhsTime < rhsTime
        }
    }

    /// speedSnapshot（0x100950208 L44-46 域确证）。
    func speedSnapshot() -> [String: Double] {
        lock.lock()
        defer { lock.unlock() }
        return speeds
    }

    /// estimatedTime(for:)（签名确证）。
    func estimatedTime(for sourceUrl: String) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return speeds[sourceUrl] ?? 5.0
    }
}
