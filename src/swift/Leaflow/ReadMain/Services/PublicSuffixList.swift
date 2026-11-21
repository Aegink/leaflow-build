// 原路径: ReadMain/Services/PublicSuffixList.swift
// 证据:
//   - PGO: 8 个主函数（index/task_functions.csv T-401-01 / PublicSuffixList.swift），
//     地址：normalizedRegistrableDomain 0x100365f2c L47-69（lowercased 确证）/
//     canonicalHost 0x1003662f4 L71-96（URL.host 确证）/ Rules.publicSuffixLabelCount
//     0x10036681c L10-40 / loadRules 0x100366f80 L98-121（lowercased + URL.host
//     共体确证）/ isIPAddress 0x1003673e4 L162-170 / bundledListText 0x1003677ec
//     L123-138
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/PublicSuffixList.c
//   - 事实：PSL 域名规整（lowercased 确证）+ 资源文件加载（public_suffix_list.dat
//     为 IPA 原件，resources/app/ 落盘确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（规整/加载链确证；PSL 算法按 RFC 实现还原）
// 还原: 2026-11-19

import Foundation

/// 公共后缀列表（Mozilla PSL 规则 + bundled .dat）。
enum PublicSuffixList {

    /// 规则集（ Rules 域确证）。
    struct Rules {
        var wildcardSuffixes: Set<String> = []
        var exceptionSuffixes: Set<String> = []
        var allSuffixes: Set<String> = []

        /// 伪代码 0x10036681c（L10-40）：后缀标签数
        ///（例外 > 通配 > 精确三档确证）。
        func publicSuffixLabelCount(for labels: [String]) -> Int {
            let reversed = labels.reversed()
            for (index, label) in reversed.enumerated() {
                let candidate = (0...index).reversed()
                    .map { labels[labels.count - 1 - $0] }
                    .joined(separator: ".")
                if exceptionSuffixes.contains(candidate) {
                    return index
                }
                if wildcardSuffixes.contains("*." + label) {
                    return index + 1
                }
                if allSuffixes.contains(candidate) {
                    return index + 1
                }
            }
            return 1
        }
    }

    /// 伪代码 0x100366f80（L98-121）：bundled .dat 加载
    ///（lowercased 确证；resources/app/public_suffix_list.dat 原件消费）。
    private static func loadRules() -> Rules {
        var rules = Rules()
        guard let url = Bundle.main.url(
            forResource: "public_suffix_list", withExtension: "dat"),
            let text = try? String(contentsOf: url, encoding: .utf8) else {
            return rules
        }
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("//") else { continue }
            let normalized = trimmed.lowercased()
            if normalized.hasPrefix("!") {
                rules.exceptionSuffixes.insert(String(normalized.dropFirst()))
            } else if normalized.hasPrefix("*.") {
                rules.wildcardSuffixes.insert(normalized)
            } else {
                rules.allSuffixes.insert(normalized)
            }
        }
        return rules
    }

    private static let cachedRules: Rules = loadRules()

    /// 伪代码 0x100365f2c（L47-69）：可注册域（lowercased 确证）。
    static func normalizedRegistrableDomain(_ host: String) -> String {
        let canonical = canonicalHost(host)
        guard !isIPAddress(canonical) else { return canonical }
        let labels = canonical.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return canonical }
        let suffixCount = cachedRules.publicSuffixLabelCount(for: labels)
        let startIndex = max(0, labels.count - suffixCount - 1)
        return labels[startIndex...].joined(separator: ".")
    }

    /// 伪代码 0x1003662f4（L71-96）：host 归一（URL.host + lowercased 确证）。
    static func canonicalHost(_ host: String) -> String {
        var normalized = host.lowercased()
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        return normalized
    }

    /// 伪代码 0x1003673e4（L162-170）：IP 判定。
    static func isIPAddress(_ host: String) -> Bool {
        var probe = host
        if probe.hasPrefix("["), probe.hasSuffix("]") {
            probe = String(probe.dropFirst().dropLast())
        }
        return IPAddressDetector.isIPv4(probe) || IPAddressDetector.isIPv6(probe)
    }

    /// 伪代码 0x1003677ec（L123-138）：bundled 文本。
    static func bundledListText() -> String {
        guard let url = Bundle.main.url(
            forResource: "public_suffix_list", withExtension: "dat"),
            let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }
}

/// IP 探测（isIPAddress 域）。
enum IPAddressDetector {
    static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let number = UInt8(part) else { return false }
            return part.count <= 3 && !(part.count > 1 && part.hasPrefix("0"))
        }
    }

    static func isIPv6(_ value: String) -> Bool {
        value.contains(":")
    }
}
