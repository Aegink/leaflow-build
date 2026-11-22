// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+CSS.swift
// 证据:
//   - PGO: executeCssRule / isValidCssSelector / executeCssRuleForList / isInsideQuotes /
//     isBareLegadoSelectorRule(LL) 及各 implicit closure
//   - CovMap: executeCssRule L18-162 @0x100015814；isValidCssSelector L206-225 @0x1000170fc；
//     executeCssRuleForList L165-168 @0x100015628
//   - IDA: 0x100015814、0x1000170fc 的 Hex-Rays 伪代码
//   - 关键常量（低字节在前）："\n"=10、"\r"=13、"@@"=16448、"##"=8995、
//     "$."=11812、"$["=23332、"$.."=3026468、"@"=64、"baseUrl"=0x6C725565736162、
//     ":eq("=678520122、"//"=12079、"<html></html>"=0x2F3C3E6C6D74683C/0xED00003E6C6D7468、
//     正则 "\{\{([^{]+)\}\}"=0x7D5E5B287B5C7B5C/0xEF7D5C7D5C292B5D、"java."=0x2E6176616A
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - isValidCssSelector: high（trim/常量检查/前缀链逐条对应；LRU 负缓存语义为推断）
//   - executeCssRule: medium-high（多行/##/模板分发/JSoup 调用确证；个别细节见读后记“仍不清楚”）
//   - executeCssRuleForList: medium（地址被折叠，按签名与 4 行 CovMap 推断包装行为）
//   - isInsideQuotes / isBareLegadoSelectorRule: medium（PGO-only 无地址，按名与调用点还原）
// 依赖: LegadoJSoupAnalyzer（T-206）、AnalyzeRule 主类 baseUrl/regexGroupValue 缓存（T-201 后续）。
// 还原: 2026-11-18

import Foundation
import SwiftSoup

extension AnalyzeRule {

    /// 执行 CSS 选择子规则，支持多行、`##` 替换指令与 `{{...}}` 模板展开。
    ///
    /// 伪代码 0x100015814（L18-162）主干：
    /// 1. 含 "\n" → 按行拆分；逐行 trim 后：空行跳过；"##" 开头的行是替换指令
    ///    （`dropFirst(2)` 后以下一个 "##" 切成 pattern/replacement）；其余行递归
    ///    `executeCssRule`，命中则收集，未命中且不含 "##" 的行原样保留。
    /// 2. 结果 `joined(separator: "\n")` 后应用替换指令（options = 1024 正则替换）；
    ///    replacement 同时含 "{{"/"}}" 时先过 `processInnerJs`。
    /// 3. 单行：正则 `\{\{([^{]+)\}\}` 逐个 occurrence 展开——内层按
    ///    `@@`/`$.`/`$[`/`$..`/`getVariable`/`baseUrl`/`java.` 分发，结果
    ///    `replaceSubrange` 回填。
    /// 4. 处理后的选择子须 `hasPrefix("@")` 或通过 `isValidCssSelector`，
    ///    再交给 `LegadoJSoupAnalyzer.getString` 执行。
    /// 5. 模板正则与结果缓存于 os_unfair_lock 保护的 LRU（超 32 条按 count>>2 淘汰）。
    func executeCssRule(_ rule: String) -> String? {
        // 事实 7：多行路径。
        if rule.contains("\n") {
            return executeCssRuleMultiLine(rule)
        }
        return executeCssRuleSingleLine(rule)
    }

    /// 伪代码 L165-168（@0x100015628，地址折叠未单独导出，按签名还原）：
    /// `executeCssRule` 的列表包装 —— 返回 `[String]?`。
    func executeCssRuleForList(_ rule: String) -> [String]? {
        guard let result = executeCssRule(rule) else { return nil }
        return result.components(separatedBy: "\n")
    }

    // MARK: - 多行路径

