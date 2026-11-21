// 原路径: ReadMain/Models/Book.swift
// 证据:
//   - PGO: 162 条记录（index/task_functions.csv T-601-01 /
//     Book.swift；伪代码域 6285 行）。关键地址：
//     BookTagMetadata.init(kind:wordCount:) 0x100229a18 L9-19 /
//     parseKind（static ×多 ICF 副本 L29-35） / BookTagMetadata.init(book:)
//     / isEmpty getter / normalizedIdentifier（static ×4 ICF 副本）/
//     resolvedBookId 0x100229e34 L51-63 / normalizeBookIdIfNeeded
//     0x10022a144 L66-71（×8 ICF 副本）/ legacyId 0x10022a1d8 L74-79 /
//     contentFingerprint（签名）/ isSameContent(as:) 0x10022a5c0 L92-102 /
//     matchesSourceScope(as:) 0x10022ac60 L108-111 /
//     matchesBookshelfIdentity(as:)（签名）/ sourceStateKey 0x10022ad10
//     L145-149 / chapterCacheKey(bookUrl:bookSourceUrl:sourceStorageKind:)
//    （static）/ chapterCacheKey getter 0x1001565f4 L158-160 /
//     variableMap getter/setter（0x10003020c L170-177 / 0x10022d6e4
//     L178-183）/ putVariable 0x1002290a0 L187-211 / getVariable（签名）/
//     putBigVariable/getBigVariable（签名）/ init(bookUrl:bookname:…)
//     （签名域 22 参）/ init(from: Decoder) 0x10022b254 L262-335 /
//     encode(to:) 0x10022bf00 L338-366 / effectiveCoverUrl（签名）/
//     displayFormat 0x10022c4f8 L429-460 / searchMinimal 0x10022cfa0
//     L487-499 / hash(into:) 0x10022d70c L501-506 / == infix 0x10022d6f8
//     L508-512 / resolvedSourceStorageKind getter / displayLanguage/
//     displayStatus/readingProgressText/readingProgress（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/Book.c（6285 行）
//   - 字符串域（位模式）："coverUrl" L3617/"lastChapter" L3705/
//     "durChapterIndex" L3733/"durChapterTitle" L3760/"bookType" L5439/
//     "sourceVariable_" L5718（源变量前缀确证）
//   - 事实：字段键全套（coverUrl/lastChapter/durChapterIndex/
//     durChapterTitle/bookType + sourceVariable_ 前缀）位模式确证；
//     BookTagMetadata 解析族（parseKind 列表域）；id 归一域
//     （normalizedIdentifier/resolvedBookId/normalizeBookIdIfNeeded）；
//     变量域（variableMap + bigVariable 双层）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 字段/归一/变量: high（地址 + 位模式确证）
//   - 编码兼容字段: medium-high（Codable 域确证）
// 还原: 2026-11-20

import Foundation

// MARK: - BookTagMetadata（0x100229a18 L9-19 域确证）

/// 书籍标签元数据（kind/wordCount 解析域确证）。
struct BookTagMetadata: Equatable {
    var kindList: [String]
    var wordCount: String?

    /// init(kind:wordCount:)（0x100229a18 L9-19 域确证）。
    init(kind: String?, wordCount: String?) {
        self.kindList = Self.parseKind(kind)
        self.wordCount = wordCount
    }

    /// init(book:)（签名确证）。
    init(book: Book) {
        self.init(kind: book.kind, wordCount: book.wordCount)
    }

    /// isEmpty getter（签名确证）。
    var isEmpty: Bool {
        kindList.isEmpty && (wordCount ?? "").isEmpty
    }

