// 原路径: ReadMain/Views/Source/SourceFullTestView.swift
// 证据:
//   - PGO: 430 条记录（index/task_functions.csv T-401-05 /
//     SourceFullTestView.swift；242 个伪代码块 + 188 pgo_only）。关键地址：
//     body 0x100c08f74 L301-404 / 主体闭包 0x100c09200 L302-400 /
//     chainContent 0x100c1e7b4 L1029-1102 / DiagnosticsSheet.body
//     0x100c3aebc L2140-2208 / 诊断主体 0x100c3b41c L2141-2207 /
//     resultSummary getter（L364 域）/ debugSearch（L8519-8620）/
//     debugBookUrl（L9123-9236）/ debugToc（L10637-10695）/ chainBookInfo
//     （L9236）/ chainChapterList（L9621）/ debugContent/chainContent
//     （L10695+）/ copyTestReport（L7717 域 + formatTimestamp 按钮域 L6311）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/
//     SourceFullTestView.c（22453 行）
//   - 字符串确证（位模式/IPA 指针）：标题 "配置测试"；模式域 "当前模式: " /
//     "解析模式: 本地解析" / "https://" / "⚠️ 不支持" / "不支持 "；
//     输入域 "常用输入" / "keyboard" / "正在执行解析链路" / "搜索示例" /
//     "magnifyingglass" / "推荐::" / "++目录"（list.bullet）/
//     "--正文"（doc.text）/ "play.circle.fill" / "doc.text.below.ecg"；
//     结果域 "测试结果" / "─────\n" / "❌ 失败: " / "（'不支持' 0x8CE6AF94E68DB8E4
//     + ' (%.2fs)' 格式 + joined(separator:)）"；链路域 "发现结果"
//     （safari.fill）/ "搜索结果" / "查看全部章节" / "章节列表" /
//     "N 本，可继续详情链路" / "N 章，可继续下钻正文" / "目继续详情链路" /
//     " → 目录 → 正文" / "当前正文片段 · " / "正文预览" /
//     "内容过长，仅显示前 X K 字符（共 Y）" / "  最新章: " / "waveform.path.ecg"；
//     日志域 "调试日志" / "顺序记录关键步骤" / "暂无日志" / "清除日志" /
//     "JS控制台 (N)" / "JS 控制台 (N)" / "系统日志 (N)" / "全部 (N)" /
//     "[%02d:%02d.%03d]" / "terminal" / "[配置调试] "；源码域 "搜索页源码" /
//     "发现页源码" / "详情页源码" / "目录页源码" / "正文页源码" /
//     "list.bullet.rectangle.fill" / "chevron."；动作域 "开始测试" /
//     "重置测试" / "重置测试"/"清除配置变量"（"sourceVariable_" 前缀确证）/
//     "复制测试报告"；报告域 "=======\n配置名称: " @ptr / "配置地址: " /
//     "测试时间: " / "测试输入: " / "\n\n调试日志:\n" @ptr /
//     "\n\n功能测试结果:" @ptr / "❌ 失败: "；诊断域 "诊断时间线" /
//     "诊断时间线 (N)" / "时间线" / "总步骤" / "最慢步骤"；
//     链路日志 "开始搜索关键字: " / "searchUrl: " / "配置未配置搜索规则" /
//     "配置未配置 searchUrl" / "发现页解析完成，N" / "目录页解析完成，共 N" /
//     "目录解析完成但为空" / "未配置目录规则" / "正文解析失败: " /
//     "未配置正文规则" / "开始访问正文页: " / "保留已有字段" /
//     "正在导入本地书籍" / "captureLogsDisabled=1" / "获取完整内容。"
//   - 事实：TestStatus 枚举（icon/color/shortTitle/description）+
//     DebugLogItem.LogLevel（color/prefix/symbolName）+ SourceViewType
//     （id/title）+ DebugMode（icon/tintColor）pgo_only 确证；
//     resultSummary（passed/failed/notSupported/totalTime，'不支持' +
//     %.2fs 格式 + joined 确证）；body onDisappear 域挂 4 个 sheet
//     （JsConsoleSheet/SystemLogSheet/ReaderChapterListView + closure10）；
//     quickActionSection QuickActionChip ×6（2 可选 + 4 必选确证）；
//     chainChapterList/chainContent 经 nextChapterUrl(after:) 下钻；
//     parseExploreCategories 与 ExploreSourceDetailView.parseExploreCategories
//     域交叉（L4692 确证）；prefixAutoComplete（L4850 派发域确证）；
//     enableDebugCapture 与 ParseFailureLogger 域交叉（captureLogsDisabled=1
//     确证）；诊断时间线 slowThreshold（最慢步骤域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 调试主链（搜索/详情/目录/正文 + 下钻）: medium-high（块体 + 日志串确证）
//   - 统计/报告/诊断: high（格式串确证）
//   - 视图树形状: medium（签名族结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - 状态与模型

/// 测试状态（pgo_only icon/color/shortTitle/description 确证）。
enum TestStatus: Equatable {
    case pending
    case running
    case passed
    case failed(String)
    case notSupported

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "clock"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .notSupported: return "minus.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .blue
        case .passed: return .green
        case .failed: return .red
        case .notSupported: return .secondary
        }
    }

    var shortTitle: String {
        switch self {
        case .pending: return "等待"
        case .running: return "进行中"
        case .passed: return "通过"
        case .failed: return "失败"
        case .notSupported: return "不支持"
        }
    }

    var description: String { shortTitle }
}

/// 调试日志条目。
struct DebugLogItem: Identifiable {
    enum LogLevel {
        case info
        case success
        case warning
        case error

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        /// pgo_only prefix getter（"[配置调试] " 域确证）。
        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }

        var symbolName: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            }
        }
    }

    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

