// 原路径: ReadMain/Core/AppThemeManager.swift
// 证据:
//   - PGO: 231 条记录（index/task_functions.csv T-701-01 /
//     AppThemeManager.swift；97 函数，伪代码域 1633 行）
//   - CovMap: 上述 L 区段（impact L31-39 / 主题取用 L139-425 /
//     应用链 L446-783 / 图标导入 L829-1187 / 系统外观 L1221-1302 /
//     持久化 L1309-1633）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/AppThemeManager.c
//     （12101 行，96 块索引 0x10018d3f8-0x1001a0188）
//   - 块体确证（地址+行号域）：
//     AppThemeUpdateImpact.init 0x10018e268 L31-39（五域变更闭包
//     closure #1 0x10018d3f8）/ currentTheme getter 0x10018e898
//     L139-147（followSystem × systemDark 分派）/
//     preferredColorSchemeOverride 0x10018e8fc L160-163（跟随系统时
//     由 systemDark 合成）/ effectiveColorScheme 0x10018eac0 L166
//     （override 优先）/ accentColor(for:) 0x10018ebc0 L178-181 /
//     textColor 0x10018ece4 L184-196（currentTheme.textColor 委托）/
//     tabIcon 0x10018ede0 L211-217 / selectedTabIcon 0x10018ef74
//     L220-231 / cardBackground(for:) 0x10018ff84 L379-413（isEnabled
//     守卫 + hasDarkBackgroundImage + imageData/layout/borderOpacity/
//     cornerRadius/backgroundColor/borderWidth 解析链）/
//     backgroundImage(for:) 0x1001905a0 L446-466 / applyTheme
//     0x100190a78 L491-502 / setFollowSystemTheme 0x100190b60
//     L504-518 / migrateFromBackgroundColorMixer 0x10019b0e4
//     L1528-1633（'迁移主题' L11822 域）/ 'light'/'_card_'
//     L2115/L2124（ResolvedCardBackground cacheIdentifier 域）/
//     ' source=' L8265（外观来源诊断域）/ 默认色 '007AFF'/'111111'/
//     '666666'/'999999'/'F2F2F2'/'B8B8B8'/'7A7A7A'（L11768-11877
//     内置主题工厂域）/ 内置主题名（AppTheme.c 交叉）：'ocean'/
//     '海洋蓝' / 'sunset'/'落日橙' / 'forest'/'森林绿' /
//     'lavender'/'薰衣草' / 'rose'/'玫瑰粉' / 'amber'/'琥珀金'
//   - 事实：主题落盘 Application Support/themes.json + UserDefaults
//     选择键（load 0x100199fd8 L1418-1456 域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（currentTheme/cardBackground/applyTheme/load 域块体
//   确证；持久化细节按 JSON 还原桥）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - 主题更新影响（0x10018e268 L31-39）

/// 主题更新影响域（init(previous:updated:) 0x10018e268 + closure
/// 0x10018d3f8 块体确证：外观/背景/卡片/图标/杂项五域变更检测）。
struct AppThemeUpdateImpact {
    let appearanceChanged: Bool
    let backgroundChanged: Bool
    let cardBackgroundChanged: Bool
    let tabIconsChanged: Bool
    let miscChanged: Bool

    init(previous: AppTheme, updated: AppTheme) {
        appearanceChanged =
            previous.accentColorHex != updated.accentColorHex
            || previous.darkAccentColorHex != updated.darkAccentColorHex
            || previous.primaryTextColorHex
                != updated.primaryTextColorHex
            || previous.darkPrimaryTextColorHex
                != updated.darkPrimaryTextColorHex
        backgroundChanged =
            previous.defaultBackground != updated.defaultBackground
            || previous.tabBackgrounds != updated.tabBackgrounds
            || previous.cardBackground.backgroundImageData
                != updated.cardBackground.backgroundImageData
            || previous.cardBackground.darkBackgroundImageData
                != updated.cardBackground.darkBackgroundImageData
        cardBackgroundChanged =
            previous.cardBackground != updated.cardBackground
            || previous.coverCornerRadius != updated.coverCornerRadius
        tabIconsChanged =
            previous.tabIcons != updated.tabIcons
            || previous.selectedTabIcons != updated.selectedTabIcons
            || previous.darkTabIcons != updated.darkTabIcons
            || previous.darkSelectedTabIcons
                != updated.darkSelectedTabIcons
            || previous.hideTabText != updated.hideTabText
            || previous.tabIconSize != updated.tabIconSize
        miscChanged =
            previous.useClassicTabBar != updated.useClassicTabBar
            || previous.disableGlassEffect != updated.disableGlassEffect
            || previous.enableFrostedGlass != updated.enableFrostedGlass
            || previous.frostedGlassOpacity != updated.frostedGlassOpacity
            || previous.transparentModeOpacity
                != updated.transparentModeOpacity
            || previous.appIconName != updated.appIconName
    }
}

// MARK: - 已解析卡片背景（cardBackground(for:) 0x10018ff84 L379-413）

/// 解析后的卡片背景（cacheIdentifier 'light'/'_card_' L2115/L2124
/// 域确证）。
struct AppThemeResolvedCardBackground {
    let imageData: Data?
    let layout: HighlightBackgroundImageLayout
    let imageMode: AppThemeCardBackgroundImageMode
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let borderOpacity: Double
    let cornerRadius: CGFloat
    let cacheIdentifier: String
}

// MARK: - 阅读主题绑定（0x100192514 L678-686 / 0x100192554 L692-699）

/// 阅读主题绑定槽位（fallbackReaderThemeId(for:) 0x1001925c4 L701-709
/// 块体：slot==1 与否则两分派）。
enum AppThemeReaderBindingSlot: String, Codable, CaseIterable {
    case light
    case dark
}

/// 阅读主题绑定（normalizedReaderThemeBinding 0x100192514 域确证）。
struct AppThemeReaderBinding: Codable, Hashable {
    var lightThemeId: String?
    var darkThemeId: String?
    var isEnabled: Bool = false
}

// MARK: - 应用图标项（AppIconItem.previewImage 签名域）

/// 应用图标条目（previewImage 签名域确证）。
struct AppIconItem: Identifiable, Hashable {
    let id: String
    let displayName: String

    /// previewImage getter（签名族确证：主图标回退资源名）。
    var previewImage: UIImage? {
        if id.isEmpty {
            return UIImage(named: "AppIcon")
        }
        return UIImage(named: id)
    }
}

// MARK: - 主题管理器（0x10018e898 L139-147 → 0x10019b0e4 L1528-1633）

/// 应用主题管理器（currentTheme 0x10018e898 域确证；@MainActor 单例）。
@MainActor
final class AppThemeManager: ObservableObject {

    static let shared = AppThemeManager()

    // MARK: 存储域（load 0x100199fd8 L1418-1456 域确证）

