// 原路径: ReadMain/Core/ReaderLayoutConfig.swift
// 分册只改变边界，函数、规模、桩仍计入原始文件。
import Foundation
import UIKit
import SwiftUI

/// 阅读器展示项（isDynamic 0x100766880 / getContent 0x1001f12f0 域；块体为
/// 计数器桩/空串默认域确证，档位与文案推断）。
enum ReaderDisplayItem: String, CaseIterable {
    case time
    case battery
    case readingDuration
    case remainingDuration
    case chapterTitle
    case bookName
    case progress

    /// 展示项名称（DisplayItemGrid 域引用；档位文案推断——枚举本体
    /// 计数器桩/空串默认域，真机核清项）。
    var displayName: String {
        switch self {
        case .time: return "时间"
        case .battery: return "电量"
        case .readingDuration: return "阅读时长"
        case .remainingDuration: return "剩余时长"
        case .chapterTitle: return "章节名"
        case .bookName: return "书名"
        case .progress: return "进度"
        }
    }

    /// 伪代码 0x100766880（L285-294）：随时间/状态变化的展示项。
    var isDynamic: Bool {
        switch self {
        case .time, .battery, .readingDuration, .remainingDuration:
            return true
        default:
            return false
        }
    }

    /// 伪代码 0x1001f12f0（L348-423）：按上下文取展示内容（未知项 → 空串）。
    func getContent(context: ReaderDisplayContext) -> String {
        switch self {
        case .time:
            return context.timeText
        case .battery:
            return context.batteryFraction > 0
                ? "\(Int(context.batteryFraction * 100))%" : ""
        case .readingDuration:
            return context.readingDurationMinutes > 0
                ? "\(context.readingDurationMinutes) 分钟" : ""
        case .remainingDuration:
            guard let minutes = context.remainingMinutes, minutes > 0
            else { return "" }
            return "剩 \(minutes) 分钟"
        case .chapterTitle:
            return context.chapterTitle
        case .bookName:
            return context.bookName
        case .progress:
            return context.totalPages > 0
                ? "\(context.currentPageIndex + 1)/\(context.totalPages)" : ""
        }
    }
}

/// 阅读器展示上下文（0x100763d5c varinit 域：PageContentViewController
/// bookName/totalChapters ivar 域 + sub_1001F800C/60 分钟换算确证）。
struct ReaderDisplayContext {
    var bookName: String = ""
    var chapterTitle: String = ""
    var totalChapters: Int = 0
    var currentChapterIndex: Int = 0
    var currentPageIndex: Int = 0
    var totalPages: Int = 0
    var isScrollMode: Bool = false

    /// 伪代码 0x100763d5c（L437）：初始值 = 阅读时长跟踪估算
    ///（sub_1001F800C/60 分钟换算域确证）。
    var readingDurationMinutes: Int =
        Int(ReadingDurationTracker.shared.totalDuration / 60)

    /// 伪代码 0x1001f1068（L449-454）：电量比例（块体与 "HH:mm" 时间格式化
    /// 域 ICF 合并——0x6D6D3A4848 确证）；电量监控未启用 → 0。
    var batteryFraction: Double {
        UIDevice.current.isBatteryMonitoringEnabled
            ? Double(UIDevice.current.batteryLevel) / 100.0 : 0
    }

    /// 时间文案（batteryFraction 块体 "HH:mm" 格式化域对应消费）。
    var timeText: String = ""
    var remainingMinutes: Int?
}