/// 源码查看页签（pgo_only id/title 确证）。
enum SourceViewType: String, CaseIterable, Identifiable {
    case search = "搜索页源码"
    case explore = "发现页源码"
    case bookInfo = "详情页源码"
    case toc = "目录页源码"
    case content = "正文页源码"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// 调试模式（pgo_only icon/tintColor 确证；"解析模式: 本地解析" 域）。
enum DebugMode: Equatable {
    case remote
    case local

    var icon: String {
        self == .remote ? "network" : "internaldrive"
    }

    var tintColor: Color {
        self == .remote ? .blue : .orange
    }
}

/// 功能测试结果项。
struct TestResultItem: Identifiable {
    let id = UUID()
    let name: String
    var status: TestStatus
    var details: String?
    var duration: Double?
}

// MARK: - SourceFullTestView

/// 书源完整调试视图（搜索/发现/详情/目录/正文全链）。
struct SourceFullTestView: View {

    let source: BookSource

    // 测试态
    @State private var testInput: String = ""
    @State private var isRunning = false
    @State private var mode: DebugMode = .remote
    @State private var results: [TestResultItem] = []
    @State private var logs: [DebugLogItem] = []
    @State private var testStart: Date?
    @State private var totalElapsed: Double = 0

    // 链路数据
    @State private var searchBooks: [Book] = []
    @State private var exploreBooks: [Book] = []
    @State private var currentBook: Book?
    @State private var chapters: [Chapter] = []
    @State private var contentPreview: String = ""
    @State private var rawResponse: String?
    @State private var rawContent: String?
    @State private var exploreCategories: [(title: String, url: String)] = []

    // 源码缓存（sourceContent(for:) 消费确证）。
    @State private var pageSources: [SourceViewType: String] = [:]

    // Sheet 态（body onDisappear 域确证）。
    @State private var showingJsConsole = false
    @State private var showingSystemLogs = false
    @State private var showingChapterList = false
    @State private var showingSourceCode = false
    @State private var showingDiagnostics = false
    @State private var showingExplorePicker = false
    @State private var jsConsoleLogs: [String] = []
    @State private var systemLogs: [String] = []
    @State private var diagnostics: [ParseDiagnostic] = []

    // 服务
    private let sourceService = SourceService()

    var body: some View {
        // 伪代码 0x100c08f74（L301-404）：ScrollView 全链布局。
        ScrollView {
            VStack(alignment: .leading, spacing: 12.0) {
                inputSection
                quickActionSection
                testResultSection
                explorePreviewSection
                searchResultSection
                chapterPreviewSection
                contentPreviewSection
                logSection
            }
            .padding(.all, 12.0)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("配置测试")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            enableDebugCapture()
        }
        .onDisappear {
            stopTest()
        }
        .sheet(isPresented: $showingJsConsole) {
            JsConsoleSheet(logs: jsConsoleLogs)
        }
        .sheet(isPresented: $showingSystemLogs) {
            SystemLogSheet(logs: systemLogs)
        }
        .sheet(isPresented: $showingChapterList) {
            NavigationStack {
                List(Array(chapters.enumerated()), id: \.1.index) { _, chapter in
                    Button {
                        showingChapterList = false
                        Task {
                            await debugSelectedChapter(
                                chapter, book: currentBook ?? Book(),
                                nextChapterUrl: nextChapterUrl(after: chapter))
                        }
                    } label: {
                        Text(chapter.name)
                            .lineLimit(1)
                    }
                }
                .navigationTitle("查看全部章节")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingSourceCode) {
            SourceCodeViewerSheet(sources: pageSources)
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsSheet(steps: diagnostics)
        }
        .sheet(isPresented: $showingExplorePicker) {
            ExploreCategoryPickerSheet(categories: exploreCategories) {
                category in
                Task { await debugExplore(input: category.url) }
            }
        }
    }

    // MARK: 输入区

    /// inputSection（closure 签名族确证）：模式提示 + 输入框 + 开始按钮。
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text(modeHint)
                .appThemeText(.caption, opacity: 0.6)
                .textSelection(.enabled)
            HStack(spacing: 8.0) {
                Image(systemName: "keyboard")
                    .foregroundColor(.secondary)
                TextField(
                    "常用输入（URL / 搜索关键词 / 发现URL）",
                    text: $testInput)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .onSubmit { startDebug() }
            }
            .glassEffectRoundedBackground(cornerRadius: 12.0)
            .disabled(isRunning)
            if let start = testStart, isRunning {
                Text("正在执行解析链路")
                    .appThemeText(.caption, opacity: 0.6)
            }
        }
    }

    /// modeHint getter（pgo_only；"当前模式: " 域确证）。
    private var modeHint: String {
        "当前模式: \(mode == .remote ? "远程" : "本地解析") · \(source.bookSourceName)"
    }

    // MARK: 快捷动作