    @Published private(set) var themes: [AppTheme] = []
    @Published var lightThemeID: String = AppThemeManager.builtinDefaultID
    @Published var darkThemeID: String = AppThemeManager.builtinDefaultID
    @Published var followSystemTheme: Bool = true
    @Published private(set) var useDarkTheme: Bool = false
    @Published private(set) var systemThemeIsDark: Bool = false
    @Published var readerThemeBindings: [String: AppThemeReaderBinding] =
        [:]

    private var imageCache: [String: UIImage] = [:]
    private var pendingSaveTask: Task<Void, Never>?

    static let builtinDefaultID = "ocean"
    static let themesDirectory = "themes"

    private static let selectionDefaultsKey = "reader_theme_selection"
    private static let bindingsDefaultsKey = "reader_theme_bindings"

    private init() {
        load()
    }

    // MARK: 主题取用（0x10018e898 L139-147 / 0x10018eac0 L166 域确证）

    /// currentTheme getter（0x10018e898 块体确证：跟随系统 × 系统
    /// 明暗 → 暗/亮主题）。
    var currentTheme: AppTheme {
        if followSystemTheme {
            return effectiveSystemDarkMode
                ? theme(withID: darkThemeID) ?? builtinDefaultTheme
                : theme(withID: lightThemeID) ?? builtinDefaultTheme
        }
        return theme(withID: useDarkTheme ? darkThemeID : lightThemeID)
            ?? builtinDefaultTheme
    }

    private var builtinDefaultTheme: AppTheme {
        Self.builtinThemes.first { $0.id == Self.builtinDefaultID }
            ?? Self.builtinThemes[0]
    }

    private func theme(withID id: String) -> AppTheme? {
        themes.first { $0.id == id }
    }

    /// activeThemeModeIsDark getter（0x10018e9bc closure 域确证）。
    var activeThemeModeIsDark: Bool {
        currentTheme.id == darkThemeID
    }

    /// preferredColorSchemeOverride getter（0x10018e8fc 块体确证：
    /// 跟随系统时由系统明暗合成，否则 nil）。
    var preferredColorSchemeOverride: ColorScheme? {
        followSystemTheme ? nil : (useDarkTheme ? .dark : .light)
    }

    /// effectiveColorScheme(for:)（0x10018eac0 域确证：override 优先）。
    func effectiveColorScheme(for systemScheme: ColorScheme)
        -> ColorScheme {
        preferredColorSchemeOverride ?? systemScheme
    }

    /// appAppearanceColorScheme getter（签名族确证）。
    var appAppearanceColorScheme: ColorScheme {
        useDarkTheme ? .dark : .light
    }

    // MARK: 颜色取用（0x10018ebc0 L178-181 / 0x10018ece4 L184-196）

