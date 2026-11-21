// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSRuntime/JSCJSImportBridgeContext.swift
// 证据:
//   - PGO: JSContext.installVoidStringFunction(named:block:) 扩展 (0x10007e330 L5-7)
//   - CovMap: L5-7 @0x10007e330
//   - IDA: 0x10007e330
//   - @convention(block) 桥安装
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

extension JSContext {

    /// 伪代码 0x10007e330（L5-7）：安装无返回值的字符串函数（@convention(block)）。
    func installVoidStringFunction(
        named name: String,
        block: @convention(block) (String) -> Void
    ) {
        setObject(block, forKeyedSubscript: name as NSString)
    }
}