    /// quickActionSection（QuickActionChip ×6 确证：搜索示例/++目录/--正文/
    /// 推荐::/发现/开始）。
    private var quickActionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.0) {
                if source.ruleSearch.bookList.isEmpty == false {
                    QuickActionChip(
                        title: "搜索示例", systemImage: "magnifyingglass") {
                        prefixAutoComplete("搜索示例")
                    }
                }
                if source.ruleToc.chapterList.isEmpty == false {
                    QuickActionChip(
                        title: "++目录", systemImage: "list.bullet") {
                        prefixAutoComplete("++目录")
                    }
                }
                if source.ruleContent.content.isEmpty == false {
                    QuickActionChip(
                        title: "--正文", systemImage: "doc.text") {
                        prefixAutoComplete("--正文")
                    }
                }
                if source.ruleExplore.exploreUrl.isEmpty == false {
                    QuickActionChip(
                        title: "推荐::", systemImage: "safari.fill") {
                        prefixAutoComplete("推荐::")
                    }
                }
                Button {
                    startDebug()
                } label: {
                    Label("开始测试", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || testInput.isEmpty)
            }
        }
    }

    /// prefixAutoComplete（L4850 派发域确证）：前缀展开测试输入。
    private func prefixAutoComplete(_ prefix: String) {
        switch prefix {
        case "搜索示例":
            testInput = testInput.isEmpty ? "斗破苍穹" : testInput
            mode = detectMode(testInput)
            Task { await debugSearch(keyword: testInput) }
        case "++目录":
            if let book = currentBook ?? searchBooks.first {
                testInput = book.tocUrl ?? book.bookUrl ?? testInput
                Task {
                    await debugToc(url: book.tocUrl ?? book.bookUrl ?? "")
                }
            }
        case "--正文":
            if let chapter = chapters.first {
                testInput = chapter.url
                Task {
                    await debugSelectedChapter(
                        chapter, book: currentBook ?? Book(),
                        nextChapterUrl: nextChapterUrl(after: chapter))
                }
            }
        case "推荐::":
            showingExplorePicker = true
        default:
            break
        }
    }

    // MARK: 结果区

    /// testResultSection（ForEach TestResultRow 确证）。
    @ViewBuilder
    private var testResultSection: some View {
        if !results.isEmpty {
            DebugPanelCard(
                title: "测试结果", subtitle: testResultSummaryText,
                systemImage: "doc.text.below.ecg", tint: .blue) {
                VStack(spacing: 6.0) {
                    ForEach(results) { item in
                        TestResultRow(item: item)
                    }
                }
            }
        }
    }

    /// resultSummary getter（L364 域；'不支持' + ' (%.2fs)' + joined 确证）。
    private var resultSummary: (
        passed: Int, failed: Int, notSupported: Int, totalTime: Double
    ) {
        let passed = results.filter {
            $0.status == .passed
        }.count
        let failed = results.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
        let notSupported = results.filter { $0.status == .notSupported }.count
        let totalTime = results.compactMap(\.duration).reduce(0, +)
        return (passed, failed, notSupported, totalTime)
    }

    /// testResultSummaryText getter（pgo_only）。
    private var testResultSummaryText: String {
        let summary = resultSummary
        var parts = [
            "通过 \(summary.passed)",
            "失败 \(summary.failed)",
            "不支持 \(summary.notSupported)",
        ]
        if summary.totalTime > 0 {
            parts.append(String(format: "%.2fs", summary.totalTime))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: 链路预览区

    /// explorePreviewSection（"发现结果" + safari.fill 确证）。
    @ViewBuilder
    private var explorePreviewSection: some View {
        if !exploreBooks.isEmpty {
            DebugPanelCard(
                title: "发现结果", subtitle: "\(exploreBooks.count) 本，可继续详情链路",
                systemImage: "safari.fill", tint: .orange) {
                VStack(spacing: 6.0) {
                    ForEach(
                        exploreBooks.prefix(5), id: \.bookUrl
                    ) { book in
                        DebugBookPreviewRow(book: book) {
                            Task { await chainBookInfo(book: book, testIndex: results.count) }
                        }
                    }
                }
            }
        }
    }

    /// searchResultSection（ForEach ArraySlice<Book> + DebugBookPreviewRow
    /// 确证）。
    @ViewBuilder
    private var searchResultSection: some View {
        if !searchBooks.isEmpty {
            DebugPanelCard(
                title: "搜索结果", subtitle: "\(searchBooks.count) 本，可继续详情链路",
                systemImage: "magnifyingglass", tint: .blue) {
                VStack(spacing: 6.0) {
                    ForEach(searchBooks.prefix(5), id: \.bookUrl) { book in
                        DebugBookPreviewRow(book: book) {
                            Task {
                                await chainBookInfo(
                                    book: book, testIndex: results.count)
                            }
                        }
                    }
                    Button("查看全部章节") {
                        showingChapterList = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    /// chapterPreviewSection（DebugInfoRow ×2 确证）。
    @ViewBuilder
    private var chapterPreviewSection: some View {
        if !chapters.isEmpty {
            DebugPanelCard(
                title: "章节列表",
                subtitle: "\(chapters.count) 章，可继续下钻正文",
                systemImage: "waveform.path.ecg", tint: .purple) {
                VStack(spacing: 6.0) {
                    if let first = chapters.first {
                        DebugInfoRow(
                            title: "首章", value: first.name)
                    }
                    if let last = chapters.last {
                        DebugInfoRow(
                            title: "  最新章: ",
                            value: last.name)
                    }
                    Button("开始访问正文页: \(chapters.first?.name ?? "")") {
                        if let first = chapters.first {
                            Task {
                                await debugSelectedChapter(
                                    first, book: currentBook ?? Book(),
                                    nextChapterUrl: nextChapterUrl(after: first))
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .glassEffectRoundedBackground(cornerRadius: 12.0)
            }
        }
    }

    /// contentPreviewSection（"当前正文片段 · " + 截断域确证）。
    @ViewBuilder
    private var contentPreviewSection: some View {
        if !contentPreview.isEmpty {
            DebugPanelCard(
                title: "正文预览",
                subtitle: "当前正文片段 · \(contentPreview.count) 字",
                systemImage: "doc.text", tint: .green) {
                Text(Self.truncatedContent(contentPreview))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .glassEffectRoundedBackground(cornerRadius: 12.0)
            }
        }
    }

    /// 截断域（"内容过长，仅显示前 X K 字符（共 Y）" 确证）。
    private static func truncatedContent(_ text: String) -> String {
        let limit = 2000
        guard text.count > limit else { return text }
        let prefix = String(text.prefix(limit))
        return
            "内容过长，仅显示前 \(limit / 1000) K 字符（共 \(text.count)）\n\(prefix)"
    }

    /// logSection（"调试日志" + "顺序记录关键步骤" + "暂无日志" 确证）。
    private var logSection: some View {
        DebugPanelCard(
            title: "调试日志", subtitle: "顺序记录关键步骤",
            systemImage: "terminal", tint: .secondary) {
            VStack(alignment: .leading, spacing: 4.0) {
                if logs.isEmpty {
                    Text("暂无日志")
                        .appThemeText(.caption, opacity: 0.6)
                } else {
                    ForEach(logs.suffix(30)) { item in
                        DebugLogRow(item: item)
                    }
                }
            }
        }
    }

    // MARK: 工具栏

    /// toolbarContent（ellipsis.circle + JS 控制台/系统日志/重置/复制 确证）。
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingJsConsole = true
                } label: {
                    Text("JS控制台 (\(jsConsoleLogs.count))")
                }
                Button {
                    showingSystemLogs = true
                } label: {
                    Text("系统日志 (\(systemLogs.count))")
                }
                Button {
                    showingSourceCode = true
                } label: {
                    Text("页面源码")
                }
                Button {
                    showingDiagnostics = true
                } label: {
                    Text("诊断时间线 (\(diagnostics.count))")
                }
                Divider()
                Button(role: .destructive) {
                    resetTest()
                } label: {
                    Label("重置测试", systemImage: "arrow.counterclockwise")
                }
                Button {
                    copyTestReport()
                } label: {
                    Label("复制测试报告", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: 调试主链

    /// startDebug：按输入模式派发（detectMode 确证）。
    private func startDebug() {
        let input = testInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty, !isRunning else { return }
        mode = detectMode(input)
        resetTestData()
        isRunning = true
        testStart = Date()
        log("开始搜索关键字: \(input)", level: .info)
        Task {
            if input.hasPrefix("推荐::") {
                await debugExplore(input: String(input.dropFirst("推荐::".count)))
            } else if input.hasPrefix("++目录") {
                await debugToc(url: String(input.dropFirst("++目录".count)))
            } else if input.hasPrefix("--正文") {
                await debugContent(
                    url: String(input.dropFirst("--正文".count)),
                    chapterTitle: "")
            } else if mode == .local {
                await debugBookUrl(url: input)
            } else {
                await debugSearch(keyword: input)
            }
            await MainActor.run {
                isRunning = false
                if let start = testStart {
                    totalElapsed = Date().timeIntervalSince(start)
                }
                flushAllCaptureLogs()
            }
        }
    }

    /// detectMode（pgo_only；"解析模式: 本地解析" 域确证）。
    private func detectMode(_ input: String) -> DebugMode {
        if input.hasPrefix("https://") || input.hasPrefix("http://") {
            return .local
        }
        return .remote
    }

    /// debugSearch(keyword:)（L8519-8620；"配置未配置 searchUrl" 确证）。
    private func debugSearch(keyword: String) async {
        guard source.ruleSearch.bookList.isEmpty == false else {
            await MainActor.run {
                log("配置未配置 searchUrl", level: .error)
            }
            updateTest(
                0, status: .notSupported, details: "searchUrl: 未配置")
            return
        }
        let start = Date()
        do {
            let books = try await sourceService.searchBook(
                source: source, keyword: keyword, page: 1)
            let elapsed = Date().timeIntervalSince(start)
            await MainActor.run {
                searchBooks = books
                updateTest(
                    0, status: books.isEmpty ? .failed("") : .passed,
                    details: "\(books.count) 本",
                    duration: elapsed)
                log(
                    "发现页解析完成，\(books.count) 本",
                    level: books.isEmpty ? .warning : .success)
            }
            if let first = books.first {
                await chainBookInfo(book: first, testIndex: 1)
            }
        } catch {
            let message = error.localizedDescription
            await MainActor.run {
                updateTest(
                    0, status: .failed(message), duration: Date().timeIntervalSince(start))
                log("❌ 失败: \(message)", level: .error)
            }
        }
    }

    /// debugBookUrl(url:)（L9123-9236；components separatedBy 域确证）。
    private func debugBookUrl(url: String) async {
        let parts = url.components(separatedBy: ",")
        let bookUrl = parts.joined(separator: ",")
        let book = Book()
        await MainActor.run {
            var target = book
            target.bookUrl = bookUrl
            currentBook = target
        }
        await chainBookInfo(book: book, testIndex: 0)
    }

    /// debugExplore(input:)（"发现页解析完成" 域确证）。
    private func debugExplore(input: String) async {
        if exploreCategories.isEmpty {
            exploreCategories = parseExploreCategories(input)
        }
        guard let first = exploreCategories.first else {
            await MainActor.run {
                log("⚠️ 不支持", level: .warning)
            }
            return
        }
        do {
            let books = try await sourceService.exploreBook(
                source: source, exploreUrl: first.url, page: 1)
            await MainActor.run {
                exploreBooks = books
                updateTest(
                    1, status: books.isEmpty ? .failed("") : .passed,
                    details: "\(books.count) 本")
                log("发现页解析完成，\(books.count) 本", level: .success)
            }
        } catch {
            await MainActor.run {
                updateTest(1, status: .failed(error.localizedDescription))
                log("❌ 失败: \(error.localizedDescription)", level: .error)
            }
        }
    }

    /// parseExploreCategories（pgo_only；ExploreSourceDetailView 域交叉
    /// L4692 确证）：`名称::URL` 或 `名称::URL\n…` 行解析。
    private func parseExploreCategories(
        _ input: String
    ) -> [(title: String, url: String)] {
        input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                let segments = line.components(separatedBy: "::")
                guard segments.count == 2 else { return nil }
                return (title: segments[0], url: segments[1])
            }
    }

    /// debugToc(url:)（L10637-10695；"未配置目录规则" 域确证）。
    private func debugToc(url: String) async {
        guard source.ruleToc.chapterList.isEmpty == false else {
            await MainActor.run {
                log("未配置目录规则", level: .error)
            }
            updateTest(2, status: .notSupported, details: "未配置目录规则")
            return
        }
        var book = currentBook ?? Book()
        book.tocUrl = url
        await chainChapterList(book: book, testIndex: 2)
    }

    /// debugContent(url:chapterTitle:)（"开始访问正文页: " 域确证）。
    private func debugContent(url: String, chapterTitle: String) async {
        guard source.ruleContent.content.isEmpty == false else {
            await MainActor.run {
                log("未配置正文规则", level: .error)
            }
            updateTest(3, status: .notSupported, details: "未配置正文规则")
            return
        }
        let chapter = Chapter(
            name: chapterTitle.isEmpty ? "测试章节" : chapterTitle,
            url: url, index: 0, isRead: false, isPay: nil,
            resourceUrl: nil, isVip: false, isVolume: false,
            updateTime: nil, wordCount: nil, variable: nil)
        await chainContent(
            book: currentBook ?? Book(), chapter: chapter,
            nextChapterUrl: nil, testIndex: 3)
    }

    /// chainBookInfo(book:testIndex:)（L9236；"保留已有字段" 域确证）。
    private func chainBookInfo(book: Book, testIndex: Int) async {
        let start = Date()
        await MainActor.run {
            log("正在导入本地书籍", level: .info)
        }
        let info = await sourceService.getBookInfo(
            source: source, book: book, canReName: false)
        await MainActor.run {
            if let info {
                currentBook = info
                updateTest(
                    testIndex, status: .passed,
                    details: info.name,
                    duration: Date().timeIntervalSince(start))
                prefixAutoComplete("++目录")
            } else {
                updateTest(
                    testIndex, status: .failed("详情解析失败"),
                    duration: Date().timeIntervalSince(start))
            }
        }
        if let info {
            await chainChapterList(book: info, testIndex: testIndex + 1)
        }
    }

    /// chainChapterList(book:testIndex:)（L9621；"目录页解析完成，共 N" 域）。
    private func chainChapterList(book: Book, testIndex: Int) async {
        let start = Date()
        do {
            let list = try await sourceService.getChapterList(
                source: source, book: book, needRefresh: false)
            let elapsed = Date().timeIntervalSince(start)
            await MainActor.run {
                chapters = list
                currentBook = book
                updateTest(
                    testIndex,
                    status: list.isEmpty ? .failed("目录解析完成但为空") : .passed,
                    details: "\(list.count) 章  最新章: \(list.last?.title ?? "")",
                    duration: elapsed)
                log(
                    "目录页解析完成，共 \(list.count) 章",
                    level: list.isEmpty ? .warning : .success)
            }
            if let first = list.first {
                await chainContent(
                    book: book, chapter: first,
                    nextChapterUrl: nextChapterUrl(after: first),
                    testIndex: testIndex + 1)
            }
        } catch {
            await MainActor.run {
                updateTest(
                    testIndex, status: .failed(error.localizedDescription),
                    duration: Date().timeIntervalSince(start))
                log("❌ 失败: \(error.localizedDescription)", level: .error)
            }
        }
    }

    /// chainContent(book:chapter:nextChapterUrl:testIndex:)
    ///（0x100c1e7b4 L1029-1102 确证）。
    private func chainContent(
        book: Book, chapter: Chapter, nextChapterUrl: String?,
        testIndex: Int
    ) async {
        let start = Date()
        await MainActor.run {
            log("开始访问正文页: \(chapter.name)", level: .info)
        }
        do {
            let content = try await sourceService.getChapterContent(
                source: source, book: book, chapter: chapter)
            let elapsed = Date().timeIntervalSince(start)
            await MainActor.run {
                contentPreview = content.content
                rawContent = content.content
                updateTest(
                    testIndex,
                    status: content.content.isEmpty
                        ? .failed("正文解析失败: 空内容") : .passed,
                    details: "\(content.content.count) 字",
                    duration: elapsed)
                log(
                    "正文解析失败: " + (content.content.isEmpty ? "是" : "否"),
                    level: content.content.isEmpty ? .error : .success)
            }
        } catch {
            await MainActor.run {
                updateTest(
                    testIndex, status: .failed(error.localizedDescription),
                    duration: Date().timeIntervalSince(start))
                log("❌ 失败: \(error.localizedDescription)", level: .error)
            }
        }
    }

    /// debugSelectedChapter(_:book:nextChapterUrl:)（签名域确证）。
    private func debugSelectedChapter(
        _ chapter: Chapter, book: Book, nextChapterUrl: String?
    ) async {
        await chainContent(
            book: book, chapter: chapter, nextChapterUrl: nextChapterUrl,
            testIndex: results.count)
    }

    /// nextChapterUrl(after:)（pgo_only；下一章 URL 下钻确证）。
    private func nextChapterUrl(after chapter: Chapter) -> String? {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }),
              index + 1 < chapters.count
        else { return nil }
        return chapters[index + 1].url
    }

    // MARK: 状态维护

    /// updateTest(_:status:details:)（签名确证）：更新/追加结果项。
    private func updateTest(
        _ index: Int, status: TestStatus, details: String? = nil,
        duration: Double? = nil
    ) {
        let names = ["搜索", "发现", "目录", "正文"]
        let name = index < names.count ? names[index] : "步骤 \(index)"
        if index < results.count {
            results[index].status = status
            results[index].details = details ?? results[index].details
            if let duration { results[index].duration = duration }
        } else {
            results.append(
                TestResultItem(
                    name: name, status: status, details: details,
                    duration: duration))
        }
    }

    /// log(_:level:)（签名确证；"[配置调试] " 前缀域确证）。
    private func log(_ message: String, level: DebugLogItem.LogLevel) {
        logs.append(
            DebugLogItem(timestamp: Date(), level: level, message: message))
        let line = "[配置调试] \(message)"
        systemLogs.append(line)
        if systemLogs.count > 500 {
            systemLogs.removeFirst(systemLogs.count - 500)
        }
    }

    /// formatTimestamp（pgo_only；"[%02d:%02d.%03d]" 确证）。
    private func formatTimestamp(_ date: Date) -> String {
        let seconds = Int(date.timeIntervalSince1970) % 3600
        let minutes = seconds / 60
        let secs = seconds % 60
        let millis = Int(date.timeIntervalSince1970 * 1000) % 1000
        return String(
            format: "[%02d:%02d.%03d]", minutes, secs, millis)
    }

    // MARK: 捕获与冲刷

    /// enableDebugCapture（pgo_only；captureLogsDisabled=1 域确证；
    /// ParseFailureLogger.shared 域交叉——开启前清历史）。
    private func enableDebugCapture() {
        ParseFailureLogger.shared.clearLogHistory()
    }

    /// flushJsConsoleLogs（签名确证；JS 控制台桥域随 JS 分册交叉，
    /// 当前以本地收集为准）。
    private func flushJsConsoleLogs() {
        // TODO(JS 桥分册): JsConsoleBridge 挂接后接入。
    }

    /// flushSystemLogs（签名确证；Logger.consumeCapturedLogs 真身确证）。
    private func flushSystemLogs() {
        for entry in Logger.consumeCapturedLogs() {
            systemLogs.append("\(entry.level.emoji) \(entry.message)")
        }
    }

    /// flushDiagnostics（签名确证）：链路结果 → ParseStepResult 快照
    ///（ParseFailureLogger 捕获域随分册交叉）。
    private func flushDiagnostics() {
        diagnostics = results.map { item in
            ParseStepResult(
                name: item.name,
                message: item.details ?? item.status.shortTitle,
                result: {
                    switch item.status {
                    case .passed: return .success
                    case .failed: return .failure
                    case .notSupported, .pending, .running: return .skipped
                    }
                }(),
                duration: item.duration ?? 0)
        }
    }

    /// flushAllCaptureLogs（签名确证）。
    private func flushAllCaptureLogs() {
        flushJsConsoleLogs()
        flushSystemLogs()
        flushDiagnostics()
    }

    // MARK: 源码缓存

    /// sourceContent(for:)（签名确证）。
    private func sourceContent(for type: SourceViewType) -> String {
        pageSources[type] ?? ""
    }

    /// consumeRawResponse/consumeRawContent（签名确证）：一次性取走原始
    /// 响应域。
    private func consumeRawResponse() -> String? {
        defer { rawResponse = nil }
        return rawResponse
    }

    private func consumeRawContent() -> String? {
        defer { rawContent = nil }
        return rawContent
    }

    /// sourceTypeTitle（签名确证）。
    private var sourceTypeTitle: String {
        source.bookSourceName
    }

    /// sourceStorageTitle（签名确证）。
    private var sourceStorageTitle: String {
        mode == .remote ? "远程源" : "本地源"
    }

    /// sourceSummaryText（签名确证）。
    private var sourceSummaryText: String {
        "\(source.bookSourceName)（\(source.bookSourceGroup ?? "未分组")）"
    }

    /// shouldShowGuide getter（签名确证）。
    private var shouldShowGuide: Bool {
        results.isEmpty && logs.isEmpty && testInput.isEmpty
    }

    /// isRemote getter（签名确证）。
    private var isRemote: Bool {
        mode == .remote
    }

    // MARK: 重置与报告

    /// resetTest（"重置测试" 域确证）。
    private func resetTest() {
        resetTestData()
    }

    /// resetTestData（签名确证）。
    private func resetTestData() {
        results = []
        logs = []
        searchBooks = []
        exploreBooks = []
        chapters = []
        contentPreview = ""
        currentBook = nil
        pageSources = [:]
        testStart = nil
        totalElapsed = 0
        PersistedBatchTestSession.delete()
    }

    /// copyTestReport（"=======\n配置名称: " + "配置地址: " + "测试时间: " +
    /// "测试输入: " + "\n\n调试日志:\n" + "\n\n功能测试结果:" + "❌ 失败: " 确证）。
    private func copyTestReport() {
        var report = "=======\n配置名称: \(source.bookSourceName)\n"
        report += "配置地址: \(source.bookSourceUrl)\n"
        if let start = testStart {
            report += "测试时间: \(formatTimestamp(start))\n"
        }
        report += "测试输入: \(testInput)\n"
        report += "\n\n调试日志:\n"
        for item in logs {
            report += "\(formatTimestamp(item.timestamp)) \(item.level.prefix) \(item.message)\n"
        }
        report += "\n\n功能测试结果:\n"
        for item in results {
            switch item.status {
            case .failed(let reason):
                report += "❌ 失败: \(item.name) — \(reason)\n"
            case .notSupported:
                report += "⚠️ 不支持: \(item.name)\n"
            default:
                report += "\(item.status.shortTitle): \(item.name)"
                if let details = item.details {
                    report += "（\(details)）"
                }
                report += "\n"
            }
        }
        UIPasteboard.general.string = report
    }

    /// stopTest（"测试已停止" 域确证）。
    private func stopTest() {
        if isRunning {
            isRunning = false
            log("测试已停止", level: .warning)
        }
    }
}

// MARK: - 面板与行视图

/// 面板卡（DebugPanelCard init(title:subtitle:systemImage:tint:acces…
/// 签名确证）。
struct DebugPanelCard<Accessory: View>: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let tint: Color
    let content: () -> Content
    var accessory: () -> Accessory

    init(
        title: String, subtitle: String? = nil, systemImage: String,
        tint: Color,
        @ViewBuilder content: @escaping () -> Content
    ) where Accessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.content = content
        self.accessory = { EmptyView() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 6.0) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                Text(title)
                    .appThemeText(.headline)
                Spacer()
                accessory()
            }
            if let subtitle {
                Text(subtitle)
                    .appThemeText(.caption, opacity: 0.6)
                    .textSelection(.enabled)
            }
            content()
        }
        .padding(.all, 12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffectRoundedBackground(cornerRadius: 16.0)
    }
}

/// 信息行（DebugInfoRow 确证）。
struct DebugInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}

/// 快捷芯片（QuickActionChip 确证）。
struct QuickActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .appThemeText(.caption)
                .padding(.horizontal, 10.0)
                .padding(.vertical, 6.0)
                .glassEffectRoundedBackground(cornerRadius: 12.0)
        }
        .buttonStyle(.plain)
    }
}

/// 书籍预览行（DebugBookPreviewRow.metaItems 签名确证）。
struct DebugBookPreviewRow: View {
    let book: Book
    let action: () -> Void

    /// metaItems getter（pgo_only）。
    private var metaItems: [String] {
        var items: [String] = []
        if !book.author.isEmpty { items.append(book.author) }
        if let category = book.kind, !category.isEmpty {
            items.append(category)
        }
        if let latest = book.lastChapter, !latest.isEmpty {
            items.append(latest)
        }
        return items
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8.0) {
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(book.name)
                        .lineLimit(1)
                    if !metaItems.isEmpty {
                        Text(metaItems.joined(separator: " · "))
                            .appThemeText(.caption, opacity: 0.6)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 结果行（TestResultRow.detailText 签名确证）。
struct TestResultRow: View {
    let item: TestResultItem

    /// detailText getter（pgo_only）。
    private var detailText: String? {
        if let details = item.details, !details.isEmpty {
            if let duration = item.duration {
                return "\(details)（\(String(format: "%.2fs", duration))）"
            }
            return details
        }
        if let duration = item.duration {
            return String(format: "%.2fs", duration)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 8.0) {
            Image(systemName: item.status.icon)
                .foregroundColor(item.status.color)
            VStack(alignment: .leading, spacing: 1.0) {
                Text(item.name)
                if let detail = detailText {
                    Text(detail)
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(item.status.shortTitle)
                .appThemeText(.caption)
                .foregroundColor(item.status.color)
        }
    }
}

/// 日志行（DebugLogRow 确证）。
struct DebugLogRow: View {
    let item: DebugLogItem

    var body: some View {
        HStack(alignment: .top, spacing: 6.0) {
            Image(systemName: item.level.symbolName)
                .font(.caption)
                .foregroundColor(item.level.color)
            Text(item.message)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }
}

// MARK: - 源码查看

/// 页面源码查看器（ContentTab/availableTabs/activeContent/displayContent/
/// formatSize/isTruncated 签名确证）。
struct SourceCodeViewerSheet: View {
    let sources: [SourceViewType: String]

    @State private var activeTab: SourceViewType = .search
    @Environment(\.dismiss) private var dismiss

    /// availableTabs getter（pgo_only）。
    private var availableTabs: [SourceViewType] {
        SourceViewType.allCases.filter { sources[$0]?.isEmpty == false }
    }

    /// activeContent getter（pgo_only）。
    private var activeContent: String {
        sources[activeTab] ?? ""
    }

    /// displayContent getter（pgo_only；截断域确证）。
    private var displayContent: String {
        String(activeContent.prefix(20000))
    }

    /// isTruncated getter（pgo_only）。
    private var isTruncated: Bool {
        activeContent.count > 20000
    }

    /// formatSize（pgo_only）。
    private func formatSize(_ bytes: Int) -> String {
        bytes >= 1024
            ? String(format: "%.1f KB", Double(bytes) / 1024)
            : "\(bytes) B"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if availableTabs.isEmpty {
                    Spacer()
                    Text("暂无日志")
                        .appThemeText(.caption, opacity: 0.6)
                    Spacer()
                } else {
                    Picker("页签", selection: $activeTab) {
                        ForEach(availableTabs) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.all, 8.0)
                    SourceCodeTextView(text: displayContent)
                        .padding(.horizontal, 8.0)
                    Text(
                        formatSize(displayContent.utf8.count)
                            + (isTruncated ? "（已截断）" : ""))
                        .appThemeText(.caption, opacity: 0.6)
                        .padding(.bottom, 8.0)
                }
            }
            .navigationTitle("页面源码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = activeContent
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
            .onAppear {
                if let first = availableTabs.first {
                    activeTab = first
                }
            }
        }
    }
}

/// 源码文本视图（SourceCodeTextView 签名确证）。
struct SourceCodeTextView: UIViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.text = text
    }

    final class Coordinator {}
}

// MARK: - JS 控制台

/// JS 控制台（JsConsoleSheet + formatTime 签名确证）。
struct JsConsoleSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss

    /// formatTime（pgo_only）。
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            JsConsoleTextView(text: logs.joined(separator: "\n"))
                .padding(.horizontal, 8.0)
            .navigationTitle("JS 控制台 (\(logs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string =
                            logs.joined(separator: "\n")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

/// 控制台文本视图（JsConsoleTextView 签名确证）。
struct JsConsoleTextView: UIViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.text = text
    }

    final class Coordinator {}
}

// MARK: - 系统日志

/// 系统日志条目（SystemLogItem.formattedLine 签名确证）。
struct SystemLogItem: Identifiable {
    let id = UUID()
    let line: String

    /// formattedLine getter（pgo_only）。
    var formattedLine: String { line }
}

/// 系统日志面板（filteredLogs/filterOptions/toggleFind/copyFilteredLogs
/// 签名确证）。
struct SystemLogSheet: View {
    let logs: [String]

    @State private var filter: String = "全部"
    @State private var searchText: String = ""
    @State private var showFind = false
    @Environment(\.dismiss) private var dismiss

    /// filteredLogs getter（pgo_only）。
    private var filteredLogs: [SystemLogItem] {
        logs
            .filter { line in
                (filter == "全部" || line.contains(filter))
                    && (searchText.isEmpty
                        || line.localizedCaseInsensitiveContains(searchText))
            }
            .map { SystemLogItem(line: $0) }
    }

    /// filterOptions getter（pgo_only；"全部 (N)" 域确证）。
    private var filterOptions: [String] {
        ["全部"] + ["info", "warning", "error", "配置调试"]
    }

    /// toggleFind（pgo_only）。
    private func toggleFind() {
        showFind.toggle()
    }

    /// copyFilteredLogs（pgo_only）。
    private func copyFilteredLogs() {
        UIPasteboard.general.string = filteredLogs
            .map(\.formattedLine)
            .joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showFind {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("查找", text: $searchText)
                            .autocorrectionDisabled()
                    }
                    .padding(.all, 8.0)
                }
                SystemLogFilterBar(
                    options: filterOptions, selection: $filter)
                SystemLogBody(items: filteredLogs)
            }
            .navigationTitle("系统日志 (\(logs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        toggleFind()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    Button {
                        copyFilteredLogs()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

/// 过滤条（SystemLogFilterBar 签名确证）。
struct SystemLogFilterBar: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(option)
                            .appThemeText(.caption)
                            .padding(.horizontal, 10.0)
                            .padding(.vertical, 4.0)
                            .background(
                                selection == option
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear)
                            .cornerRadius(10, antialiased: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12.0)
        }
    }
}

/// 日志主体（SystemLogBody 签名确证）。
struct SystemLogBody: View {
    let items: [SystemLogItem]

    var body: some View {
        if items.isEmpty {
            Spacer()
            Text("暂无日志")
                .appThemeText(.caption, opacity: 0.6)
            Spacer()
        } else {
            SystemLogTextView(text: items.map(\.formattedLine).joined(separator: "\n"))
        }
    }
}

/// 系统日志文本视图（SystemLogTextView 签名确证）。
struct SystemLogTextView: UIViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.text = text
    }

    final class Coordinator {}
}

