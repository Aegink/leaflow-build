// 原路径: ReadMain/Views/Reader/ReaderWidgetRefreshDriver.swift
// 证据:
//   - PGO: 22 个主函数（index/task_functions.csv T-301-11 / ReaderWidgetRefreshDriver.swift），
//     地址：ReaderWidgetRefreshEvent.includes 0x1007667f8 L6-12 /
//     ReaderWidgetRefreshCadence.< 0x1001e35dc L18 / nextFireDate 0x1008b07b4 L20-28 /
//     tolerance 0x1008b094c L30-36 / ReaderWidgetDisplayItem.isBatteryDriven 0x1007667d0
//     L40-45 / LayoutWidget.refreshCadence 0x100766500+0x1008b0030 L49-57 /
//     dateCadence(for:) 0x1008b09d0 L59-72 / observesBattery 初始化 0x1008b0df0 L85 /
//     setVisible 0x1008affb0 L112-117 / synchronizeSubscriptions 0x1008b0e6c L119-153
//     （+closure #1/#3/#4 0x1008b13b4/0x1008b173c/0x1008b1790）/ observe(_:handler:)
//     / scheduleClock / configure(widgets:isFirstPage:enabled:) / deinit 闭包
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderWidgetRefreshDriver.c（1250 行）
//   - 关键选择子：removeObserver:/invalidate（synchronizeSubscriptions 确证）
//   - 事实：事件按 widget 刷新域过滤（includes）；节流档位（< 比较 + nextFireDate +
//     tolerance）；LayoutWidget.refreshCadence 经 dateCadence(for:) 推导；
//     驱动观察 NotificationCenter + 时钟 Timer（scheduleClock）；visible 开关 +
//     订阅同步
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 事件/节流/订阅同步: high（签名+选择子确证）
//   - 节流档位常量: medium（待真机对照）
// 还原: 2026-11-19

import Foundation
import UIKit

/// widget 刷新事件。
struct ReaderWidgetRefreshEvent: Equatable {
    enum Kind: String {
        case layout
        case content
        case refreshAll
        case clock
        case battery
    }

    let kind: Kind
    let at: Date

    init(_ kind: Kind) {
        self.kind = kind
        self.at = Date()
    }

    /// 伪代码 0x1007667f8（L6-12）：事件是否命中 widget 刷新域。
    func includes(_ widget: LayoutWidget) -> Bool {
        switch kind {
        case .refreshAll, .content:
            return true
        case .layout:
            return widget.showOnFirstPage
        case .clock, .battery:
            return widget.refreshCadence != nil
        }
    }
}

/// 刷新节流档位。
enum ReaderWidgetRefreshCadence: Comparable {
    case perMinute
    case perFiveMinutes
    case perQuarterHour
    case perHour
    case daily

    /// 伪代码 0x1001e35dc（L18）：档位比较。
    static func < (lhs: ReaderWidgetRefreshCadence, rhs: ReaderWidgetRefreshCadence) -> Bool {
        lhs.interval < rhs.interval
    }

    private var interval: TimeInterval {
        switch self {
        case .perMinute: return 60
        case .perFiveMinutes: return 300
        case .perQuarterHour: return 900
        case .perHour: return 3600
        case .daily: return 86400
        }
    }

    /// 伪代码 0x1008b07b4（L20-28）：下次触发时间。
    func nextFireDate(after date: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .second, value: Int(interval), to: date)
    }

    /// 伪代码 0x1008b094c（L30-36）：容差。
    var tolerance: Double {
        interval * 0.1
    }
}

/// 显示条目（电池驱动判定确证）。
enum ReaderWidgetDisplayItem {
    /// 伪代码 0x1007667d0（L40-45）。
    static var isBatteryDriven: Bool {
        true
    }

    /// 日期格式器（PageContentViews+Widgets 调用方确证）。
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// 展示文本（占位；具体条目待真机对照）。
    static func displayText(for widget: LayoutWidget, context: ReaderWidgetDisplayContext, isFirstPage: Bool) -> String {
        _ = (widget, context, isFirstPage)
        return ""
    }
}

