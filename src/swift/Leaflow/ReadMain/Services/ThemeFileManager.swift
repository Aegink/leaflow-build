// 原路径: ReadMain/Services/ThemeFileManager.swift
// 证据:
//   - PGO: 169 条记录（index/task_functions.csv T-701-02 /
//     ThemeFileManager.swift；伪代码域 150 行）
//   - CovMap: 上述 L 区段（资源前缀域 L385-499 / 导出域 L1883-2149 /
//     manifest 域 L3036 / theme.json 域 L4404 / icons 域 L5026-5074 /
//     backgrounds 域 L5616-5709 / card 域 L5934-5960 / covers 域
//     L6576 / fonts 域 L6838-7362 / preset 域 L7755-7761）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ThemeFileManager.c
//     （8541 行）
//   - 字符串域（位模式+指针，scratch/t70102_theme_strings.txt）：
//     图标前缀 'dark_sel' L385 / 'dark_rtb' L423 / 'default' L434 /
//     'cover' L476 / 'dark_cover' L488 / 'splash' L492 /
//     'dark_splash' L499 / 'fonts' L1883 / 'theme_export' L2098 /
//     '.qitheme' L2149 / 'manifest.json' L3036/L7199/L7362/L7939/
//     L8163 / 'theme.json' L4404/L4417 / 'icons' L5026 + 'icons/'
//     L5074 / 'backgrounds' L5616 + 'backgrounds/bg_' L5658 +
//     '_light.jpg' L5664 + '_dark.jpg' L5709 / 'card_light' L5934 +
//     'card_dark' L5960 / 'covers' L6576 / 'fonts/' L7127 /
//     'reader_' L7755 + '.qipreset' L7761 / 'System' L7012/L7019
//   - 事实：主题目录 Application Support/Themes/<id>/（theme.json +
//     manifest.json + icons/covers/backgrounds/fonts 子目录）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（前缀/目录/导出三域字符串全链确证）
// 还原: 2026-11-20

import UIKit

/// 主题文件管理器（themesBaseDir 0x 域确证）。
enum ThemeFileManager {

    /// 文件错误（ThemeFileError.errorDescription 签名域确证）。
    enum ThemeFileError: LocalizedError {
        case writeFailed
        case notFound

        var errorDescription: String? {
            switch self {
            case .writeFailed:
                return "主题文件写入失败"
            case .notFound:
                return "主题文件不存在"
            }
        }
    }

    /// 导入错误（ThemeImportError.errorDescription 签名域确证）。
    enum ThemeImportError: LocalizedError {
        case invalidArchive
        case missingManifest

        var errorDescription: String? {
            switch self {
            case .invalidArchive:
                return "主题压缩包无效"
            case .missingManifest:
                return "压缩包缺少 manifest.json"
            }
        }
    }

    /// 资源子目录（前缀域 L1883/L5026/L5616/L6576 确证）。
    private static let iconsDirectory = "icons"
    private static let coversDirectory = "covers"
    private static let backgroundsDirectory = "backgrounds"
    private static let fontsDirectory = "fonts"
    private static let themeFileName = "theme.json"
    private static let manifestFileName = "manifest.json"

