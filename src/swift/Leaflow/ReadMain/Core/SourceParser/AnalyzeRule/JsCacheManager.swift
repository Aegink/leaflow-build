// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/JsCacheManager.swift
// 证据:
//   - PGO: putMemory / getFromMemory / put / get / delete 及 MemoryState 闭包族
//   - CovMap: putMemory L45-59 @0x100070c38；closure#1 L47-58 @0x100070e8c；implicit L50
//     @0x100071524；getFromMemory L61-69 @0x10000f9a8；closure L62-68 @0x100071368 / L72-74
//     @0x100071468；put L79-81 @0x1000715f0；get L83-85 @0x100071674；delete L87-89 @0x1000716b0；
//     closure 副本 @0x100155454/0x100070d74/0x100155010（ICF）
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 选择子
//   - 持久化选择子：standardUserDefaults/stringForKey:/setObject:forKey:/removeObjectForKey:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（内存态 + UserDefaults 双层结构，选择子逐一可见）
// 还原: 2026-11-19

import Foundation

/// JS 侧缓存管理：内存字典 + UserDefaults 双层。
final class JsCacheManager {

    /// 伪代码 MemoryState：内存缓存态（closure #1 系列操作的存储）。
    private struct MemoryState {
        var storage: [String: String] = [:]
    }

    /// 共享实例（put/get/delete 为实例方法，访问路径由调用方持有）。
    static let shared = JsCacheManager()

    /// UserDefaults 键前缀（选择子 setObject:forKey: 的键空间）。
    private static let defaultsPrefix = "jsCache."

    /// 事实 22：内存态（闭包以 inout MemoryState 操作，串行队列承载）。
    private let memoryLock = NSLock()
    private var memoryState = MemoryState()

    // MARK: - 内存层

    /// 伪代码 0x100070c38（L45-59）。
    func putMemory(_ key: String, _ value: String) {
        memoryLock.lock()
        defer { memoryLock.unlock() }
        memoryState.storage[key] = value
    }

    /// 伪代码 0x10000f9a8（L61-69）。
    func getFromMemory(_ key: String) -> String? {
        memoryLock.lock()
        defer { memoryLock.unlock() }
        return memoryState.storage[key]
    }

    // MARK: - 持久层（UserDefaults）

    /// 伪代码 0x1000715f0（L79-81）：put = 内存 + UserDefaults。
    func put(_ key: String, _ value: String) {
        putMemory(key, value)
        UserDefaults.standard.set(value, forKey: Self.defaultsPrefix + key)
    }

    /// 伪代码 0x100071674（L83-85）：get = 内存优先，回退 UserDefaults。
    func get(_ key: String) -> String? {
        if let cached = getFromMemory(key) {
            return cached
        }
        return UserDefaults.standard.string(forKey: Self.defaultsPrefix + key)
    }

    /// 伪代码 0x1000716b0（L87-89）：delete = 双层清除（removeObjectForKey:）。
    func delete(_ key: String) {
        memoryLock.lock()
        memoryState.storage.removeValue(forKey: key)
        memoryLock.unlock()
        UserDefaults.standard.removeObject(forKey: Self.defaultsPrefix + key)
    }
}
