// 原路径: ReadMain/Views/Explore/ExploreView.swift
// 0x1005cc760实际为源筛选谓词（PGO误标loadExploreSources），0x1005cc2cc消费。
// 本地源须有分类/脚本与列表规则，远程摘要可省略规则；禁用源不展示。
import Foundation

enum ExploreSourceAvailability {
    static func isVisible(_ source: BookSource) -> Bool {
        guard source.enabled, source.enabledExplore else { return false }
        if source.storageKind == .remote { return true }
        let rule = source.resolvedExploreUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = rule.lowercased()
        let isCategoryRule = lower.hasPrefix("@js:") || lower.hasPrefix("<js>")
            || rule.contains("::") || rule.hasPrefix("[")
        return isCategoryRule && (!source.ruleExplore.bookList.isEmpty || !source.ruleSearch.bookList.isEmpty)
    }
}
