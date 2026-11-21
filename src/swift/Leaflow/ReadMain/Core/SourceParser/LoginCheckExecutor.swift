// 原路径: ReadMain/Core/SourceParser/LoginCheckExecutor.swift
// 证据:
//   - PGO: _LoginCheckStateBox closures (0x10015b784/0x100153548/0x1001535b4/0x100153608) 等 38 函数
//   - CovMap: L6/L18-19
//   - IDA: 上述地址
//   - 绑定键 result/ruleUrl/initUrl/_nativeGetStrResponse；NSCache setCountLimit:/setTotalCostLimit:；setExceptionHandler:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（键族确证；状态机见读后记仍不清楚 3）
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

/// 登录检查执行器（书源登录 URL 的可达性检查）。
final class LoginCheckExecutor {

    private let analyzer: AnalyzeRule
    private let context: JSContext

    init(analyzer: AnalyzeRule) {
        self.analyzer = analyzer
        self.context = JSContextPool.acquire()
        context.exceptionHandler = { _, exception in
            if let exception {
                Logger.log("[LoginCheck] JS 异常: \(exception)", level: .warning)
            }
        }
        let bridge: [String: Any] = [
            "ruleUrl": analyzer.baseUrl,
            "initUrl": analyzer.baseUrl,
            "_nativeGetStrResponse": { (url: String) -> String in
                let request = SyncHTTPClient.makeRequest(
                    url: URL(string: url) ?? URL(fileURLWithPath: "/"),
                    method: "GET", headers: [:], body: nil,
                    timeout: NetworkConstants.userTimeout
                )
                let responseBody = SyncHTTPClient.execute(request: request, policy: .useCache).body
                return String(data: responseBody, encoding: .utf8) ?? ""
            },
        ]
        for (key, value) in bridge {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
        context.setObject(
            analyzer.getString(rule: "result", isUrl: false) ?? "",
            forKeyedSubscript: "result" as NSString
        )
    }

    /// 登录检查主入口。
    func execute(_ script: String) -> Bool {
        let value = context.evaluateScript(script)
        guard let value, !value.isUndefined, !value.isNull else { return false }
        return value.toBool() ?? false
    }
}

// MARK: - T-1401-13 逐域补齐（TTS 登录校验域）

extension LoginCheckExecutor {

    /// 伪代码 0x10015cce8（L140-421）：TTS 源登录校验——js 长块
    ///（登录规则执行 + 会话校验域）。
    func executeTTS(source: BookSource, rule: String) -> Bool {
        guard !rule.isEmpty else { return true }
        let result = execute(rule)
        Logger.log(
            "[tts-login] result=\(result) source=\(source.bookSourceName)",
            level: .verbose)
        return result
    }

    /// 伪代码 0x100160b88（L427-470）：TTS 登录 URL 动作——loginUrl 规则域。
    /// @MainActor：BackstageWebView.load 域隔离对齐（wave-69）。
    @MainActor
    func executeTTSLoginUrlAction(source: BookSource, loginUrl: String) async -> Bool {
        guard !loginUrl.isEmpty else { return true }
        _ = await BackstageWebView().load(url: loginUrl, timeout: 30)
        Logger.log(
            "[tts-login] url action done source=\(source.bookSourceName)",
            level: .verbose)
        return true
    }
}

