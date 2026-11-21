// 原路径: ReadMain/Services/ServiceProtocols.swift
// 证据:
//   - PGO: 1 条 pgo_only 记录（index/task_functions.csv T-101-04 /
//     ServiceProtocols.swift）：(extension in Leaflow):SourceServiceProtocol
//     .getBookInfo(source:book:) async -> Book? —— 无独立地址（协议 witness
//     内联到 SourceService.getBookInfo 0x1003c195c L440-474，见 T-401-02 分册）
//   - CovMap: 0 插桩行（协议声明无函数体）
//   - IDA: 无独立伪代码（协议扩展默认实现内联进实现类）
//   - 事实：协议扩展默认实现 getBookInfo —— 由 SourceService.getBookInfo
//     （0x1003c195c，L440-474，"[远程后端] getBookInfo 成功" 诊断串确证）承载；
//     SourceService 及其 +Parsing/+Storage 分册承载其余方法（本协议的完整方法集
//     待 T-401 分册交叉确认后补齐）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（getBookInfo 默认实现归属已交叉定位；其余方法集保守不臆造）
// 还原: 2026-11-19

import Foundation

/// 书源服务协议（本分册仅承载 PGO 确证的方法；完整方法集随 T-401 落地扩充）。
protocol SourceServiceProtocol: AnyObject {
    /// 获取书籍详情（默认实现 = SourceService.getBookInfo 0x1003c195c）。
    func getBookInfo(source: BookSource, book: Book) async -> Book?
}

extension SourceServiceProtocol {

    /// pgo_only 默认实现（签名确证；实现体在 SourceService.getBookInfo
    /// 0x1003c195c L440-474，"[远程后端] getBookInfo 成功" 诊断串确证，
    /// 函数体见 T-401-02 分册；此处默认 nil 兜底）。
    func getBookInfo(source: BookSource, book: Book) async -> Book? {
        nil
    }
}
