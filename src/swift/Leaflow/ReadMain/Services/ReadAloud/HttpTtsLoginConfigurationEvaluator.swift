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
        return AnalyzeRule(source: temporary, parent: nil)
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
        let analyzer = try configuredAnalyzer(for: source)
        // 已登录信息域（loginInfo 域桥）。
        if let loginInfo = store.loginInfo(sourceID: source.id) {
            analyzer.putVariable("loginInfo", value: loginInfo)
        }
        if let header = store.loginHeader(sourceID: source.id) {
            analyzer.putVariable("header", value: header)
        }
        for (key, value) in store.loginInfoMap(sourceID: source.id) {
            analyzer.putVariable(key, value: value)
        }
        if let variable = store.sourceVariable(sourceID: source.id) {
            analyzer.putVariable("sourceVariable", value: variable)
        }
        return analyzer.getString(rule: expression, isUrl: false)
    }

    /// prepareDefaultsIfNeeded(for:store:)（签名域确证：默认键预置）。
    func prepareDefaultsIfNeeded(
        for source: HttpTts, store: HttpTtsRuntimeStore
    ) throws {
        if store.loginInfo(sourceID: source.id) == nil,
           let loginUi = source.loginUi, !loginUi.isEmpty {
            store.setLoginInfoMap([:], sourceID: source.id)
        }
        if store.loginHeader(sourceID: source.id) == nil,
           let header = source.header, !header.isEmpty {
            store.setLoginHeader(header, sourceID: source.id)
        }
    }
}
