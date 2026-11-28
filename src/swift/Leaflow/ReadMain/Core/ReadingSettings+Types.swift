// 原路径: ReadMain/Core/ReadingSettings.swift
// 分册只改变边界，函数、规模与桩仍计入原始文件。
import SwiftUI
import UIKit

// MARK: - 搜索模式

/// 搜索模式（伪代码 0x1002125f0，L10-24）。
enum SearchMode: String, CaseIterable, Codable {
    case all = "all"
    case titleOnly = "titleOnly"

    var label: String {
        self == .all ? "全文搜索" : "仅标题"
    }

    var description: String {
        self == .all ? "搜索书名、作者和正文" : "仅搜索书名和作者"
    }
}

/// 发现页排序模式（伪代码 0x100212818，L33-47）。
enum ExploreSectionRankingMode: String, CaseIterable, Codable {
    case defaultOrder = "default"
    case updatedFirst = "updated"

    var label: String {
        self == .defaultOrder ? "默认排序" : "最近更新"
    }

    var description: String {
        self == .defaultOrder ? "按书源原始顺序" : "按最近更新时间排序"
    }
}

/// 发现页缓存 TTL（伪代码 0x100212abc，L60-83）。
enum ExploreCacheTTLOption: String, CaseIterable, Codable {
    case fiveMinutes = "300"
    case thirtyMinutes = "1800"
    case oneHour = "3600"
    case sixHours = "21600"
    case oneDay = "86400"

    var label: String {
        switch self {
        case .fiveMinutes: return "5 分钟"
        case .thirtyMinutes: return "30 分钟"
        case .oneHour: return "1 小时"
        case .sixHours: return "6 小时"
        case .oneDay: return "1 天"
        }
    }

    /// 伪代码 0x100212c40（L73-83）。
    var seconds: Double {
        Double(rawValue) ?? 300.0
    }
}

/// 底部工具栏样式（伪代码 0x100213094，L90）。
enum ReaderBottomToolbarStyle: String, CaseIterable, Codable {
    case minimal = "classic"
    case full = "chatInput"

    var id: String { rawValue }
}

/// 屏幕常亮选项（伪代码 0x1002130c0，L120-140）。
enum ScreenAwakeOption: String, CaseIterable, Codable {
    case system = "system"
    case fiveMinutes
    case tenMinutes
    case thirtyMinutes
    case never

    var id: String { rawValue }

    /// 伪代码 0x10021316c（L122-130）。
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .fiveMinutes: return "5分钟"
        case .tenMinutes: return "10分钟"
        case .thirtyMinutes: return "30分钟"
        case .never: return "始终常亮"
        }
    }

    /// 伪代码 0x100213258（L132-140）。
    var duration: Duration? {
        switch self {
        case .fiveMinutes: return .seconds(300)
        case .tenMinutes: return .seconds(600)
        case .thirtyMinutes: return .seconds(1800)
        case .system, .never: return nil
        }
    }
}



// MARK: - 章节标题预设


extension ReadingSettings {

    /// 双页模式（loadDoublePageMode 0x10021f85c 返回类型确证；档位推断）。
    enum DoublePageMode: String, Codable, CaseIterable {
        case off
        case auto
        case always
    }
}

extension ReadingSettings {

    /// 章节标题预设（ChapterTitleSettingsView 消费域 + init(from:) 域还原；
    /// 原桥扩展自 Views/Reader/ChapterTitleSettingsView.swift 迁回本文件）。
    struct ChapterTitlePreset: Codable, Identifiable, Equatable {
        var id: UUID
        var name: String
        var template: String
        var darkTemplate: String?
        var height: CGFloat
        var useCustomFont: Bool
        var lightConfig: ChapterTitleConfig?
        var darkConfig: ChapterTitleConfig?

        init(
            id: UUID, name: String, template: String, darkTemplate: String?,
            height: CGFloat, useCustomFont: Bool,
            lightConfig: ChapterTitleConfig?, darkConfig: ChapterTitleConfig?
        ) {
            self.id = id
            self.name = name
            self.template = template
            self.darkTemplate = darkTemplate
            self.height = height
            self.useCustomFont = useCustomFont
            self.lightConfig = lightConfig
            self.darkConfig = darkConfig
        }

