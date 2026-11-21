// 原路径: ReadMain/Core/SourceParser/LockedState.swift
// 证据:
//   - PGO: init(A) 多 ICF 副本 @0x100007a74/0x1000f4d84/0x10011ded4/0x10015bc78 等 38 函数
//   - CovMap: L7-9
//   - IDA: 上述地址
//   - 泛型锁态容器 + NSMapTable + 通知 + JS 桥联动
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（泛型容器语义自洽）
// 还原: 2026-11-19


import Foundation

/// 泛型锁态容器（单态化 ICF 副本多，真身 ≤ 8 个，读后记推断 1）。
final class LockedState<Value> {

    private var storage: Value
    private let lock = NSLock()

    /// 伪代码 0x100007a74（L7-9）。
    init(_ initialValue: Value) {
        storage = initialValue
    }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage = newValue
        }
    }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&storage)
    }
}

extension LockedState {

    /// 伪代码 0x100070a48（L20-24）：无返回值域（withLock Void 变体）。
    func withValue(_ body: (inout Value) -> Void) {
        withLock(body)
    }
}

extension UncheckedLockedState {

    /// 伪代码 0x100015294（L47-51）：无锁变体（unchecked 域语义）。
    func withValue(_ body: (inout Value) -> Void) {
        body(&storage)
    }
}


/// 无锁状态容器（0x100015294 L47-51 域容器；类型缺失按签名还原——
/// unchecked 语义：无锁直读直写）。
final class UncheckedLockedState<Value> {

    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        get { storage }
        set { storage = newValue }
    }

    /// 伪代码 0x100015294（L47-51）：无锁域。
    func withValue(_ body: (inout Value) -> Void) {
        body(&storage)
    }
}
