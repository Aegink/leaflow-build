// 原路径: ReadMain/Core/AppError.swift
// 证据:
//   - PGO: 4 个主函数（index/task_functions.csv T-101-02 / AppError.swift），
//     地址：badURLMessage(for:) 0x1001701cc L30-41（+0x1003c6990 共体块）/
//     errorDescription.getter 0x100170374 L43-89（+closure #1）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/AppError.c（63 行）
//   - 事实：badURLMessage —— switch URLError.Code 分档（type metadata for
//     URLError.Code/URLError 确证；分档文案未解码，按常用码语义还原）；
//     errorDescription —— LocalizedError 描述串拼接（String.append 确证，
//     0xAE00203A00000000 = 20 字符外部小串参与）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - badURLMessage 分档: medium-high（URLError.Code 判定确证；文案待真机对照）
//   - errorDescription: medium-high（拼接链确证）
// 还原: 2026-11-19

import Foundation

/// 应用错误（LocalizedError）。
enum AppError: LocalizedError {
    /// 网络请求失败（携带 URLError）。
    case network(URLError)
    /// 解析失败。
    case parsing(String)
    /// 内容为空。
    case emptyContent
    /// 通用失败。
    case generic(String)

    /// 伪代码 0x1001701cc（L30-41 + 共体 0x1003c6990）：
    /// switch URLError.Code 分档返回友好文案。
    static func badURLMessage(for error: URLError) -> String {
        switch error.code {
        case .badURL, .unsupportedURL:
            return "链接无效"
        case .timedOut:
            return "连接超时"
        case .cannotConnectToHost, .cannotFindHost:
            return "无法连接服务器"
        case .networkConnectionLost, .notConnectedToInternet:
            return "网络连接不可用"
        case .cancelled:
            return "请求已取消"
        default:
            return "网络请求失败"
        }
    }

    /// 伪代码 0x100170374（L43-89）：LocalizedError 描述。
    var errorDescription: String? {
        switch self {
        case .network(let urlError):
            return Self.badURLMessage(for: urlError)
        case .parsing(let detail):
            return "解析失败：\(detail)"
        case .emptyContent:
            return "内容为空"
        case .generic(let message):
            return message
        }
    }
}
