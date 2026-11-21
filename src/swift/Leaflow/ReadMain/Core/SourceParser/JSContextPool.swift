// 原路径: ReadMain/Core/SourceParser/JSContextPool.swift
// 证据:
//   - PGO: CachedContext.init(context:ownerThread:) / ContextHandle.context / release /
//     acquireHandle / release(LL) / drain / warmup(count:) / snapshot / state / currentThreadID /
//     JSContextPoolReuseTracker / JSContextCompiledExpressionCache(init(maxEntries:)/
//     functionName/removeFunctionName/store(functionName:)/touch/makeFunctionName) /
//     JSContext 扩展（poolReuseTracker/compiledExpressionCache/compiledExpressionFunction/
//     didRecoverFromEvaluateSanitizedSyntaxFallback/evaluateWrappedSanitizedString/
//     evaluateSanitizedFunctionBody/evaluateSanitized）/ ruleEvaluation 家族
//   - CovMap: CachedContext L17-22 @0x1000fbe70；context L67-71 @0x1000f9e98；handle.release
//     L88-100 @0x1000fae70（@Sendable closure）；acquireHandle L105-135 @0x1000fabc8；
//     release L143-175 @0x1000fbed8；drain L180-197 @0x1000faa44；warmup L201-209 @0x1000f9e24；
//     ReuseTracker L227 @0x1000fca9c；CompiledExpressionCache L241-285 @0x1000fda78/0x1000fcb90/
//     0x1000fcf88/0x1000fd050/0x1000fcc90；JSContext 扩展 L294-531 @0x1000fd714/0x1000fd870/
//     0x1000fdb7c/0x1000fa2dc/0x1000fbc60/0x1000fa3d0/0x1000f9ec8；ruleEvaluationStringValue
//     L534-548 @0x1000fb510；ruleEvaluationTemplateOutcome L555-577 @0x1000faff4；
//     ruleEvaluationStructuredValue L579-603 @0x1000fb2e0；ruleEvaluationMarkedJavaStringValue
//     L626-639 @0x1000fe0ac；snapshot/state/currentThreadID 见骨架尾部条目
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字面量
//   - 包裹脚本字面量："(function() {\n" + "var __script = String(__evaluateSanitizedScript || '');"
//     + "return Function(__script + '').call(this);" + ").call(this)"
//   - 选择子：isMainThread/objectForKey:/setObject:forKey:/setException:/JSGlobalContextRef/
//     evaluateScript:/exception/isUndefined/isNull/objectForKeyedSubscript:/
//     __evaluateSanitizedScript/__qireaderCollectionBridge/valueForProperty:/toBool/
//     invokeMethod:withArguments:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 池句柄/drain/warmup/snapshot: high（PoolState inout 闭包链可见；线程亲和见 ownerThread）
//   - evaluateSanitized 链: medium-high（包裹字面量确证，清洗顺序见读后记推断 2）
//   - ruleEvaluation 家族: high（结构体出口，签名以骨架为准）
// 还原: 2026-11-19

import Foundation
import JavaScriptCore

/// 求值模板结果（伪代码 0x1000faff4 的返回结构体，骨架签名）。
struct RuleEvaluationTemplateOutcome {
    var text: String?
    var structured: Any?
}

/// 求值结构化结果。
struct RuleEvaluationResult {
    var text: String?
    var value: Any?
}

/// JSContext 池：线程亲和的预建/复用/排水 + 编译表达式缓存。
final class JSContextPool {

    /// 伪代码 CachedContext（L17-22，ownerThread 线程亲和）。
    private struct CachedContext {
        let context: JSContext
        let ownerThread: UInt64
        var inUse: Bool = false
    }

    /// 伪代码 state（PoolState 载体）。
    private var state: [CachedContext] = []
    private var checkedOut = 0
    private var maxInFlight = 0
    private let lock = NSLock()

    /// 伪代码 currentThreadID（骨架尾部条目）。
    static func currentThreadID() -> UInt64 {
        UInt64(bitPattern: pthread_self().hashValue & 0x7FFF_FFFF_FFFF_FFFF)
    }

    /// 伪代码 ContextHandle（L67-100，release 走 @Sendable 闭包归还）。
    final class ContextHandle {
        let context: JSContext
        private weak var pool: JSContextPool?
        private var released = false

        init(pool: JSContextPool, context: JSContext) {
            self.pool = pool
            self.context = context
        }

        /// 伪代码 0x1000fae70（L88-100）。
        func release() {
            guard !released else { return }
            released = true
            pool?.returnContext(context)
        }

        deinit {
            release()
        }
    }

