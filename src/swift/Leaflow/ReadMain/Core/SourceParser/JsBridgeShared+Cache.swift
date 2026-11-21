// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsBridgeShared+Cache.swift
// 证据:
//   - PGO: JsBridgeTemplates.registerCacheBridge(in:) (0x10002311c L12-37) 及 closure #1-#4
//   - CovMap: L12-37 @0x10002311c；closures @0x1000f12a4/0x1000f12b8/0x1000f133c/0x1000f1394
//   - IDA: 上述地址
//   - 对应 _cacheMemoryPut/Get/Delete/_cachePersistentPut/Get/Delete 键族（T-203-02 事实 3）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（键族与闭包签名一一对应）
// 还原: 2026-11-19


import Foundation

/// JS cache 桥（memory + persistent 双层）。
enum JsBridgeTemplates {

    /// 伪代码 0x10002311c（L12-37）：注册 cache 桥。
    static func registerCacheBridge(in context: JSImportBridgeContext) {
        let cache = JsCacheManager.shared
        let bridge: [String: Any] = [
            // closure #1（L13-15）put。
            "_cacheMemoryPut": { (key: String, value: String) in
                cache.putMemory(key, value)
            },
            // closure #2（L16-18）get。
            "_cacheMemoryGet": { (key: String) -> String in
                cache.getFromMemory(key) ?? ""
            },
            // closure #3（L19-21）delete。
            "_cacheMemoryDelete": { (key: String) in
                cache.delete(key)
            },
            // closure #4（L22-24）persistent put。
            "_cachePersistentPut": { (key: String, value: String) in
                cache.put(key, value)
            },
        ]
        for (key, value) in bridge {
            context.context.setObject(value, forKeyedSubscript: key as NSString)
        }
        context.context.setObject(
            { (key: String) -> String in cache.get(key) ?? "" },
            forKeyedSubscript: "_cachePersistentGet" as NSString
        )
        context.context.setObject(
            { (key: String) in cache.delete(key) },
            forKeyedSubscript: "_cachePersistentDelete" as NSString
        )
    }
}

/// import 桥上下文（SymmetricCrypto/Cache 注册共用）。
struct JSImportBridgeContext {
    let context: JSContext
}
