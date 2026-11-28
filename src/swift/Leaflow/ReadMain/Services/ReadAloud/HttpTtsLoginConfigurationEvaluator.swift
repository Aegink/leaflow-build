// 原路径: ReadMain/Services/ReadAloud/HttpTtsLoginConfigurationEvaluator.swift
// 证据:
//   - PGO: 24 条记录（index/task_functions.csv T-801-06 /
//     HttpTtsLoginConfigurationEvaluator.swift；伪代码域 200 行）
//   - CovMap: 上述 L 区段（configuredAnalyzer/temporaryBookSource/
//     evaluate/prepareDefaultsIfNeeded 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsLoginConfigurationEvaluator.c（763 行）
//   - 块体确证（签名域）：
//     configuredAnalyzer(for: HttpTts) / temporaryBookSource(for:
//     HttpTts) / evaluate(_: String, source: HttpTts) throws /
//     prepareDefaultsIfNeeded(for: HttpTts, store:
//     HttpTtsRuntimeStore) throws
//   - 事实：登录 UI 配置串（loginUi JSON）分析桥（临时 BookSource
//     走 AnalyzeRule 域）+ 默认值预置域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（四签名域确证）
// 还原: 2026-11-20

import Foundation
import JavaScriptCore

/// 朗读源登录配置分析器（evaluate/configuredAnalyzer 签名域确证）。
struct HttpTtsLoginConfigurationEvaluator {

    private let store: HttpTtsRuntimeStore

    init(store: HttpTtsRuntimeStore = .shared) {
        self.store = store
    }

    /// configuredAnalyzer(for: HttpTts)（签名域确证：临时书源 +
    /// AnalyzeRule 分析桥，AnalyzeRule(source:parent:) 域）。
    private func configuredAnalyzer(for source: HttpTts)
        throws -> AnalyzeRule {
        let temporary = try temporaryBookSource(for: source)
        let analyzer = AnalyzeRule(source: temporary, parent: nil, isolatedJavaScript: true)
        JsBridgeTemplates.registerHttpTtsSourceBridge(in: analyzer.jsContextHandle(), source: source, runtimeStore: store)
        return analyzer
    }

    /// temporaryBookSource(for: HttpTts)（签名域确证：loginUi JSON →
    /// 临时 BookSource 壳）。
    private func temporaryBookSource(for source: HttpTts) throws
        -> BookSource {
        var bookSource = BookSource()
        bookSource.bookSourceUrl = "tts://\(source.id)"
        bookSource.bookSourceName = source.name
        if let loginUrl = source.loginUrl, !loginUrl.isEmpty {
            bookSource.loginUrl = loginUrl
        }
        if let header = source.header, !header.isEmpty {
            bookSource.header = header
        }
        return bookSource
    }

    /// evaluate(_: String, source: HttpTts)（签名域确证：配置串求值）。
    func evaluate(_ expression: String, source: HttpTts) throws
        -> String? {
        let raw = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let isScript = raw.hasPrefix("@js:") || (raw.hasPrefix("<js>") && raw.hasSuffix("</js>"))
        if !isScript {
            if let data = raw.data(using: .utf8),
               let value = try? JSONSerialization.jsonObject(with: data),
               let json = LegadoJSONLiteral.jsonString(from: value) { return json }
            // 0x10026779c显式拒绝顶层数组尾逗号，不沿用通用解析器的自动修复。
            guard !LegadoJSONLiteral.hasTopLevelArrayTrailingComma(raw),
                  let value = LegadoJSONLiteral.parse(raw), let json = LegadoJSONLiteral.jsonString(from: value) else {
                throw AppError.parsing("朗读配置不是有效JSON")
            }
            return json
        }
        let analyzer = try configuredAnalyzer(for: source)
        defer { analyzer.releaseOwnedJSContext() }
        let context = analyzer.jsContextHandle()
        context.exceptionHandler = { _, _ in }
        if let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
            guard context.exception == nil else { throw AppError.parsing("朗读配置脚本库执行失败") }
        }
        let result = context.evaluateScript(AnalyzeUrl.processJsPrefix(raw))
        guard context.exception == nil, let result, !result.isUndefined, !result.isNull,
              let output = result.toString(), !output.isEmpty, output != "undefined" else {
            throw AppError.parsing("朗读配置脚本未返回有效内容")
        }
        return output
    }

    /// prepareDefaultsIfNeeded(for:store:)（签名域确证：默认键预置）。
    func prepareDefaultsIfNeeded(
        for source: HttpTts, store: HttpTtsRuntimeStore
    ) throws {
        guard store.loginInfo(sourceID: source.id) == nil,
              let loginUi = source.loginUi, !loginUi.isEmpty else { return }
        let evaluator = HttpTtsLoginConfigurationEvaluator(store: store)
        guard let json = try evaluator.evaluate(loginUi, source: source),
              let rows = LegadoJSONLiteral.parse(json) as? [[String: Any]] else { return }
        var values: [String: String] = [:]
        for row in rows {
            let name = LegadoJSONLiteral.stringValue(row["name"]) ?? ""
            let type = LegadoJSONLiteral.stringValue(row["type"]) ?? "text"
            guard !name.isEmpty, type != "button" else { continue }
            values[name] = LegadoJSONLiteral.stringValue(row["default"]) ?? ""
        }
        if !values.isEmpty { store.setLoginInfoMap(values, sourceID: source.id) }
    }
}
