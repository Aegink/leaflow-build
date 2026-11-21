// 原路径: ReadMain/Core/ReaderTheme.swift
// 证据:
//   - PGO: ReaderTheme.init(id:name:textColorHex:...) (0x100212150 L95-103) / init(from: Decoder) (0x100200de8 L105-144) /
//     encode(to: Encoder) (0x1002019b8 L146-184) / == infix (0x100202224 L186-224) /
//     backgroundColor.getter (0x10020748c L227) / builtIn (0x1002041a4 L230-258) /
//     ThemeManager.currentThemeId / ThemeManager.saveCustomThemes (0x10020476c L350-355)
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址的 Hex-Rays 伪代码（10060 行，44 函数）
//   - 诊断串：[ReaderTheme] apply skip source=/reader_preset_import_/reader_preset_export_/
//     缺少背景资源：/e skipped autoDark=0 source=
//   - 选择子：dataForKey:/objectForKey:/boolForKey:/standardUserDefaults/
//     sharedApplication/connectedScenes/activationState/removeItemAtURL:error:/
//     copyItemAtURL:toURL:error:/fileExistsAtPath:/temporaryDirectory
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - ReaderTheme 模型: high（Codable init/encode/== 确证）
//   - ThemeManager: medium-high（currentThemeId/saveCustomThemes/导入导出确证）
//   - 预设导入导出（temporaryDirectory + reader_preset_ 前缀）：medium-high
// 还原: 2026-11-19

import SwiftUI
import UIKit

// MARK: - 阅读器主题

/// 阅读器主题（Codable 模型）。
struct ReaderTheme: Codable, Equatable, Identifiable {

    var id: String
    var name: String
    var textColorHex: String
    var backgroundColorHex: String
    var useDarkBackground: Bool
    var isCustom: Bool

    /// 伪代码 0x100212150（L95-103）：memberwise init。
    init(
        id: String, name: String, textColorHex: String,
        backgroundColorHex: String, useDarkBackground: Bool, isCustom: Bool
    ) {
        self.id = id
        self.name = name
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.useDarkBackground = useDarkBackground
        self.isCustom = isCustom
    }

    /// 伪代码 0x100200de8（L105-144）：Codable decode。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        textColorHex = try container.decode(String.self, forKey: .textColorHex)
        backgroundColorHex = try container.decode(String.self, forKey: .backgroundColorHex)
        useDarkBackground = try container.decode(Bool.self, forKey: .useDarkBackground)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
    }

    /// 伪代码 0x1002019b8（L146-184）。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(textColorHex, forKey: .textColorHex)
        try container.encode(backgroundColorHex, forKey: .backgroundColorHex)
        try container.encode(useDarkBackground, forKey: .useDarkBackground)
        try container.encode(isCustom, forKey: .isCustom)
    }

    /// 伪代码 0x100202224（L186-224）。
    static func == (lhs: ReaderTheme, rhs: ReaderTheme) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case textColorHex = "textColor"
        case backgroundColorHex = "backgroundColor"
        case useDarkBackground = "dark"
        case isCustom = "custom"
    }

    /// 伪代码 0x10020748c（L227）：背景色。
    var backgroundColor: Color {
        Color(hex: backgroundColorHex) ?? .white
    }

    /// 前景色。
    var foregroundColor: Color {
        Color(hex: textColorHex) ?? .black
    }

    /// 伪代码 0x1002041a4（L230-258）：内置主题工厂。
    static func builtIn(
        id: String, name: String, textColorHex: String,
        backgroundColorHex: String, useDarkBackground: Bool
    ) -> ReaderTheme {
        ReaderTheme(
            id: id, name: name, textColorHex: textColorHex,
            backgroundColorHex: backgroundColorHex,
            useDarkBackground: useDarkBackground, isCustom: false
        )
    }

    /// 内置主题集合（伪代码 builtIn 调用族推断）。
    static let builtInThemes: [ReaderTheme] = [
        builtIn(id: "white", name: "白色", textColorHex: "#1A1A1A",
                backgroundColorHex: "#FFFFFF", useDarkBackground: false),
        builtIn(id: "sepia", name: "羊皮纸", textColorHex: "#5B4636",
                backgroundColorHex: "#F5ECD9", useDarkBackground: false),
        builtIn(id: "green", name: "护眼绿", textColorHex: "#3B4A3F",
                backgroundColorHex: "#C7EDCC", useDarkBackground: false),
        builtIn(id: "dark", name: "夜间", textColorHex: "#B8B8B8",
                backgroundColorHex: "#1A1A1A", useDarkBackground: true),
        builtIn(id: "black", name: "纯黑", textColorHex: "#999999",
                backgroundColorHex: "#000000", useDarkBackground: true),
    ]
}

