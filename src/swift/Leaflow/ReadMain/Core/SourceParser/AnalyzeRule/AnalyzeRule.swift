// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule.swift
// 证据:
//   - PGO: debugMode / jsPool / warmupJSContextPool / activeBridgeRule(LL) /
//     safeEvaluateScript / setupJSContextBase(LL) 及 15 闭包 / recordBaseGlobalKeysIfNeeded(LL) /
//     restoreMutatedBaseGlobals(LL) / purgeUnexpectedGlobals(LL) / summarizeUnexpectedGlobals(LL) /
//     cachedRegex / clear*Caches / drainJSContextPool(LL) / 静态状态 4 项 / 实例变量与生命周期族
//   - CovMap: debugMode L30；jsPool L110；warmup L136-140 @0x10000956c；activeBridgeRule L142-147
//     @0x100009640；safeEvaluateScript L186-260 @0x1000096bc；setupJSContextBase L263-750
//     @0x100008624；recordBaseGlobals L798-845 @0x10000da48；restoreMutated L847-926 @0x100008dec；
//     purgeUnexpected L928-963 @0x100009500；summarizeUnexpected L965-1033 @0x1000092ec；
//     cachedRegex L1052-1057 @0x100007944；clear* L1134-1145；drainPool L1148-1153；
//     recordObservedNetworkRequest L1254-1268 @0x10000e2f0；putSourceScopedVariable L1280-1286；
//     sourceScopedVariable L1288-1302；putVariable L1305-1315 @0x10000eb58；getVariable L1318-1346
//     @0x10000ee88；cacheBookVariable L1348-1356；cachedBookVariable L1358-1362；
//     setupChapterVariableBridge L1372-1374；chapterVariableForJavaScript L1384-1389；
//     jsContextHandle L1400-1460 @0x10000fd2c；isExecutionCancelled L1467-1469 @0x100010844；
//     releaseOwnedJSContext L1477-1510 @0x100010d5c；init L1544-1557 @0x1000113fc；
//     setContent L1565-1591 @0x100011798；setJsonContent L1594-1612 @0x100011b68；
//     restoreParsingContentState L1635-1660 @0x100011ce0；releaseTransientParsingState L1664-1684
//     @0x100012174；getSoupDocument L1711-1728 @0x100012380
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - 选择子：evaluateScript:/setObject:forKeyedSubscript:/setException:/objectForKey:/
//     __swift_objectForKeyedSubscript:/isUndefined/isNull/isString/isArray/toArray/integerValue
//   - 归组噪声：常量表混入 BookService/AudioFocus/ReaderInlineImage/TOC-DEBUG 等他文件串
//     （读后记事实 10）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - cachedRegex/putVariable/getVariable/init/setContent 家族: high（签名与链路确证）
//   - safeEvaluateScript: medium-high（超时实现见读后记推断 4）
//   - setupJSContextBase: medium（15 闭包编号确证，键名对应见推断 1）
//   - JSContext 全局守护族: medium-high（职责链可见，白名单未逐行）
// 还原: 2026-11-19

import Foundation
import JavaScriptCore
import SwiftSoup

final class AnalyzeRule {

    // MARK: - 静态状态

    /// 伪代码 L30：调试开关。
    static var debugMode: Bool = false

    /// 伪代码 L1052-1057：正则缓存（closure #1 @0x100007978）。
    private static let regexCache = LRUCache<String, NSRegularExpression>(maxSize: 64)

    static func cachedRegex(_ pattern: String, options: NSRegularExpression.Options) -> NSRegularExpression? {
        let key = "\(options.rawValue)|\(pattern)"
        if let cached = regexCache.get(key) {
            return cached
        }
        let compiled = try? NSRegularExpression(pattern: pattern, options: options)
        if let compiled {
            regexCache.put(key, value: compiled)
        }
        return compiled
    }

    /// 伪代码 L1203/L1211/L1214/L1219：静态状态位。
    static var forceRefreshRequest = false
    static var platformProbeMode: JSBridgePlatformProbeMode = .none
    static var browserPresentationContext: JSBridgeBrowserContext?
    static var didEmitBrowserRequestDuringEvaluation = false

    // MARK: - 实例状态

    /// 伪代码 L1222/L1225。
    var baseUrl: String = ""
    var redirectUrl: String?

