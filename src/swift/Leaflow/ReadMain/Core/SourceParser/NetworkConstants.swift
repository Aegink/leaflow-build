// 原路径: ReadMain/Core/SourceParser/NetworkConstants.swift
// 证据:
//   - PGO: defaultUserAgent (0x100162480 L11-14) / fullUserAgent (0x100162358 L17-20) / userTimeout (0x100162340 L25-28) / batchSessionRequestTimeout (0x100b78a5c L43) 等 7 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - standardUserDefaults/doubleForKey: 覆盖；日志源 BatchTestView/SourceFullTestView
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high
// 还原: 2026-11-19


import Foundation

/// 网络常量（事实 1）。
enum NetworkConstants {

    /// 伪代码 0x100162480（L11-14）。
    static var defaultUserAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
    }

    /// 伪代码 0x100162358（L17-20）。
    static var fullUserAgent: String {
        UserDefaults.standard.string(forKey: "userAgent") ?? defaultUserAgent
    }

    /// 伪代码 0x100162340（L25-28）：UserDefaults 可覆盖。
    static var userTimeout: Double {
        UserDefaults.standard.double(forKey: "userTimeout").nonZero ?? 60.0
    }

    /// 伪代码 0x100b78a5c（L43）。
    static var batchSessionRequestTimeout: Double {
        UserDefaults.standard.double(forKey: "batchSessionRequestTimeout").nonZero ?? 30.0
    }

    /// 同步拉取（T-203-01 downloadScript 的回调）。
    static func fetchSync(_ url: String) -> String? {
        guard let target = URL(string: url),
            let data = try? Data(contentsOf: target),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }
}

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}

extension NetworkConstants {

    /// 伪代码 0x100096e30（L46）：批量会话资源超时（批次请求域的
    /// resourceTimeout 档；推断 60s）。
    static var batchSessionResourceTimeout: Double {
        60.0
    }
}

