// 原路径: ReadMain/Core/SourceParser/RuleSampleSelfTest.swift（T-1601-B1 新增）
// 证据:
//   - T-1601.md §B-1 验收：固定 HTML 样本断言
//     getString(rule: "//div[@class='x']/text()") 与
//     getString(rule: "$.data.name") 非 nil（样本入测试文件可复算）。
//   - 分派依据：RuleExecutorRegistry（pipelineExecutor 家族协议化承载）
//     的 mode → 执行器映射；xpath/json/default_/mode8 四模式在
//     T-1601-B1 接线前于字符串链直接返回 nil。
// 说明: 本文件是**可复算样本**而非 XCTest 目标（构建仓无 test target）；
//       -selfTestRules 启动参数下运行并打印 SELFTEST 行，CI 以
//       simctl launch --console 抓取后 grep 判定。
// 状态: 语义级还原（不是原始源码）
// 置信度: high（样本输入/规则/期望值固定，输出逐条打印）

import Foundation

/// 书源解析固定样本自测（T-1601-B1 验收）。
enum RuleSampleSelfTest {

    /// 单条样本。
    struct Sample {
        let name: String
        let content: String
        let rule: String
        let expect: [String]
        let asList: Bool
    }

    static let samples: [Sample] = [
        Sample(
            name: "xpath_text",
            content: "<html><body><div class=\"x\">hello</div></body></html>",
            rule: "//div[@class='x']/text()",
            expect: ["hello"],
            asList: false),
        Sample(
            name: "json_name",
            content: "{\"data\":{\"name\":\"Alice\"}}",
            rule: "$.data.name",
            expect: ["Alice"],
            asList: false),
        Sample(
            name: "css_text",
            content: "<html><body><div class=\"x\">hello</div></body></html>",
            rule: "@css:.x@text",
            expect: ["hello"],
            asList: false),
        Sample(
            name: "xpath_list",
            content: "<html><body><ul><li>a</li><li>b</li></ul></body></html>",
            rule: "//li/text()",
            expect: ["a", "b"],
            asList: true),
        Sample(
            name: "json_list",
            content: "{\"data\":{\"list\":[\"a\",\"b\"]}}",
            rule: "$.data.list",
            expect: ["a", "b"],
            asList: true),
        // B-2/B-3：JS 链（result 绑定 + java.put/get 混用）。
        Sample(
            name: "js_result",
            content: "hello",
            rule: "@js:result",
            expect: ["hello"],
            asList: false),
        Sample(
            name: "js_upper",
            content: "abc",
            rule: "@js:result.toUpperCase()",
            expect: ["ABC"],
            asList: false),
        Sample(
            name: "js_java_var",
            content: "",
            rule: "@js:java.put('k','v');java.get('k')",
            expect: ["v"],
            asList: false),
        Sample(
            name: "js_put_type",
            content: "",
            rule: "@js:typeof java.put",
            expect: ["function"],
            asList: false),
        Sample(
            name: "js_put_ret",
            content: "",
            rule: "@js:java.put('k','v')",
            expect: ["v"],
            asList: false),
        Sample(
            name: "js_list",
            content: "",
            rule: "@js:['a','b']",
            expect: ["a", "b"],
            asList: true),
    ]