    /// 伪代码 0x1000fabc8（L105-135）：取空闲（同线程优先）或新建。
    func acquireHandle() -> ContextHandle {
        let threadID = Self.currentThreadID()
        lock.lock()
        defer { lock.unlock() }
        if let index = state.firstIndex(where: { !$0.inUse && $0.ownerThread == threadID }) {
            state[index].inUse = true
            checkedOut += 1
            maxInFlight = max(maxInFlight, checkedOut)
            return ContextHandle(pool: self, context: state[index].context)
        }
        if let index = state.firstIndex(where: { !$0.inUse }) {
            state[index].inUse = true
            state[index].ownerThread = threadID
            checkedOut += 1
            maxInFlight = max(maxInFlight, checkedOut)
            return ContextHandle(pool: self, context: state[index].context)
        }
        let context = JSContext()
        context.setName("qireader-pool")
        state.append(CachedContext(context: context, ownerThread: threadID, inUse: true))
        checkedOut += 1
        maxInFlight = max(maxInFlight, checkedOut)
        return ContextHandle(pool: self, context: context)
    }

    /// 伪代码 0x1000fbed8（L143-175）：归还（去重回池）。
    private func returnContext(_ context: JSContext) {
        lock.lock()
        defer { lock.unlock() }
        if let index = state.firstIndex(where: { $0.context === context }) {
            state[index].inUse = false
            checkedOut = max(0, checkedOut - 1)
        }
    }

    /// 伪代码 0x1000faa44（L180-197）：清空池，返回清理数。
    @discardableResult
    func drain() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let count = state.count
        state.removeAll()
        checkedOut = 0
        return count
    }

    /// 伪代码 0x1000f9e24（L201-209）：预建至 count。
    func warmup(count: Int) {
        lock.lock()
        let missing = max(0, count - state.count)
        lock.unlock()
        for _ in 0..<missing {
            let context = JSContext()
            context.setName("qireader-pool")
            lock.lock()
            state.append(
                CachedContext(context: context, ownerThread: Self.currentThreadID(), inUse: false)
            )
            lock.unlock()
        }
    }

    /// 伪代码 snapshot()：(checkedOut, pooled, maxInFlight)。
    func snapshot() -> (checkedOut: Int, pooled: Int, maxInFlight: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (checkedOut, state.count, maxInFlight)
    }

    // MARK: - 静态便捷入口（AnalyzeRule/AnalyzeUrl 家族调用形态）

    static let shared = JSContextPool()

    static func acquire() -> JSContext {
        shared.acquireHandle().context
    }

    static func release(_ context: JSContext) {
        shared.returnContext(context)
    }

    static func warmup(count: JSContext) {
        // AnalyzeRule.jsContextHandle 的 warmup 调用形态：确保池至少 1 个热上下文。
        shared.warmup(count: 1)
    }

    static func drain() {
        shared.drain()
    }

    static func boundRule(for context: JSContext) -> AnalyzeRule? {
        context.objectForKeyedSubscript("__activeAnalyzer") as? AnalyzeRule
    }
}

/// 伪代码 JSContextPoolReuseTracker（L227）。
final class JSContextPoolReuseTracker {
    private(set) var reuseCount = 0
    private(set) var acquireCount = 0

    func recordAcquire() { acquireCount += 1 }
    func recordReuse() { reuseCount += 1 }
}

/// 伪代码 JSContextCompiledExpressionCache（L241-285）：编译表达式 LRU 缓存。
final class JSContextCompiledExpressionCache {
    private let maxEntries: Int
    private var storage: [String: JSValue] = [:]
    private var order: [String] = []
    private var counter = 0

    init(maxEntries: Int) {
        self.maxEntries = max(1, maxEntries)
    }

    /// 伪代码 0x1000fcb90（L245-249）/makeFunctionName（骨架尾部）。
    func functionName(for script: String) -> String {
        "fn_\(abs(script.hashValue))_\(counter)"
    }

    func makeFunctionName() -> String {
        counter += 1
        return "fn_\(counter)"
    }

    /// 伪代码 0x1000fcf88：按脚本名移除。
    func removeFunctionName(for script: String) {
        let name = functionName(for: script)
        storage.removeValue(forKey: name)
        order.removeAll { $0 == name }
    }

    /// 伪代码 0x1000fd050（L263-279）：存储（超限淘汰最旧）。
    func store(functionName name: String, value: JSValue) {
        if storage.count >= maxEntries, let oldest = order.first {
            storage.removeValue(forKey: oldest)
            order.removeAll { $0 == oldest }
        }
        storage[name] = value
        order.append(name)
    }

    /// 伪代码 0x1000fcc90（L281-285）：命中刷新。
    func touch(_ name: String) {
        if let index = order.firstIndex(of: name) {
            order.remove(at: index)
            order.append(name)
        }
    }

    func lookup(_ name: String) -> JSValue? {
        guard let value = storage[name] else { return nil }
        touch(name)
        return value
    }
}

// MARK: - JSContext 扩展

extension JSContext {

    /// 伪代码 0x1000fd714（L294-307）。
    var poolReuseTracker: JSContextPoolReuseTracker {
        if let existing = objectForKeyedSubscript("__poolReuseTracker")
            as? JSContextPoolReuseTracker {
            return existing
        }
        let tracker = JSContextPoolReuseTracker()
        setObject(tracker, forKeyedSubscript: "__poolReuseTracker" as NSString)
        return tracker
    }

