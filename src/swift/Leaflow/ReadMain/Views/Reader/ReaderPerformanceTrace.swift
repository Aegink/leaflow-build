// 原路径: ReadMain/Views/Reader/ReaderPerformanceTrace.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-08 / ReaderPerformanceTrace.swift），
//     地址：enabled 开关闭包 0x1007c2d50 L4-10 / now() 0x1001e982c 等（L26-28，多 ICF
//     共体块）/ log(@autoclosure) 0x10070afdc 等（L34-39，多 ICF 共体块）；
//     骨架补充：beginOperation/beginPage/PageSample/OperationSample/pageLabel/ms/
//     recordSVGCache/ReaderFrameTimingStats.record
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderPerformanceTrace.c（3943 行）
//   - 事实：enabled 为静态开关（UserDefaults/FeatureFlag 判定，闭包确证）；
//     now() → CACurrentMediaTime 语义；log(@autoclosure String) 仅在 enabled 时求值；
//     log 块大量 ICF 共体（全文件 30+ 块共享同一体），"=" 分隔字面量确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - enabled/now/log: high（共体模式确证）
//   - beginPage/PageSample: medium-high（PageContentViews 调用方证据回溯确证）
// 还原: 2026-11-19

import UIKit

/// 性能埋点（枚举命名空间；enabled 短路全部开销）。
enum ReaderPerformanceTrace {

    /// 伪代码 0x1007c2d50（L4-10）：静态开关（一次性初始化闭包确证）。
    static let enabled: Bool = {
        UserDefaults.standard.bool(forKey: "readerPerformanceTraceEnabled")
    }()

    /// 伪代码 0x1001e982c（L26-28）：当前时间（多 ICF 共体块确证）。
    static func now() -> Double {
        CACurrentMediaTime()
    }

    /// 伪代码 0x10070afdc（L34-39）：条件日志（autoclosure 确证）。
    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        Logger.log(message(), level: 7)
    }

    /// 条件日志（trace 闭包变体，PageContentViews viewDidLoad 调用方确证）。
    static func log(_ label: String, body: () throws -> Bool) rethrows {
        guard enabled else { return }
        _ = try body()
        Logger.log(label, level: 7)
    }

    /// 毫秒格式（骨架签名 ms(_)）。
    static func ms(_ duration: Double) -> String {
        String(format: "%.2fms", duration * 1000)
    }

    /// 页标签（骨架签名 pageLabel(_)；PageBackViewController/Pool 调用方确证）。
    static func pageLabel(_ label: String) -> String {
        label
    }

    /// 页级埋点（beginPage(_:reason:role:)，PageContentViews/Pool 调用方确证）。
    static func beginPage(_ page: PageData?, reason: String, role: PageRole) {
        guard enabled else { return }
        Logger.log("page \(page?.layoutId ?? "-") reason=\(reason) role=\(role.rawValue)", level: 7)
    }

    enum PageRole: String {
        case content
        case backdrop
        case spread
    }

    /// 操作级样本（OperationSample.mark(reason:)，PageContentViews 调用方确证）。
    struct OperationSample {
        let startedAt: Double
        let operation: String

        init(mark reason: String) {
            self.operation = reason
            self.startedAt = now()
            log("begin \(reason)")
        }

        func finish() {
            log("end \(operation) \(ms(now() - startedAt))")
        }

        /// 伪代码 0x1007c2124（L76-80）：标记事件——enabled 位早退域 +
        /// 104 字节 PageSample 槽 + OperationSample.init(event:page:detail:)
        /// 域 + 全局样本表 append（qword_1016B5B78 域确证）。
        func mark(_ detail: String) {
            guard enabled else { return }
            log("mark \(operation) \(detail)")
        }
    }

    /// 页样本（PageSample(page:reason:role:previous:)，updateContent 调用方确证）。
    struct PageSample {
        let page: PageData
        let reason: String
        let role: PageRole
        let previous: PageSample?

        init(page: PageData, reason: String, role: PageRole, previous: PageSample?) {
            self.page = page
            self.reason = reason
            self.role = role
            self.previous = previous
        }

        func record() {
            log("sample page=\(page.layoutId) reason=\(reason) role=\(role.rawValue)")
        }

        /// 伪代码 0x1007c22dc（L113-117）：页样本标记（计数器桩域，
        /// 按签名语义还原）。
        func mark(_ detail: String) {
            guard enabled else { return }
            log("mark page=\(page.layoutId) \(detail)")
        }
    }

    /// SVG 缓存事件（骨架签名 recordSVGCache(_)）。
    static func recordSVGCache(_ event: SVGCacheEvent) {
        guard enabled else { return }
        Logger.log("svg \(event)", level: 7)
    }

    enum SVGCacheEvent: String {
        case hit
        case miss
        case evict
    }
}

/// 帧时间统计（骨架签名 ReaderFrameTimingStats.record(time:)）。
struct ReaderFrameTimingStats {
    private(set) var lastCallbackTime: Double = 0
    private var samples: [Double] = []

    mutating func record(time: Double) {
        lastCallbackTime = time
        samples.append(time)
        if samples.count > 120 {
            samples.removeFirst()
        }
    }

    var averageFrameTime: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }
}

/// 翻页性能轨迹（start 0x1007c206c L225-228 域确证）。
enum ReaderTurnPerformanceTrace {

    /// 伪代码 0x1007c206c（L225-228）：轨迹开启（计数器桩域；enabled 门控）。
    static func start(reason: String) {
        guard ReaderPerformanceTrace.enabled else { return }
        ReaderPerformanceTrace.log("turn start reason=\(reason)")
    }
}