// MARK: - 十六进制颜色扩展

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}

// MARK: - 主题管理器

/// 主题管理器（伪代码 ThemeManager，L290-L355）。
final class ThemeManager {

    /// 伪代码 L290：currentThemeId 初始化。
    private(set) var currentThemeId: String = "white"

    private(set) var customThemes: [ReaderTheme] = []
    private let lock = NSLock()

    /// 伪代码 0x10020476c（L350-355）：保存自定义主题。
    func saveCustomThemes() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(customThemes) {
            defaults.set(data, forKey: "reader_custom_themes")
        }
    }

    // MARK: - 界面设置应用桥（T-1401-01 performReaderThemeApplication
    // 0x100206dc4 调用域确证；本体无独立导出块，语义桥接）

    /// 归一化暗色章节标题配置：暗档缺省时从亮档继承（块名域确证）。
    func normalizedDarkChapterTitleConfig(from settings: ReadingSettings) {
        guard let light = settings.chapterTitleConfigLight,
            settings.chapterTitleConfigDark == nil else { return }
        settings.chapterTitleConfigDark = ChapterTitleConfig(
            fontName: light.fontName, fontSize: light.fontSize,
            textAlignment: light.textAlignment, useBold: light.useBold)
    }

    // MARK: - 界面设置应用桥（T-1401-01 performReaderThemeApplication
    // 0x100206dc4 调用域确证；本体无独立导出块，语义桥接）

    /// 界面设置应用：主题刷新 + 重排标志桥（forceRepagination 域）。
    func applyInterfaceSettings(
        from settings: ReadingSettings, to target: ReadingSettings,
        forceRepagination: Bool
    ) {
        if forceRepagination {
            target.needsRepagination = true
        }
    }

    func loadCustomThemes() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "reader_custom_themes"),
            let themes = try? JSONDecoder().decode([ReaderTheme].self, from: data)
        {
            customThemes = themes
        }
    }

    func switchTheme(id: String) {
        currentThemeId = id
        UserDefaults.standard.set(id, forKey: "reader_current_theme_id")
    }

    var currentTheme: ReaderTheme {
        let all = ReaderTheme.builtInThemes + customThemes
        return all.first { $0.id == currentThemeId } ?? ReaderTheme.builtInThemes[0]
    }

    /// 预设导出（伪代码 reader_preset_export_ + temporaryDirectory）。
    func exportPreset(theme: ReaderTheme) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("reader_preset_export_\(theme.id).json")
        guard let data = try? JSONEncoder().encode(theme) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    /// 预设导入（伪代码 reader_preset_import_）。
    func importPreset(from url: URL) -> ReaderTheme? {
        guard FileManager.default.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url),
            let theme = try? JSONDecoder().decode(ReaderTheme.self, from: data)
        else { return nil }
        var imported = theme
        imported.isCustom = true
        imported.id = "custom_\(theme.id)_\(Int(Date().timeIntervalSince1970))"
        customThemes.append(imported)
        saveCustomThemes()
        try? FileManager.default.removeItem(at: url)
        return imported
    }

    static let shared = ThemeManager()
}

/// 自定义字体名（ReaderTheme 的字体属性载体）。
extension ReaderTheme {
    static var currentCustomFontName: String? {
        UserDefaults.standard.string(forKey: "reader_custom_font")
    }
}

// MARK: - T-1401-03 逐域补齐（主题应用域）

extension ThemeManager {

    /// 应用执行域（applyBoundThemePair 0x100206f50 调用域确证：
    /// applyResolvedTheme(_:source:rememberAppearanceSelection:forceRepagination:)
    /// 四参形态；source 2 = 绑定对来源域）。
    func applyResolvedTheme(
        _ theme: ReaderTheme,
        source: Int,
        rememberAppearanceSelection: Bool,
        forceRepagination: Bool
    ) {
        currentThemeId = theme.id
        UserDefaults.standard.set(theme.id, forKey: "reader_current_theme_id")
        if forceRepagination {
            NotificationCenter.default.post(
                name: Notification.Name("readerThemeDidChange"), object: nil)
        }
    }

