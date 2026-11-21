// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JavaScript.swift
// 证据:
//   - PGO: AnalyzeRuleStringRuleEvaluator / executeJsRule / executeJsRuleForElements /
//     executeJsRuleForObjectInternal / setJavaScriptGlobalVariable /
//     setJavaScriptRuntimeBindingValue(LL) / shouldBindStructuredJSONObjectDirectly(LL) /
//     isValidJsCode / stringValueForJavaScriptRuleResult / javaScriptElementHTMLList 等
//   - CovMap: evaluate L29-38 @0x10004ef8c；setJavaScriptGlobalVariable L114-121 @0x10004f3bc；
//     setJavaScriptRuntimeBindingValue L137-191 @0x10004f5b4；
//     shouldBindStructuredJSONObjectDirectly L193-203 @0x100050a84；
//     javaScriptElementHTMLList L408-457 @0x100051724；executeJsRuleForElements L620-805
//     @0x10004bc38；executeJsRule L876-994 @0x10004dbf4；executeJsRuleForObjectInternal
//     L1000-1047 @0x100054854
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - 关键常量（低字节在前）："js>"=4092778、"<js>"=1047751228、"<"=60、">"=62、
//     "var "=544366966、" = "=2112800、"result;"=0x3B746C75736572、"src"=6517363
//   - 绑定键：__runtimeBindingHtmlList/__runtimeBindingBaseUrl/__runtimeBindingValue/
//     __jsonBridgeValue/__jsLibSourceUrl/__jsoupBridgeLoaded
//   - 诊断串：[TOC-JS-DIAG] baseUrl=/[TOC-JS-PRE] baseUrl=/[TOC-JS-DIAG] qdBookId=/
//     [TOC-JS-DIAG] __jsLibSourceUrl=/[TOC-JS] 数组结果: /远程脚本执行错误(/
//     [JS] RuleEvaluator 返回空结果, rule=
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - evaluate / setJavaScriptGlobalVariable / setJavaScriptRuntimeBindingValue: high
//   - executeJsRule: medium-high（截取/校验/processInnerJs/求值/诊断链可见）
//   - executeJsRuleForElements: medium（主干证据齐，1,835 行体量逐分支留待交叉验证，
//     见读后记推断 3）
//   - isValidJsCode: medium（正则族确证，判定先后待反汇编，见“仍不清楚”4）
// 依赖: JSContextPool（T-204）、AnalyzeRuleStringRuleEvaluator（本文件）。
// 还原: 2026-11-18

import Foundation
import JavaScriptCore
import SwiftSoup

/// 字符串规则的 JS 求值器（0x10004ef8c，L29-38）：
/// safeEvaluateScript(timeout: 15.0, convertLegadoTemplates: true) +
/// ruleEvaluationTemplateOutcome；nil → 空结果。
struct AnalyzeRuleStringRuleEvaluator {
    struct Result {
        var text: String?
        var ok: Bool
    }

    func evaluate(_ script: String) throws -> Result {
        guard let evaluated = AnalyzeRule.sharedInstance().safeEvaluateScript(
            script,
            timeout: 15.0,
            convertLegadoTemplates: true
        ) else {
            return Result(text: nil, ok: false)
        }
        let outcome = ruleEvaluationStringValue(from: evaluated)
        return Result(text: outcome, ok: outcome != nil)
    }
}

extension AnalyzeRule {

    // MARK: - 全局变量注入

