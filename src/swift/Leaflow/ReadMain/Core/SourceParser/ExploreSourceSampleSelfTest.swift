// T-1602：发现首页生产筛选谓词的格式、禁用及本地/远程边界。
import Foundation

enum ExploreSourceSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        var source = BookSource(bookSourceUrl: "https://sample.invalid/discovery", bookSourceName: "固定发现配置")
        source.storageKind = .local
        emit("explore_source_empty_rejected", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
        source.exploreUrl = " 推荐::https://sample.invalid/list\n"
        emit("explore_source_requires_book_list", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
        source.ruleExplore.bookList = "//li"
        emit("explore_source_category_list", ["true"], [String(ExploreSourceAvailability.isVisible(source))])
        source.enabled = false
        emit("explore_source_disabled", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
        source.enabled = true
        source.enabledExplore = false
        emit("explore_source_discovery_disabled", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
        source.enabledExplore = true
        source.ruleExplore.bookList = ""
        source.ruleSearch.bookList = "//article"
        emit("explore_source_search_rule_fallback", ["true"], [String(ExploreSourceAvailability.isVisible(source))])
        source.exploreUrl = " \n@JS:java.get('categories')"
        emit("explore_source_javascript", ["true"], [String(ExploreSourceAvailability.isVisible(source))])
        source.exploreUrl = "<JS>result</JS>"
        emit("explore_source_script_tag", ["true"], [String(ExploreSourceAvailability.isVisible(source))])
        source.exploreUrl = " [{\"title\":\"推荐\",\"url\":\"/list\"}]"
        emit("explore_source_json_categories", ["true"], [String(ExploreSourceAvailability.isVisible(source))])
        source.exploreUrl = "https://sample.invalid/list"
        emit("explore_source_plain_url_rejected", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
        source.exploreUrl = " \n"
        emit("explore_source_whitespace_rejected", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
        source.storageKind = .remote
        source.ruleSearch.bookList = ""
        emit("explore_source_remote_summary", ["true"], [String(ExploreSourceAvailability.isVisible(source))])
        source.enabled = false
        emit("explore_source_remote_disabled", ["false"], [String(ExploreSourceAvailability.isVisible(source))])
    }
}
