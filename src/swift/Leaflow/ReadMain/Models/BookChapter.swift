import Foundation

/// 书籍章节（BookChapter 签名族确证：LocalSourceParser.getChapterList 构造域
/// title/url/index 三参 + AnalyzeRule.currentChapter 消费域；T-601 Chapter
/// 与本类型并存，构建桥）。
struct BookChapter: Codable, Identifiable, Equatable, Hashable {
    var title: String
    var url: String
    var index: Int
    var isRead: Bool = false

    var id: String { "\(index)-\(url)" }

    /// 便捷 name 视图（局部日志域 `chapter.name` 消费）。
    var name: String? { title }

    init(title: String, url: String, index: Int, isRead: Bool = false) {
        self.title = title
        self.url = url
        self.index = index
        self.isRead = isRead
    }
}
