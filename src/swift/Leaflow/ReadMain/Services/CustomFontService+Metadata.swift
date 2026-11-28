// 原路径: ReadMain/Services/CustomFontService.swift
// 类型表6066/6074：原版字体清单字段；旧重建扩展字段只保留读取兼容。
import Foundation

extension CustomFontService {
    /// 字体信息（readableName/importDisplayFileName/hasOriginalFileName/
    /// internalDisplayName/managementDisplayName 签名域确证）。
    struct FontInfo: Codable, Identifiable, Hashable {
        let id: String
        var fileName: String
        var originalFileName: String?
        var postScriptName: String?
        var familyName: String?
        var importedAt: Date
        var storedDisplayName: String?

        init(id: String, fileName: String, originalFileName: String?, postScriptName: String?,
             familyName: String?, importedAt: Date, displayName: String? = nil) {
            self.id = id
            self.fileName = fileName
            self.originalFileName = originalFileName
            self.postScriptName = postScriptName
            self.familyName = familyName
            self.importedAt = importedAt
            storedDisplayName = displayName
        }

        enum CodingKeys: String, CodingKey {
            case id, fileName, originalFileName, postScriptName, displayName, familyName, importedAt
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            fileName = try values.decode(String.self, forKey: .fileName)
            guard !fileName.isEmpty, !fileName.contains("/"), !fileName.contains("\\"), fileName != ".", fileName != ".." else {
                throw DecodingError.dataCorruptedError(forKey: .fileName, in: values, debugDescription: "字体文件名越界")
            }
            originalFileName = try values.decodeIfPresent(String.self, forKey: .originalFileName)
            postScriptName = try values.decodeIfPresent(String.self, forKey: .postScriptName)
            storedDisplayName = try values.decodeIfPresent(String.self, forKey: .displayName)
            familyName = try values.decodeIfPresent(String.self, forKey: .familyName)
            importedAt = try values.decodeIfPresent(Date.self, forKey: .importedAt) ?? .distantPast
        }

        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(id, forKey: .id)
            try values.encode(fileName, forKey: .fileName)
            try values.encodeIfPresent(originalFileName, forKey: .originalFileName)
            try values.encode(postScriptName ?? "", forKey: .postScriptName)
            try values.encode(displayName, forKey: .displayName)
        }

        /// name 桥（ChapterTitleFontPickerView 字体选择域确证——即
        /// fileName，wave-16 补桥）。
        var name: String { fileName }

        /// displayName 桥（readableName 归一；nil 回退 fileName）。
        var displayName: String {
            storedDisplayName.flatMap(Self.readableName) ?? familyName.flatMap(Self.readableName)
                ?? Self.readableName(fileName) ?? fileName
        }

        /// readableName(_:)（签名域确证：PostScript 名 → 文件名去
        /// 扩展 → 空兜底）。
        static func readableName(_ fileName: String) -> String? {
            let cleaned = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty || ["undefined", "null", "nil", "(null)"].contains(cleaned.lowercased()) ? nil : cleaned
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
            displayName
        }

        /// managementDisplayName getter（签名域确证）。
        var managementDisplayName: String {
            internalDisplayName
        }
    }
}