    /// 伪代码 0x10004f3bc（L114-121）：`var <name> = <json>` 注入 JSContext。
    /// JSON 序列化失败抛错。
    static func setJavaScriptGlobalVariable(
        named name: String,
        toJSONObject value: Any,
        filename: String
    ) throws {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw NSError(domain: "AnalyzeRule", code: 1)
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "AnalyzeRule", code: 2)
        }
        let script = "var \(name) = \(json);"
        let context = jsContextHandle()
        _ = context.evaluateScript(script)
    }

    /// 伪代码 0x10004f5b4（L137-191）：运行时绑定值写入。
    /// 依次尝试元素数组 → 解包值 → JSON 引用数组 → JSON 数组桥 →
    /// 结构化 JSON 直绑 / preferJSONObjectBinding 字符串化 → 兜底桥接。
    static func setJavaScriptRuntimeBindingValue(
        named name: String,
        value: Any,
        rawJSONString: String?,
        preferJSONObjectBinding: Bool
    ) {
        let context = jsContextHandle()
        JSContextPool.warmup(count: context)

        if let elementArray = makeJavaScriptElementArrayValueIfNeeded(value) {
            context.setObject(elementArray, forKey: name as NSString)
            return
        }
        let unwrapped = javaScriptRuntimeBindingUnwrappedValue(value)
        if let bridgeValue = makeJavaScriptJSONArrayBridgeValueIfNeeded(
            unwrapped ?? value,
            rawJSONString: rawJSONString
        ) {
            context.setObject(bridgeValue, forKey: name as NSString)
            return
        }
        if let referenceArray = makeJavaScriptJSONObjectReferenceArrayValueIfNeeded(value) {
            context.setObject(referenceArray, forKey: name as NSString)
            return
        }
        if shouldBindStructuredJSONObjectDirectly(value) {
            context.setObject(value, forKey: name as NSString)
            return
        }
        if preferJSONObjectBinding, JSONSerialization.isValidJSONObject(value) {
            if let rawJSONString {
                context.setObject(rawJSONString, forKey: name as NSString)
                return
            }
            if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
               let json = String(data: data, encoding: .utf8) {
                context.setObject(json, forKey: name as NSString)
                return
            }
        }
        if let rawJSONString {
            context.setObject(rawJSONString, forKey: name as NSString)
            return
        }
        let bridged = bridgeAnythingToObjectiveC(value)
        context.setObject(bridged, forKey: name as NSString)
    }

    /// 伪代码 0x100050a84（L193-203）：合法 JSON 对象（非数组）直绑。
    static func shouldBindStructuredJSONObjectDirectly(_ value: Any) -> Bool {
        guard JSONSerialization.isValidJSONObject(value) else { return false }
        if value is [Any] {
            return false
        }
        return true
    }

    // MARK: - JS 代码校验

    /// 伪代码 0x100053110（L1071-1116 区段）：JS 代码嗅探正则族（事实 16）。
    private static let jsPathRegex = try? NSRegularExpression(
        pattern: "^[A-Za-z_$][A-Za-z0-9_$]*(\\.[A-Za-z_$][A-Za-z0-9_$]*|\\['[^']*'\\]|\\[\"[^\"]*\"\\])+$"
    )
    private static let jsCallRegex = try? NSRegularExpression(
        pattern: "^[A-Za-z_$][A-Za-z0-9_$]*(\\.[A-Za-z_$][A-Za-z0-9_$]*)*\\([^;]*\\)$"
    )
    private static let jsDeclarationRegex = try? NSRegularExpression(
        pattern: "(var|let|const)\\s+\\w+\\s*="
    )
    private static let cssSniffRegex = try? NSRegularExpression(
        pattern: "^[a-z][a-z0-9]*($|\\.|#|\\[|\\s|,|>|\\+|~|@)"
    )

    /// 伪代码：`<...>` 形态的脚本体先经本校验，非法 → nil（事实 15）。
    /// 判定顺序（路径/调用/声明 vs CSS 嗅探）见读后记“仍不清楚”4。
    static func isValidJsCode(_ code: String) -> Bool {
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        if jsDeclarationRegex?.firstMatch(in: code, options: [], range: range) != nil {
            return true
        }
        if jsCallRegex?.firstMatch(in: code, options: [], range: range) != nil {
            return true
        }
        if jsPathRegex?.firstMatch(in: code, options: [], range: range) != nil {
            return true
        }
        // CSS 嗅探命中 → 不是 JS。
        return cssSniffRegex?.firstMatch(in: code, options: [], range: range) == nil
    }

    // MARK: - 单值 JS 执行

    /// 伪代码 0x10004dbf4（L876-994）：
    /// 1. `<js>...</js>` / `<...>` 形态截取脚本体；`<...>` 时 isValidJsCode 校验；
    /// 2. 脚本过 processInnerJs 展开 `{{...}}`；
    /// 3. 字符串规则求值器求值（timeout 15.0）；
    /// 4. resultBinding 写回 + isExecutionCancelled 双点检查；
    /// 5. "result;" 后缀剥离；失败记诊断并 LRU 登记；
    /// 6. 成功 stringValueForJavaScriptRuleResult 归一。
    func executeJsRule(
        _ rule: String,
        input: Any?,
        resultBinding: AnalyzeRuleJavaScriptResultBinding? = nil
    ) -> String? {
        var script = rule
        // 事实 15：js>/<js> 形态截取。
        if let open = script.range(of: "<js>") {
            if let close = script.range(of: "</js>", range: open.upperBound..<script.endIndex) {
                script = String(script[open.upperBound..<close.lowerBound])
            } else {
                script = String(script[open.upperBound...])
            }
        } else if script.hasPrefix("<"), script.hasSuffix(">") {
            // 伪代码 L5429-L5447：<...> 形态校验。
            let body = String(script.dropFirst().dropLast())
            guard Self.isValidJsCode(body) else {
                return nil
            }
            script = body
        }

        // 事实 15：内嵌模板展开。
        let processed = processInnerJs(script)

        // 事实 12：字符串规则求值器（timeout 15.0）。
        let evaluator = AnalyzeRuleStringRuleEvaluator()
        let result = (try? evaluator.evaluate(processed)) ?? Result(text: nil, ok: false)

        guard isExecutionCancelled == false else {
            return nil
        }

        guard var text = result.text, result.ok else {
            // 伪代码 L5714-L5811：空结果诊断。
            Logger.log(
                "[JS] RuleEvaluator 返回空结果, rule=\(rule)",
                level: Self.executeRuleLogLevel,
                anchor: 984
            )
            Self.jsRuleFailureCache.insert(rule)
            return nil
        }

        // 伪代码 L5621-L5657：result; 后缀剥离。
        if text.hasSuffix("result;") {
            text = String(text.dropLast("result;".count))
        }

        if let binding = resultBinding {
            binding.store(text)
        }
        return stringValueForJavaScriptRuleResult(text)
    }

    // MARK: - 列表 JS 执行

    /// 伪代码 0x10004bc38（L620-805，推断 3）：
    /// JS 求值 → 数组结果（[TOC-JS] 数组结果）→ 逐项包成子 AnalyzeRule。
    /// 完整逐分支还原待后续交叉验证（见读后记推断 3）。
    func executeJsRuleForElements(_ rule: String) -> [AnalyzeRule]? {
        guard let evaluated = executeJsRule(rule, input: contentString) else {
            return nil
        }
        let normalized = evaluated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        // 事实 18：HTML 片段 → SwiftSoup 元素 → 子规则。
        if normalized.contains("<") {
            let fragments = javaScriptElementHTMLList(normalized)
            if let fragments, !fragments.isEmpty {
                Logger.log(
                    "[TOC-JS] 数组结果: \(fragments.count) 项",
                    level: Self.executeRuleLogLevel
                )
                return AnalyzeRule.wrapSoupNodesAsChildRules(fragments)
            }
        }
        // 行分隔的纯文本结果。
        let lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        return AnalyzeRule.wrapRegexGroupListsAsChildRules(lines.map { [$0] })
    }

    /// 伪代码 0x100051724（L408-457）：HTML 片段 → SwiftSoup 元素数组。
    /// `_jsoupCreateFragmentElements` 桥（事实 18）。
    func javaScriptElementHTMLList(_ html: String) -> [SwiftSoupElement]? {
        guard let document = try? SwiftSoup.parse(html) else { return nil }
        let elements = (try? document.body()?.children()) ?? nil
        return elements?.array()
    }

    /// 伪代码 0x100054854（L1000-1047）：对象形态的 JS 求值内部实现。
    /// 与 executeJsRule 同链路，返回 Any（对象/数组不强制字符串化）。
    func executeJsRuleForObjectInternal(
        _ rule: String,
        input: Any?,
        resultBinding: AnalyzeRuleJavaScriptResultBinding? = nil
    ) -> Any? {
        executeJsRule(rule, input: input, resultBinding: resultBinding)
    }
}