        /// 伪代码 0x10021929c（L871-885）：UUID id 解码失败 → 新建 UUID；
        /// name/template decode，darkTemplate decodeIfPresent；height 缺省
        /// 120.0（0x405E000000000000 确证）；useCustomFont 缺省 false；
        /// 亮/暗档 decodeIfPresent 缺省回退（块尾 v86 拷贝域）。
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
            name = try container.decode(String.self, forKey: .name)
            template = try container.decode(String.self, forKey: .template)
            darkTemplate = try container.decodeIfPresent(
                String.self, forKey: .darkTemplate)
            height = try container.decodeIfPresent(
                CGFloat.self, forKey: .height) ?? 120.0
            useCustomFont = try container.decodeIfPresent(
                Bool.self, forKey: .useCustomFont) ?? false
            lightConfig = try container.decodeIfPresent(
                ChapterTitleConfig.self, forKey: .lightConfig)
            darkConfig = try container.decodeIfPresent(
                ChapterTitleConfig.self, forKey: .darkConfig)
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case template
            case darkTemplate
            case height
            case useCustomFont
            case lightConfig
            case darkConfig
        }

        /// 内置预设（builtin 判定域确证；集合内容待真机对照）。
        static let builtIns: [ChapterTitlePreset] = [
            ChapterTitlePreset(
                id: UUID(), name: "经典", template: "<div>{{chapterNumber}} {{chapterName}}</div>",
                darkTemplate: nil, height: 120, useCustomFont: false,
                lightConfig: nil, darkConfig: nil),
            ChapterTitlePreset(
                id: UUID(), name: "居中", template: "<div class='center'>{{chapterName}}</div>",
                darkTemplate: nil, height: 120, useCustomFont: false,
                lightConfig: nil, darkConfig: nil),
        ]
    }
}

// MARK: - Color hex 桥

extension Color {

    /// 伪代码 0x100211b5c（L1815-1837）：hex 解析（trim 非字母数字 +
    /// NSScanner scanHexLongLong 确证；8/6/3 位域；3 位短格式 ×17 展开；
    /// 非法回退近黑 1/255）。原桥 leaflowColor 依赖本初始化器。
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        switch cleaned.count {
        case 8:  // AARRGGBB（BYTE2 域确证：取 16-23 位红通道，透明度舍弃）
            red = CGFloat((value >> 16) & 0xFF) / 255.0
            green = CGFloat((value >> 8) & 0xFF) / 255.0
            blue = CGFloat(value & 0xFF) / 255.0
        case 6:
            red = CGFloat((value >> 16) & 0xFF) / 255.0
            green = CGFloat((value >> 8) & 0xFF) / 255.0
            blue = CGFloat(value & 0xFF) / 255.0
        case 3:
            red = CGFloat((value >> 8) & 0xF) * 17.0 / 255.0
            green = CGFloat((value >> 4) & 0xF) * 17.0 / 255.0
            blue = CGFloat(value & 0xF) * 17.0 / 255.0
        default:
            red = 1.0 / 255.0
            green = 1.0 / 255.0
            blue = 1.0 / 255.0
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// 伪代码 0x100212000（L1839-1847）：UIColor 桥 → CGColor RGBA 分量 →
    /// "#RRGGBB"（块体与 preferredReaderSystemUIFont 域交错，按语义还原）。
    func toHex() -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }
}

extension ReadingSettings {

    /// 页面模式（PageViewController 路由域 + ReaderViewModifiers `.horizontal`
    /// 域确证；档位推断）。
    enum PageMode: String, Codable {
        case horizontal = "slide"
        case curl = "pageCurl"
        case scroll = "verticalScroll"
    }

    /// 段评浮层呈现（ReaderSettingsComponents tag 域确证：modal/inline）。
    enum ParagraphCommentBrowserPresentation: String, Codable {
        case modal
        case inline
    }
}
