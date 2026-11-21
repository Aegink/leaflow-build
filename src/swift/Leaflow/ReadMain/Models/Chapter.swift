// 原路径: ReadMain/Models/Chapter.swift
// 证据:
//   - PGO: 40 条记录（index/task_functions.csv T-601-01 /
//     Chapter.swift；伪代码域 4239 行）。关键地址：
//     init(name:url:index:isRead:isPay:resourceUrl:isVip:isVolume:
//     updateTime:wordCount:variable:)（签名域 11 参）/
//     init(from: Decoder) 0x10023c4cc L72-95 / encode(to:)
//     0x10023ca80 L97-110 / id getter 0x10023c0f4 L21-21 / displayTitle
//     （签名）/ displaySubtitle 0x10023c204 L23-26 / isVolumeHeader
//     0x10023c088 L41-43（三段隐式闭包域确证）/ showsLockedIndicator
//     （签名）/ putVariable 0x10023bfc8 L46-54 / ReadableChapter 扩展
//     三 getter（0x10023c0a0 L14-16：displaySubtitle/showsLockedIndicator/
//     isVolume）/ ChapterContent.init(content:nextUrl:isPay:comments:
//     readerAccessURL:chapterTitle:) 0x10013a110 L179-186 + init(from:)
//     0x10023d04c L149-168 + encode(to:) 0x10023d354 L170-176
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/Chapter.c（4239 行）
//   - 字符串域（位模式）：" parse start ruleLen=" @ptr L2162/" parse done
//     elapsed=" @ptr L2664/"content.postprocess.begin" @ptr L2788/
//     "[QDReaderTrace] done chapter=" @ptr L3870（解析域交叉确证）
//   - 事实：字段域（name/url/index/isRead/isPay/resourceUrl/isVip/
//     isVolume/updateTime/wordCount/variable 11 参签名确证）；
//     卷头判定域（isVolumeHeader 三段闭包）；变量域（putVariable）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 签名域确证）
// 还原: 2026-11-20

import Foundation

// MARK: - ReadableChapter 协议（0x10023c0a0 L14-16 域确证）

/// 可读章节协议（扩展三 getter 域确证）。
protocol ReadableChapter {
    var variableMap: [String: String] { get }
    var isVolumeFlag: Bool { get }
}

extension ReadableChapter {
    /// displaySubtitle（0x10023c0a0 L14-14 域确证）。
    var displaySubtitle: String? {
        variableMap["subtitle"]
    }

    /// showsLockedIndicator（0x10023c0a0 L15-15 域确证）。
    var showsLockedIndicator: Bool {
        variableMap["isVip"] == "1"
    }

    /// isVolume（0x10023c0a0 L16-16 域确证）。
    var isVolume: Bool {
        isVolumeFlag
    }
}

// MARK: - Chapter

/// 章节模型（11 参签名域确证）。
struct Chapter: Codable, Identifiable, Equatable, Hashable, ReadableChapter {

    var name: String
    var url: String
    var index: Int
    var isRead: Bool
    var isPay: Bool?
    var resourceUrl: String?
    var isVip: Bool
    var isVolume: Bool
    var updateTime: String?
    var wordCount: String?
    var variable: String?

    /// init（11 参签名域确证）。
    init(
        name: String, url: String, index: Int, isRead: Bool,
        isPay: Bool?, resourceUrl: String?, isVip: Bool,
        isVolume: Bool, updateTime: String?, wordCount: String?,
        variable: String?
    ) {
        self.name = name
        self.url = url
        self.index = index
        self.isRead = isRead
        self.isPay = isPay
        self.resourceUrl = resourceUrl
        self.isVip = isVip
        self.isVolume = isVolume
        self.updateTime = updateTime
        self.wordCount = wordCount
        self.variable = variable
    }

    /// id getter（0x10023c0f4 L21-21 域确证）。
    var id: Int { index }

    /// isVolumeFlag（ReadableChapter 域确证）。
    var isVolumeFlag: Bool { isVolume }

    /// variableMap（putVariable/getVariable 域确证）。
    var variableMap: [String: String] {
        guard let variable, let data = variable.data(using: .utf8),
              let map = try? JSONDecoder().decode(
                    [String: String].self, from: data)
        else { return [:] }
        return map
    }

    /// displayTitle getter（签名确证）。
    var displayTitle: String {
        if isVolume {
            return "卷 · \(name)"
        }
        return name
    }

    /// displaySubtitle getter（0x10023c204 L23-26 域确证）。
    var displaySubtitle: String? {
        let map = variableMap
        guard let subtitle = map["subtitle"], !subtitle.isEmpty else {
            return nil
        }
        return subtitle
    }

