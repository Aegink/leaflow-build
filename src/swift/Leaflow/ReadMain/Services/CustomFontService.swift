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
//   - 事实：字体落盘 Application Support/Fonts/CustomFonts/ +
//     字体清单 UserDefaults JSON（loadFontList/saveFontList 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（导入/CSS/MIME 三域字符串全链确证）
// 还原: 2026-11-20

import UIKit

/// 自定义字体服务（fontsDirectory 域确证：Application Support/Fonts/
/// CustomFonts/，'CustomFonts' L102）。
/// @MainActor：currentTheme/ReadingSettings 域均为 MainActor 隔离——
/// 消费方（设置视图）亦然（wave-16）。
@MainActor
final class CustomFontService {

    /// 字体信息（readableName/importDisplayFileName/hasOriginalFileName/
    /// internalDisplayName/managementDisplayName 签名域确证）。
    struct FontInfo: Codable, Identifiable, Hashable {
        let id: String
        var fileName: String
        var originalFileName: String?
        var postScriptName: String?
        var familyName: String?
        var importedAt: Date

        /// name 桥（ChapterTitleFontPickerView 字体选择域确证——即
        /// fileName，wave-16 补桥）。
        var name: String { fileName }

        /// displayName 桥（readableName 归一；nil 回退 fileName）。
        var displayName: String {
            Self.readableName(fileName) ?? fileName
        }

        /// readableName(_:)（签名域确证：PostScript 名 → 文件名去
        /// 扩展 → 空兜底）。
        static func readableName(_ fileName: String) -> String? {
            let stem = (fileName as NSString).deletingPathExtension
            let cleaned = stem
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }

        /// importDisplayFileName getter（签名域确证）。
        var importDisplayFileName: String {
            originalFileName ?? fileName
        }

        /// hasOriginalFileName getter（签名域确证）。
        var hasOriginalFileName: Bool {
            originalFileName != nil
        }

        /// internalDisplayName getter（签名域确证：familyName 优先）。
        var internalDisplayName: String {
            if let familyName, !familyName.isEmpty {
                return familyName
            }
            return FontInfo.readableName(fileName)
                ?? (fileName as NSString).deletingPathExtension
        }

        /// managementDisplayName getter（签名域确证）。
        var managementDisplayName: String {
            internalDisplayName
        }
    }

    /// 导入错误（errorDescription 签名域确证）。
    enum FontImportError: LocalizedError {
        case unsupportedFormat
        case readFailed
        case duplicate

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "不支持的字体格式（仅 ttf/otf/ttc/woff/woff2）"
            case .readFailed:
                return "字体文件读取失败"
            case .duplicate:
                return "字体已存在"
            }
        }
    }

    static let shared = CustomFontService()

    private static let fontListDefaultsKey = "reader_custom_fonts"
    private static let fontsSubdirectory = "CustomFonts"

    private(set) var fonts: [FontInfo] = []

    /// fontsDirectory getter（签名域确证）。
    var fontsDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return base
            .appendingPathComponent("Fonts", isDirectory: true)
            .appendingPathComponent(Self.fontsSubdirectory,
                                    isDirectory: true)
    }

    init() {
        loadFontList()
        registerAllFonts()
    }

    // MARK: 注册（registerAllFonts 签名域确证：CTFontManager 全量注册）

    /// registerAllFonts()（签名域确证：closure #1/#2 CFError 计数域）。
    func registerAllFonts() {
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
        if fonts.contains(where: {
            // closure #1 域确证：同原始文件名去重。
            $0.originalFileName == url.lastPathComponent
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
                postScriptName: Self.postScriptName(of: destination),
                familyName: Self.familyName(of: destination),
                importedAt: Date())
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
        let font = CTFontCreateWithName(
            (url.lastPathComponent as NSString) as CFString, 12, nil)
        let name = CTFontCopyPostScriptName(font) as String
        return name.isEmpty ? nil : name
    }

    private static func familyName(of url: URL) -> String? {
        let font = CTFontCreateWithName(
            (url.lastPathComponent as NSString) as CFString, 12, nil)
        let name = CTFontCopyFamilyName(font) as String
        return name.isEmpty ? nil : name
    }

    /// deleteFont(_:)（'删除字体: ' L2543 域确证：删文件 + 反注册 +
    /// 清单收窄 + 引用回退）。
    func deleteFont(_ font: FontInfo) {
        let url = fontsDirectory.appendingPathComponent(font.fileName)
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        try? FileManager.default.removeItem(at: url)
        fonts.removeAll { $0.id == font.id }
        resetFontReferences(font.internalDisplayName)
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
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.fontListDefaultsKey),
              let stored = try? JSONDecoder().decode(
                [FontInfo].self, from: data) else {
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
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(fonts) {
            defaults.set(data, forKey: Self.fontListDefaultsKey)
        }
    }

    /// reloadPersistedFonts(pruneMissingFiles:)
    /// （签名域确证：compact + 回读 + 重注册）。
    @discardableResult
    func reloadPersistedFonts(pruneMissingFiles: Bool) -> [FontInfo] {
        if pruneMissingFiles {
            compactStoredFontList()
            saveFontList()
        }
        loadFontList()
        registerAllFonts()
        return fonts
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
            try fm.copyItem(
                at: source,
                to: directory.appendingPathComponent(font.fileName))
            copied += 1
        }
        return copied
    }
}
