// 原路径: ReadMain/Core/ChapterTitleDesignerProject.swift
// 证据:
//   - PGO: 18 个主函数（index/task_functions.csv T-303-01 / ChapterTitleDesignerProject.swift），
//     地址：ChapterTitleDesignerSavePayload.encode 0x1001afe3c L148-154 /
//     ChapterTitleStylePackage.init(from:) 0x1001b03a0 L205-221 / encode 0x1001b0e50
//     L223-232 / ChapterTitleStyleFileError.errorDescription 0x1001b13c0 L254-261 /
//     FileService.makePackage 0x1001b15a4 L274-296 / refreshedConfig 0x1001b1adc
//     L465-472 / exportFile 0x1001b1bf0 L303-314 / importPackageData 0x1001b2184
//     L322-354 / decodePackage 0x1001b2984 L400-406 / importAssets 0x1001b2b44
//     L411-418 / uniqueName 0x1001b2db8 L479-487 / rewritePreset 0x1001afa70
//     L439-456 / makePreset 0x1001b30d8 L424-433 / importPrimaryConfigs
//     0x10020b458 L359-365；payload closure #1（[String]）0x1001affb8 L144
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/ChapterTitleDesignerProject.c
//   - 事实：ChapterTitleDesignerSavePayload —— htmlTemplate/projectJSON/assetIds/
//     canvasHeight 四字段（init 签名确证）；ChapterTitleStylePackage ——
//     version/exportedAt/name/light/dark/assets（init(version:...) 签名确证）；
//     FileService —— makePackage（资产收集）/exportFile（落盘）/importPackageData
//     （decodePackage → importAssets → rewritePreset/importPrimaryConfigs）/
//     uniqueName 去重/refreshedConfig 刷新
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - payload/package Codable/FileService 主链: high（签名/调用链确证）
//   - 字段细节: medium（待真机对照）
// 还原: 2026-11-19

import Foundation

// MARK: - 设计器保存载荷

/// 设计器保存载荷（四字段 init 签名确证）。
struct ChapterTitleDesignerSavePayload: Codable {
    var htmlTemplate: String
    var projectJSON: String
    var assetIds: [String]
    var canvasHeight: Double

    init(
        htmlTemplate: String, projectJSON: String,
        assetIds: [String], canvasHeight: Double
    ) {
        self.htmlTemplate = htmlTemplate
        self.projectJSON = projectJSON
        self.assetIds = assetIds
        self.canvasHeight = canvasHeight
    }

    /// 伪代码 0x1001afe3c（L148-154）：encode。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(htmlTemplate, forKey: .htmlTemplate)
        try container.encode(projectJSON, forKey: .projectJSON)
        try container.encode(assetIds, forKey: .assetIds)
        try container.encode(canvasHeight, forKey: .canvasHeight)
    }

    /// 伪代码 init(from:) + closure #1（[String] 解码确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        htmlTemplate = try container.decodeIfPresent(String.self, forKey: .htmlTemplate) ?? ""
        projectJSON = try container.decodeIfPresent(String.self, forKey: .projectJSON) ?? "{}"
        assetIds = try container.decodeIfPresent([String].self, forKey: .assetIds) ?? []
        canvasHeight = try container.decodeIfPresent(Double.self, forKey: .canvasHeight) ?? 120
    }

    private enum CodingKeys: String, CodingKey {
        case htmlTemplate, projectJSON, assetIds, canvasHeight
    }
}

// MARK: - 样式包

/// 章节标题样式包（导出/导入双通道）。
struct ChapterTitleStylePackage: Codable {
    var version: Int
    var exportedAt: Date
    var name: String?
    var light: ChapterTitleConfig
    var dark: ChapterTitleConfig
    var assets: [ChapterTitlePackagedAsset]