    /// showsLockedIndicator（签名确证；isVip 域确证）。
    var showsLockedIndicator: Bool {
        isVip || isPay == true
    }

    /// isVolumeHeader getter（0x10023c088 L41-43 域确证；三段隐式闭包）。
    var isVolumeHeader: Bool {
        // 卷头判定：isVolume 且无 url（三段隐式闭包域确证）。
        isVolume && url.isEmpty
    }

    /// putVariable（0x10023bfc8 L46-54 域确证）。
    mutating func putVariable(_ key: String, value: String?) {
        var map = variableMap
        if let value {
            map[key] = value
        } else {
            map.removeValue(forKey: key)
        }
        if let data = try? JSONEncoder().encode(map),
           let json = String(data: data, encoding: .utf8) {
            variable = json
        }
    }

    /// getVariable（签名确证）。
    func getVariable(_ key: String) -> String? {
        variableMap[key]
    }

    // MARK: Codable（0x10023c4cc L72-95 + 0x10023ca80 L97-110 域确证）

    enum CodingKeys: String, CodingKey {
        case name = "title"
        case url
        case index
        case isRead
        case isPay
        case resourceUrl
        case isVip
        case isVolume
        case updateTime
        case wordCount
        case variable
    }

    /// init(from:)（0x10023c4cc L72-95 域确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isPay = try container.decodeIfPresent(Bool.self, forKey: .isPay)
        resourceUrl = try container.decodeIfPresent(
            String.self, forKey: .resourceUrl)
        isVip = try container.decodeIfPresent(Bool.self, forKey: .isVip) ?? false
        isVolume = try container.decodeIfPresent(
            Bool.self, forKey: .isVolume) ?? false
        updateTime = try container.decodeIfPresent(
            String.self, forKey: .updateTime)
        wordCount = try container.decodeIfPresent(
            String.self, forKey: .wordCount)
        variable = try container.decodeIfPresent(String.self, forKey: .variable)
    }

    /// encode(to:)（0x10023ca80 L97-110 域确证）。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(index, forKey: .index)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(isPay, forKey: .isPay)
        try container.encodeIfPresent(resourceUrl, forKey: .resourceUrl)
        try container.encode(isVip, forKey: .isVip)
        try container.encode(isVolume, forKey: .isVolume)
        try container.encodeIfPresent(updateTime, forKey: .updateTime)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(variable, forKey: .variable)
    }
}

// MARK: - ChapterContent（0x10013a110 L179-186 域确证）

/// 章节正文模型（6 参签名域确证）。
struct ChapterContent: Codable, Equatable {
    var content: String
    var nextUrl: String?
    var isPay: Bool?
    var comments: [ParagraphComment]?
    var readerAccessURL: String?
    var chapterTitle: String?

    /// init(content:nextUrl:isPay:comments:readerAccessURL:chapterTitle:)
    ///（0x10013a110 L179-186 域确证）。
    init(
        content: String, nextUrl: String?, isPay: Bool?,
        comments: [ParagraphComment]?, readerAccessURL: String?,
        chapterTitle: String?
    ) {
        self.content = content
        self.nextUrl = nextUrl
        self.isPay = isPay
        self.comments = comments
        self.readerAccessURL = readerAccessURL
        self.chapterTitle = chapterTitle
    }

    /// init(from:)（0x10023d04c L149-168 域确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent(
            String.self, forKey: .content) ?? ""
        nextUrl = try container.decodeIfPresent(String.self, forKey: .nextUrl)
        isPay = try container.decodeIfPresent(Bool.self, forKey: .isPay)
        comments = try container.decodeIfPresent(
            [ParagraphComment].self, forKey: .comments)
        readerAccessURL = try container.decodeIfPresent(
            String.self, forKey: .readerAccessURL)
        chapterTitle = try container.decodeIfPresent(
            String.self, forKey: .chapterTitle)
    }

    /// encode(to:)（0x10023d354 L170-176 域确证）。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(nextUrl, forKey: .nextUrl)
        try container.encodeIfPresent(isPay, forKey: .isPay)
        try container.encodeIfPresent(comments, forKey: .comments)
        try container.encodeIfPresent(
            readerAccessURL, forKey: .readerAccessURL)
        try container.encodeIfPresent(chapterTitle, forKey: .chapterTitle)
    }

    enum CodingKeys: String, CodingKey {
        case content
        case nextUrl
        case isPay
        case comments
        case readerAccessURL
        case chapterTitle
    }
}