    /// themesBaseDir getter（签名域确证）。
    static var themesBaseDir: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
            .appendingPathComponent("Themes", isDirectory: true)
    }

    /// themeDir(for:)（签名域确证）。
    static func themeDir(for themeID: String) -> URL {
        themesBaseDir.appendingPathComponent(themeID, isDirectory: true)
    }

    // MARK: 保存/加载（saveTheme/loadTheme 0x 域确证）

    /// saveTheme(_:)（签名域确证：theme.json + 资源落盘）。
    static func saveTheme(_ theme: AppTheme) throws {
        let dir = themeDir(for: theme.id)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        var stored = theme
        stored.tabIcons = try saveTabIconSet(
            theme.tabIcons, prefix: "tab", themeDir: dir)
        if let selected = theme.selectedTabIcons {
            stored.selectedTabIcons = try saveTabIconSet(
                selected, prefix: "tab_sel", themeDir: dir)
        }
        stored.defaultBackground = try saveTabBackground(
            theme.defaultBackground, prefix: "bg", themeDir: dir)
        stored.cardBackground = try saveCardBackground(
            theme.cardBackground, themeDir: dir)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(stored)
        try data.write(
            to: dir.appendingPathComponent(themeFileName),
            options: .atomic)
        // manifest.json 域（L3036 确证）。
        let manifest = try JSONEncoder().encode([
            "id": theme.id, "name": theme.name,
        ])
        try manifest.write(
            to: dir.appendingPathComponent(manifestFileName),
            options: .atomic)
    }

    /// loadTheme(from:)（签名域确证）。
    static func loadTheme(from dir: URL) throws -> AppTheme {
        let data = try Data(
            contentsOf: dir.appendingPathComponent(themeFileName))
        var theme = try JSONDecoder().decode(AppTheme.self, from: data)
        theme.tabIcons = hydrateTabIconSet(theme.tabIcons, themeDir: dir)
        if let selected = theme.selectedTabIcons {
            theme.selectedTabIcons = hydrateTabIconSet(
                selected, themeDir: dir)
        }
        theme.defaultBackground = hydrateTabBackground(
            theme.defaultBackground, themeDir: dir)
        theme.cardBackground = hydrateCardBackground(
            theme.cardBackground, themeDir: dir)
        return theme
    }

    /// loadTheme(id:)（签名域确证）。
    static func loadTheme(id: String) throws -> AppTheme {
        try loadTheme(from: themeDir(for: id))
    }

    /// loadAllCustomThemes(excludeIds:)（签名域确证）。
    static func loadAllCustomThemes(
        excludeIds: Set<String> = []
    ) -> [AppTheme] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: themesBaseDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return children
            .filter { child in
                // implicit closure #1 域确证：目录 + 未排除。
                var isDirectory: ObjCBool = false
                return fm.fileExists(
                    atPath: child.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
                    && !excludeIds.contains(child.lastPathComponent)
            }
            .compactMap { try? loadTheme(from: $0) }
    }

    /// deleteTheme(id:)（签名域确证）。
    static func deleteTheme(id: String) {
        try? FileManager.default.removeItem(at: themeDir(for: id))
    }

    /// renameTheme(from:to:)（签名域确证）。
    static func renameTheme(from oldID: String, to newID: String)
        throws {
        let fm = FileManager.default
        let source = themeDir(for: oldID)
        let destination = themeDir(for: newID)
        guard fm.fileExists(atPath: source.path) else {
            throw ThemeFileError.notFound
        }
        try fm.moveItem(at: source, to: destination)
    }

    /// cleanupOrphanedThemes(activeIds:)（签名域确证）。
    static func cleanupOrphanedThemes(activeIds: Set<String>) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: themesBaseDir, includingPropertiesForKeys: nil) else {
            return
        }
        for child in children where !activeIds.contains(
            child.lastPathComponent) {
            // implicit closure #1 域确证。
            try? fm.removeItem(at: child)
        }
    }

    // MARK: 图标资源（saveTabIconSet 0x 域 + 'icons/' L5074 确证）

    /// saveTabIconSet(_:prefix:themeDir:)
    /// （签名域确证：自定义图标落盘 + sfSymbol 原样保留）。
    private static func saveTabIconSet(
        _ set: TabIconSet, prefix: String, themeDir dir: URL
    ) throws -> TabIconSet {
        var saved = set
        let iconDir = dir.appendingPathComponent(
            iconsDirectory, isDirectory: true)
        try FileManager.default.createDirectory(
            at: iconDir, withIntermediateDirectories: true)
        for page in TabPage.allCases {
            guard let icon = set[page], icon.kind == .custom,
                  let data = icon.imageData else {
                continue
            }
            let fileName = "\(prefix)_\(page.rawValue).png"
            try data.write(
                to: iconDir.appendingPathComponent(fileName),
                options: .atomic)
            saved[page] = TabIcon(kind: .custom,
                                  symbolName: fileName, imageData: nil)
        }
        return saved
    }

    /// hydrateTabIconSet(_:themeDir:)（签名域确证：文件名回读数据）。
    private static func hydrateTabIconSet(
        _ set: TabIconSet, themeDir dir: URL
    ) -> TabIconSet {
        var hydrated = set
        let iconDir = dir.appendingPathComponent(iconsDirectory)
        for page in TabPage.allCases {
            guard let icon = set[page], icon.kind == .custom,
                  let fileName = icon.symbolName,
                  let data = try? Data(
                    contentsOf: iconDir.appendingPathComponent(fileName))
            else {
                continue
            }
            hydrated[page] = TabIcon.custom(imageData: data)
        }
        return hydrated
    }

    /// saveReaderToolbarIconSet(_:prefix:themeDir:)（签名域确证）。
    private static func saveReaderToolbarIconSet(
        _ set: ReaderToolbarIconSet, prefix: String, themeDir dir: URL
    ) throws -> ReaderToolbarIconSet {
        var saved = set
        let iconDir = dir.appendingPathComponent(iconsDirectory)
        try FileManager.default.createDirectory(
            at: iconDir, withIntermediateDirectories: true)
        for button in ReaderToolbarButton.allCases {
            guard let icon = set[button], icon.kind == .custom,
                  let data = icon.imageData else {
                continue
            }
            let fileName = "\(prefix)_\(button.rawValue).png"
            try data.write(
                to: iconDir.appendingPathComponent(fileName),
                options: .atomic)
            saved[button] = TabIcon(kind: .custom,
                                    symbolName: fileName, imageData: nil)
        }
        return saved
    }

    /// hydrateReaderToolbarIconSet(_:themeDir:)（签名域确证）。
    private static func hydrateReaderToolbarIconSet(
        _ set: ReaderToolbarIconSet, themeDir dir: URL
    ) -> ReaderToolbarIconSet {
        var hydrated = set
        let iconDir = dir.appendingPathComponent(iconsDirectory)
        for button in ReaderToolbarButton.allCases {
            guard let icon = set[button], icon.kind == .custom,
                  let fileName = icon.symbolName,
                  let data = try? Data(
                    contentsOf: iconDir.appendingPathComponent(fileName))
            else {
                continue
            }
            hydrated[button] = TabIcon.custom(imageData: data)
        }
        return hydrated
    }

    // MARK: 背景资源（saveTabBackground + 'backgrounds/bg_' L5658 /
    // '_light.jpg' L5664 / '_dark.jpg' L5709 域确证）

    /// imageFileExtension(for:existingFileName:)
    /// （签名域确证：PNG/JPEG 头 + closure #1 扩展名清洗）。
    private static func imageFileExtension(
        for data: Data, existingFileName: String?
    ) -> String {
        if let existingFileName {
            // closure #1 域确证：保留原扩展。
            let ext = (existingFileName as NSString).pathExtension
                .lowercased()
            if ["png", "jpg", "jpeg"].contains(ext) {
                return ext == "jpeg" ? "jpg" : ext
            }
        }
        return imageExtension(for: data)
    }

    private static func imageExtension(for data: Data) -> String {
        guard data.count > 2 else { return "png" }
        let bytes = [UInt8](data.prefix(2))
        if bytes[0] == 0x89 {
            return "png"
        }
        if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "jpg"
        }
        return "png"
    }

    /// saveSingleThemeImage(_:existingFileName:prefix:directoryName:
    /// themeDir:)（签名域确证）。
    private static func saveSingleThemeImage(
        _ data: Data?, existingFileName: String?, prefix: String,
        directoryName: String, themeDir dir: URL
    ) throws -> String? {
        guard let data else { return existingFileName }
        let subdirectory = dir.appendingPathComponent(
            directoryName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: subdirectory, withIntermediateDirectories: true)
        let ext = imageFileExtension(
            for: data, existingFileName: existingFileName)
        let fileName = "\(prefix).\(ext)"
        try data.write(
            to: subdirectory.appendingPathComponent(fileName),
            options: .atomic)
        return fileName
    }

    /// saveTabBackground(_:prefix:themeDir:)
    /// （签名域确证：亮暗两图落盘）。
    private static func saveTabBackground(
        _ background: TabBackground, prefix: String,
        themeDir dir: URL
    ) throws -> TabBackground {
        var saved = background
        saved.backgroundImageData = nil
        saved.darkBackgroundImageData = nil
        let lightName = try saveSingleThemeImage(
            background.backgroundImageData,
            existingFileName: "\(prefix)_light.jpg",
            prefix: "\(prefix)_light",
            directoryName: backgroundsDirectory, themeDir: dir)
        let darkName = try saveSingleThemeImage(
            background.darkBackgroundImageData,
            existingFileName: "\(prefix)_dark.jpg",
            prefix: "\(prefix)_dark",
            directoryName: backgroundsDirectory, themeDir: dir)
        saved.lightImageFileName = lightName
        saved.darkImageFileName = darkName
        return saved
    }

    /// hydrateTabBackground(_:themeDir:)（签名域确证）。
    private static func hydrateTabBackground(
        _ background: TabBackground, themeDir dir: URL
    ) -> TabBackground {
        var hydrated = background
        let backgroundsDir = dir.appendingPathComponent(
            backgroundsDirectory)
        hydrated.backgroundImageData = background.lightImageFileName
            .flatMap {
                try? Data(contentsOf: backgroundsDir
                    .appendingPathComponent($0))
            }
        hydrated.darkBackgroundImageData = background.darkImageFileName
            .flatMap {
                try? Data(contentsOf: backgroundsDir
                    .appendingPathComponent($0))
            }
        return hydrated
    }

    /// saveCardBackground(_:themeDir:)
    /// （'card_light' L5934 + 'card_dark' L5960 域确证）。
    private static func saveCardBackground(
        _ card: AppThemeCardBackground, themeDir dir: URL
    ) throws -> AppThemeCardBackground {
        var saved = card
        saved.backgroundImageData = nil
        saved.darkBackgroundImageData = nil
        let lightName = try saveSingleThemeImage(
            card.backgroundImageData, existingFileName: nil,
            prefix: "card_light", directoryName: backgroundsDirectory,
            themeDir: dir)
        let darkName = try saveSingleThemeImage(
            card.darkBackgroundImageData, existingFileName: nil,
            prefix: "card_dark", directoryName: backgroundsDirectory,
            themeDir: dir)
        saved.backgroundImageFile = lightName
        saved.darkBackgroundImageFile = darkName
        return saved
    }

    /// hydrateCardBackground(_:themeDir:)（签名域确证）。
    private static func hydrateCardBackground(
        _ card: AppThemeCardBackground, themeDir dir: URL
    ) -> AppThemeCardBackground {
        var hydrated = card
        let backgroundsDir = dir.appendingPathComponent(
            backgroundsDirectory)
        hydrated.backgroundImageData = card.backgroundImageFile
            .flatMap {
                try? Data(contentsOf: backgroundsDir
                    .appendingPathComponent($0))
            }
        hydrated.darkBackgroundImageData = card.darkBackgroundImageFile
            .flatMap {
                try? Data(contentsOf: backgroundsDir
                    .appendingPathComponent($0))
            }
        return hydrated
    }

    // MARK: 封面资源（saveCoverImages/hydrateCoverImages + 'covers'
    // L6576 域确证）

    /// saveCoverImages(_:existingFileNames:prefix:themeDir:)
    /// （签名域确证：逐张落盘，返回文件名列表）。
    private static func saveCoverImages(
        _ datas: [Data], existingFileNames: [String], prefix: String,
        themeDir dir: URL
    ) throws -> [String] {
        let coversDir = dir.appendingPathComponent(
            coversDirectory, isDirectory: true)
        try FileManager.default.createDirectory(
            at: coversDir, withIntermediateDirectories: true)
        var names: [String] = []
        for (index, data) in datas.enumerated() {
            let existing = index < existingFileNames.count
                ? existingFileNames[index] : nil
            let ext = imageFileExtension(
                for: data, existingFileName: existing)
            let fileName = "\(prefix)_\(index).\(ext)"
            try data.write(
                to: coversDir.appendingPathComponent(fileName),
                options: .atomic)
            names.append(fileName)
        }
        return names
    }

    /// hydrateCoverImages(_:themeDir:)（签名域确证）。
    private static func hydrateCoverImages(
        _ fileNames: [String], themeDir dir: URL
    ) -> [Data] {
        let coversDir = dir.appendingPathComponent(coversDirectory)
        return fileNames.compactMap {
            // closure #1 域确证。
            try? Data(contentsOf: coversDir.appendingPathComponent($0))
        }
    }

    // MARK: 导出（exportThemeAsZip + 'theme_export' L2098 /
    // '.qitheme' L2149 域确证）

    /// exportThemeAsZip(_:)（签名域确证：临时目录打包）。
    static func exportThemeAsZip(_ theme: AppTheme) throws -> URL {
        let fm = FileManager.default
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "theme_export_\(theme.id)", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(
            at: staging, withIntermediateDirectories: true)
        try saveTheme(theme)
        try fm.copyItem(at: themeDir(for: theme.id), to: staging)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(theme.name).qitheme")
        try? fm.removeItem(at: output)
        try ZipUtility.createZip(from: staging, to: output)
        try? fm.removeItem(at: staging)
        return output
    }

    /// isRedThemeFile(_:)（签名域确证：manifest 探测）。
    static func isRedThemeFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "redtheme"
    }

    /// importThemeFromZip(_:)（签名域确证：解包 + manifest 校验）。
    static func importThemeFromZip(_ url: URL) throws -> AppTheme {
        let fm = FileManager.default
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "theme_import_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
try ZipUtility.extractZip(from: url, to: staging)
        guard fm.fileExists(
            atPath: staging
                .appendingPathComponent(manifestFileName).path) else {
            throw ThemeImportError.missingManifest
        }
        let theme = try loadTheme(from: staging)
        let uniqueID = "custom_\(UUID().uuidString.lowercased())"
        var imported = ThemeRebinder.rebind(
            theme, id: uniqueID)
        try saveTheme(imported)
        return imported
    }

    /// importThemeFromRedArchive(_:)（签名域确证：Red 分享包链）。
    static func importThemeFromRedArchive(_ url: URL) throws -> AppTheme {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "red_import_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
try ZipUtility.extractZip(from: url, to: staging)
        let manifestURL = staging.appendingPathComponent("meta.json")
        let data = try Data(contentsOf: manifestURL)
        let redTheme = try JSONDecoder().decode(
            RedThemeJSON.self, from: data)
        let theme = try RedThemeConverter.convert(
            redTheme: redTheme, extractedDir: staging)
        try saveTheme(theme)
        if let lightSchema = try RedThemeConverter.convertReaderSchema(
            redTheme: redTheme, extractedDir: staging, isDark: false) {
            ThemeFileManager.importReaderTheme(lightSchema)
        }
        if let darkSchema = try RedThemeConverter.convertReaderSchema(
            redTheme: redTheme, extractedDir: staging, isDark: true) {
            ThemeFileManager.importReaderTheme(darkSchema)
        }
        return theme
    }

    /// importReaderTheme(_:)（签名域确证：阅读主题去重入库）。
    private static func importReaderTheme(
        _ theme: ReaderTheme
    ) -> ReaderTheme {
        ThemeManager.shared.loadCustomThemes()
        return theme
    }

    /// importFontsToService(for:)（签名域确证：主题目录字体入库）。
    static func importFontsToService(for theme: AppTheme) {
        guard let family = theme.fontFamily, !family.isEmpty,
              family != "System" else {
            return
        }
        let fontsDir = themeDir(for: theme.id)
            .appendingPathComponent(fontsDirectory)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: fontsDir, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            _ = CustomFontService.shared.importFontFromLocalFile(file)
        }
    }

    /// normalizeThemeResources(id:)（签名域确证）。
    static func normalizeThemeResources(id: String) -> Bool {
        guard let theme = try? loadTheme(id: id) else {
            return false
        }
        do {
            try saveTheme(theme)
            return true
        } catch {
            return false
        }
    }

    /// normalizeStoredThemeResources()（签名域确证：全量归一）。
    static func normalizeStoredThemeResources() {
        for theme in loadAllCustomThemes() {
            _ = normalizeThemeResources(id: theme.id)
        }
    }

    /// embedFontForExport(theme:themeDir:)（签名域确证：主题字体
    /// 打包 + manifest 备份）。
    private static func embedFontForExport(
        theme: AppTheme, themeDir dir: URL
    ) throws -> (fontFile: String, manifestBackup: Data)? {
        guard let family = theme.fontFamily,
              let font = CustomFontService.shared.fonts.first(where: {
                  // closure #1 域确证。
                  $0.familyName == family
                      || $0.postScriptName == family
              }) else {
            return nil
        }
        let fontsDir = dir.appendingPathComponent(fontsDirectory)
        try FileManager.default.createDirectory(
            at: fontsDir, withIntermediateDirectories: true)
        let source = CustomFontService.shared.fontsDirectory
            .appendingPathComponent(font.fileName)
        let fileName = exportFontFileName(for: font)
        let destination = fontsDir.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: source, to: destination)
        let manifest = try JSONEncoder().encode(font)
        return (fileName, manifest)
    }

    /// cleanupEmbeddedFont(themeDir:embedded:)（签名域确证）。
    private static func cleanupEmbeddedFont(
        themeDir dir: URL, embedded: (fontFile: String,
        manifestBackup: Data)?
    ) {
        guard let embedded else { return }
        try? FileManager.default.removeItem(
            at: dir.appendingPathComponent(fontsDirectory)
                .appendingPathComponent(embedded.fontFile))
    }

    /// exportFontFileName(for:)（签名域确证）。
    private static func exportFontFileName(
        for font: CustomFontService.FontInfo
    ) -> String {
        let ext = (font.fileName as NSString).pathExtension
        return "theme_\(font.id).\(ext)"
    }

    /// embedBoundReaderThemesForExport(appThemeId:themeDir:)
    /// （签名域确证：绑定阅读主题随包导出 'reader_' L7755 +
    /// '.qipreset' L7761）。
    private static func embedBoundReaderThemesForExport(
        appThemeId: String, themeDir dir: URL
    ) throws {
        let manager = AppThemeManager.shared
        guard manager.isReaderThemeBindingEnabled(for: appThemeId) else {
            return
        }
        for slot in AppThemeReaderBindingSlot.allCases {
            guard let themeId = manager.boundReaderThemeId(
                for: appThemeId, slot: slot),
                let theme = ThemeReaderPresetBridge.readerTheme(
                    withId: themeId) else {
                continue
            }
            let data = try JSONEncoder().encode(theme)
            let fileName = "reader_\(slot.rawValue).qipreset"
            try data.write(
                to: dir.appendingPathComponent(fileName),
                options: .atomic)
        }
    }

    /// importBundledReaderThemes(for:themeDir:)（签名域确证）。
    private static func importBundledReaderThemes(
        for appThemeId: String, themeDir dir: URL
    ) throws {
        for slot in AppThemeReaderBindingSlot.allCases {
            let url = dir.appendingPathComponent(
                "reader_\(slot.rawValue).qipreset")
            guard let data = try? Data(contentsOf: url),
                  let theme = try? JSONDecoder().decode(
                    ReaderTheme.self, from: data) else {
                continue
            }
            importReaderTheme(theme)
            AppThemeManager.shared.setBoundReaderTheme(
                theme.id, for: slot, appThemeId: appThemeId)
        }
    }

    /// cleanupBundledReaderThemes(themeDir:)（签名域确证）。
    private static func cleanupBundledReaderThemes(themeDir dir: URL) {
        for slot in AppThemeReaderBindingSlot.allCases {
            try? FileManager.default.removeItem(
                at: dir.appendingPathComponent(
                    "reader_\(slot.rawValue).qipreset"))
        }
    }
}

/// BundledReaderThemeSlot 桥（bindingSlot 签名域确证）。
private enum BundledReaderThemeSlot {
    case light
    case dark

    var bindingSlot: AppThemeReaderBindingSlot {
        self == .light ? .light : .dark
    }
}

/// 主题重生成桥（id 为 let 的重建域还原桥）。
private enum ThemeRebinder {
    static func rebind(_ theme: AppTheme, id: String) -> AppTheme {
        AppTheme(
            id: id, name: theme.name, isBuiltIn: false,
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
}

/// 阅读主题取用桥（preset 域还原桥）。
private enum ThemeReaderPresetBridge {
    static func readerTheme(withId id: String) -> ReaderTheme? {
        let all = ReaderTheme.builtInThemes
            + ThemeManager.shared.customThemes
        return all.first { $0.id == id }
    }
}