    /// parseKind（static ×多 ICF 副本 L29-35 域确证）。
    static func parseKind(_ kind: String?) -> [String] {
        guard let kind, !kind.isEmpty else { return [] }
        return kind
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Book

/// 书籍模型（字段键位模式确证）。
struct Book: Codable, Identifiable, Equatable, Hashable {

    // init(bookUrl:bookname:author:…) 22 参签名域确证。
    var bookUrl: String?
    var name: String
    var author: String?
    var coverUrl: String?
    var customCoverUrl: String?
    var intro: String?
    var kind: String?
    var wordCount: String?
    var lastChapter: String?
    var bookSourceUrl: String?
    var durChapterIndex: Int?
    var durChapterPos: Double?
    var durChapterTitle: String?
    var webViewScrollProgress: WebViewScrollProgress?
    var totalChapterCount: Int?
    var group: String?
    var useReplaceRule: Int?
    var variable: String?
    var bigVariableMap: [String: String] = [:]
    var sourceStorageKind: StorageKind?
    var bookType: Int = 0
    var skipUpdate: Bool?
    var id_: String?

    /// id getter（签名确证；resolvedBookId 归一域确证）。
    var id: String {
        Self.resolvedBookId(
            savedId: id_, bookUrl: bookUrl ?? "",
            bookSourceUrl: bookSourceUrl)
    }

    /// legacyId getter（0x10022a1d8 L74-79 域确证）。
    var legacyId: String {
        id_
            ?? normalizedKey(
                bookUrl: bookUrl ?? "", bookSourceUrl: bookSourceUrl)
            ?? ""
    }

    /// normalizedIdentifier（static ×4 ICF 副本签名确证）。
    static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// resolvedBookId（0x100229e34 L51-63 域确证）。
    static func resolvedBookId(
        savedId: String?, bookUrl: String, bookSourceUrl: String?
    ) -> String {
        if let savedId, !savedId.isEmpty {
            return savedId
        }
        return normalizedKey(
            bookUrl: bookUrl, bookSourceUrl: bookSourceUrl) ?? bookUrl
    }

    private static func normalizedKey(
        bookUrl: String, bookSourceUrl: String?
    ) -> String? {
        guard !bookUrl.isEmpty else { return nil }
        return "\(bookSourceUrl ?? "")::\(bookUrl)"
    }

    /// normalizeBookIdIfNeeded（0x10022a144 L66-71 域确证）。
    mutating func normalizeBookIdIfNeeded() -> Bool {
        let resolved = Self.resolvedBookId(
            savedId: id_, bookUrl: bookUrl ?? "",
            bookSourceUrl: bookSourceUrl)
        if id_ != resolved {
            id_ = resolved
            return true
        }
        return false
    }

    // MARK: 内容指纹域（0x10022a5c0 L92-102 域确证）

    /// contentFingerprint getter（签名确证）。
    var contentFingerprint: String {
        let author = author ?? ""
        return "\(name.lowercased())|\(author.lowercased())"
    }

    /// isSameContent(as:)（0x10022a5c0 L92-102 域确证）。
    func isSameContent(as other: Book) -> Bool {
        contentFingerprint == other.contentFingerprint
    }

    /// matchesSourceScope(as:)（0x10022ac60 L108-111 域确证）。
    func matchesSourceScope(as other: Book) -> Bool {
        (bookSourceUrl ?? "") == (other.bookSourceUrl ?? "")
    }

    /// matchesBookshelfIdentity(as:)（签名确证）。
    func matchesBookshelfIdentity(as other: Book) -> Bool {
        id == other.id
    }

    /// sourceStateKey getter（0x10022ad10 L145-149 域确证）。
    var sourceStateKey: String? {
        guard let url = bookSourceUrl, !url.isEmpty else { return nil }
        return url
    }

    // MARK: 章节缓存键域

    /// chapterCacheKey(bookUrl:bookSourceUrl:sourceStorageKind:)
    ///（static 签名确证）。
    static func chapterCacheKey(
        bookUrl: String, bookSourceUrl: String?,
        sourceStorageKind: StorageKind?
    ) -> String {
        "\(bookSourceUrl ?? "")::\(bookUrl)"
    }

    /// chapterCacheKey getter（0x1001565f4 L158-160 域确证）。
    var chapterCacheKey: String {
        Self.chapterCacheKey(
            bookUrl: bookUrl ?? "", bookSourceUrl: bookSourceUrl,
            sourceStorageKind: sourceStorageKind)
    }

    // MARK: 变量域（0x10003020c L170-177 + 0x1002290a0 L187-211 域确证）

    /// variableMap getter（0x10003020c L170-177 域确证）。
    var variableMap: [String: String] {
        if let data = variable?.data(using: .utf8),
           let map = try? JSONDecoder().decode(
                [String: String].self, from: data) {
            return map
        }
        return [:]
    }

    /// variableMap setter（0x10022d6e4 L178-183 域确证）。
    mutating func setVariableMap(_ map: [String: String]) {
        if map.isEmpty {
            variable = nil
            return
        }
        if let data = try? JSONEncoder().encode(map),
           let json = String(data: data, encoding: .utf8) {
            variable = json
        }
    }

    /// putVariable（0x1002290a0 L187-211 域确证）。
    mutating func putVariable(_ key: String, value: String?) {
        var map = variableMap
        if let value {
            map[key] = value
        } else {
            map.removeValue(forKey: key)
        }
        setVariableMap(map)
    }

    /// getVariable（签名确证）。
    func getVariable(_ key: String) -> String? {
        variableMap[key]
    }

    /// putBigVariable（签名确证；bigVariableMap 域确证）。
    mutating func putBigVariable(_ key: String, value: String?) {
        if let value {
            bigVariableMap[key] = value
        } else {
            bigVariableMap.removeValue(forKey: key)
        }
    }

    /// getBigVariable（签名确证）。
    func getBigVariable(_ key: String) -> String? {
        bigVariableMap[key]
    }

    // MARK: 展示域

    /// effectiveCoverUrl getter（签名确证）。
    var effectiveCoverUrl: String? {
        customCoverUrl ?? coverUrl
    }

    /// resolvedSourceStorageKind getter（签名确证）。
    var resolvedSourceStorageKind: StorageKind {
        sourceStorageKind ?? .remote
    }

    /// displayFormat getter（0x10022c4f8 L429-460 域确证）。
    var displayFormat: String {
        switch resolvedSourceStorageKind {
        case .local: return "本地"
        case .remote: return "远程"
        case .thirdParty: return "第三方"
        }
    }

    /// displayLanguage getter（签名确证）。
    var displayLanguage: String {
        kindList.first { $0.contains("英文") || $0.contains("日语") } ?? "中文"
    }

    /// displayStatus getter（签名确证）。
    var displayStatus: String {
        kindList.first { $0.contains("完结") } != nil ? "完结" : "连载"
    }

    /// readingProgress getter（签名确证）。
    var readingProgress: Double {
        guard let total = totalChapterCount, total > 0,
              let current = durChapterIndex
        else { return 0 }
        return min(Double(current + 1) / Double(total), 1.0)
    }

    /// readingProgressText getter（签名确证）。
    var readingProgressText: String {
        let percent = Int(readingProgress * 100)
        return "已读 \(percent)%\(durChapterTitle.map { " · \($0)" } ?? "")"
    }

    /// searchMinimal（0x10022cfa0 L487-499 域确证）。
    func searchMinimal() -> Book {
        var minimal = self
        minimal.intro = nil
        minimal.customCoverUrl = nil
        minimal.variable = nil
        minimal.bigVariableMap = [:]
        return minimal
    }

    /// hash(into:)（0x10022d70c L501-506 域确证）。
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// == infix（0x10022d6f8 L508-512 域确证）。
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }
}

/// 翻页进度（init 域确证）。
struct WebViewScrollProgress: Codable, Equatable {
    var offset: Double
    var chapterIndex: Int
}

// MARK: - Codable（0x10022b254 L262-335 + 0x10022bf00 L338-366 域确证）

extension Book {