// MARK: - 静态缓存

extension AnalyzeRule {

    /// 伪代码 LRUCache.put（事实 15）：失败规则登记（去重诊断）。
    fileprivate static var jsRuleFailureCache: Set<String> = []
}

// MARK: - T-1401-11 逐域补齐（JS 求值域）

extension AnalyzeRule {

    /// 伪代码 0x10004b7e0（L501-519）：求值上下文预备——变量桥 + 库装载域。
    func prepareJavaScriptEvaluationContext() {
        let context = jsContextHandle()
        setupJSContextBase(context)
        setupChapterVariableBridge()
        installSourceBridgeBindings()
        ensureJsLibLoaded()
    }

    /// 伪代码 0x10004ec5c（L545-584）：JSON 对象元素值构造（数组 → JSValue
    /// 对象数组域）。
    func makeJavaScriptJSONObjectElementValue(
        _ elements: [String]
    ) -> JSValue? {
        let context = jsContextHandle()
        let array = JSValue(newArrayIn: context)!
        for element in elements {
            if let value = try? JSONSerialization.jsonObject(
                with: Data(element.utf8), options: []),
                let object = JSValue(object: value, in: context) {
                array.setObject(object, atIndexedSubscript: array.toArray().count)
            } else {
                array.setObject(
                    JSValue(string: element, in: context) ?? JSValue(undefinedIn: context),
                    atIndexedSubscript: array.toArray().count)
            }
        }
        return array
    }

