// 原路径: ReadMain/Services/CustomFontService.swift
// 证据:
//   - PGO: 70 条记录（index/task_functions.csv T-701-02 /
//     CustomFontService.swift；伪代码域 130 行）
//   - CovMap: 上述 L 区段（FontInfo L13-60 / 目录 L65-102 / 导入链
//     L180-669 / CSS 域 L3140-3204 / 描述域 L3352-3417 / MIME 域
//     L3990-4027）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/CustomFontService.c
//     （4047 行）
//   - 字符串域（位模式+指针，scratch/t70102_font_strings.txt）：
//     'CustomFonts' L102（字体子目录）/ '删除字体: ' L2543 /
//     'System' L2602/L3497（系统字体名比对）/ @font-face 域
//     "url('" L3140 + " format('" L3165 + "';src:" L3197 /
//     '阅读字体' L3352 / '主题「' L3372 / '阅读主题「' L3417 /
//     MIME 域 'font/ttf' L3990-3991 / 'font/otf' L3997-3998 /
//     'font/collection' L4011 / 'font/woff' L4019-4027 /
//     'woff2' L4023 / CTFont 诊断 'undefined' L54 / '(null)' L65 /
//     ', error: ' L669
//   - 事实：0x100317cbc/0x100317a54确证Documents/CustomFonts +
//     字体清单 UserDefaults JSON（loadFontList/saveFontList 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（导入/CSS/MIME 三域字符串全链确证）
// 还原: 2026-11-20

import UIKit

/// 自定义字体服务（Documents/CustomFonts，清单键importedCustomFonts）。
/// @MainActor：currentTheme/ReadingSettings 域均为 MainActor 隔离——
/// 消费方（设置视图）亦然（wave-16）。
@MainActor
final class CustomFontService {