    /// 伪代码 0x100015814 L358-L941：多行拆分、逐行递归、"##" 替换指令。
    private func executeCssRuleMultiLine(_ rule: String) -> String? {
        var collected: [String] = []
        var replacePattern: String?
        var replaceReplacement: String?

        for rawLine in rule.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            // 事实 7："##" 开头的行是替换指令。
            if line.hasPrefix("##") {
                let body = String(line.dropFirst(2))
                if let separator = body.range(of: "##") {
                    replacePattern = String(body[body.startIndex..<separator.lowerBound])
                    replaceReplacement = String(body[separator.upperBound...])
                }
                continue
            }

            // 其余行递归执行单行 CSS。
            if let executed = executeCssRule(line) {
                collected.append(executed)
            } else if !line.contains("##") {
                // 伪代码 L844-L868：未命中且不含 "##" 的行原样保留。
                collected.append(line)
            }
        }

        let joined = collected.joined(separator: "\n")
        guard let pattern = replacePattern else {
            return joined.isEmpty ? nil : joined
        }

        // 事实 8：replacement 含 "{{"/"}}" 时先过 processInnerJs，再正则替换。
        var replacement = replaceReplacement ?? ""
        if replacement.contains("{{"), replacement.contains("}}") {
            replacement = processInnerJs(replacement)
        }
        return joined.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: .regularExpression,
            range: joined.startIndex..<joined.endIndex
        )
    }

    // MARK: - 单行路径

    /// 伪代码 0x100015814 L441-L524：模板展开 → 选择子校验 → JSoup 执行。
    private func executeCssRuleSingleLine(_ rule: String) -> String? {
        var processed = rule

        // 事实 9/10：模板正则 \{\{([^{]+)\}\}（编译结果走锁保护的 LRU 缓存）。
        let templateRegex = Self.cachedTemplateRegex()
        let fullRange = NSRange(processed.startIndex..<processed.endIndex, in: processed)
        let matches = templateRegex?.matches(in: processed, options: [], range: fullRange) ?? []

        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let outer = Range(match.range(at: 0), in: processed),
                  let innerRange = Range(match.range(at: 1), in: processed)
            else { continue }
            let inner = String(processed[innerRange])

            let replacement: String?
            if inner.hasPrefix("@@") {
                // 事实 10：@@ → dropFirst(2) 递归 CSS。
                replacement = executeCssRule(String(inner.dropFirst(2)))
            } else if Self.isJsonPathPrefix(inner) {
                // 事实 10：$. / $[ / $.. → executeJsonRule。
                replacement = executeJsonRule(inner)
            } else if inner == "baseUrl" {
                // 事实 10：baseUrl → 实例属性（ivar OBJC_IVAR____TtC7Leaflow11AnalyzeRule_baseUrl）。
                replacement = baseUrl
            } else if let variable = getVariable(inner) {
                // 事实 10：模板变量优先于 JS。
                replacement = variable
            } else if inner.contains("java.") {
                // 事实 10：含 "java." 的表达式走 JS 求值。
                // prepareJavaScriptEvaluationContext 为无参域（签名确证，
                // wave-16）。
                prepareJavaScriptEvaluationContext()
                let evaluated = safeEvaluateScript(
                    inner,
                    timeout: 15.0,
                    convertLegadoTemplates: true
                )
                replacement = ruleEvaluationStringValue(from: evaluated)
            } else {
                replacement = nil
            }

            if let replacement {
                processed.replaceSubrange(outer, with: replacement)
            }
        }

        // 事实 11：@ 前缀直通或选择子合法才执行 JSoup。
        // 伪代码：栈上构造 LegadoJSoupAnalyzer 并 retain self（swift_initStackObject +
        // sub_1000724C8），随后调用其 getString(_:)；构造器签名未知，按语义调用。
        let selector = processed
        guard selector.hasPrefix("@") || Self.isValidCssSelector(selector) else {
            return nil
        }
        let analyzer = LegadoJSoupAnalyzer(source: self)
        return analyzer.getString(selector)
    }

    // MARK: - 选择子校验

    /// 伪代码 0x1000170fc（L206-225）：
    /// 1. trim；空 → false；
    /// 2. contains("\n") / contains("\r") / contains(":eq(") → false（事实 12，
    ///    contains-vs-hasPrefix 见读后记推断 1）；
    /// 3. `drop(while: { $0.isNumber || $0 == "-" })`；
    /// 4. 剩余串 hasPrefix("//") / "$." / "$[" → false（XPath/JSONPath 不是 CSS）；
    /// 5. LRU 负缓存命中 → false（推断 2）；
    /// 6. 以 "<html></html>" 模板文档验证选择子可解析。
    static func isValidCssSelector(_ selector: String) -> Bool {
        let trimmed = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return false
        }
        if trimmed.contains("\n") || trimmed.contains("\r") {
            return false
        }
        if trimmed.contains(":eq(") {
            return false
        }

        let remaining = trimmed.drop { $0.isNumber || $0 == "-" }
        let rest = String(remaining)
        if rest.isEmpty {
            return false
        }
        if rest.hasPrefix("//") || rest.hasPrefix("$.") || rest.hasPrefix("$[") {
            return false
        }

        // T-1601-B1：CSS 后缀记号（@text/@html/...）只属于取串阶段，
        // 选择子校验只看后缀之前的选择子本体（LegadoJSoupAnalyzer
        // parseSuffix 同源后缀表）。
        var selectorPart = rest
        if let at = selectorPart.lastIndex(of: "@") {
            let suffix = selectorPart[
                selectorPart.index(after: at)...].lowercased()
            let suffixes = [
                "html", "text", "textnodes", "all", "id", "tag",
                "children",
            ]
            if suffixes.contains(suffix) {
                selectorPart = String(selectorPart[..<at])
            }
        }
        if selectorPart.isEmpty {
            return false
        }

        // 推断 2：历史无效选择子负缓存（LRU 命中即 false）。
        if rejectedSelectors.contains(rest) {
            return false
        }

        // 事实 12：用最小模板文档实际执行一次选择子。
        guard let document = try? SwiftSoup.parse("<html></html>") else {
            return false
        }
        do {
            _ = try document.select(selectorPart)
        } catch {
            rejectedSelectors.insert(rest)
            return false
        }
        return true
    }

    /// 事实 10 辅助：与 InnerRuleProcessor 闭包 #2（0x100022ef4）同源的三前缀判断。
    private static func isJsonPathPrefix(_ expression: String) -> Bool {
        expression.hasPrefix("$.") || expression.hasPrefix("$[") || expression.hasPrefix("$..")
    }

    // MARK: - 缓存

    /// 事实 9：模板正则缓存。原实现为 os_unfair_lock 保护的 LRU
    /// （keyed by pattern，超 32 条按 count>>2 淘汰）；此处模式固定，
    /// 以 NSCache + 锁等价承载，淘汰语义对单条目无差异。
    private static let regexCacheLock = NSLock()
    private static var compiledTemplateRegex: NSRegularExpression?

    private static func cachedTemplateRegex() -> NSRegularExpression? {
        regexCacheLock.lock()
        defer { regexCacheLock.unlock() }
        if let cached = compiledTemplateRegex {
            return cached
        }
        // 常量 0x7D5E5B287B5C7B5C/0xEF7D5C7D5C292B5D = "\{\{([^{]+)\}\}"。
        let pattern = "\\{\\{([^{]+)\\}\\}"
        let regex = try? NSRegularExpression(pattern: pattern)
        compiledTemplateRegex = regex
        return regex
    }

    /// 推断 2 的载体：被判定无效的选择子集合（原实现为 LRU，32 条上限）。
    private static var rejectedSelectors: Set<String> = []

    /// 推断 4：`@@` 前缀的裸选择子判断（PGO-only `isBareLegadoSelectorRule`）。
    /// 依据：别名列表 + executeCssRule 中 hasPrefix("@") 直通分支。
    static func isBareLegadoSelectorRule(_ rule: String) -> Bool {
        rule.hasPrefix("@@")
    }

    /// 推断 4：`isInsideQuotes`（PGO-only，无地址）。按名与调用点：
    /// 判断 `text` 中 `target` 的出现处是否位于引号内。
    /// 注：引号字符集（单/双引号）无直接证据，按 CSS 语境取双引号。
    static func isInsideQuotes(_ text: String, _ target: String) -> Bool {
        guard let range = text.range(of: target) else { return false }
        let prefix = String(text[text.startIndex..<range.lowerBound])
        let doubleQuotes = prefix.filter { $0 == "\"" }.count
        let singleQuotes = prefix.filter { $0 == "'" }.count
        return (doubleQuotes + singleQuotes) % 2 == 1
    }
}