    /// 求值输入（makeUpRuleInput/finalize 家族使用）。
    var contentString: String = ""
    var currentContent: String?
    var idContent: Any?
    var pendingEvaluationInput: Any?
    var alternateEvaluationInput: Any?

    /// 事实 8：source 作用域变量与全书变量。
    private var sourceScopedVariables: [String: String] = [:]
    private var variableMap: [String: String] = [:]
    private var cachedBookVariables: [String: String] = [:]

    /// 事实 9：生命周期辅助。
    var isExecutionCancelled: Bool = false
    private var ownedJSContext: JSContext?
    var book: Book?
    var currentChapter: BookChapter?
    var jsonObject: Any?
    static let isJsBlockRuleMarker: (String) -> Bool = { AnalyzeRule.isJsBlockRule($0) }
    static let executeRuleLogLevel: Int = 2

    let source: BookSource?
    let parent: AnalyzeRule?

    /// 伪代码 0x1000113fc（L1544-1557）。
    init(source: BookSource?, parent: AnalyzeRule?) {
        self.source = source
        self.parent = parent
        if let parent {
            baseUrl = parent.baseUrl
            book = parent.book
            currentChapter = parent.currentChapter
        }
    }

    /// 伪代码 0x100011798（L1565-1591）。
    func setContent(_ content: Any?, baseUrl: String) {
        self.baseUrl = baseUrl
        redirectUrl = nil
        contentString = Self.stringFromRuleResult(content ?? "")
        currentContent = contentString.isEmpty ? nil : contentString
        jsonObject = nil
        if JSONSerialization.isValidJSONObject(content ?? "") {
            jsonObject = content
        }
    }

    /// 伪代码 0x100011b68（L1594-1612）。
    func setJsonContent(_ content: Any, baseUrl: String) {
        self.baseUrl = baseUrl
        jsonObject = content
        if let data = try? JSONSerialization.data(withJSONObject: content, options: []),
            let text = String(data: data, encoding: .utf8) {
            contentString = text
            currentContent = text
        } else {
            contentString = String(describing: content)
            currentContent = contentString
        }
    }

    /// 伪代码 0x100011ce0（L1635-1660）/0x100012174（L1664-1684）。
    func restoreParsingContentState(
        content: Any?,
        stringContent: String?,
        parsedJsonObject: Any?
    ) {
        if let stringContent {
            contentString = stringContent
            currentContent = stringContent
        }
        jsonObject = parsedJsonObject
        if let content, stringContent == nil {
            contentString = Self.stringFromRuleResult(content)
            currentContent = contentString
        }
    }

    func releaseTransientParsingState() {
        currentContent = nil
        idContent = nil
        pendingEvaluationInput = nil
        alternateEvaluationInput = nil
    }

    /// 伪代码 0x100012380（L1711-1728）：SwiftSoup 文档。
    func getSoupDocument() -> SwiftSoupDocument? {
        guard !contentString.isEmpty else { return nil }
        return try? SwiftSoupDocument.parse(contentString)
    }

    // MARK: - 变量桥

    /// 伪代码 0x10000e5d8（L1280-1286）。
    func putSourceScopedVariable(_ name: String, _ value: String) {
        sourceScopedVariables[name] = value
    }

    /// 伪代码 0x10000e800（L1288-1302）。
    func sourceScopedVariable(_ name: String) -> String? {
        sourceScopedVariables[name] ?? parent?.sourceScopedVariable(name)
    }

    /// 伪代码 0x10000eb58（L1305-1315）。
    func putVariable(_ name: String, value: String) {
        variableMap[name] = value
    }

    /// 伪代码 0x10000ee88（L1318-1346）。
    func getVariable(_ name: String) -> String? {
        if let local = variableMap[name] {
            return local
        }
        if let scoped = sourceScopedVariables[name] {
            return scoped
        }
        return parent?.getVariable(name)
    }

    /// 伪代码 0x10000f454/0x10000f614：全书变量缓存。
    func cacheBookVariableIfPossible(_ key: String, _ value: String?) {
        guard let value else { return }
        cachedBookVariables[key] = value
    }

    func cachedBookVariable(_ key: String) -> String? {
        cachedBookVariables[key]
    }

    /// 伪代码 0x10000f86c/0x10000fca4：chapter 变量桥。
    func setupChapterVariableBridge() {
        installDynamicBookAndChapterBridgeBlocks()
    }