// MARK: - 诊断时间线

/// 诊断面板（totalDuration/formatDuration/stepIcon/resultText/resultColor/
/// slowThreshold 签名确证；"诊断时间线"/"总步骤"/"最慢步骤"/"时间线" 域）。
struct DiagnosticsSheet: View {
    let steps: [ParseStepResult]
    @Environment(\.dismiss) private var dismiss

    /// slowThreshold getter（pgo_only；慢步阈值域）。
    private var slowThreshold: Double { 1.0 }

    /// totalDuration getter（pgo_only）。
    private var totalDuration: Double {
        steps.reduce(0) { $0 + $1.duration }
    }

    /// formatDuration（pgo_only）。
    private func formatDuration(_ seconds: Double) -> String {
        String(format: "%.3fs", seconds)
    }

    /// stepIcon（pgo_only）。
    private func stepIcon(_ step: ParseDiagnostic) -> String {
        switch step.result {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    /// resultText（pgo_only）。
    private func resultText(_ step: ParseStepResult) -> String {
        step.message
    }

    /// resultColor（pgo_only）。
    private func resultColor(_ step: ParseStepResult) -> Color {
        switch step.result {
        case .success: return .green
        case .failure: return .red
        case .skipped: return .secondary
        }
    }

    var body: some View {
        // 伪代码 0x100c3aebc（L2140-2208）：概览 + 时间线列表。
        NavigationStack {
            List {
                Section("诊断时间线 (\(steps.count))") {
                    HStack {
                        StatBlockLite(title: "总步骤", value: "\(steps.count)")
                        StatBlockLite(
                            title: "最慢步骤",
                            value: formatDuration(
                                steps.map(\.duration).max() ?? 0))
                        StatBlockLite(
                            title: "总时长",
                            value: formatDuration(totalDuration))
                    }
                }
                Section("时间线") {
                    ForEach(steps) { step in
                        HStack(spacing: 8.0) {
                            Image(systemName: stepIcon(step))
                                .foregroundColor(resultColor(step.result))
                            VStack(alignment: .leading, spacing: 1.0) {
                                Text(step.name)
                                Text(resultText(step.result))
                                    .appThemeText(.caption, opacity: 0.6)
                            }
                            Spacer()
                            Text(formatDuration(step.duration))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("诊断时间线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

/// 步骤诊断结果（DiagnosticsSheet.resultText/resultColor 签名确证；
/// ParseStepResult 本体 pgo_only）。
struct ParseStepResult {
    enum Outcome {
        case success
        case failure
        case skipped
    }

    let name: String
    let message: String
    let result: Outcome
    let duration: Double
}

/// 应用自带毛玻璃圆角修饰（签名族 glassEffectRoundedBackground 确证；
/// 基础实现，视觉细节待真机对照）。
extension View {
    @ViewBuilder
    func glassEffectRoundedBackground(
        cornerRadius: CGFloat, followsAppearance: Bool = true
    ) -> some View {
        self
            .padding(.horizontal, 12.0)
            .padding(.vertical, 8.0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground)))
    }
}

/// 迷你统计块（诊断概览域确证）。
struct StatBlockLite: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2.0) {
            Text(value)
                .font(.system(.body, design: .monospaced))
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 发现分类选择

/// 发现分类选择（filteredCategories 签名确证）。
struct ExploreCategoryPickerSheet: View {
    let categories: [(title: String, url: String)]
    let onSelect: ((title: String, url: String)) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    /// filteredCategories getter（pgo_only）。
    private var filteredCategories: [(title: String, url: String)] {
        guard !searchText.isEmpty else { return categories }
        return categories.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories, id: \.url) { category in
                    Button {
                        onSelect(category)
                        dismiss()
                    } label: {
                        HStack {
                            Text(category.title)
                            Spacer()
                            Text(category.url)
                                .appThemeText(.caption, opacity: 0.5)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("发现分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
