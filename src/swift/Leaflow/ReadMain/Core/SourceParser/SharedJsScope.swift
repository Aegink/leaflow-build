// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/SharedJsScope.swift
// 证据:
//   - PGO: scriptCache 初始化 (0x10016720c L13) / init() 7 ICF 副本 (0x100166608…0x100166be4 L18-23) / clearAll (0x100097430 L72-74)
//   - CovMap: L13/L18-23/L72-74
//   - IDA: 0x10016720c/0x100166608 族/0x100097430
//   - 共享脚本作用域（JsExtensionsSharedState 同族）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（缓存与清理链确证）
// 还原: 2026-11-19


import Foundation

/// 共享 JS 作用域：跨执行的脚本缓存（书源 JS 库去重加载）。
final class SharedJsScope {

    /// 伪代码 0x10016720c（L13）：scriptCache。
    private var scriptCache: [String: String] = [:]
    private let lock = NSLock()

    init() {
        // 伪代码 0x100166608 族（L18-23，7 个 ICF 地址副本为同一 init）。
    }

    func cacheScript(_ url: String, _ script: String) {
        lock.lock()
        defer { lock.unlock() }
        scriptCache[url] = script
    }

    func cachedScript(_ url: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return scriptCache[url]
    }

    /// 伪代码 0x100097430（L72-74）。
    static func clearAll() {
        SharedJsScope.shared.clearAllInternal()
    }

    private func clearAllInternal() {
        lock.lock()
        defer { lock.unlock() }
        scriptCache.removeAll()
    }

    static let shared = SharedJsScope()
}