    /// 背景图应用域（applyUserSelectedTheme 0x100206e7c 调用域确证）。
    func applyBackgroundImage(from: ReaderTheme, to: ReaderTheme) {
        // 背景图资源域随主题资产管线落地；当前语义桥不触发重排。
    }

    /// 状态保存域（applyBoundThemePair 尾调 saveState() 域确证）。
    func saveState() {
        saveCustomThemes()
    }

    /// 系统外观解析域（0x100206e7c resolvedSystemUserInterfaceStyle 域确证）。
    static var resolvedSystemUserInterfaceStyle: UIUserInterfaceStyle {
        UITraitCollection.current.userInterfaceStyle
    }

    /// 伪代码 0x10020643c（L470-480）：useDarkBackground 位（a1[10] 域）分流
    /// 双应用路径（sub_100203CA4 带参 / sub_100203DB8 单参域）。
    func applyTheme(_ theme: ReaderTheme) {
        if theme.useDarkBackground {
            applyResolvedTheme(
                theme, source: 1,
                rememberAppearanceSelection: true, forceRepagination: false)
        } else {
            applyResolvedTheme(
                theme, source: 0,
                rememberAppearanceSelection: false, forceRepagination: false)
        }
    }

    /// 伪代码 0x100206e7c（L541-551）：AppThemeManager
    /// .updateCurrentReaderThemeBindingFromManualSelection(_:) 位 → 成功 →
    /// applyBackgroundImage；失败 → resolvedSystemUserInterfaceStyle
    /// （ColorScheme.dark == 2 域）比对 useDarkBackground 变化后应用。
    func applyUserSelectedTheme(_ theme: ReaderTheme) {
        let bindingUpdated = AppThemeManager.shared
            .updateCurrentReaderThemeBindingFromManualSelection(theme)
        if bindingUpdated {
            applyBackgroundImage(from: theme, to: theme)
            return
        }
        let systemDark =
            ThemeManager.resolvedSystemUserInterfaceStyle == .dark
        if systemDark != theme.useDarkBackground {
            applyBackgroundImage(from: theme, to: theme)
        }
    }

    /// 伪代码 0x100206f50（L593-625）：lightId/darkId 双档解析 →
    /// ReaderTheme.backgroundColor 域 + == infix 去重（v38/v77 域）→
    /// saveState() + applyResolvedTheme(_:source:2, remember:0, force:1)
    /// （调用域确证）+ ColorScheme.dark 比较选档（v60 域）。
    func applyBoundThemePair(
        lightId: String?, darkId: String?, activeColorScheme: ColorScheme
    ) {
        let allThemes = ReaderTheme.builtInThemes + customThemes
        let light = lightId.flatMap { id in allThemes.first { $0.id == id } }
            ?? currentTheme
        let dark = darkId.flatMap { id in allThemes.first { $0.id == id } }
            ?? light
        let target = activeColorScheme == .dark ? dark : light
        saveState()
        if target.id != currentThemeId {
            applyResolvedTheme(
                target, source: 2,
                rememberAppearanceSelection: false, forceRepagination: true)
        }
    }

    /// 伪代码 0x1002083f0（L711-761）：UUID 域（type metadata accessor for
    /// UUID 确证）→ 当前主题深拷贝改名 + isDark 写 useDarkBackground →
    /// 入 customThemes + saveCustomThemes()。
    func saveCurrentAsTheme(name: String, isDark: Bool) {
        let source = currentTheme
        let copy = ReaderTheme(
            id: "custom_\(UUID().uuidString)",
            name: name,
            textColorHex: source.textColorHex,
            backgroundColorHex: source.backgroundColorHex,
            useDarkBackground: isDark,
            isCustom: true)
        customThemes.append(copy)
        currentThemeId = copy.id
        saveCustomThemes()
    }

