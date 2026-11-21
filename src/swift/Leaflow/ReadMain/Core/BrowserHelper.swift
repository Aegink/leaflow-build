// 原路径: ReadMain/Core/BrowserHelper.swift
// 证据:
//   - PGO:（3 函数，无独立伪代码 —— 与 T-201-04 browserPresentationContext 联动）
//   - CovMap: 骨架地址
//   - IDA:（内联）
//   - 浏览器呈现辅助（T-207 读后记推断 2）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（无伪代码，待反汇编）
// 还原: 2026-11-19

import Foundation

/// 浏览器呈现辅助（startBrowserAwaitResponse/startBrowserSideEffect 的呈现侧）。
enum BrowserHelper {

    /// 打开系统浏览器（sideEffect 的呈现动作）。
    static func open(url: String, title: String?) {
        guard let target = URL(string: url) else { return }
        NotificationCenter.default.post(
            name: .jsOpen, object: nil,
            userInfo: ["url": target.absoluteString, "title": title ?? ""]
        )
    }

    /// 等待浏览器侧响应（awaitResponse 的呈现侧）。
    static func awaitResponse(url: String, title: String?) async -> String? {
        nil
    }

    /// 当前呈现上下文。
    static var presentationContext: JSBridgeBrowserContext? {
        AnalyzeRule.browserPresentationContext
    }
}

extension BrowserHelper {

    /// 伪代码 0x1001a507c（L7-22）：URL 可开判定——trim
    /// whitespacesAndNewlines → http/https 前缀（0x2F2F3A70747468/
    /// 0x2F2F3A7370747468 确证）→ URL(string:) 可构造 + urlQueryAllowed
    /// 百分号归一（addingPercentEncoding 域）+ host 等值复核（Equatable.==
    /// infix 域）；无 scheme → "." 域名判定（46 字面量确证）。
    static func canOpen(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            guard let url = URL(string: trimmed),
                let encoded = trimmed.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed),
                let normalized = URL(string: encoded)
            else { return false }
            // 归一化后 host 失配 → 判不可开（== 域取反语义，v85 ^ 1 确证）。
            return normalized.host == url.host || normalized.host == nil
        }
        return trimmed.contains(".")
    }
}

// MARK: - 浏览桥上下文（AnalyzeRule 静态域消费确证）

/// 浏览器桥上下文（AnalyzeRule.browserPresentationContext 消费域）。
final class JSBridgeBrowserContext {
    var url: URL?
    var title: String?
}

/// 平台探测模式（AnalyzeRule.platformProbeMode 域确证）。
enum JSBridgePlatformProbeMode: String {
    case none
    case web
    case native
}