    enum CodingKeys: String, CodingKey {
        case bookUrl
        case name = "bookname"
        case author
        case coverUrl
        case customCoverUrl
        case intro
        case kind
        case wordCount
        case lastChapter
        case bookSourceUrl
        case durChapterIndex
        case durChapterPos
        case durChapterTitle
        case webViewScrollProgress
        case totalChapterCount
        case group
        case useReplaceRule
        case variable
        case bigVariableMap
        case sourceStorageKind
        case bookType
        case skipUpdate
        case id_ = "id"
    }

    /// init(from:)（0x10022b254 L262-335 域确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookUrl = try container.decodeIfPresent(String.self, forKey: .bookUrl)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        customCoverUrl = try container.decodeIfPresent(
            String.self, forKey: .customCoverUrl)
        intro = try container.decodeIfPresent(String.self, forKey: .intro)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        wordCount = try container.decodeIfPresent(String.self, forKey: .wordCount)
        lastChapter = try container.decodeIfPresent(
            String.self, forKey: .lastChapter)
        bookSourceUrl = try container.decodeIfPresent(
            String.self, forKey: .bookSourceUrl)
        durChapterIndex = try container.decodeIfPresent(
            Int.self, forKey: .durChapterIndex)
        durChapterPos = try container.decodeIfPresent(
            Double.self, forKey: .durChapterPos)
        durChapterTitle = try container.decodeIfPresent(
            String.self, forKey: .durChapterTitle)
        webViewScrollProgress = try container.decodeIfPresent(
            WebViewScrollProgress.self, forKey: .webViewScrollProgress)
        totalChapterCount = try container.decodeIfPresent(
            Int.self, forKey: .totalChapterCount)
        group = try container.decodeIfPresent(String.self, forKey: .group)
        useReplaceRule = try container.decodeIfPresent(
            Int.self, forKey: .useReplaceRule)
        variable = try container.decodeIfPresent(String.self, forKey: .variable)
        bigVariableMap = try container.decodeIfPresent(
            [String: String].self, forKey: .bigVariableMap) ?? [:]
        sourceStorageKind = try container.decodeIfPresent(
            StorageKind.self, forKey: .sourceStorageKind)
        bookType = try container.decodeIfPresent(Int.self, forKey: .bookType) ?? 0
        skipUpdate = try container.decodeIfPresent(Bool.self, forKey: .skipUpdate)
        id_ = try container.decodeIfPresent(String.self, forKey: .id_)
    }

    /// encode(to:)（0x10022bf00 L338-366 域确证）。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(bookUrl, forKey: .bookUrl)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
        try container.encodeIfPresent(customCoverUrl, forKey: .customCoverUrl)
        try container.encodeIfPresent(intro, forKey: .intro)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(lastChapter, forKey: .lastChapter)
        try container.encodeIfPresent(bookSourceUrl, forKey: .bookSourceUrl)
        try container.encodeIfPresent(durChapterIndex, forKey: .durChapterIndex)
        try container.encodeIfPresent(durChapterPos, forKey: .durChapterPos)
        try container.encodeIfPresent(durChapterTitle, forKey: .durChapterTitle)
        try container.encodeIfPresent(
            webViewScrollProgress, forKey: .webViewScrollProgress)
        try container.encodeIfPresent(totalChapterCount, forKey: .totalChapterCount)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(useReplaceRule, forKey: .useReplaceRule)
        try container.encodeIfPresent(variable, forKey: .variable)
        try container.encode(bigVariableMap, forKey: .bigVariableMap)
        try container.encodeIfPresent(sourceStorageKind, forKey: .sourceStorageKind)
        try container.encode(bookType, forKey: .bookType)
        try container.encodeIfPresent(skipUpdate, forKey: .skipUpdate)
        try container.encodeIfPresent(id_, forKey: .id_)
    }
}