    /// 伪代码 0x100208c04（L770-791）：自定义主题移除 + 内置主题拒绝域；
    /// 当前主题被删 → 回退首个内置。
    func deleteTheme(_ theme: ReaderTheme) {
        guard theme.isCustom else { return }
        customThemes.removeAll { $0.id == theme.id }
        if currentThemeId == theme.id {
            currentThemeId = ReaderTheme.builtInThemes[0].id
        }
        saveCustomThemes()
    }

    /// 伪代码 0x100209aec（L848-884）：观察到的系统外观应用——源外观与
    /// 当前主题暗色位比较（source 串随日志域）；变化 → 应用暗/亮档主题。
    @discardableResult
    func applyObservedSystemAppearance(
        _ style: UIUserInterfaceStyle, source: String
    ) -> Bool {
        let systemDark = style == .dark
        if systemDark == currentTheme.useDarkBackground {
            return false
        }
        let allThemes = ReaderTheme.builtInThemes + customThemes
        if let target = allThemes.first(where: {
            $0.useDarkBackground == systemDark
        }) {
            applyResolvedTheme(
                target, source: 3,
                rememberAppearanceSelection: false, forceRepagination: false)
        }
        return true
    }

    /// 伪代码 0x10020ba90（L897-907）：自定义主题入库（NSFileManager
    /// defaultManager 域确证；资产文件域随主题资产管线）→ 返回入库副本。
    @discardableResult
    func addCustomTheme(_ theme: ReaderTheme) -> ReaderTheme {
        var added = theme
        added.isCustom = true
        added.id = "custom_\(theme.id)_\(Int(Date().timeIntervalSince1970))"
        customThemes.append(added)
        saveCustomThemes()
        return added
    }
}

/// 预设文件管理器（0x100209f78/0x10020ab3c/0x10020c248 域；
/// reader_preset_export_/reader_preset_import_ 诊断串确证）。
enum ReaderPresetFileManager {

    /// 预设文件错误（errorDescription 0x10020c248 L958-965 域确证：
    /// "缺少背景资源：" 前缀 + 明细串 / 24 字符静态串双分支）。
    enum PresetFileError: LocalizedError {
        case missingBackgroundResource(String)
        case invalidPackage

        var errorDescription: String? {
            switch self {
            case .missingBackgroundResource(let detail):
                return "缺少背景资源：" + detail
            case .invalidPackage:
                return "预设包无效或已损坏"
            }
        }
    }

    /// 伪代码 0x100209f78（L968-1004）：预设导出 zip——主题 JSON + 背景资源
    /// 目录打包（ZipUtility.createZip 域桥接；temporaryDirectory +
    /// reader_preset_export_ 前缀确证）。
    static func exportPresetAsZip(_ theme: ReaderTheme) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent(
            "reader_preset_export_\(theme.id)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workDir, withIntermediateDirectories: true)
        let jsonData = try JSONEncoder().encode(theme)
        try jsonData.write(
            to: workDir.appendingPathComponent("theme.json"), options: .atomic)
        let output = tempDir.appendingPathComponent(
            "reader_preset_export_\(theme.id).zip")
        try ZipUtility.createZip(from: workDir, to: output)
        try? FileManager.default.removeItem(at: workDir)
        return output
    }

    /// 伪代码 0x10020ab3c（L1006-1033）：预设导入 zip——解包 → theme.json
    /// 解码 → 背景资源存在性校验（PresetFileError.missingBackgroundResource
    /// 域）→ isCustom 写入。
    static func importPresetFromZip(_ url: URL) throws -> ReaderTheme {
        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent(
            "reader_preset_import_\(Int(Date().timeIntervalSince1970))",
            isDirectory: true)
        try ZipUtility.extractZip(from: url, to: workDir)
        let jsonURL = workDir.appendingPathComponent("theme.json")
        guard let data = try? Data(contentsOf: jsonURL),
            var theme = try? JSONDecoder().decode(ReaderTheme.self, from: data)
        else {
            throw PresetFileError.invalidPackage
        }
        let hasBackground = FileManager.default.fileExists(
            atPath: workDir.appendingPathComponent("backgrounds").path)
        if !hasBackground && !theme.backgroundColorHex.isEmpty {
            throw PresetFileError.missingBackgroundResource(theme.name)
        }
        theme.isCustom = true
        theme.id = "custom_\(theme.id)_\(Int(Date().timeIntervalSince1970))"
        try? FileManager.default.removeItem(at: workDir)
        return theme
    }
}