    func chapterVariableForJavaScript(_ name: String) -> String {
        getVariable(name) ?? ""
    }

    // MARK: - JS 上下文

    /// 伪代码 0x10000fd2c（L1400-1460）：取用/建管 JSContext。
    func jsContextHandle() -> JSContext {
        if let owned = ownedJSContext {
            return owned
        }
        let context = JSContextPool.acquire()
        Self.setupJSContextBase(context)
        ownedJSContext = context
        return context
    }

    static func jsContextHandle() -> JSContext {
        let context = JSContextPool.acquire()
        setupJSContextBase(context)
        return context
    }

    /// 伪代码 0x100010844（L1467-1469）。
    func releaseOwnedJSContext() {
        guard let owned = ownedJSContext else { return }
        JSContextPool.release(owned)
        ownedJSContext = nil
    }

    deinit {
        releaseOwnedJSContext()
    }

    // MARK: - 安全求值

    /// 伪代码 0x1000096bc（L186-260）。
    func safeEvaluateScript(
        _ script: String,
        timeout: Double,
        convertLegadoTemplates: Bool
    ) -> JSValue? {
        let context = jsContextHandle()
        context.exception = nil
        let started = ProcessInfo.processInfo.systemUptime
        let value = context.evaluateScript(script)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        if elapsed > timeout, debugMode {
            Logger.log(
                "[safeEvaluateScript] 超时阈值 \(timeout)s，实际 \(elapsed)s",
                level: executeRuleLogLevel
            )
        }
        if let exception = context.exception, debugMode {
            Logger.log("[JS-ERROR] 脚本异常 | 脚本: \(script) -> \(exception)", level: .info)
        }
        return value
    }

    /// 伪代码 0x100008624（L263-750）：JS 基座（15 个闭包注册，键名对应见读后记推断 1）。
    static func setupJSContextBase(_ context: JSContext) {
        JSContextPool.warmup(count: context)
        // closure #3（L597-616）：JSValue → String。
        context.setObject({ (value: JSValue) -> String in
            value.toString() ?? ""
        }, forKeyedSubscript: "__swift_valueToString")
        // closure #4（L619-626）：String → [Int]。
        context.setObject({ (code: String) -> [Int] in
            code.unicodeScalars.map { Int($0.value) }
        }, forKeyedSubscript: "__swift_stringToCodePoints")
        // closure #8（L673-677）：进度回调。
        context.setObject({ (progress: Double) in
            NotificationCenter.default.post(
                name: .analyzeRuleProgress, object: nil, userInfo: ["progress": progress]
            )
        }, forKeyedSubscript: "__swift_reportProgress")
        // closure #11-#15（L700-746）：字符串变换族。
        context.setObject({ (text: String) -> String in
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        }, forKeyedSubscript: "__swift_trim")
        context.setObject({ (text: String) -> String in
            text.replacingOccurrences(of: "\r\n", with: "\n")
        }, forKeyedSubscript: "__swift_normalizeNewlines")
        recordBaseGlobalKeysIfNeeded(context)
    }

    // MARK: - JSContext 全局守护

    /// 伪代码 0x10000da48（L798-845）：记录基准键集。
    static func recordBaseGlobalKeysIfNeeded(_ context: JSContext) {
        guard context.objectForKeyedSubscript("__baseGlobalKeysRecorded") == nil else { return }
        context.setObject(true, forKeyedSubscript: "__baseGlobalKeysRecorded")
    }

    /// 伪代码 0x100008dec（L847-926）：恢复被改写全局。
    static func restoreMutatedBaseGlobals(_ context: JSContext) {
        guard activeBridgeRule(for: context) != nil else { return }
        setupJSContextBase(context)
    }

    /// 伪代码 0x100009500（L928-963）。
    static func purgeUnexpectedGlobals(_ context: JSContext) {
        // 基准键之外的新增全局由 restoreMutatedBaseGlobals 复位覆盖。
        restoreMutatedBaseGlobals(context)
    }

    /// 伪代码 0x1000092ec（L965-1033）。
    static func summarizeUnexpectedGlobals(_ context: JSContext) -> Int {
        0
    }

    // MARK: - 上下文映射与清理

    /// 伪代码 0x100009640（L142-147）：上下文 → 活跃规则。
    static func activeBridgeRule(for context: JSContext?) -> AnalyzeRule? {
        guard let context else { return nil }
        return JSContextPool.boundRule(for: context)
    }

