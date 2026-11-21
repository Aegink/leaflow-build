// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+LegadoChain.swift
// 证据:
//   - PGO: executeRegexRuleForList / splitRegexChain / executeVariableRule / formatUrl
//   - CovMap: L17-26 @0x1000621c8；L28-34 @0x1000620ac；L39-56 @0x100062448；
//     L61-104 @0x100062688
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量（低字节在前）："{"=123、"}"=125、":"=58、"//"=12079、
//     BOM=12565487(EF BB BF)、U+200B=9142498(E2 80 8B)、U+00A0=41154(C2 A0)、
//     "https:"=0x3A7370747468、"http://"=0x2F2F3A70747468、"https://"=0x2F2F3A7370747468、
//     "data:"=0x3A61746164、"://"=3092282
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - executeRegexRuleForList / splitRegexChain: high（捕获组偏移与过滤逐条对应）
//   - executeVariableRule: medium-high（花括号剥离/putMap/variableMap 链可见；
//     ":" 复合键语义为推断 1）
//   - formatUrl: medium-high（清洗链与协议前缀分支确证；redirectUrl 写入方见推断 2）
// 依赖: AnalyzeByRegex（T-202）、AnalyzeRule 主类 variableMap/contentString/redirectUrl。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    /// 伪代码 0x1000621c8（L17-26）：正则列表提取。
    /// 规则为空 → nil；`AnalyzeByRegex.getElements(content, rule, isJsBlockRule)`；
    /// 匹配 ≥2 组取组 1、==1 组取整匹配；可选变换过滤后空 → nil。
    func executeRegexRuleForList(_ rule: String) -> [String]? {
        guard !rule.isEmpty else { return nil }
        let matches = AnalyzeByRegex.getElements(
            contentString,
            rule,
            Self.isJsBlockRuleMarker
        )
        var collected: [String] = []
        for match in matches {
            if match.count >= 2 {
                collected.append(match[1])
            } else if match.count == 1 {
                collected.append(match[0])
            }
        }
        let filtered = collected.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    /// 伪代码 0x1000620ac（L28-34）：正则链首捕获。
    /// `AnalyzeByRegex.getElement(content, rule, isJsBlockRule)` 首捕获；
    /// 无匹配/捕获为空 → 空串。
    func splitRegexChain(_ rule: String) -> [String] {
        guard !rule.isEmpty else { return [] }
        guard let captured = AnalyzeByRegex.getElement(
            contentString,
            [rule],
            0
        ) else {
            return []
        }
        let first = captured.first ?? ""
        return first.isEmpty ? [] : [first]
    }

    /// 伪代码 0x100062448（L39-56）：变量规则。
    /// `{...}` 剥花括号；含 ":" → parseLegadoPutMap 非空即返回（推断 1）；
    /// 否则 getVariable → variableMap 字典兜底。
    func executeVariableRule(_ rule: String) -> String? {
        var body = rule
        if body.hasPrefix("{"), body.hasSuffix("}") {
            body = String(body.dropFirst().dropLast())
        }
        if body.contains(":") {
            let parts = body.split(separator: ":", maxSplits: 1)
            if let parsed = parseLegadoPutMap(String(parts.first ?? "")), !parsed.isEmpty {
                return String(describing: parsed)
            }
            return nil
        }
        if let variable = getVariable(body) {
            return variable
        }
        return variableMap[body]
    }

    /// 伪代码 0x100062688（L61-104）：URL 清洗与解析。
    /// 1. 剥 BOM / U+200B / U+00A0（→ 空格）后 trim；
    /// 2. lowercased 判定 http:// / https:// / data: 直通；
    /// 3. "//" 前缀补 https:；
    /// 4. 相对路径按 redirectUrl（空则 baseUrl）解析为绝对 URL，跨域记日志。
    func formatUrl(_ url: String) -> String {
        var cleaned = url
        cleaned = cleaned.replacingOccurrences(of: "\u{FEFF}", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\u{200B}", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\u{00A0}", with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowered = cleaned.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
            || lowered.hasPrefix("data:") {
            return cleaned
        }
        if cleaned.hasPrefix("//") {
            return "https:" + cleaned
        }

        // 事实 4：redirectUrl 优先，空则 baseUrl。
        let base = redirectUrl?.isEmpty == false ? redirectUrl! : baseUrl
        guard let reference = URL(string: base) else {
            return cleaned
        }

        if cleaned.hasPrefix("/") {
            // 伪代码 L680-L792：根路径按 host/scheme 拼接。
            var components = URLComponents()
            components.scheme = reference.scheme ?? "https"
            components.host = reference.host
            components.path = cleaned
            if let absolute = components.url?.absoluteString {
                logCrossOriginIfNeeded(absolute, reference: base, anchor: 85)
                return absolute
            }
            return cleaned
        }

        // 伪代码 L804-L887：相对路径 URL.init(string:relativeTo:) 解析。
        guard let resolved = URL(string: cleaned, relativeTo: reference) else {
            return cleaned
        }
        let absolute = resolved.absoluteString
        logCrossOriginIfNeeded(absolute, reference: base, anchor: 96)
        return absolute
    }

    /// 伪代码 L728-L773 / L829-L877：解析结果与 baseUrl 不同域时打日志（锚点 85/96）。
    private func logCrossOriginIfNeeded(_ absolute: String, reference: String, anchor: Int) {
        guard absolute != baseUrl, absolute != reference else { return }
        Logger.log(
            "[formatUrl] 解析结果与 baseUrl 不同域: url=\(absolute) baseUrl=\(baseUrl) "
                + "ref=\(reference)",
            level: Self.executeRuleLogLevel,
            anchor: anchor
        )
    }
}
