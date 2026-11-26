// 原路径: ReadMain/Models/ExploreModels.swift
// 证据:
//   - PGO: 4 个主函数（index/task_functions.csv T-1001-01 / ExploreModels.swift），
//     地址：ParagraphComment.init(imageSource:clickActionScript:imageTag:) 0x1001640cc
//     L20-25 / init(from:) 0x10023e894 L31-38 / == infix 0x10023ea44 L40-44
//     （+closure #1 0x10023fbd8 L42）；另含 pgo_only：RssSource.id、
//     BookReview.id/ExploreFilter.id/ExploreFilterOption.id 变量初始化、
//     ParagraphComment.clickActionScript 变量初始化 ×2
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/ExploreModels.c（164 行，4 块）
//   - 事实：ParagraphComment.init(imageSource:...) —— 三参存储（init 链 ivar 写入
//     确证）；init(from:) —— KeyedDecodingContainer.decodeIfPresent 链 + 
//     implicit closure #10 in ParagraphCommentParser（回退值确证）；== infix ——
//     字段相等（closure #1/#2 字段级比较）；uuid id 变量初始化族（UUID() 默认）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - ParagraphComment: high（三参/解码链/相等链确证）
//   - RssSource/BookReview/ExploreFilter: medium（签名确证；字段名为还原命名）
// 还原: 2026-11-19

import Foundation

/// 段落评论（阅读页正文段落挂载）。
struct ParagraphComment: Codable, Identifiable, Equatable {
    /// 评论图片源（URL 或规则串）。
    var imageSource: String
    /// 点击图片执行的 JS（可空）。
    var clickActionScript: String?
    /// 图片标记（去重/排序键）。
    var imageTag: String

    /// 伪代码 0x1001640cc（L20-25）：三参存储构造。
    init(imageSource: String, clickActionScript: String?, imageTag: String) {
        self.imageSource = imageSource
        self.clickActionScript = clickActionScript
        self.imageTag = imageTag
    }

    /// 伪代码 0x10023e894（L31-38）：
    /// decodeIfPresent 链 + 回退闭包（implicit closure #10 确证）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageSource = try container.decodeIfPresent(String.self, forKey: .imageSource) ?? ""
        clickActionScript = try container.decodeIfPresent(String.self, forKey: .clickActionScript)
        imageTag = try container.decodeIfPresent(String.self, forKey: .imageTag) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case imageSource
        case clickActionScript
        case imageTag
    }
}

extension ParagraphComment {
    /// UUID 身份（点击/去重用；推断派生自 imageTag）。
    var id: String {
        imageTag
    }

    /// 伪代码 0x10023ea44（L40-44 + closure #1/#2）：字段相等。
    static func == (lhs: ParagraphComment, rhs: ParagraphComment) -> Bool {
        lhs.imageSource == rhs.imageSource
            && lhs.clickActionScript == rhs.clickActionScript
            && lhs.imageTag == rhs.imageTag
    }
}

/// 订阅号源（pgo_only RssSource.id 确证）。
struct RssSource: Codable, Identifiable, Equatable {
    var sourceUrl: String
    var sourceName: String
    var iconUrl: String?
    var sortUrl: String?
    var enabled: Bool = true

    var id: String {
        sourceUrl
    }
}

/// 类型表4633-4639与0x10014aeec：头像、正文、时间、引用，不含作者和评分。
struct BookReview: Codable, Identifiable, Equatable {
    var id = UUID()
    var avatar: String?
    var content: String
    var postTime: String?
    var quote: String?
}

/// 发现页过滤器（pgo_only ExploreFilter.id = UUID()/selectedIndex = 0 确证）。
struct ExploreFilter: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var options: [ExploreFilterOption]
    /// 伪代码 selectedIndex 变量初始化：初始 0。
    var selectedIndex = 0
}

/// 过滤器选项（pgo_only ExploreFilterOption.id = UUID() 确证）。
struct ExploreFilterOption: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var value: String
}