    /// -selfTestRules 时运行、打印并退出（仅 CI 参数触发）。
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-selfTestRules")
        else { return }
        beginOutput()
        Task { @MainActor in
            run()
            await ReaderSampleSelfTest.run(emit: emit)
            await ReadAloudSampleSelfTest.run(emit: emit)
            await TtsPlayerSampleSelfTest.run(emit: emit)
            BookshelfActionSampleSelfTest.run(emit: emit)
            await SourceImportSampleSelfTest.run(emit: emit)
            await ReaderSelectionSampleSelfTest.run(emit: emit)
            await BookReviewSampleSelfTest.run(emit: emit)
            ReaderRenderingSampleSelfTest.run(emit: emit)
            await ReaderPageTurnSampleSelfTest.run(emit: emit)
            await ReaderPageCurlSampleSelfTest.run(emit: emit)
            ReaderRouteSampleSelfTest.run(emit: emit)
            ExploreSourceSampleSelfTest.run(emit: emit)
            BookDetailSampleSelfTest.run(emit: emit)
            await LocalBookSampleSelfTest.run(emit: emit)
            await LocalReaderSampleSelfTest.run(emit: emit)
            await EpubSampleSelfTest.run(emit: emit)
            await PDFSampleSelfTest.run(emit: emit)
            BackupArchiveSampleSelfTest.run(emit: emit)
            await BackupSelectionSampleSelfTest.run(emit: emit)
            await ReadingStatisticsSampleSelfTest.run(emit: emit)
            await WebDAVSampleSelfTest.run(emit: emit)
            ReadingDurationSampleSelfTest.run(emit: emit)
            await ReadingSettingsSampleSelfTest.run(emit: emit)
            await AppearanceBackupSampleSelfTest.run(emit: emit)
            LoginModelSampleSelfTest.run(emit: emit)
            LoginActionSampleSelfTest.run(emit: emit)
            LoginHeaderSampleSelfTest.run(emit: emit)
            LoginUISampleSelfTest.run(emit: emit)
            await ScreenAwakeSampleSelfTest.run(emit: emit)
            emitRaw("SELFTEST_END")
            exit(0)
        }
    }

    static func run() {
        for sample in samples {
            let analyzer = AnalyzeRule(source: nil, parent: nil)
            analyzer.setContent(sample.content, baseUrl: "")
            let actual: [String]
            if sample.asList {
                actual = analyzer.getStringList(
                    rule: sample.rule, isUrl: false)
            } else if let single = analyzer.getString(
                rule: sample.rule, isUrl: false) {
                actual = [single]
            } else {
                actual = []
            }
            emit(name: sample.name, expected: sample.expect,
                 actual: actual)
        }

        // 模式接线直测：default_（JSoup 单值）与 mode8（[String] 归一）。
        let html = AnalyzeRule(source: nil, parent: nil)
        html.setContent(
            "<html><body><div class=\"x\">hello</div></body></html>",
            baseUrl: "")
        let defaultExecutor = RuleExecutorRegistry.executor(for: .default_)
        if let css = defaultExecutor?.execute(
            rule: ".x@text", context: html) {
            emit(name: "default_jsoup", expected: ["hello"],
                 actual: [css])
        } else {
            emit(name: "default_jsoup", expected: ["hello"], actual: [])
        }

        let json = AnalyzeRule(source: nil, parent: nil)
        json.setContent("{\"data\":{\"name\":\"Alice\"}}", baseUrl: "")
        let mode8Executor = RuleExecutorRegistry.executor(for: .mode8)
        if let list = mode8Executor?.executeForList(
            rule: "$.data.name", context: json) {
            emit(name: "mode8_normalize", expected: ["Alice"],
                 actual: list)
        } else {
            emit(name: "mode8_normalize", expected: ["Alice"], actual: [])
        }

        runBridgeSamples()
    }

    // MARK: - B-5 三链离线样本（AnalyzeRuleBridge）

    /// 固定页面 → 搜索/详情/目录/正文四链可复算。
    private static func runBridgeSamples() {
        let html = """
        <html><body>
        <h1>Book T</h1>
        <span class="author">Author T</span>
        <div class="intro">Intro T</div>
        <a class="toc" href="/toc/1">目录</a>
        <div class="content">Content T</div>
        <div class="book"><h3>Book A</h3>\
        <span class="author">Author A</span>\
        <a href="/book/a">详情</a></div>
        <div class="book"><h3>Book B</h3>\
        <span class="author">Author B</span>\
        <a href="/book/b">详情</a></div>
        <ul class="toc"><li><a href="/c/1">Chapter 1</a></li>\
        <li><a href="/c/2">Chapter 2</a></li></ul>
        </body></html>
        """
        var source = BookSource(
            bookSourceUrl: "https://example.com/", bookSourceName: "sample")

        var searchRule = SearchRule()
        searchRule.bookList = "//div[@class='book']"
        searchRule.name = "//h3/text()"
        searchRule.author = "//span[@class='author']/text()"
        searchRule.bookUrl = "//a/@href"
        let books = (try? AnalyzeRuleBridge.parseSearchBooks(
            from: html, source: source, rule: searchRule)) ?? []
        emit(
            name: "bridge_search",
            expected: [
                "Book A|Author A|https://example.com/book/a",
                "Book B|Author B|https://example.com/book/b",
            ],
            actual: books.map {
                "\($0.name)|\($0.author ?? "")|\($0.bookUrl ?? "")"
            })

        var infoRule = BookInfoRule()
        infoRule.name = "//h1/text()"
        infoRule.author = "//span[@class='author']/text()"
        infoRule.intro = "//div[@class='intro']/text()"
        infoRule.tocUrl = "//a[@class='toc']/@href"
        source.ruleBookInfo = infoRule
        let info = (try? AnalyzeRuleBridge.parseBookInfo(
            from: html, source: source, book: Book())) ?? Book()
        emit(
            name: "bridge_bookinfo",
            expected: [
                "Book T|Author T|Intro T|https://example.com/toc/1",
            ],
            actual: [
                "\(info.name)|\(info.author ?? "")|\(info.intro ?? "")|"
                    + "\(info.tocUrl ?? "")",
            ])

        var tocRule = TocRule()
        tocRule.chapterList = "//ul[@class='toc']/li"
        tocRule.chapterName = "//a/text()"
        tocRule.chapterUrl = "//a/@href"
        let chapters = (try? AnalyzeRuleBridge.parseChapters(
            from: html, source: source, rule: tocRule)) ?? []
        emit(
            name: "bridge_toc",
            expected: [
                "Chapter 1|https://example.com/c/1|0",
                "Chapter 2|https://example.com/c/2|1",
            ],
            actual: chapters.map {
                "\($0.name)|\($0.url)|\($0.index)"
            })

        var contentRule = ContentRule()
        contentRule.content = "@css:.content@text"
        let content = AnalyzeRuleBridge.parseContent(
            from: html, source: source, rule: contentRule)
        emit(
            name: "bridge_content",
            expected: ["Content T"],
            actual: content.isEmpty ? [] : [content])

        // B-4：搜索 URL `{{key}}`/`{{page}}` 替换（关键字 URL 编码）。
        let analyzedURL = AnalyzeUrl(
            ruleUrl: "https://e.com/s?q={{key}}&p={{page}}",
            key: "中文 a", page: 3, baseUrl: "https://e.com")
        emit(
            name: "url_key_page",
            expected: [
                "https://e.com/s?q=%E4%B8%AD%E6%96%87%20a&p=3",
            ],
            actual: [analyzedURL.url])

        // B-3：java.put/get 变量域（inout 字典闭包签名确证）。
        _ = JavaBridge.put("selftest.key", "selftest.value")
        emit(
            name: "java_var",
            expected: ["selftest.value"],
            actual: [JavaBridge.get("selftest.key")])

        // B-5：XPath 属性选择 + 相对 URL 归一（baseUrl 继承域）。
        let attr = AnalyzeRule(source: nil, parent: nil)
        attr.setContent("<a href='/x'>L</a>", baseUrl: "https://e.com/")
        emit(
            name: "xpath_attr_url",
            expected: ["https://e.com/x"],
            actual: attr.getString(rule: "//a/@href", isUrl: true)
                .map { [$0] } ?? [])

        // C-0：ChangeSourceView 纯函数样本（匹配/排序/缓存键）。
        let matched = Book(
            bookUrl: "/b1", name: "Book A", author: "Author A",
            bookSourceUrl: "https://s1")
        let unmatched = Book(
            bookUrl: "/b2", name: "Other", author: "X",
            bookSourceUrl: "https://s2")
        emit(
            name: "change_source_match",
            expected: ["true", "false"],
            actual: [
                String(ChangeSourceView.isChangeSourceMatch(
                    matched, targetName: "Book A", targetAuthor: "Author A")),
                String(ChangeSourceView.isChangeSourceMatch(
                    unmatched, targetName: "Book A", targetAuthor: "Author A")),
            ])
        let sourceA = BookSource(
            bookSourceUrl: "https://s1", bookSourceName: "A")
        let sourceB = BookSource(
            bookSourceUrl: "https://s2", bookSourceName: "B")
        let sorted = ChangeSourceView.sortedChangeSources(
            [sourceB, sourceA], speedSnapshot: ["https://s1": 0.5])
        emit(
            name: "change_source_sorted",
            expected: ["https://s1,https://s2"],
            actual: [sorted.map(\.bookSourceUrl).joined(separator: ",")])
        emit(
            name: "change_source_key",
            expected: ["book a|author a"],
            actual: [ChangeSourceCacheIdentity.cacheKey(for: matched)])
    }

    /// 稳定输出（CI grep `SELFTEST` + `pass=`）。同时逐行落盘——控制台
    /// 输出在进程异常退出时会因 stdio 缓冲丢失（run6 无输出根因防护）。
    private static func emit(
        name: String, expected: [String], actual: [String]
    ) {
        let pass = expected == actual
        emitRaw(
            "SELFTEST \(name) pass=\(pass) "
                + "expected=\(expected) actual=\(actual)")
    }

    private static func emitRaw(_ line: String) {
        print(line)
        fflush(stdout)
        appendToFile(line + "\n")
    }

    private static var outputURL: URL {
        let dir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("selftest.txt")
    }

    private static func beginOutput() {
        try? "SELFTEST_BEGIN\n".write(
            to: outputURL, atomically: true, encoding: .utf8)
    }

    private static func appendToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: outputURL.path) {
            try? data.write(to: outputURL, options: .atomic)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: outputURL) else {
            return
        }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }
}