    /// 伪代码 0x1000fd870（L315-328）。
    var compiledExpressionCache: JSContextCompiledExpressionCache {
        if let existing = objectForKeyedSubscript("__compiledExpressionCache")
            as? JSContextCompiledExpressionCache {
            return existing
        }
        let cache = JSContextCompiledExpressionCache(maxEntries: 32)
        setObject(cache, forKeyedSubscript: "__compiledExpressionCache" as NSString)
        return cache
    }

    /// 伪代码 0x1000fdb7c（L351-395）：编译缓存命中或新建。
    func compiledExpressionFunction(_ script: String) -> JSValue? {
        let cache = compiledExpressionCache
        let name = cache.functionName(for: script)
        if let cached = cache.lookup(name) {
            return cached
        }
        let wrapped = """
        (function() {
            var __script = String(__evaluateSanitizedScript || '');
            return Function(__script + '').call(this);
        }).call(this)
        """
        setObject(script, forKeyedSubscript: "__evaluateSanitizedScript" as NSString)
        let compiled = evaluateScript(wrapped)
        if let compiled {
            cache.store(functionName: name, value: compiled)
        }
        return compiled
    }

    /// 伪代码 0x1000fa2dc（L401-403）。
    func didRecoverFromEvaluateSanitizedSyntaxFallback() -> Bool {
        objectForKeyedSubscript("__sanitizedSyntaxRecovered") != nil
    }

    /// 伪代码 0x1000fbc60（L413-424）。
    func evaluateWrappedSanitizedString(_ script: String) -> JSValue? {
        setObject(script, forKeyedSubscript: "__evaluateSanitizedScript" as NSString)
        let wrapped = """
        (function() {
            var __script = String(__evaluateSanitizedScript || '');
            return Function(__script + '').call(this);
        }).call(this)
        """
        return evaluateScript(wrapped)
    }

    /// 伪代码 0x1000fa3d0（L426-448）：函数体形态求值。
    func evaluateSanitizedFunctionBody(
        _ body: String,
        convertLegadoTemplates: Bool
    ) -> JSValue? {
        let prepared = convertLegadoTemplates
            ? sanitizeJavaScriptForCompatibility(body, convertLegadoTemplates: true)
            : body
        return evaluateWrappedSanitizedString(prepared)
    }

    /// 伪代码 0x1000f9ec8（L452-531）：清洗求值主入口。
    func evaluateSanitized(_ script: String, convertLegadoTemplates: Bool) -> JSValue? {
        exception = nil
        let prepared = convertLegadoTemplates
            ? sanitizeJavaScriptForCompatibility(script, convertLegadoTemplates: true)
            : script
        if let compiled = compiledExpressionFunction(prepared) {
            return compiled
        }
        let value = evaluateWrappedSanitizedString(prepared)
        if value == nil, exception != nil {
            setObject(true, forKeyedSubscript: "__sanitizedSyntaxRecovered" as NSString)
        }
        return value
    }
}

// MARK: - 求值结果归一（全项目复用出口）

/// 伪代码 0x1000fb510（L534-548）：字符串形态出口。
func ruleEvaluationStringValue(from value: JSValue?) -> String? {
    guard let value, !value.isUndefined, !value.isNull else { return nil }
    let text = value.toString()
    return (text?.isEmpty == false) ? text : nil
}

/// 伪代码 0x1000faff4（L555-577）：结构体出口（骨架签名）。
func ruleEvaluationTemplateOutcome(from value: JSValue?) -> RuleEvaluationTemplateOutcome {
    RuleEvaluationTemplateOutcome(
        text: ruleEvaluationStringValue(from: value),
        structured: ruleEvaluationStructuredValue(from: value)
    )
}

/// 伪代码 ruleEvaluationCollectionArrayValue（骨架尾部）：数组形态。
func ruleEvaluationCollectionArrayValue(from value: JSValue?) -> [Any]? {
    guard let value, value.isArray else { return nil }
    return value.toArray()
}

/// 伪代码 ruleEvaluationResult（骨架尾部）：组合出口。
func ruleEvaluationResult(from value: JSValue?) -> RuleEvaluationResult {
    RuleEvaluationResult(
        text: ruleEvaluationStringValue(from: value),
        value: ruleEvaluationStructuredValue(from: value)
    )
}

/// 伪代码 0x1000fb2e0（L579-603）。
func ruleEvaluationStructuredValue(from value: JSValue?) -> Any? {
    guard let value, !value.isUndefined, !value.isNull else { return nil }
    if value.isBool { return value.toBool() }
    if value.isNumber { return value.toNumber() }
    if value.isString { return value.toString() }
    if value.isArray { return value.toArray() }
    if value.isObject { return value.toObject() }
    return value.toString()
}

/// 伪代码 0x1000fe0ac（L626-639）。
func ruleEvaluationMarkedJavaStringValue(from value: JSValue?) -> String? {
    ruleEvaluationStringValue(from: value)
}