    /// 伪代码 0x1001b03a0（L205-221）：decode（closure #4 资产数组确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        name = try container.decodeIfPresent(String.self, forKey: .name)
        light = try container.decode(ChapterTitleConfig.self, forKey: .light)
        dark = try container.decode(ChapterTitleConfig.self, forKey: .dark)
        assets = try container.decodeIfPresent(
            [ChapterTitlePackagedAsset].self, forKey: .assets) ?? []
    }

    /// 伪代码 0x1001b0e50（L223-232）：encode。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(light, forKey: .light)
        try container.encode(dark, forKey: .dark)
        try container.encode(assets, forKey: .assets)
    }

    /// 伪代码 init(version:exportedAt:name:light:dark:assets:)（签名确证）。
    init(
        version: Int, exportedAt: Date, name: String?,
        light: ChapterTitleConfig, dark: ChapterTitleConfig,
        assets: [ChapterTitlePackagedAsset]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.name = name
        self.light = light
        self.dark = dark
        self.assets = assets
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, name, light, dark, assets
    }
}

/// 样式文件错误。
enum ChapterTitleStyleFileError: LocalizedError {
    case decodeFailed(String)
    case exportFailed(String)

    /// 伪代码 0x1001b13c0（L254-261）。
    var errorDescription: String? {
        switch self {
        case .decodeFailed(let detail):
            return "样式包解码失败：\(detail)"
        case .exportFailed(let detail):
            return "样式包导出失败：\(detail)"
        }
    }
}

/// 资产 Codable 桥（包内资产序列化；推断 JSON 三字段）。
extension ChapterTitlePackagedAsset: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, data, preferredFilename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let base64 = try container.decode(String.self, forKey: .data)
        data = Data(base64Encoded: base64) ?? Data()
        preferredFilename = try container.decodeIfPresent(String.self, forKey: .preferredFilename)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(data.base64EncodedString(), forKey: .data)
        try container.encodeIfPresent(preferredFilename, forKey: .preferredFilename)
    }
}

// MARK: - 文件服务

/// 样式文件服务（导出/导入/资产收集）。
enum ChapterTitleStyleFileService {

    /// 伪代码 0x1001b15a4（L274-296）：组装包。
    static func makePackage(
        styleName: String,
        light: ChapterTitleConfig,
        dark: ChapterTitleConfig,
        assetManager: ChapterTitleAssetManager
    ) throws -> ChapterTitleStylePackage {
        let assetIds = Set(
            [light, dark].flatMap { config in
                ChapterTitleAssetManager.extractAssetIDs(from: config.fontName)
                    + ChapterTitleAssetManager.extractAssetIDs(from: config.textAlignment == .center ? "" : "")
            })
        var packaged: [ChapterTitlePackagedAsset] = []
        for id in assetIds {
            packaged.append(try assetManager.packagedAsset(for: id))
        }
        return ChapterTitleStylePackage(
            version: 1, exportedAt: Date(), name: uniqueName(styleName, existing: []),
            light: light, dark: dark, assets: packaged)
    }