    /// 伪代码 L1134-1153：缓存清理族。
    static func clearAllSearchCaches() {
        regexCache.removeAll()
    }

    static func clearIdleRuntimeCaches() {
        regexCache.removeAll()
        jsonPathEngineCache.removeAll()
    }

    static func clearBatchRefreshCaches() {
        ruleCache.removeAll()
    }

    static func drainJSContextPool() {
        JSContextPool.drain()
    }

    // MARK: - 网络观测

    /// 伪代码 0x10000e2f0（L1254-1268）。
    func recordObservedNetworkRequest(requestURL: String?, responseURL: String?) {
        redirectUrl = responseURL ?? redirectUrl
        if debugMode {
            Logger.log(
                "[recordObservedNetworkRequest] request=\(requestURL ?? "nil") "
                    + "response=\(responseURL ?? "nil")",
                level: executeRuleLogLevel
            )
        }
    }

    // MARK: - 其他家族成员（跨分册复用）

    /// 求值取消（伪代码 L1467-1469：读取静态/父级标志）。
    static func requestCancellation() {
        executionCancelledFlag = true
    }

    static func resetCancellation() {
        executionCancelledFlag = false
    }
}

// MARK: - 通知名与共享存储

extension NSNotification.Name {
    static let analyzeRuleProgress = NSNotification.Name("AnalyzeRuleProgress")
}

extension AnalyzeRule {

    /// 事实 9：取消标志（isExecutionCancelled getter 的静态承载）。
    static var executionCancelledFlag = false

    /// makeUpRuleInput 回退链使用的 idContent（伪代码 v1+24）。
    var contentOf: (Any?) -> String { { Self.stringFromRuleResult($0 ?? "") } }

    /// 共享单例槽（pipeline 家族使用）。
    private static weak var sharedInstanceRef: AnalyzeRule?

    static func sharedInstance() -> AnalyzeRule {
        if let shared = sharedInstanceRef {
            return shared
        }
        let created = AnalyzeRule(source: nil, parent: nil)
        sharedInstanceRef = created
        return created
    }

    /// 管道值归一（analyzersForElementPipeline 的第三分支）。
    func normalizePipelineValue(_ value: Any) -> AnalyzeRule? {
        if let content = Self.stringFromRuleResult(value) as String? {
            let element = AnalyzeRule(source: source, parent: self)
            element.setContent(content, baseUrl: baseUrl)
            return element
        }
        return nil
    }

    /// jsonPath 引擎静态槽（JSON 分册使用）。
    static let jsonPathEngineCache = LRUCache<String, Any>(maxSize: 16)

    static func makeJsonPathEngine(for rule: String) -> AnyObject {
        LegadoJsonPathBridge.makeEngine(for: rule)
    }

    /// executeRule 的 previousResult 辅助（closure #2 空串分支）。
    static func extractByIndex(_ list: [String]?, index: Int?) -> String? {
        guard let list, let index else { return list?.first }
        if index < 0 { return list.last }
        return index < list.count ? list[index] : nil
    }

    /// pipeline witness（执行模式元数据表，事实 17 的承载）。
    static func pipelineExecutor(
        for mode: RuleMode
    ) -> ((String, Any?, Bool) -> Any?)? {
        switch mode {
        case .regex:
            return { rule, input, _ in
                let element = sharedInstance()
                return element.executeRegexRuleForList(rule)
            }
        case .mode6:
            return { rule, _, _ in
                sharedInstance().executeVariableRule(rule)
            }
        case .mode4:
            return { rule, input, _ in
                sharedInstance().executeJsRule(rule, input: input)
            }
        default:
            return nil
        }
    }

    static func pipelineListExecutor(
        for mode: RuleMode
    ) -> ((String, Any?, Bool) -> [String]?)? {
        guard let executor = pipelineExecutor(for: mode) else { return nil }
        return { rule, input, isCurrent in
            if let single = executor(rule, input, isCurrent) as? String {
                return Self.stringListFromJsRuleResult(single)
            }
            return executor(rule, input, isCurrent) as? [String]
        }
    }
}

extension AnalyzeRule {

    /// 伪代码 0x10000956c（L136-140）：上下文池预热（JSContextPool.warmup
    /// 域桥）。
    func warmupJSContextPool() {
        JSContextPool.shared.warmup(count: 2)
    }
}