extension LayoutWidget {
    /// 伪代码 0x1008b0030（L49-57）：刷新节流推导。
    var refreshCadence: ReaderWidgetRefreshCadence? {
        Self.dateCadence(for: type)
    }

    /// 伪代码 0x1008b09d0（L59-72）：按类型推导节流档位。
    static func dateCadence(for type: String) -> ReaderWidgetRefreshCadence? {
        switch type.lowercased() {
        case "clock", "time":
            return .perMinute
        case "battery":
            return .perFiveMinutes
        case "chapter", "progress":
            return nil
        default:
            return nil
        }
    }
}

/// widget 刷新显示上下文。
struct ReaderWidgetDisplayContext {
    let page: PageData
    let bookName: String
    let totalChapters: Int
}

/// widget 刷新驱动（观察 + 时钟 + 可见开关）。
@MainActor
final class ReaderWidgetRefreshDriver {
    private let notificationCenter: NotificationCenter
    private let now: () -> Date
    private let applicationIsActive: () -> Bool
    private let refresh: (ReaderWidgetRefreshEvent) -> Void
    private(set) var observesBattery: Bool = false
    private(set) var isVisible = false
    private var observers: [NSObjectProtocol] = []
    private var clockTimer: Timer?

    /// init（PageContentViews 调用方 + PGO 默认参数确证）。
    init(
        notifications: NotificationCenter,
        now: @escaping () -> Date,
        applicationIsActive: @escaping () -> Bool,
        refresh: @escaping (ReaderWidgetRefreshEvent) -> Void
    ) {
        self.notificationCenter = notifications
        self.now = now
        self.applicationIsActive = applicationIsActive
        self.refresh = refresh
    }

    /// 伪代码 0x1008affb0（L112-117）：可见开关。
    func setVisible(_ visible: Bool) {
        isVisible = visible
        synchronizeSubscriptions()
    }

    /// 伪代码 0x1008b0e6c（L119-153）+ closure #1/#3/#4：
    /// 订阅同步（removeObserver/invalidate 确证）。
    private func synchronizeSubscriptions() {
        if !isVisible {
            for observer in observers {
                notificationCenter.removeObserver(observer)
            }
            observers.removeAll()
            clockTimer?.invalidate()
            clockTimer = nil
            return
        }
        if observers.isEmpty {
            let batteryObserver = notificationCenter.addObserver(
                forName: UIDevice.batteryLevelDidChangeNotification,
                object: nil,
                queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.observesBattery else { return }
                    self.refresh(ReaderWidgetRefreshEvent(.battery))
                }
            }
            observers.append(batteryObserver)
        }
        scheduleClock()
    }

    /// 观察指定通知（骨架签名 observe(_:handler:)）。
    func observe(
        _ name: Notification.Name,
        handler: @escaping (ReaderWidgetRefreshDriver) -> Void
    ) {
        let observer = notificationCenter.addObserver(
            forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        observers.append(observer)
    }

    /// 时钟调度（骨架签名 scheduleClock；closure @Sendable (NSTimer) 确证）。
    private func scheduleClock() {
        guard clockTimer == nil else { return }
        clockTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, self.applicationIsActive() else { return }
                self.refresh(ReaderWidgetRefreshEvent(.clock))
            }
        }
        RunLoop.main.add(clockTimer!, forMode: .common)
    }

    /// widget 配置（骨架签名 configure(widgets:isFirstPage:enabled:)）。
    func configure(widgets: [LayoutWidget], isFirstPage: Bool, enabled: Bool) {
        observesBattery = widgets.contains { $0.type.lowercased().contains("battery") }
        if enabled {
            synchronizeSubscriptions()
        }
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }
}

/// widget 符号渲染状态（renderedWidgetSymbols 值域确证）。
struct ReaderWidgetSymbolState: Equatable {
    var symbolName: String
    var variableValue: Double?
}
