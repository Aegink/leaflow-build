// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSRuntime/JSRuntimeHost.swift
// 证据:
//   - PGO: SanitizedJSCExecutionContextAdapter.evaluate(_:filename:) (0x10007e3b0 L19-27)
//   - CovMap: L19-27 @0x10007e3b0；另 2 函数无独立伪代码
//   - IDA: 0x10007e3b0
//   - 选择子：exception/isUndefined/isNull/description
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（适配器链确证；另 2 函数见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

/// JS 执行上下文协议（JSRuntime 家族的统一抽象）。
protocol JSExecutionContext {
    func evaluate(_ script: String, filename: String) throws -> JSValue?
    var context: JSContext { get }
}

/// 伪代码 0x10007e3b0（L19-27）：清洗求值适配器。
struct SanitizedJSCExecutionContextAdapter: JSExecutionContext {
    let context: JSContext

    init(context: JSContext) {
        self.context = context
    }

    func evaluate(_ script: String, filename: String) throws -> JSValue? {
        context.setName(filename)
        let value = context.evaluateSanitized(script, convertLegadoTemplates: false)
        if let exception = context.exception {
            throw NSError(
                domain: "JSRuntimeHost", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(describing: exception)]
            )
        }
        return value
    }
}