    /// 伪代码 0x1001b1bf0（L303-314）：落盘导出。
    static func exportFile(
        styleName: String,
        light: ChapterTitleConfig,
        dark: ChapterTitleConfig,
        assetManager: ChapterTitleAssetManager
    ) throws -> URL {
        let package = try makePackage(
            styleName: styleName, light: light, dark: dark, assetManager: assetManager)
        let data = try JSONEncoder().encode(package)
        let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let url = documents.appendingPathComponent("\(styleName).qitheme")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// 伪代码 0x1001b2984（L400-406）：包解码。
    static func decodePackage(from data: Data) throws -> ChapterTitleStylePackage {
        do {
            return try JSONDecoder().decode(ChapterTitleStylePackage.self, from: data)
        } catch {
            throw ChapterTitleStyleFileError.decodeFailed(
                error.localizedDescription)
        }
    }

    /// 伪代码 0x1001b2184（L322-354）：数据导入主链
    ///（decodePackage → importAssets → importPrimaryConfigs 确证）。
    static func importPackageData(
        _ data: Data,
        sourceName: String,
        into library: inout ChapterTitleStyleLibrary,
        assetManager: ChapterTitleAssetManager
    ) throws -> ChapterTitleStyleImportSummary {
        let package = try decodePackage(from: data)
        try importAssets(package.assets, assetManager: assetManager)
        let configs = try importPrimaryConfigs(from: package, assetManager: assetManager)
        library.register(
            name: package.name ?? sourceName, light: configs.light, dark: configs.dark)
        return ChapterTitleStyleImportSummary(primaryName: package.name ?? sourceName)
    }

    /// 伪代码 0x1002b458 0x10020b458（L359-365）：主配置导入
    ///（资产 ID 重写确证）。
    static func importPrimaryConfigs(
        from package: ChapterTitleStylePackage,
        assetManager: ChapterTitleAssetManager
    ) throws -> (light: ChapterTitleConfig, dark: ChapterTitleConfig) {
        var idMap: [String: String] = [:]
        for asset in package.assets {
            let newId = try assetManager.importPackagedAsset(asset).id
            idMap[asset.id] = newId
        }
        let light = Self.rewritePreset(package.light, idMap: idMap)
        let dark = Self.rewritePreset(package.dark, idMap: idMap)
        return (light, dark)
    }

    /// 伪代码 0x1001b2b44（L411-418）：批量资产导入。
    static func importAssets(
        _ assets: [ChapterTitlePackagedAsset],
        assetManager: ChapterTitleAssetManager
    ) throws {
        for asset in assets {
            _ = try assetManager.importPackagedAsset(asset)
        }
    }

    /// 伪代码 0x1001afa70（L439-456）：配置内资产 ID 重写。
    static func rewritePreset(
        _ config: ChapterTitleConfig, idMap: [String: String]
    ) -> ChapterTitleConfig {
        var updated = config
        if !idMap.isEmpty {
            updated.fontName = ChapterTitleAssetManager.rewriteAssetIDs(
                in: config.fontName, idMap: idMap)
        }
        return updated
    }

    /// 伪代码 0x1001b30d8（L424-433）：构造预设。
    /// 伪代码 0x1001b30d8（L424-433）：构造预设。
    /// 8 参真实 init 桥（模板串/高度域随设计器载荷对齐——还原推断）。
    static func makePreset(
        name: String, light: ChapterTitleConfig, dark: ChapterTitleConfig
    ) -> ReadingSettings.ChapterTitlePreset {
        ReadingSettings.ChapterTitlePreset(
            id: UUID(),
            name: name,
            template: "",
            darkTemplate: nil,
            height: 120,
            useCustomFont: !light.chapterNameFont.isEmpty,
            lightConfig: light,
            darkConfig: dark)
    }

    /// 伪代码 0x1001b1adc（L465-472）：配置刷新（默认值回填）。
    static func refreshedConfig(_ config: ChapterTitleConfig) -> ChapterTitleConfig {
        var updated = config
        if updated.fontName.isEmpty {
            updated.fontName = "System"
        }
        return updated
    }

    /// 伪代码 0x1001b2db8（L479-487）：名称去重。
    static func uniqueName(_ base: String, existing: Set<String>) -> String {
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
}

/// 导入摘要（primaryName getter 确证）。
struct ChapterTitleStyleImportSummary {
    let primaryName: String?
}

/// 样式库（register 域；类型占位，字段随 T-701 分册落地）。
struct ChapterTitleStyleLibrary {
    private(set) var entries: [(name: String, light: ChapterTitleConfig, dark: ChapterTitleConfig)] = []

    mutating func register(name: String, light: ChapterTitleConfig, dark: ChapterTitleConfig) {
        entries.removeAll { $0.name == name }
        entries.append((name, light, dark))
    }
}
