// 原始归属: ReadMain/Models/BookSource.swift
// 规则字段与对象/JSON字符串解码；原始类型表与地址见主文件分册。
import Foundation

// MARK: - 规则子结构（init() 默认构造确证）

struct SearchRule: Codable, Equatable {
    // 字段表：index/swift_types_dump.txt SearchRule（全部 String?，原版）。
    var bookList: String = ""
    var name: String = ""
    var author: String = ""
    var coverUrl: String = ""
    var intro: String = ""
    var kind: String = ""
    var lastChapter: String = ""
    var bookUrl: String = ""
    var wordCount: String = ""
    var checkKeyWord: String = ""
    var updateTime: String = ""

    /// 伪代码 SearchRule.init()（pgo 内联默认构造）。
    init() {}

    /// T-1601-B5：宽容解码——legado 源普遍缺省字段；综合成
    /// Decodable 对缺键直接抛错会导致整条规则对象被丢弃。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookList = try c.decodeLenientStringIfPresent(forKey: .bookList) ?? ""
        name = try c.decodeLenientStringIfPresent(forKey: .name) ?? ""
        author = try c.decodeLenientStringIfPresent(forKey: .author) ?? ""
        coverUrl = try c.decodeLenientStringIfPresent(forKey: .coverUrl) ?? ""
        intro = try c.decodeLenientStringIfPresent(forKey: .intro) ?? ""
        kind = try c.decodeLenientStringIfPresent(forKey: .kind) ?? ""
        lastChapter = try c.decodeLenientStringIfPresent(forKey: .lastChapter) ?? ""
        bookUrl = try c.decodeLenientStringIfPresent(forKey: .bookUrl) ?? ""
        wordCount = try c.decodeLenientStringIfPresent(forKey: .wordCount) ?? ""
        checkKeyWord = try c.decodeLenientStringIfPresent(forKey: .checkKeyWord) ?? ""
        updateTime = try c.decodeLenientStringIfPresent(forKey: .updateTime) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case bookList, name, author, bookUrl, coverUrl, intro, kind
        case lastChapter, wordCount, checkKeyWord, updateTime
    }
}



struct TocRule: Codable, Equatable {
    var preUpdateJs: String = ""
    var chapterList: String = ""
    var chapterName: String = ""
    var chapterUrl: String = ""
    var formatJs: String = ""
    var isVolume: String = ""
    var isVip: String = ""
    var isPay: String = ""
    var updateTime: String = ""
    var nextTocUrl: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preUpdateJs = try c.decodeLenientStringIfPresent(forKey: .preUpdateJs) ?? ""
        chapterList = try c.decodeLenientStringIfPresent(forKey: .chapterList) ?? ""
        chapterName = try c.decodeLenientStringIfPresent(forKey: .chapterName) ?? ""
        chapterUrl = try c.decodeLenientStringIfPresent(forKey: .chapterUrl) ?? ""
        formatJs = try c.decodeLenientStringIfPresent(forKey: .formatJs) ?? ""
        isVolume = try c.decodeLenientStringIfPresent(forKey: .isVolume) ?? ""
        isVip = try c.decodeLenientStringIfPresent(forKey: .isVip) ?? ""
        isPay = try c.decodeLenientStringIfPresent(forKey: .isPay) ?? ""
        updateTime = try c.decodeLenientStringIfPresent(forKey: .updateTime) ?? ""
        nextTocUrl = try c.decodeLenientStringIfPresent(forKey: .nextTocUrl) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case preUpdateJs, chapterList, chapterName, chapterUrl, formatJs
        case isVolume, isVip, isPay, updateTime, nextTocUrl
    }
}



struct ContentRule: Codable, Equatable {
    var content: String = ""
    var title: String = ""
    var subContent: String = ""
    var nextContentUrl: String = ""
    var replaceRegex: String = ""
    var webJs: String = ""
    var sourceRegex: String = ""
    var imageStyle: String = ""
    var imageDecode: String = ""
    var payAction: String = ""
    var callBackJs: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decodeLenientStringIfPresent(forKey: .content) ?? ""
        title = try c.decodeLenientStringIfPresent(forKey: .title) ?? ""
        subContent = try c.decodeLenientStringIfPresent(forKey: .subContent) ?? ""
        nextContentUrl = try c.decodeLenientStringIfPresent(forKey: .nextContentUrl) ?? ""
        replaceRegex = try c.decodeLenientStringIfPresent(forKey: .replaceRegex) ?? ""
        webJs = try c.decodeLenientStringIfPresent(forKey: .webJs) ?? ""
        sourceRegex = try c.decodeLenientStringIfPresent(forKey: .sourceRegex) ?? ""
        imageStyle = try c.decodeLenientStringIfPresent(forKey: .imageStyle) ?? ""
        imageDecode = try c.decodeLenientStringIfPresent(forKey: .imageDecode) ?? ""
        payAction = try c.decodeLenientStringIfPresent(forKey: .payAction) ?? ""
        callBackJs = try c.decodeLenientStringIfPresent(forKey: .callBackJs) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case content, title, subContent, nextContentUrl, replaceRegex
        case webJs, sourceRegex, imageStyle, imageDecode, payAction
        case callBackJs
    }
}