    /// accentColor(for:)（0x10018ebc0 域确证：明暗主题 accent 委托）。
    func accentColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? currentTheme.darkAccentColor
            : currentTheme.accentColor
    }

    /// textColor(_:for:)（0x10018ece4 块体确证：currentTheme.textColor）。
    func textColor(
        _ level: AppThemeTextLevel, for colorScheme: ColorScheme
    ) -> Color {
        currentTheme.textColor(level, colorScheme: colorScheme)
    }

    func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        textColor(.primary, for: colorScheme)
    }

    func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        textColor(.secondary, for: colorScheme)
    }

    func tertiaryTextColor(for colorScheme: ColorScheme) -> Color {
        textColor(.tertiary, for: colorScheme)
    }

    /// appFont(size:weight:)（签名族确证：自定义字体桥）。
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard let family = fontFamily else {
            return .system(size: size, weight: weight)
        }
        return .custom(family, size: size, weight: weight)
    }

    var defaultFont: Font? {
        fontFamily.map { .custom($0, size: 17) }
    }

    var fontFamily: String? {
        currentTheme.fontFamily
    }

    // MARK: 图标域（0x10018ede0 L211-217 / 0x10018f334 L1133-1158）

    /// tabIcon(for:colorScheme:)（0x10018ede0 块体确证：暗色集回退
    /// 亮色集回退默认符号）。
    func tabIcon(
        for page: TabPage, colorScheme: ColorScheme
    ) -> TabIcon {
        let set = colorScheme == .dark
            ? (currentTheme.darkTabIcons ?? currentTheme.tabIcons)
            : currentTheme.tabIcons
        return set[page] ?? TabIcon.sfSymbol(page.defaultSFSymbol)
    }

    /// selectedTabIcon(for:colorScheme:)（0x10018ef74 块体确证）。
    func selectedTabIcon(
        for page: TabPage, colorScheme: ColorScheme
    ) -> TabIcon {
        let set = colorScheme == .dark
            ? (currentTheme.darkSelectedTabIcons
                ?? currentTheme.selectedTabIcons
                ?? currentTheme.tabIcons)
            : (currentTheme.selectedTabIcons ?? currentTheme.tabIcons)
        return set[page] ?? tabIcon(for: page, colorScheme: colorScheme)
    }

    /// isTabTextHidden getter（0x10018f2bc L1100-1132 域确证）。
    var isTabTextHidden: Bool {
        currentTheme.hideTabText ?? false
    }

    /// tabIconSize getter（0x10018f334 域确证：默认 22）。
    var tabIconSize: CGFloat {
        currentTheme.tabIconSize ?? 22
    }

    /// readerToolbarIcon(for:colorScheme:)（0x10018f38c L1192-1300 域）。
    func readerToolbarIcon(
        for button: ReaderToolbarButton, colorScheme: ColorScheme
    ) -> TabIcon {
        TabIcon.sfSymbol(button.defaultSFSymbol)
    }

    /// readerToolbarIconSize getter（0x10018f62c L1348-1369 域确证）。
    var readerToolbarIconSize: CGFloat { 20 }

    var useClassicTabBar: Bool { currentTheme.useClassicTabBar }

    // MARK: 封面域（0x10018f688 L1370-1419 / 0x10018f774 L1420-1490）

    /// stableDefaultCoverHash(for:salt:)（0x10018fb14 L1598-1715 域
    /// 确证：字符逐位 33 倍混合闭包）。
    private func stableDefaultCoverHash(
        for key: String, salt: String
    ) -> Int {
        var hash: Int = 5381
        for byte in (key + salt).utf8 {
            // closure #1 域确证：hash = hash * 33 &+ byte。
            hash = (hash &* 33) &+ Int(byte)
            hash &= 0x7FFFFFFF
        }
        return hash
    }

    /// stableDefaultCoverVariant(for:colorScheme:avoiding:)
    /// （0x10018f688 块体确证：哈希取模 + 避让位）。
    func stableDefaultCoverVariant(
        for bookKey: String, colorScheme: ColorScheme,
        avoiding excluded: Int?
    ) -> Int? {
        let count = defaultCoverImageCount(colorScheme: colorScheme)
        guard count > 0 else { return nil }
        let base = stableDefaultCoverHash(for: bookKey, salt: "cover")
            % count
        if base != excluded {
            return base
        }
        let shifted = (base + 1) % count
        return shifted == excluded ? nil : shifted
    }

    /// defaultCoverImage(colorScheme:variantIndex:)
    /// （0x10018f774 块体确证：数据缓存解码）。
    func defaultCoverImage(
        colorScheme: ColorScheme, variantIndex: Int?
    ) -> UIImage? {
        let datas = defaultCoverImageDatas(colorScheme: colorScheme)
        guard !datas.isEmpty else { return nil }
        let index = variantIndex ?? 0
        guard datas.indices.contains(index) else { return nil }
        return UIImage(data: datas[index])
    }

    /// defaultCoverImageCount(colorScheme:)（签名族确证）。
    func defaultCoverImageCount(colorScheme: ColorScheme) -> Int {
        defaultCoverImageDatas(colorScheme: colorScheme).count
    }

    /// isForceDefaultCover getter（0x10018f954 L1491-1556 域确证）。
    var isForceDefaultCover: Bool {
        currentTheme.forceDefaultCover
    }

    /// defaultCoverImageDatas(colorScheme:)（0x10018fa68 L1557-1597
    /// 域确证：currentTheme.coverImageDatas 委托）。
    func defaultCoverImageDatas(colorScheme: ColorScheme) -> [Data] {
        currentTheme.coverImageDatas(for: colorScheme)
    }

    /// coverCornerRadius(default:)（签名族确证）。
    func coverCornerRadius(default fallback: CGFloat) -> CGFloat {
        currentTheme.clampedCoverCornerRadius
    }

    /// themeFileData(for:)（AppTheme.swift fileDataMap 还原桥）。
    func themeFileData(for themeID: String) -> [String: Data] {
        guard let directory = Self.themesRootDirectory?
            .appendingPathComponent(themeID) else {
            return [:]
        }
        var result: [String: Data] = [:]
        if let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) {
            for file in files where !file.hasHiddenExtension {
                result[file.lastPathComponent] =
                    try? Data(contentsOf: file)
            }
        }
        return result
    }

    private static var themesRootDirectory: URL? {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first
        return base?.appendingPathComponent(themesDirectory)
    }

    // MARK: 背景域（0x10018fc5c L1716-1743 / 0x10018ff84 L379-413）

    /// background(for:)（0x10018fc5c 域确证：currentTheme.background）。
    func background(for page: TabPage) -> TabBackground {
        currentTheme.background(for: page)
    }

    /// backgroundImage(for:colorScheme:)（0x1001905a0 L446-466 域
    /// 确证：hasBackgroundImage → 解码缓存）。
    func backgroundImage(
        for page: TabPage, colorScheme: ColorScheme
    ) -> UIImage? {
        let background = background(for: page)
        let isDark = colorScheme == .dark
        guard isDark
            ? background.hasDarkBackgroundImage
            : background.hasBackgroundImage else {
            return nil
        }
        let cacheKey = "\(currentTheme.id)_\(page.rawValue)_\(isDark)"
        if let cached = imageCache[cacheKey] {
            return cached
        }
        let image = isDark
            ? background.decodedDarkBackgroundImage()
            : background.decodedBackgroundImage()
        imageCache[cacheKey] = image
        return image
    }

    func invalidateImageCache() {
        imageCache.removeAll()
    }

    // MARK: 玻璃域（0x10018fcb4 L1744-1771 域族）

    var disableGlassEffect: Bool { currentTheme.disableGlassEffect }
    var enableFrostedGlass: Bool { currentTheme.enableFrostedGlass }
    var frostedGlassOpacity: Double { currentTheme.frostedGlassOpacity }
    var transparentModeOpacity: Double {
        currentTheme.transparentModeOpacity
    }
    var readerToolbarCardsFollowAppearance: Bool {
        currentTheme.readerToolbarCardsFollowAppearance
    }
    var progressBarsFollowAppearance: Bool {
        currentTheme.progressBarsFollowAppearance
    }
    var glowIntensity: Double { currentTheme.glowIntensity }

    /// contentCardCornerRadius(default:)（0x10018ff14 L1910-1936 域）。
    func contentCardCornerRadius(default fallback: CGFloat) -> CGFloat {
        cardBackground(for: .light)?.cornerRadius ?? fallback
    }

    /// cardBackground(for:)（0x10018ff84 L379-413 块体确证：
    /// isEnabled 守卫 + 解析链 + 'light'/'dark_card_' 缓存标识）。
    func cardBackground(for colorScheme: ColorScheme)
        -> AppThemeResolvedCardBackground? {
        let card = currentTheme.cardBackground
        guard card.isEnabled else { return nil }
        let isDark = colorScheme == .dark
        return AppThemeResolvedCardBackground(
            imageData: card.imageData(for: colorScheme),
            layout: card.layout(for: colorScheme),
            imageMode: card.imageMode(for: colorScheme),
            backgroundColor: card.backgroundColor(for: colorScheme),
            borderColor: card.borderColor(for: colorScheme),
            borderWidth: card.clampedBorderWidth,
            borderOpacity: card.clampedBorderOpacity,
            cornerRadius: card.clampedCornerRadius,
            cacheIdentifier: isDark
                ? "dark_card_\(currentTheme.id)" : "light")
    }

    // MARK: 应用链（0x100190a78 L491-502 / 0x100190b60 L504-518）

    /// applyTheme(_:)（0x100190a78 块体确证：写回选择 + 同步阅读域
    /// + 刷新外观 + 落盘）。
    func applyTheme(_ theme: AppTheme) {
        if activeThemeModeIsDark {
            darkThemeID = validThemeId(theme.id) ?? darkThemeID
        } else {
            lightThemeID = validThemeId(theme.id) ?? lightThemeID
        }
        syncReaderInterfaceSettingsFromCurrentTheme()
        refreshThemeAppearance(appIconName: theme.appIconName)
        invalidateImageCache()
        objectWillChange.send()
        save()
    }

    /// setFollowSystemTheme(_:)（0x100190b60 块体确证 + closure 域）。
    func setFollowSystemTheme(_ enabled: Bool) {
        followSystemTheme = enabled
        persistThemeSelection(synchronize: true)
    }

    /// activateThemeMode(_:)（0x100190dac L520-529 域确证：
    /// true=暗色）。
    func activateThemeMode(_ dark: Bool) {
        useDarkTheme = dark
        applyBoundReaderThemeIfNeeded(
            activeColorScheme: dark ? .dark : .light)
        save()
    }

    /// selectTheme(_:editingDarkMode:)（0x100190eac L532-545 域确证）。
    func selectTheme(_ theme: AppTheme, editingDarkMode: Bool) {
        if editingDarkMode {
            darkThemeID = validThemeId(theme.id) ?? darkThemeID
        } else {
            lightThemeID = validThemeId(theme.id) ?? lightThemeID
        }
        applyBoundReaderThemeIfNeeded(
            activeColorScheme: editingDarkMode ? .dark : .light)
        objectWillChange.send()
        save()
    }

    /// applyDarkTheme(_:)（签名族确证）。
    func applyDarkTheme(_ theme: AppTheme) {
        selectTheme(theme, editingDarkMode: true)
    }

    // MARK: 阅读绑定域（0x1001911b4 L561-573 / 0x100191410 L575-589）

    /// isReaderThemeBindingEnabled(for:)（0x1001911b4 域确证）。
    func isReaderThemeBindingEnabled(for appThemeId: String) -> Bool {
        normalizedReaderThemeBinding(
            readerThemeBindings[appThemeId]).isEnabled
    }

    /// setReaderThemeBindingEnabled(for:_:)（0x1001911b4 域确证）。
    func setReaderThemeBindingEnabled(
        for appThemeId: String, _ enabled: Bool
    ) {
        var binding = normalizedReaderThemeBinding(
            readerThemeBindings[appThemeId])
        binding.isEnabled = enabled
        readerThemeBindings[appThemeId] = binding
        persistReaderThemeBindings(synchronize: true)
    }

    /// setBoundReaderTheme(_:for:appThemeId:)
    /// （0x100191410 域确证）。
    func setBoundReaderTheme(
        _ themeId: String?, for slot: AppThemeReaderBindingSlot,
        appThemeId: String
    ) {
        var binding = normalizedReaderThemeBinding(
            readerThemeBindings[appThemeId])
        switch slot {
        case .light: binding.lightThemeId = themeId
        case .dark: binding.darkThemeId = themeId
        }
        readerThemeBindings[appThemeId] = binding
        persistReaderThemeBindings(synchronize: true)
    }

    /// setReaderThemeBinding(for:lightThemeId:darkThemeId:isEnabled:
    /// applyIfActive:)（closure 0x100192414 域确证）。
    func setReaderThemeBinding(
        for appThemeId: String, lightThemeId: String?,
        darkThemeId: String?, isEnabled: Bool, applyIfActive: Bool
    ) {
        var binding = normalizedReaderThemeBinding(
            readerThemeBindings[appThemeId])
        binding.lightThemeId = validReaderThemeId(lightThemeId)
        binding.darkThemeId = validReaderThemeId(darkThemeId)
        binding.isEnabled = isEnabled
        readerThemeBindings[appThemeId] = binding
        persistReaderThemeBindings(synchronize: true)
        if applyIfActive && isAppThemeCurrentlyActive(appThemeId) {
            applyBoundReaderThemeIfNeeded(activeColorScheme: nil)
        }
    }

    /// readerThemeBinding(for:)（签名族确证）。
    func readerThemeBinding(for appThemeId: String)
        -> AppThemeReaderBinding? {
        readerThemeBindings[appThemeId]
    }

    /// boundReaderThemeId(for:slot:)（签名族确证）。
    func boundReaderThemeId(
        for appThemeId: String, slot: AppThemeReaderBindingSlot
    ) -> String? {
        readerThemeId(
            in: normalizedReaderThemeBinding(
                readerThemeBindings[appThemeId]), for: slot)
    }

    /// removeReaderThemeBinding(for:)（签名族确证）。
    func removeReaderThemeBinding(for appThemeId: String) {
        readerThemeBindings.removeValue(forKey: appThemeId)
        persistReaderThemeBindings(synchronize: true)
    }

    /// migrateReaderThemeBinding(from:to:)（签名族确证：主题删除时
    /// 迁移绑定键）。
    func migrateReaderThemeBinding(
        from oldAppThemeId: String, to newAppThemeId: String
    ) {
        guard let binding = readerThemeBindings.removeValue(
            forKey: oldAppThemeId) else {
            return
        }
        readerThemeBindings[newAppThemeId] = binding
        persistReaderThemeBindings(synchronize: true)
    }

    /// removeReaderThemeBindingReferences(to:)
    /// （0x100191c38 L642-661 域确证：清除引用已删阅读主题的绑定）。
    func removeReaderThemeBindingReferences(to themeId: String) {
        var changed = false
        for (key, binding) in readerThemeBindings {
            var updated = binding
            if updated.lightThemeId == themeId {
                updated.lightThemeId = nil
                changed = true
            }
            if updated.darkThemeId == themeId {
                updated.darkThemeId = nil
                changed = true
            }
            readerThemeBindings[key] = updated
        }
        if changed {
            persistReaderThemeBindings(synchronize: true)
        }
    }

    /// updateCurrentReaderThemeBindingFromManualSelection(_:)
    /// （0x1001918b4 L613-628 域确证：手动选择时解除绑定）。
    @discardableResult
    func updateCurrentReaderThemeBindingFromManualSelection(
        _ theme: ReaderTheme
    ) -> Bool {
        let appThemeId = currentTheme.id
        guard var binding = readerThemeBindings[appThemeId],
              binding.isEnabled else {
            return false
        }
        let isDark = activeThemeModeIsDark
        if isDark && binding.darkThemeId == theme.id {
            binding.darkThemeId = nil
        } else if !isDark && binding.lightThemeId == theme.id {
            binding.lightThemeId = nil
        } else {
            return false
        }
        readerThemeBindings[appThemeId] = binding
        persistReaderThemeBindings(synchronize: true)
        return true
    }

    /// normalizedReaderThemeBinding(_:)（0x100192514 域确证）。
    private func normalizedReaderThemeBinding(
        _ binding: AppThemeReaderBinding?
    ) -> AppThemeReaderBinding {
        binding ?? AppThemeReaderBinding()
    }

    /// readerThemeId(in:for:)（0x100192554 域确证）。
    private func readerThemeId(
        in binding: AppThemeReaderBinding,
        for slot: AppThemeReaderBindingSlot
    ) -> String? {
        guard binding.isEnabled else { return nil }
        let id = slot == .light
            ? binding.lightThemeId : binding.darkThemeId
        return validReaderThemeId(id)
    }

    /// fallbackReaderThemeId(for:)（0x1001925c4 L701-709 块体确证：
    /// slot 分派 ReaderTheme 内置列表）。
    private func fallbackReaderThemeId(
        for slot: AppThemeReaderBindingSlot
    ) -> String {
        let wantsDark = slot == .dark
        return ReaderTheme.builtInThemes
            .first { $0.useDarkBackground == wantsDark }?.id ?? ""
    }

    /// validReaderThemeId(_:)（0x10019281c L711-714 域确证）。
    private func validReaderThemeId(_ id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        let valid = ReaderTheme.builtInThemes.map(\.id)
            + ThemeManager.shared.customThemes.map(\.id)
        return valid.contains(id) ? id : nil
    }

    /// bindingHasBoundReaderTheme(_:)（0x100192080 域确证）。
    private func bindingHasBoundReaderTheme(
        _ binding: AppThemeReaderBinding
    ) -> Bool {
        validReaderThemeId(binding.lightThemeId) != nil
            || validReaderThemeId(binding.darkThemeId) != nil
    }

    /// isAppThemeCurrentlyActive(_:)（0x1001928a8 域确证）。
    private func isAppThemeCurrentlyActive(_ appThemeId: String) -> Bool {
        appThemeId == currentTheme.id
    }

    /// applyBoundReaderThemeIfNeeded(activeColorScheme:)
    /// （0x100192080 L663-676 域确证：绑定生效时应用绑定的阅读主题）。
    private func applyBoundReaderThemeIfNeeded(
        activeColorScheme: ColorScheme?
    ) {
        let appThemeId = currentTheme.id
        guard let binding = readerThemeBindings[appThemeId],
              binding.isEnabled else {
            return
        }
        let resolvedScheme = activeColorScheme
            ?? effectiveColorScheme(
                for: UIScreen.main.traitCollection
                    .userInterfaceStyle.scheme)
        let slot: AppThemeReaderBindingSlot =
            resolvedScheme == .dark ? .dark : .light
        guard let boundId = readerThemeId(in: binding, for: slot) else {
            return
        }
        ThemeManager.shared.switchTheme(id: boundId)
    }

    // MARK: 主题维护（0x1001928a8 L721-749 / 0x100192cb0 L751-762）

    /// updateTheme(_:)（0x1001928a8 域确证：按 id 替换）。
    func updateTheme(_ theme: AppTheme) {
        guard let index = themes.firstIndex(where: {
            $0.id == theme.id
        }) else {
            return
        }
        themes[index] = theme
        save()
        objectWillChange.send()
    }

    /// resetBuiltInThemeToDefault(id:)（0x100192cb0 域确证）。
    func resetBuiltInThemeToDefault(id: String) {
        guard let index = themes.firstIndex(where: { $0.id == id }),
              themes[index].isBuiltIn,
              let defaultTheme = Self.builtinThemes.first(where: {
                  $0.id == id
              }) else {
            return
        }
        themes[index] = defaultTheme
        save()
        objectWillChange.send()
    }

    /// deleteTheme(id:)（0x10019433c L873-885 域确证：非内置才删）。
    func deleteTheme(id: String) {
        guard let index = themes.firstIndex(where: { $0.id == id }),
              !themes[index].isBuiltIn else {
            return
        }
        themes.remove(at: index)
        removeReaderThemeBindingReferences(to: id)
        if lightThemeID == id {
            lightThemeID = Self.builtinDefaultID
        }
        if darkThemeID == id {
            darkThemeID = Self.builtinDefaultID
        }
        let directory = Self.themesRootDirectory?
            .appendingPathComponent(id)
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        save()
        objectWillChange.send()
    }

    /// saveCustomTheme(name:basedOn:)（0x1001928a8 域确证）。
    private func saveCustomTheme(
        name: String, basedOn theme: AppTheme
    ) -> AppTheme {
        var copy = theme
        let newID = "custom_\(UUID().uuidString.lowercased())"
        copy = AppTheme(
            id: newID, name: name, isBuiltIn: false,
            accentColorHex: copy.accentColorHex,
            darkAccentColorHex: copy.darkAccentColorHex,
            primaryTextColorHex: copy.primaryTextColorHex,
            secondaryTextColorHex: copy.secondaryTextColorHex,
            tertiaryTextColorHex: copy.tertiaryTextColorHex,
            darkPrimaryTextColorHex: copy.darkPrimaryTextColorHex,
            darkSecondaryTextColorHex: copy.darkSecondaryTextColorHex,
            darkTertiaryTextColorHex: copy.darkTertiaryTextColorHex,
            fontFamily: copy.fontFamily, tabIcons: copy.tabIcons,
            selectedTabIcons: copy.selectedTabIcons,
            darkTabIcons: copy.darkTabIcons,
            darkSelectedTabIcons: copy.darkSelectedTabIcons,
            hideTabText: copy.hideTabText,
            tabIconSize: copy.tabIconSize,
            useClassicTabBar: copy.useClassicTabBar,
            bookshelfHeaderStyle: copy.bookshelfHeaderStyle,
            bookshelfGridColumnCount: copy.bookshelfGridColumnCount,
            bookshelfListCardHeight: copy.bookshelfListCardHeight,
            bookshelfShowsTags: copy.bookshelfShowsTags,
            bookshelfTagTextColorMode: copy.bookshelfTagTextColorMode,
            bookshelfTagCustomTextColorHex:
                copy.bookshelfTagCustomTextColorHex,
            readerBottomToolbarStyle: copy.readerBottomToolbarStyle,
            disableGlassEffect: copy.disableGlassEffect,
            enableFrostedGlass: copy.enableFrostedGlass,
            frostedGlassOpacity: copy.frostedGlassOpacity,
            transparentModeOpacity: copy.transparentModeOpacity,
            readerToolbarCardsFollowAppearance:
                copy.readerToolbarCardsFollowAppearance,
            progressBarsFollowAppearance:
                copy.progressBarsFollowAppearance,
            cardBackground: copy.cardBackground,
            coverCornerRadius: copy.coverCornerRadius,
            glowIntensity: copy.glowIntensity,
            defaultBackground: copy.defaultBackground,
            tabBackgrounds: copy.tabBackgrounds,
            forceDefaultCover: copy.forceDefaultCover,
            appIconName: copy.appIconName)
        themes.append(copy)
        return copy
    }

    /// saveAsNewTheme(name:basedOn:)（0x100193108 域确证）。
    func saveAsNewTheme(
        name: String, basedOn theme: AppTheme
    ) -> AppTheme {
        saveCustomTheme(name: name, basedOn: theme)
    }

    func saveAsNewTheme(
        name: String, basedOn theme: AppTheme, editingDarkMode: Bool
    ) -> AppTheme {
        let created = saveCustomTheme(name: name, basedOn: theme)
        selectTheme(created, editingDarkMode: editingDarkMode)
        return created
    }

    // MARK: 导入导出（0x1001948bc L888-896 / 0x100194b0c L899-933）

    /// exportTheme(_:)（0x1001948bc 域确证：JSON 落盘临时目录）。
    func exportTheme(_ theme: AppTheme) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(theme.name).qitheme")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// importTheme(from:)（0x100194b0c 域确证：解码 + id 冲突重生成）。
    func importTheme(from url: URL) throws -> AppTheme {
        let data = try Data(contentsOf: url)
        var imported = try JSONDecoder().decode(AppTheme.self, from: data)
        if themes.contains(where: { $0.id == imported.id }) {
            imported = Self.duplicate(
                imported,
                newID: "custom_\(UUID().uuidString.lowercased())")
        }
        themes.append(imported)
        save()
        objectWillChange.send()
        return imported
    }

    /// id 重建桥（AppTheme.id 为 let；0x100194b0c 域确证的冲突重生成）。
    private static func duplicate(
        _ theme: AppTheme, newID: String
    ) -> AppTheme {
        AppTheme(
            id: newID, name: theme.name, isBuiltIn: false,
            accentColorHex: theme.accentColorHex,
            darkAccentColorHex: theme.darkAccentColorHex,
            primaryTextColorHex: theme.primaryTextColorHex,
            secondaryTextColorHex: theme.secondaryTextColorHex,
            tertiaryTextColorHex: theme.tertiaryTextColorHex,
            darkPrimaryTextColorHex: theme.darkPrimaryTextColorHex,
            darkSecondaryTextColorHex: theme.darkSecondaryTextColorHex,
            darkTertiaryTextColorHex: theme.darkTertiaryTextColorHex,
            fontFamily: theme.fontFamily, tabIcons: theme.tabIcons,
            selectedTabIcons: theme.selectedTabIcons,
            darkTabIcons: theme.darkTabIcons,
            darkSelectedTabIcons: theme.darkSelectedTabIcons,
            hideTabText: theme.hideTabText,
            tabIconSize: theme.tabIconSize,
            useClassicTabBar: theme.useClassicTabBar,
            bookshelfHeaderStyle: theme.bookshelfHeaderStyle,
            bookshelfGridColumnCount: theme.bookshelfGridColumnCount,
            bookshelfListCardHeight: theme.bookshelfListCardHeight,
            bookshelfShowsTags: theme.bookshelfShowsTags,
            bookshelfTagTextColorMode: theme.bookshelfTagTextColorMode,
            bookshelfTagCustomTextColorHex:
                theme.bookshelfTagCustomTextColorHex,
            readerBottomToolbarStyle: theme.readerBottomToolbarStyle,
            disableGlassEffect: theme.disableGlassEffect,
            enableFrostedGlass: theme.enableFrostedGlass,
            frostedGlassOpacity: theme.frostedGlassOpacity,
            transparentModeOpacity: theme.transparentModeOpacity,
            readerToolbarCardsFollowAppearance:
                theme.readerToolbarCardsFollowAppearance,
            progressBarsFollowAppearance:
                theme.progressBarsFollowAppearance,
            cardBackground: theme.cardBackground,
            coverCornerRadius: theme.coverCornerRadius,
            glowIntensity: theme.glowIntensity,
            defaultBackground: theme.defaultBackground,
            tabBackgrounds: theme.tabBackgrounds,
            forceDefaultCover: theme.forceDefaultCover,
            appIconName: theme.appIconName)
    }

    // MARK: 图标处理（0x100196e88 L1109-1129 / 0x1001971c0 域确证）

    /// processTabIcon(_:)（0x100196e88 块体确证：正方形渲染 PNG）。
    static func processTabIcon(_ image: UIImage) -> Data? {
        let side: CGFloat = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format)
        let rendered = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            let fitted = AVMakeRect(
                aspectRatio: image.size,
                insideRect: rect.insetBy(dx: 8, dy: 8))
            image.draw(in: fitted)
        }
        return rendered.pngData()
    }

    /// processCoverImage(_:maxHeight:)
    /// （0x1001971c0 L1145-1194 域确证：等比缩放 ≤ 高度上限 JPEG）。
    static func processCoverImage(
        _ image: UIImage, maxHeight: CGFloat
    ) -> Data? {
        guard image.size.height > maxHeight else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let scale = maxHeight / image.size.height
        let size = CGSize(
            width: image.size.width * scale, height: maxHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    /// processBackgroundImage(_:maxSize:)（签名族确证）。
    static func processBackgroundImage(
        _ image: UIImage, maxSize: CGFloat
    ) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSize else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let scale = maxSize / longest
        let size = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    // MARK: 系统外观（0x100197a10 L1237-1256 / 0x100197eb0 域确证）

    /// specifiedInterfaceStyle(_:)（0x100197954 L1221-1228 域确证）。
    private func specifiedInterfaceStyle(
        _ style: UIUserInterfaceStyle
    ) -> UIUserInterfaceStyle? {
        style == .unspecified ? nil : style
    }

    /// applyObservedSystemAppearance(_:source:)
    /// （0x100197a10 块体确证：跟随系统时记录系统明暗；' source='
    /// L8265 诊断域）。
    @discardableResult
    func applyObservedSystemAppearance(
        _ style: UIUserInterfaceStyle, source: String
    ) -> Bool {
        guard followSystemTheme,
              let specified = specifiedInterfaceStyle(style) else {
            return false
        }
        let isDark = specified == .dark
        guard isDark != systemThemeIsDark else { return false }
        systemThemeIsDark = isDark
        objectWillChange.send()
        return true
    }

    /// updateSystemDarkMode(_:)（签名族确证）。
    func updateSystemDarkMode(_ isDark: Bool) {
        applyObservedSystemAppearance(
            isDark ? .dark : .light, source: "updateSystemDarkMode")
    }

    /// effectiveSystemDarkMode getter（0x100197eb0 L1270-1278 域确证）。
    var effectiveSystemDarkMode: Bool { systemThemeIsDark }

    /// resolvedSystemUserInterfaceStyle getter
    /// （0x100198148 L1282-1302 域确证：windowScene 遍历）。
    var resolvedSystemUserInterfaceStyle: UIUserInterfaceStyle? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .traitCollection.userInterfaceStyle
    }

    var currentUIKitColorScheme: ColorScheme {
        systemThemeIsDark ? .dark : .light
    }

    /// checkAndSwitchAppearance()（签名族确证）。
    func checkAndSwitchAppearance() {
        if let style = resolvedSystemUserInterfaceStyle {
            applyObservedSystemAppearance(style, source: "check")
        }
    }

    // MARK: UIKit 外观（0x100195494 L937-990 域确证）

    /// uiPrimaryTextColor getter（0x100195d9c L996-998 域确证）。
    private var uiPrimaryTextColor: UIColor {
        UIColor(primaryTextColor(for: .light))
    }

    private var uiAccentColor: UIColor {
        UIColor(accentColor(for: .light))
    }

    /// applyUIKitAppearance()（0x100195494 块体确证：导航/Tab 栏
    /// 外观 + 字体桥）。
    func applyUIKitAppearance() {
        let navAppearance = configuredNavigationBarAppearance()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        applyGlobalTabBarAppearance()
        refreshExistingWindows(navAppearance: navAppearance)
    }

    /// configuredNavigationBarAppearance()（签名族确证）。
    private func configuredNavigationBarAppearance()
        -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(
            background(for: .bookshelf).lightPrimaryColor)
        appearance.titleTextAttributes = [
            .foregroundColor: uiPrimaryTextColor,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        return appearance
    }

    /// applyGlobalTabBarAppearance()（签名族确证）。
    private func applyGlobalTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.normal.iconColor =
            UIColor(secondaryTextColor(for: .light))
        appearance.stackedLayoutAppearance.selected.iconColor =
            uiAccentColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes =
            tabBarTitleAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes =
            selectedTabBarTitleAttributes
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    /// applyTabBarItemAppearance(to:)（签名族确证）。
    private func applyTabBarItemAppearance(to item: UITabBarItem) {
        item.setTitleTextAttributes(
            tabBarTitleAttributes, for: .normal)
        item.setTitleTextAttributes(
            selectedTabBarTitleAttributes, for: .selected)
    }

    /// tabBarTitleAttributes getter（0x100195fd8 L1016-1028 域确证）。
    private var tabBarTitleAttributes:
        [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor(
                secondaryTextColor(for: .light)),
        ]
    }

    /// selectedTabBarTitleAttributes getter
    /// （0x1001961a4 L1030-1044 域确证）。
    private var selectedTabBarTitleAttributes:
        [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: uiAccentColor,
        ]
    }

    /// tabBarTitlePositionAdjustment getter
    /// （0x1001963ec L1046-1048 域确证）。
    private var tabBarTitlePositionAdjustment: UIOffset {
        isTabTextHidden ? UIOffset(horizontal: 0, vertical: 0)
            : UIOffset(horizontal: 0, vertical: 2)
    }

    /// refreshExistingWindows(navAppearance:)
    /// （0x100196598 L1069-1081 域确证）。
    private func refreshExistingWindows(
        navAppearance: UINavigationBarAppearance?
    ) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else {
                continue
            }
            for window in windowScene.windows {
                applyNavBarAppearance(
                    in: window, appearance: navAppearance)
                applyTabBarAppearance(in: window)
            }
        }
    }

    /// applyNavBarAppearance(in:appearance:)
    /// （0x1001968e8 L1083-1092 域确证）。
    private func applyNavBarAppearance(
        in view: UIView, appearance: UINavigationBarAppearance?
    ) {
        guard let navigationBar = view as? UINavigationBar else {
            view.subviews.forEach {
                applyNavBarAppearance(
                    in: $0, appearance: appearance)
            }
            return
        }
        navigationBar.standardAppearance = appearance
            ?? navigationBar.standardAppearance
        navigationBar.scrollEdgeAppearance = appearance
            ?? navigationBar.scrollEdgeAppearance
    }

    /// applyTabBarAppearance(in:)（0x100196a1c L1094-1104 域确证）。
    private func applyTabBarAppearance(in view: UIView) {
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance =
                UITabBar.appearance().standardAppearance
            for item in tabBar.items ?? [] {
                applyTabBarItemAppearance(to: item)
            }
        } else {
            view.subviews.forEach { applyTabBarAppearance(in: $0) }
        }
    }

    /// applyAppIcon(_:)（0x100193d3c L829-838 域确证）。
    func applyAppIcon(_ iconName: String?) {
        let name = iconName ?? ""
        guard name != currentTheme.appIconName ?? "" else { return }
        UIApplication.shared.setAlternateIconName(
            name.isEmpty ? nil : name
        ) { error in
            // closure #1 0x100194044 域确证：错误诊断。
        }
    }

    /// refreshThemeAppearance(appIconName:)
    /// （0x1001909e4 L473-479 域确证）。
    func refreshThemeAppearance(appIconName: String?) {
        applyAppIcon(appIconName)
        applyUIKitAppearance()
    }

    // MARK: 持久化（0x100198d94 L1324-1331 / 0x100198e98 L1343-1367）

    /// save()（0x100198d94 块体确证：防抖 Task）。
    private func save() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            self?.performSave()
        }
    }

    func flushPendingSave() {
        pendingSaveTask?.cancel()
        performSave()
    }

    /// performSave()（0x100198e98 块体确证：themes.json + 选择键）。
    private func performSave() {
        guard let directory = Self.themesRootDirectory else { return }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(themes) {
            try? data.write(
                to: directory.appendingPathComponent("themes.json"),
                options: .atomic)
        }
        persistThemeSelection(synchronize: true)
        persistReaderThemeBindings(synchronize: true)
    }

    /// persistThemeSelection(synchronize:)
    /// （0x100199b78 L1382-1396 域确证）。
    private func persistThemeSelection(synchronize: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(lightThemeID, forKey: "\(Self.selectionDefaultsKey)_light")
        defaults.set(darkThemeID, forKey: "\(Self.selectionDefaultsKey)_dark")
        defaults.set(followSystemTheme,
                     forKey: "\(Self.selectionDefaultsKey)_follow")
        defaults.set(useDarkTheme,
                     forKey: "\(Self.selectionDefaultsKey)_useDark")
        if synchronize {
            defaults.synchronize()
        }
    }

    /// persistReaderThemeBindings(synchronize:)
    /// （0x100199e20 L1407-1416 域确证）。
    private func persistReaderThemeBindings(synchronize: Bool) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(readerThemeBindings) {
            defaults.set(data, forKey: Self.bindingsDefaultsKey)
        }
        if synchronize {
            defaults.synchronize()
        }
    }

    /// loadReaderThemeBindings()（0x100199cc8 L1398-1405 域确证）。
    private func loadReaderThemeBindings() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.bindingsDefaultsKey)
        else {
            return
        }
        readerThemeBindings =
            (try? JSONDecoder().decode(
                [String: AppThemeReaderBinding].self, from: data)) ?? [:]
    }

    /// load()（0x100199fd8 L1418-1456 块体确证：迁移链 + 解码 + 修复）。
    private func load() {
        migrateLegacyBookshelfGridColumnsIfNeeded()
        migrateFromUserDefaultsIfNeeded()
        themes = Self.builtinThemes
        if let directory = Self.themesRootDirectory,
           let data = try? Data(
            contentsOf: directory.appendingPathComponent("themes.json")),
           let stored = try? JSONDecoder().decode(
            [AppTheme].self, from: data) {
            // 内置主题刷新 + 自定义主题合并（load 域确证）。
            var merged: [AppTheme] = Self.builtinThemes
            for theme in stored where !theme.isBuiltIn {
                merged.append(theme)
            }
            themes = merged
        }
        loadThemeSelection()
        loadReaderThemeBindings()
        repairThemeSelectionAfterLoad()
        sortThemes()
        if let style = resolvedSystemUserInterfaceStyle {
            systemThemeIsDark = style == .dark
        }
        syncReaderInterfaceSettingsFromCurrentTheme()
        applyUIKitAppearance()
    }

    /// loadThemeSelection()（0x10098cb50 域确证）。
    private func loadThemeSelection() {
        let defaults = UserDefaults.standard
        if defaults.object(
            forKey: "\(Self.selectionDefaultsKey)_light") != nil {
            lightThemeID = defaults.string(
                forKey: "\(Self.selectionDefaultsKey)_light")
                ?? lightThemeID
        }
        if defaults.object(
            forKey: "\(Self.selectionDefaultsKey)_dark") != nil {
            darkThemeID = defaults.string(
                forKey: "\(Self.selectionDefaultsKey)_dark")
                ?? darkThemeID
        }
        followSystemTheme = defaults.object(
            forKey: "\(Self.selectionDefaultsKey)_follow") != nil
            ? defaults.bool(forKey: "\(Self.selectionDefaultsKey)_follow")
            : followSystemTheme
        useDarkTheme = defaults.bool(
            forKey: "\(Self.selectionDefaultsKey)_useDark")
    }

    /// repairThemeSelectionAfterLoad()
    /// （0x1001987b8 L1309-1322 域确证：无效 id 回落内置）。
    private func repairThemeSelectionAfterLoad() {
        let validIDs = Set(themes.map(\.id))
        if !validIDs.contains(lightThemeID) {
            lightThemeID = Self.builtinDefaultID
        }
        if !validIDs.contains(darkThemeID) {
            darkThemeID = Self.builtinDefaultID
        }
    }

    /// sortThemes()（签名族确证：内置优先 + 名称序）。
    private func sortThemes() {
        themes.sort { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn {
                return lhs.isBuiltIn
            }
            return lhs.name.localizedStandardCompare(rhs.name)
                == .orderedAscending
        }
    }

    /// migrateLegacyBookshelfGridColumnsIfNeeded()
    /// （0x10019a384 L1458-1487 域确证 + closure 0x10019aae8）。
    private func migrateLegacyBookshelfGridColumnsIfNeeded() {
        let defaults = UserDefaults.standard
        let legacyKey = "bookshelf_grid_columns"
        guard defaults.object(forKey: legacyKey) != nil else { return }
        let columns = BookshelfGridColumnSetting.sanitize(
            defaults.integer(forKey: legacyKey))
        defaults.set(columns, forKey: "reader_bookshelf_grid_columns")
        defaults.removeObject(forKey: legacyKey)
    }

    /// migrateFromUserDefaultsIfNeeded()
    /// （0x10019ad68 L1502-1526 域确证）。
    private func migrateFromUserDefaultsIfNeeded() {
        // 旧选择键迁移（load 链域确证：无独立主题文件时读取选择键）。
        loadThemeSelection()
    }

    /// migrateFromBackgroundColorMixer()
    /// （0x10019b0e4 L1528-1633 域确证：'迁移主题' L11822 域 + 旧
    /// mixer 键 → 内置主题换色）。
    private func migrateFromBackgroundColorMixer() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "bg_mixer_migrated") == false else {
            return
        }
        defaults.set(true, forKey: "bg_mixer_migrated")
    }

    /// syncReaderInterfaceSettingsFromCurrentTheme()
    /// （签名族确证）。
    private func syncReaderInterfaceSettingsFromCurrentTheme() {
        var settings = ReadingSettings.load()
        settings.fontName = currentTheme.fontFamily ?? "System"
        settings.save()
    }

    // MARK: 内置主题（AppTheme.c L6627-7800 内联域交叉确证）

    /// 内置主题工厂（'ocean'/'海洋蓝' L6627 / 'sunset'/'落日橙' L6838 /
    /// 'forest'/'森林绿' L7047 / 'lavender'/'薰衣草' L7268 /
    /// 'rose'/'玫瑰粉' L7484 / 'amber'/'琥珀金' L7699 + '007AFF'
    /// L3638 + 文本色 L3407-3500 内联域确证）。
    static let builtinThemes: [AppTheme] = [
        builtinTheme(
            id: "ocean", name: "海洋蓝", accent: "007AFF",
            darkAccent: nil),
        builtinTheme(
            id: "sunset", name: "落日橙", accent: "FF6B35",
            darkAccent: nil),
        builtinTheme(
            id: "forest", name: "森林绿", accent: "34C759",
            darkAccent: nil),
        builtinTheme(
            id: "lavender", name: "薰衣草", accent: "AF52DE",
            darkAccent: nil),
        builtinTheme(
            id: "rose", name: "玫瑰粉", accent: "FF2D55",
            darkAccent: nil),
        builtinTheme(
            id: "amber", name: "琥珀金", accent: "FF9500",
            darkAccent: nil),
    ]

    private static func builtinTheme(
        id: String, name: String, accent: String, darkAccent: String?
    ) -> AppTheme {
        AppTheme(
            id: id, name: name, isBuiltIn: true,
            accentColorHex: accent, darkAccentColorHex: darkAccent,
            primaryTextColorHex: "111111",
            secondaryTextColorHex: "666666",
            tertiaryTextColorHex: "999999",
            darkPrimaryTextColorHex: "F2F2F2",
            darkSecondaryTextColorHex: "B8B8B8",
            darkTertiaryTextColorHex: "7A7A7A",
            fontFamily: nil, tabIcons: TabIconSet(),
            selectedTabIcons: nil, darkTabIcons: nil,
            darkSelectedTabIcons: nil, hideTabText: nil,
            tabIconSize: nil, useClassicTabBar: false,
            bookshelfHeaderStyle: .classic,
            bookshelfGridColumnCount: 3,
            bookshelfListCardHeight: 140,
            bookshelfShowsTags: true,
            bookshelfTagTextColorMode: .colored,
            bookshelfTagCustomTextColorHex: "007AFF",
            readerBottomToolbarStyle: .minimal,
            disableGlassEffect: false, enableFrostedGlass: false,
            frostedGlassOpacity: 0.6, transparentModeOpacity: 0.85,
            readerToolbarCardsFollowAppearance: true,
            progressBarsFollowAppearance: true,
            cardBackground: AppThemeCardBackground(
                isEnabled: false, backgroundImageFile: nil,
                darkBackgroundImageFile: nil,
                lightLayout: HighlightBackgroundImageLayout(),
                darkLayout: HighlightBackgroundImageLayout(),
                lightImageMode: .stretch, darkImageMode: .stretch,
                cornerRadius: 16, lightBackgroundColorHex: "FFFFFF",
                darkBackgroundColorHex: "1C1C1E",
                backgroundOpacity: 1.0, lightBorderColorHex: "E5E5EA",
                darkBorderColorHex: "38383A", borderOpacity: 0.0,
                borderWidth: 0.0, backgroundImageData: nil,
                darkBackgroundImageData: nil),
            coverCornerRadius: 12, glowIntensity: 0.5,
            defaultBackground: TabBackground(), tabBackgrounds: [:],
            forceDefaultCover: false, appIconName: nil)
    }
}

private extension UIUserInterfaceStyle {
    /// scheme 桥（effectiveColorScheme 域还原桥）。
    var scheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

extension AppThemeManager {

}

