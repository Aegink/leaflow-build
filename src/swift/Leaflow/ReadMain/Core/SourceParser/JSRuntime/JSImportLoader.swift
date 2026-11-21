// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSRuntime/JSImportLoader.swift
// 证据:
//   - PGO: JSImportLoader.load(_:into:downloadScript:) (0x100056754 L12-47)
//   - CovMap: L12-47 @0x100056754
//   - IDA: 0x100056754
//   - 诊断串：脚本执行错误( / 远程脚本执行错误(
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（加载链确证）
// 还原: 2026-11-19


import Foundation

/// JS import 加载器（`<jslib>` 与本地模块统一入口）。
enum JSImportLoader {

    /// 伪代码 0x100056754（L12-47）：加载脚本到执行上下文。
    /// downloadScript 回调与 AnalyzeUrl.downloadScript 同源（T-203-01 事实 9）。
    static func load(
        _ url: String,
        into target: JSExecutionContext,
        downloadScript: (String) -> String?
    ) {
        guard let script = downloadScript(url) else {
            Logger.log("远程脚本执行错误(" + url + ") 拉取失败", level: 2)
            return
        }
        do {
            _ = try target.evaluate(script, filename: url)
        } catch {
            Logger.log("脚本执行错误(" + url + "): " + String(describing: error), level: 2)
        }
    }
}