struct BookInfoRule: Codable, Equatable {
    // 原版 JSON 键为 "init"（CodingKeys 映射），源码属性名 initRule。
    var initRule: String = ""
    var name: String = ""
    var author: String = ""
    var coverUrl: String = ""
    var intro: String = ""
    var kind: String = ""
    var lastChapter: String = ""
    var tocUrl: String = ""
    var wordCount: String = ""
    var canReName: String = ""
    var downloadUrls: String = ""
    var updateTime: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        initRule = try c.decodeLenientStringIfPresent(forKey: .initRule) ?? ""
        name = try c.decodeLenientStringIfPresent(forKey: .name) ?? ""
        author = try c.decodeLenientStringIfPresent(forKey: .author) ?? ""
        coverUrl = try c.decodeLenientStringIfPresent(forKey: .coverUrl) ?? ""
        intro = try c.decodeLenientStringIfPresent(forKey: .intro) ?? ""
        kind = try c.decodeLenientStringIfPresent(forKey: .kind) ?? ""
        lastChapter = try c.decodeLenientStringIfPresent(forKey: .lastChapter) ?? ""
        tocUrl = try c.decodeLenientStringIfPresent(forKey: .tocUrl) ?? ""
        wordCount = try c.decodeLenientStringIfPresent(forKey: .wordCount) ?? ""
        canReName = try c.decodeLenientStringIfPresent(forKey: .canReName) ?? ""
        downloadUrls = try c.decodeLenientStringIfPresent(forKey: .downloadUrls) ?? ""
        updateTime = try c.decodeLenientStringIfPresent(forKey: .updateTime) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case initRule = "init"
        case name, author, coverUrl, intro, kind, lastChapter, tocUrl
        case wordCount, canReName, downloadUrls, updateTime
    }
}



struct ExploreRule: Codable, Equatable {
    var exploreUrl: String = ""
    var bookList: String = ""
    var name: String = ""
    var author: String = ""
    var coverUrl: String = ""
    var intro: String = ""
    var kind: String = ""
    var lastChapter: String = ""
    var bookUrl: String = ""
    var wordCount: String = ""
    var updateTime: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exploreUrl = try c.decodeLenientStringIfPresent(forKey: .exploreUrl) ?? ""
        bookList = try c.decodeLenientStringIfPresent(forKey: .bookList) ?? ""
        name = try c.decodeLenientStringIfPresent(forKey: .name) ?? ""
        author = try c.decodeLenientStringIfPresent(forKey: .author) ?? ""
        coverUrl = try c.decodeLenientStringIfPresent(forKey: .coverUrl) ?? ""
        intro = try c.decodeLenientStringIfPresent(forKey: .intro) ?? ""
        kind = try c.decodeLenientStringIfPresent(forKey: .kind) ?? ""
        lastChapter = try c.decodeLenientStringIfPresent(forKey: .lastChapter) ?? ""
        bookUrl = try c.decodeLenientStringIfPresent(forKey: .bookUrl) ?? ""
        wordCount = try c.decodeLenientStringIfPresent(forKey: .wordCount) ?? ""
        updateTime = try c.decodeLenientStringIfPresent(forKey: .updateTime) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case exploreUrl, bookList, name, author, coverUrl, intro, kind
        case lastChapter, bookUrl, wordCount, updateTime
    }
}



struct ReviewRule: Codable, Equatable {
    // 原版字段（dump）+ 旧还原字段保留（SourceEditView 消费域）。
    var reviewUrl: String = ""
    var avatarRule: String = ""
    var contentRule: String = ""
    var postTimeRule: String = ""
    var reviewQuoteUrl: String = ""
    var voteUpUrl: String = ""
    var voteDownUrl: String = ""
    var postReviewUrl: String = ""
    var postQuoteUrl: String = ""
    var deleteUrl: String = ""
    var reviewList: String = ""
    var content: String = ""
    var author: String = ""
    var date: String = ""
    var rating: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reviewUrl = try c.decodeLenientStringIfPresent(forKey: .reviewUrl) ?? ""
        avatarRule = try c.decodeLenientStringIfPresent(forKey: .avatarRule) ?? ""
        contentRule = try c.decodeLenientStringIfPresent(forKey: .contentRule) ?? ""
        postTimeRule = try c.decodeLenientStringIfPresent(forKey: .postTimeRule) ?? ""
        reviewQuoteUrl = try c.decodeLenientStringIfPresent(forKey: .reviewQuoteUrl) ?? ""
        voteUpUrl = try c.decodeLenientStringIfPresent(forKey: .voteUpUrl) ?? ""
        voteDownUrl = try c.decodeLenientStringIfPresent(forKey: .voteDownUrl) ?? ""
        postReviewUrl = try c.decodeLenientStringIfPresent(forKey: .postReviewUrl) ?? ""
        postQuoteUrl = try c.decodeLenientStringIfPresent(forKey: .postQuoteUrl) ?? ""
        deleteUrl = try c.decodeLenientStringIfPresent(forKey: .deleteUrl) ?? ""
        reviewList = try c.decodeLenientStringIfPresent(forKey: .reviewList) ?? ""
        content = try c.decodeLenientStringIfPresent(forKey: .content) ?? ""
        author = try c.decodeLenientStringIfPresent(forKey: .author) ?? ""
        date = try c.decodeLenientStringIfPresent(forKey: .date) ?? ""
        rating = try c.decodeLenientStringIfPresent(forKey: .rating) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case reviewUrl, avatarRule, contentRule, postTimeRule
        case reviewQuoteUrl, voteUpUrl, voteDownUrl
        case postReviewUrl, postQuoteUrl, deleteUrl
        case reviewList, content, author, date, rating
    }
}