    /// 导入错误（errorDescription 签名域确证）。
    enum FontImportError: LocalizedError {
        case unsupportedFormat
        case readFailed
        case duplicate
        case invalidFont

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "不支持的字体格式（仅 ttf/otf/ttc/woff/woff2）"
            case .readFailed:
                return "字体文件读取失败"
            case .duplicate:
                return "字体已存在"
            case .invalidFont:
                return "文件不包含有效字体"
            }
        }
    }

    static let shared = CustomFontService()

    static let fontListDefaultsKey = "importedCustomFonts"
    private static let fontsSubdirectory = "CustomFonts"

    private(set) var fonts: [FontInfo] = []
    private let defaults: UserDefaults
    private let documentsDirectory: URL
    private let supportDirectory: URL
    private let registerFonts: Bool

    /// fontsDirectory getter（签名域确证）。
    var fontsDirectory: URL {
        documentsDirectory.appendingPathComponent(Self.fontsSubdirectory, isDirectory: true)
    }

    init(documentsDirectory: URL? = nil, applicationSupportDirectory: URL? = nil,
         defaults: UserDefaults = .standard, registerFonts: Bool = true) {
        self.defaults = defaults
        self.documentsDirectory = documentsDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        supportDirectory = applicationSupportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.registerFonts = registerFonts
        loadFontList()
        migrateLegacyFontFiles()
        registerAllFonts()
    }

    // MARK: 注册（registerAllFonts 签名域确证：CTFontManager 全量注册）

    /// registerAllFonts()（签名域确证：closure #1/#2 CFError 计数域）。
    func registerAllFonts() {
        guard registerFonts else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: fontsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            CTFontManagerRegisterFontsForURL(
                file as CFURL, .process, nil)
        }
    }

    // MARK: 导入（importFont 0x 域 + MIME 域 L3990-4027 确证）

    /// fontWebMetadata(forExtension:)（签名域确证：MIME 域
    /// 'font/ttf' L3990 / 'font/otf' L3997 / 'font/collection' L4011 /
    /// 'font/woff' L4019 / 'woff2' L4023）。
    private func fontWebMetadata(
        forExtension ext: String
    ) -> (mimeType: String, formatName: String?) {
        switch ext.lowercased() {
        case "ttf":
            return ("font/ttf", "truetype")
        case "otf":
            return ("font/otf", "opentype")
        case "ttc":
            return ("font/collection", "truetype-collection")
        case "woff":
            return ("font/woff", "woff")
        case "woff2":
            return ("font/woff2", "woff2")
        default:
            return ("application/octet-stream", nil)
        }
    }

    /// importedFileName(from:)（签名域确证：UUID 文件名 + 原扩展）。
    private func importedFileName(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return "\(UUID().uuidString).\(ext)"
    }

    /// importFont(from:)（签名域确证：安全域书签导入 → 拷贝 → 注册）。
    func importFont(
        from url: URL
    ) -> Result<FontInfo, FontImportError> {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        return importFontFromLocalFile(url)
    }

    /// importFontFromLocalFile(_:)（签名域确证：格式守卫 + 去重 +
    /// 拷贝 + CTFontManager 注册 + 清单回写）。
    func importFontFromLocalFile(
        _ url: URL
    ) -> Result<FontInfo, FontImportError> {
        let ext = url.pathExtension.lowercased()
        let metadata = fontWebMetadata(forExtension: ext)
        guard metadata.formatName != nil else {
            return .failure(.unsupportedFormat)
        }
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.readFailed)
        }
        // 原版导入先读文件描述符及kCTFontNameAttribute，再复制和注册。
        guard let descriptor = Self.descriptor(of: url),
              let postScriptName = (CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String).flatMap(FontInfo.readableName)
        else { return .failure(.invalidFont) }
        if fonts.contains(where: {
            $0.postScriptName == postScriptName
        }) {
            return .failure(.duplicate)
        }
        do {
            try FileManager.default.createDirectory(
                at: fontsDirectory, withIntermediateDirectories: true)
            let newFileName = importedFileName(from: url)
            let destination = fontsDirectory
                .appendingPathComponent(newFileName)
            try data.write(to: destination, options: .atomic)
            registerFontFile(at: destination)
            let info = FontInfo(
                id: UUID().uuidString, fileName: newFileName,
                originalFileName: url.lastPathComponent,
                postScriptName: postScriptName,
                familyName: CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String,
                importedAt: Date(), displayName: CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String)
            fonts.append(info)
            saveFontList()
            return .success(info)
        } catch {
            return .failure(.readFailed)
        }
    }

    private func registerFontFile(at url: URL) {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private static func postScriptName(of url: URL) -> String? {
        descriptor(of: url).flatMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
    }

    private static func familyName(of url: URL) -> String? {
        descriptor(of: url).flatMap { CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String }
    }

    private static func descriptor(of url: URL) -> CTFontDescriptor? {
        (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
    }

    /// deleteFont(_:)（'删除字体: ' L2543 域确证：删文件 + 反注册 +
    /// 清单收窄 + 引用回退）。
    func deleteFont(_ font: FontInfo) {
        let url = fontsDirectory.appendingPathComponent(font.fileName)
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        try? FileManager.default.removeItem(at: url)
        fonts.removeAll { $0.id == font.id }
        resetFontReferences(font.name)
        saveFontList()
    }

    // MARK: 展示域（displayName 0x 域 + '阅读字体' L3352 确证）

    /// displayName(forFontFamily:systemName:)（签名域确证：自定义
    /// 命中 → internalDisplayName，否则系统名）。
    func displayName(
        forFontFamily family: String, systemName: String
    ) -> String {
        if let match = fonts.first(where: {
            // closure #1 域确证：familyName/PostScript 双匹配。
            $0.familyName == family || $0.postScriptName == family
        }) {
            return match.internalDisplayName
        }
        return systemName
    }

    /// isCustomFont(_:)（签名域确证）。
    static func isCustomFont(_ family: String) -> Bool {
        shared.fonts.contains(where: {
            // closure #1 域确证。
            $0.familyName == family || $0.postScriptName == family
        })
    }

    /// fontUsageDescriptions(_:)（签名域确证：'阅读字体' L3352 /
    /// '主题「' L3372 / '阅读主题「' L3417 描述域）。
    func fontUsageDescriptions(_ family: String) -> [String] {
        var descriptions: [String] = []
        if Self.isCustomFont(family) {
            descriptions.append("阅读字体")
        }
        let current = AppThemeManager.shared.currentTheme
        if current.fontFamily == family {
            descriptions.append("主题「\(current.name)」")
        }
        return descriptions
    }

    // MARK: CSS 域（fontFaceCSSWithFileURL 0x 域 + L3140-3197 确证）

    /// escapeCSSString(_:)（签名域确证）。
    private func escapeCSSString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    /// fontFaceCSSWithFileURL(for:cssFamilyName:)
    /// （@font-face 域 "url('" L3140 + " format('" L3165 +
    /// "';src:" L3197 确证）。
    func fontFaceCSSWithFileURL(
        for family: String, cssFamilyName: String
    ) -> String? {
        guard let font = fonts.first(where: {
            // closure #1 域确证。
            $0.familyName == family || $0.postScriptName == family
        }) else {
            return nil
        }
        let fileURL = fontsDirectory
            .appendingPathComponent(font.fileName)
        let metadata = fontWebMetadata(
            forExtension: (font.fileName as NSString).pathExtension)
        let format = metadata.formatName ?? "truetype"
        let escapedFamily = escapeCSSString(cssFamilyName)
        return "@font-face { font-family: '\(escapedFamily)';"
            + "src:url('\(fileURL.absoluteString)')"
            + " format('\(format)'); }"
    }

    // MARK: 清单域（loadFontList/compactStoredFontList/saveFontList
    // 签名域确证）

    private func loadFontList() {
        guard let data = defaults.data(forKey: Self.fontListDefaultsKey) ?? defaults.data(forKey: "reader_custom_fonts"),
              let stored = try? JSONDecoder().decode(
                [FontInfo].self, from: data) else {
            fonts = []
            return
        }
        fonts = stored
    }

    /// compactStoredFontList()（closure #1 域确证：剔除缺文件项）。
    private func compactStoredFontList() {
        let fm = FileManager.default
        fonts = fonts.filter { font in
            // closure #1 域确证。
            fm.fileExists(
                atPath: fontsDirectory
                    .appendingPathComponent(font.fileName).path)
        }
    }

    private func saveFontList() {
        if let data = try? JSONEncoder().encode(fonts) {
            defaults.set(data, forKey: Self.fontListDefaultsKey)
        }
    }

    /// reloadPersistedFonts(pruneMissingFiles:)
    /// （签名域确证：compact + 回读 + 重注册）。
    @discardableResult
    func reloadPersistedFonts(pruneMissingFiles: Bool) -> [FontInfo] {
        loadFontList()
        migrateLegacyFontFiles()
        if pruneMissingFiles {
            compactStoredFontList()
            saveFontList()
        }
        registerAllFonts()
        return fonts
    }

    private func migrateLegacyFontFiles() {
        let fm = FileManager.default
        let legacy = supportDirectory.appendingPathComponent("Fonts/CustomFonts")
        for font in fonts {
            let destination = fontsDirectory.appendingPathComponent(font.fileName)
            let source = legacy.appendingPathComponent(font.fileName)
            guard !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: source.path) else { continue }
            do {
                try fm.createDirectory(at: fontsDirectory, withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: destination)
            } catch { continue }
        }
    }

    /// resetFontReferences(_:)（签名域确证：引用主题回退 System）。
    private func resetFontReferences(_ family: String) {
        var settings = ReadingSettings.load()
        if settings.fontName == family {
            settings.fontName = "System"
            settings.save()
        }
    }

    /// backfillOriginalFileName(_:at:)（签名域确证：空缺回填）。
    private func backfillOriginalFileName(
        _ originalName: String, at index: Int
    ) {
        guard fonts.indices.contains(index) else { return }
        if fonts[index].originalFileName == nil {
            fonts[index].originalFileName = originalName
        }
    }

    // MARK: 备份域（exportFontMetadataForBackup/copyFontsForBackup
    // 签名域确证）

    /// exportFontMetadataForBackup()（签名域确证）。
    func exportFontMetadataForBackup() -> Data? {
        try? JSONEncoder().encode(fonts)
    }

    /// copyFontsForBackup(to:)（签名域确证：拷贝计数返回）。
    func copyFontsForBackup(to directory: URL) throws -> Int {
        let fm = FileManager.default
        try fm.createDirectory(
            at: directory, withIntermediateDirectories: true)
        var copied = 0
        for font in fonts {
            let source = fontsDirectory
                .appendingPathComponent(font.fileName)
            guard fm.fileExists(atPath: source.path) else { continue }
            try Data(contentsOf: source).write(to: directory.appendingPathComponent(font.fileName), options: .atomic)
            copied += 1
        }
        return copied
    }
}