    /// 伪代码 0x100054550（L827-852）：原始规则求值（primitive 域——非 JSON
    /// 返回直取）。
    func evaluateJavaScriptPrimitiveRule(_ script: String) -> String? {
        let context = jsContextHandle()
        context.exception = nil
        guard let value = context.evaluateScript(script) else { return nil }
        if value.isNull || value.isUndefined { return nil }
        return value.toString()
    }

    /// 伪代码 0x10004db3c（L1061-1068）：按下标提取（result[i] 域）。
    func extractByIndex(_ result: JSValue?, index: Int) -> JSValue? {
        guard let result, result.isArray else { return nil }
        return result.objectAtIndexedSubscript(index)
    }

    /// 伪代码 0x10004b220（L1119-1159）：JSContext 装配（基座 + 桥域）。
    func setupJSContext(_ context: JSContext) {
        AnalyzeRule.setupJSContextBase(context)
        installSourceBridgeBindings()
    }

    /// 伪代码 0x100052c88（L1169-1181）：库装载确保（幂等域）。
    func ensureJsLibLoaded() {
        let context = jsContextHandle()
        let marker = "__leaflow_jslib_loaded"
        guard context.objectForKeyedSubscript(marker) == nil
            || context.objectForKeyedSubscript(marker)!.isUndefined else {
            return
        }
        loadJsLibPublic()
        context.setObject(true, forKeyedSubscript: marker)
    }

    /// 伪代码 0x1000557b8（L1184-1188）：公共库装载——沙箱 jslib 目录
    /// *.js 聚合求值（script 域；目录名与 sandboxRoots 域对齐推断）。
    func loadJsLibPublic() {
        let context = jsContextHandle()
        for root in JSImportScriptResolver.sandboxRoots() {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil) else { continue }
            for file in files
            where file.pathExtension.lowercased() == "js" {
                if let script = try? String(contentsOf: file, encoding: .utf8) {
                    context.evaluateScript(script)
                }
            }
        }
    }
}

/// JS 求值结果绑定（evaluateJS 族参数域确证；最小载体，字段随消费域补齐）。
struct AnalyzeRuleJavaScriptResultBinding {
    var elementValues: [String] = []
}
