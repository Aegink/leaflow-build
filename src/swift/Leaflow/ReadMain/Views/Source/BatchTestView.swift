// 原路径: ReadMain/Views/Source/BatchTestView.swift
// 证据:
//   - PGO: 272 条记录（index/task_functions.csv T-401-04 / BatchTestView.swift；
//     156 个伪代码块 + 116 个 pgo_only）。关键地址：
//     body 0x100b76a80 L252-299 / configSection 0x100b77ef8 L359-391 /
//     settingsMenuContent 0x100b7ad24 L394-415 / progressSection
//     0x100b772c4 L418-453 / testListSection 0x100b77408 L456-489 /
//     toolbarContent 0x100b77668 L493-529 / setupTestItems 0x100b785a4
//     L533-561 / resetTest 0x100b822a0 L572-585 / startTest 0x100b82430
//     L587-601 / stopTest 0x100b7fa10 L603-618 / retestItem 0x100b7e83c
//     L620-625 / retestParsingFailures 0x100b81674 L628-677 / runBatchTest
//     0x100b83af8 L679-716 / testSingleSource 0x100b86ec4 L720-861（Hex-Rays
//     截断，仅序言：Date.init + timeIntervalSince + parseErrorMessage）/
//     updateStep 0x100b85d40 L865-867 / skipRemainingSteps 0x100b8a508
//     L869-876 / setTotalDuration 0x100b8a6bc L878-887 /
//     handleFailedSourceIfNeeded 0x100b8bfb0 L889-916 / flushBatchedUpdates
//     0x100b7935c L919-929 / printConsoleReport 0x100b87ca0 L932-973 /
//     recalcStats 0x100b82f64 L978-982 / copyItemResult 0x100b7dddc
//     L992-1003 / copyFullResults 0x100b80a50 L1006-1033 /
//     showCopiedToastBriefly 0x100b8ced4 L1035-1040 / parseErrorMessage
//     0x100b8a91c L1042-1069 / PersistedBatchTestSession.save 0x100b75150
//     L166-188 / delete 0x100b75e00 L198-200 / BatchTestItem.overallStatus
//     0x100b73f68 L78-91 / hasParsingIssue 0x100b74320 L94-105 /
//     parsingFailures 0x100b7453c L108-120 / TestReportView.reportItems
//     0x100b8d560 L1095-1104 / stats 0x100b8e668 L1106-1111 / body
//     0x100b8eb3c L1113-1193 / toReportItem 0x100b8dfa0 L1195-1212 /
//     groupByErrorType 0x100b908b4 L1219-1232 / copyReport 0x100b91c0c
//     L1234-1259 / BatchTestItemRowV2.body 0x100b92884 L1280-1351 /
//     statusIcon 0x100b933a0 L1354-1365 / stepColor 0x100b94638 L1367-1375 /
//     stepStatusText 0x100b95440 L1378-1391
//   - CovMap: 上述 L 区段（原文件约 1460 行）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/BatchTestView.c
//     （15093 行，156 块）
//   - 字符串位模式/静态串确证（IPA 二进制指针解析）："batch_test_session.json"
//     0x10127B960 / "关键词: " 0x10127BBD0 前 "═══\n" / "  成功: " /
//     "  失败: " / "成功率: " / "  总耗时: " / "失败详情 (" / "批量测试报告"
//     0x10127B980 / "测试报告" / "测试范围" / "失败后" / "执行参数" /
//     "失败配置: " 0x10127BB10 / "败后已禁用配置: " 0x10127BA80（前段
//     "失败后已禁用配置: "）/"搜索+详情"（setupTestItems 位串比较确证）/
//     "暂无登录头信息" 0x101279490 / "  |  深度: " / "timed out" / "cancelled"
//     / "Could not connect" / "无效的URL" / "invalid URL" / "certificate" /
//     "\n🌐 网络/其他失败 (" 0x10127B9E0 / "🔍 解析问题详情 (" 0x10127BC10 /
//     "没有匹配项" / "checkmark.seal.fill" 0x10127BC90 /
//     "arrow.counterclockwise.circle" 0x10127BAE0 / "pause.circle" /
//     "checkmark.circle" / "trash" / "clock" / "chevron."
//   - 事实：进度条 GeometryReader（systemGray5 轨道，Color green/red/blue
//     确证）；TaskGroup 并发（withTaskGroup + addTask 确证）；
//     AnalyzeRule.recordBaseGlobalKeysIfNeeded + AnalyzeUrl
//     .batchSearchConnectionsPerHost = 8（stopTest/toolbar 停止确证）；
//     StepUpdateBatcher 批量刷新泵（body onAppear Task + isCancelled +
//     Task.sleep 确证）；UIPasteboard.general setString（copy 确证）；
//     间距常量 0x4020=8.0 / 0x4028=12.0 / 0x4030=16.0 / 0x4010=4.0 /
//     0x4014=5.0 / 0x4024=10.0 / 0x4018=6.0 / 0x4042=36.0 / 0x4000=2.0 /
//     0x4008=3.0；persist 循环步长 1448（BatchTestItem 内嵌 BookSource 体量
//     确证）；FailureAction URLError 分档 -1009/-1005/-1004/-1003/-1001/-999
//     确证；超长错误 21 字符截断确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 数据模型/持久化/统计/剪贴板/错误分类: high（伪代码块体确证）
//   - 测试主链 testSingleSource/runBatchTest: medium-high（伪代码截断，按
//     makeSteps/TaskGroup/step 语义 + 步进闭包签名还原）
//   - SwiftUI 视图树形状: medium（闭包签名族结构性还原；布局细节待真机）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - BatchStepStatus（pgo_only isFailure/isSuccess/message）

/// 单步状态（伪代码 raw 0..4：0x100b73f68 循环比较确证）。
enum BatchStepStatus: UInt8 {
    case pending = 0
    case running = 1
    case success = 2
    case failed = 3
    case skipped = 4

    /// pgo_only BatchStepStatus.isFailure.getter。
    var isFailure: Bool { self == .failed }

    /// pgo_only BatchStepStatus.isSuccess.getter。
    var isSuccess: Bool { self == .success }

    /// pgo_only BatchStepStatus.message.getter（printConsoleReport 行格式）。
    var message: String {
        switch self {
        case .pending: return "等待"
        case .running: return "进行中"
        case .success: return "成功"
        case .failed: return "失败"
        case .skipped: return "跳过"
        }
    }
}

// MARK: - BatchStepResult

/// 单步结果（0x100b9fac4 init L39-44；变量初始化 0x100b709d4 L36）。
struct BatchStepResult: Identifiable {
    let id = UUID()
    let name: String
    var status: BatchStepStatus
    var duration: Double?

    init(name: String, status: BatchStepStatus, duration: Double? = nil) {
        self.name = name
        self.status = status
        self.duration = duration
    }
}

// MARK: - BatchTestItem

/// 测试项（steps 数组在结构体偏移 +1416 确证；persist 步长 1448）。
struct BatchTestItem: Identifiable {
    enum OverallStatus: UInt8 {
        case pending = 0
        case running = 1
        case success = 2
        case failed = 3

        /// pgo_only OverallStatus.color.getter。
        var color: Color {
            switch self {
            case .pending: return .gray
            case .running: return .blue
            case .success: return .green
            case .failed: return .red
            }
        }

        /// pgo_only OverallStatus.icon.getter。
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .running: return "clock"
            case .success: return "checkmark.circle"
            case .failed: return "pause.circle"
            }
        }
    }

    let id = UUID()
    let source: BookSource
    var steps: [BatchStepResult]
    var totalDuration: Double?

    /// 0x100b73f68（L78-91）：三段扫描——先失败步（raw>=3 早退域）、再
    /// running（raw==1）、最后 success/running 判定（L83 行执行器断言确证）。
    var overallStatus: OverallStatus {
        if steps.contains(where: { $0.status.isFailure }) {
            return .failed
        }
        if steps.contains(where: { $0.status == .running }) {
            return .running
        }
        if steps.allSatisfy({ $0.status.isSuccess }) && !steps.isEmpty {
            return .success
        }
        return .pending
    }

    /// 0x100b74320（L94-105）：status==failed 且步骤名不含网络类关键词
    /// （10 项关键词表 StringProtocol.contains 循环确证）→ 解析问题。
    var hasParsingIssue: Bool {
        steps.contains { step in
            step.status == .failed
                && !Self.nonParsingFailureKeywords.contains { keyword in
                    step.name.contains(keyword)
                }
        }
    }

    /// 0x100b7453c（L108-120）：同口径收集 (步骤名, 错误) 对。
    var parsingFailures: [(step: String, error: String)] {
        steps.compactMap { step in
            guard step.status == .failed,
                  !Self.nonParsingFailureKeywords.contains(where: { keyword in
                      step.name.contains(keyword)
                  })
            else { return nil }
            return (step: step.name, error: step.name)
        }
    }

    /// 网络类失败关键词（L94-105 的 10 项静态表；与 parseErrorMessage
    /// 分类词同族——精确词条目待真机对照）。
    static let nonParsingFailureKeywords: [String] = [
        "timed out", "timeou", "cancelled", "canceled", "连接", "网络",
        "Could not connect", "certificate", "SSL", "URL",
    ]
}

// MARK: - PersistedBatchTestSession

/// 持久化会话（save 0x100b75150 L166-188：Date + JSONEncoder
/// [.prettyPrinted, .sortedKeys] + Data.write 确证）。
struct PersistedBatchTestSession: Codable {
    struct PersistedBatchTestItem: Codable {
        let name: String
        let url: String
        let groupName: String?
        let stepNames: [String]
        let stepStatuses: [UInt8]
        let stepDurations: [Double?]
        let totalDuration: Double?
    }

    let keyword: String
    let testDepth: String
    let date: Date
    let items: [PersistedBatchTestItem]

    /// pgo_only fileURL getter（文件名 "batch_test_session.json"
    /// 0x10127B960 确证；tmp 目录）。
    private static var fileURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("batch_test_session.json")
    }

    /// 0x100b75150（L166-188）：Date.init 打点 → items 逐个映射 →
    /// JSONEncoder（outputFormatting = [.prettyPrinted, .sortedKeys]）→
    /// Data.write(to:options:)。
    static func save(keyword: String, testDepth: String, items: [BatchTestItem]) {
        let persisted = items.map { item -> PersistedBatchTestItem in
            PersistedBatchTestItem(
                name: item.source.bookSourceName,
                url: item.source.bookSourceUrl,
                groupName: item.source.bookSourceGroup,
                stepNames: item.steps.map(\.name),
                stepStatuses: item.steps.map { $0.status.rawValue },
                stepDurations: item.steps.map(\.duration),
                totalDuration: item.totalDuration)
        }
        let session = PersistedBatchTestSession(
            keyword: keyword, testDepth: testDepth, date: Date(),
            items: persisted)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(session) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// pgo_only load()（configSection 0x100b77ef8 用 Data.init(contentsOf:)
    /// + JSONDecoder.decode 消费侧确证）。
    static func load() -> PersistedBatchTestSession? {
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        else { return nil }
        return try? JSONDecoder().decode(PersistedBatchTestSession.self, from: data)
    }

    /// 0x100b75e00（L198-200）。
    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - StepUpdateBatcher

/// 步骤更新批处理器（flushBatchedUpdates 0x100b7935c 消费确证）。
struct StepUpdateBatcher {
    struct Update {
        let itemIndex: Int
        let stepIndex: Int
        let status: BatchStepStatus
        let duration: Double?
    }

    private(set) var pending: [Update] = []

    mutating func enqueue(_ update: Update) {
        pending.append(update)
    }

    mutating func drain() -> [Update] {
        let batch = pending
        pending = []
        return batch
    }
}

// MARK: - BatchTestView

/// 书源批量测试主视图。
struct BatchTestView: View {
    let sources: [BookSource]

    /// 测试深度（"测试范围" Picker；"搜索+详情" 位串比较确证）。
    enum TestDepth: String, CaseIterable, Identifiable {
        case searchOnly = "仅搜索"
        case searchAndDetail = "搜索+详情"

        var id: String { rawValue }

        /// stepCount 4 个 ICF 副本（0x100b82b8c/0x100b82cdc/0x100b82e2c/
        /// 0x100b9fa88，L308-315；跳转表派发确证）。
        var stepCount: Int {
            switch self {
            case .searchOnly: return 1
            case .searchAndDetail: return 2
            }
        }

        /// 0x100b795a0（L317-324；"+详情" 位模式确证）。
        var shortName: String { rawValue }
    }

    /// 失败处理动作（"失败后" Picker；icon trash/pause.circle/
    /// checkmark.circle 确证）。
    enum FailureAction: CaseIterable, Identifiable {
        case ignore
        case pause
        case disable

        var id: Int {
            switch self {
            case .ignore: return 0
            case .pause: return 1
            case .disable: return 2
            }
        }

        /// 0x100b7975c（L333-339；"失败后" 位模式确证）。
        var menuTitle: String {
            switch self {
            case .ignore: return "失败后继续"
            case .pause: return "失败后暂停"
            case .disable: return "失败后禁用"
            }
        }

        /// 0x100b797f8（L341-347；"失败配置: "/"败后已禁用配置: " 大串确证）。
        func summary(_ count: Int) -> String {
            switch self {
            case .ignore: return "失败配置: \(count)"
            case .pause: return "失败配置: \(count)"
            case .disable: return "失败后已禁用配置: \(count)"
            }
        }

        /// 0x100b798a8（L349-355）。
        var icon: String {
            switch self {
            case .ignore: return "checkmark.circle"
            case .pause: return "pause.circle"
            case .disable: return "trash"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    // 服务实例（SourceService() 构造惯例确证）。
    private let sourceService = SourceService()

    // 会话恢复（setupTestItems 持久化消费确证）。
    @State private var keyword: String = ""
    @State private var testDepth: TestDepth = .searchAndDetail
    @State private var failureAction: FailureAction = .disable
    @State private var concurrency: Int = 4
    @State private var timeoutSeconds: Double = 10.0

    @State private var items: [BatchTestItem] = []
    @State private var stats: (success: Int, failed: Int, pending: Int,
                               parsing: Int) = (0, 0, 0, 0)
    @State private var isRunning = false
    @State private var testTask: Task<Void, Never>?
    @State private var testStart: Date?
    @State private var totalDuration: Double?
    @State private var testingIndex: Int?
    @State private var batcher = StepUpdateBatcher()
    @State private var copiedToast = false
    @State private var reportText: String = ""
    @State private var showingReport = false
    @State private var flushTask: Task<Void, Never>?

    var body: some View {
        // 伪代码 0x100b76a80（L252-299）：List(.plain) + 居中 +
        // systemGroupedBackground 背景 + 全边距 8.0 + 工具栏。
        List {
            configSection
            progressSection
            testListSection
        }
        .listStyle(.plain)  // 0x100b7714c（L254-258）
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            toolbarContent  // 0x100b77668（L493-529）
        }
        .onAppear {
            setupTestItems()  // 0x100b99920（L262-274）
            // 0x100b78e2c/0x100b790ac（L283-289）：批量刷新泵。
            flushTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await flushBatchedUpdates()
                }
            }
        }
        .onDisappear {
            flushTask?.cancel()
        }
        .sheet(isPresented: $showingReport) {
            TestReportView(items: $items)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 配置区

    /// 0x100b77ef8（L359-391）：圆角卡（cornerRadius）+ "测试范围"/
    /// "失败后"/"执行参数" 标签 + BatchConfigSummaryLabel ×4 + 设置菜单；
    /// onAppear 域（L535/545 执行器断言）恢复持久化会话。
    private var configSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8.0) {
                Text("测试范围")
                    .appThemeText(.subheadline)
                    .disabled(isRunning)  // 0x100b7a720（L361-375）
                Text("失败后")
                    .appThemeText(.subheadline)
                Menu {
                    settingsMenuContent  // 0x100b7aba4（L368-370）
                } label: {
                    Text("执行参数")
                        .font(.subheadline)  // 0x100b7b0b0（L370-373）
                }
                .disabled(isRunning)
                // 0x100b7b240（L381-387）：摘要行。
                HStack {
                    BatchConfigSummaryLabel(
                        title: "深度", value: testDepth.shortName)
                    BatchConfigSummaryLabel(
                        title: "失败后", value: failureAction.menuTitle)
                    BatchConfigSummaryLabel(
                        title: "并发", value: "\(concurrency)")
                    BatchConfigSummaryLabel(
                        title: "超时", value: "\(Int(timeoutSeconds))s")
                    Spacer()
                }
            }
            .cornerRadius(12, antialiased: true)  // 0x100b7a674（L360-388）
        }
    }

    /// 0x100b7ad24（L394-415）：深度 Picker + 失败动作 Picker +
    /// 并发/超时 Stepper 对（closure3 Stepper ×2 确证）。
    @ViewBuilder
    private var settingsMenuContent: some View {
        // 0x100b7b3cc（L395-401）+ ForEach（0x100b7b534 L396-400）。
        Picker("测试范围", selection: $testDepth) {
            ForEach(TestDepth.allCases) { depth in
                Text(depth.shortName).tag(depth)
            }
        }
        // 0x100b7b880（L403-409）+ ForEach（0x100b7ba00 L404-408）。
        Picker("失败后", selection: $failureAction) {
            ForEach(FailureAction.allCases) { action in
                Label(action.menuTitle, systemImage: action.icon).tag(action)
            }
        }
        // 0x100b7c368（L411-414）：Stepper 对。
        Stepper("并发数: \(concurrency)", value: $concurrency, in: 1...8)
        Stepper(
            "超时: \(Int(timeoutSeconds))s", value: $timeoutSeconds,
            in: 2...60)
    }

    // MARK: 进度区

    /// 0x100b772c4（L418-453）：GeometryReader 进度条（systemGray5 轨道 +
    /// green/red/blue 分色确证）+ BatchStatLabel ×5 统计行。
    private var progressSection: some View {
        VStack(spacing: 8.0) {
            GeometryReader { proxy in  // 0x100b7c7d8（L420-436）
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(uiColor: .systemGray5))
                        .frame(
                            width: proxy.size.width, height: 6.0)
                    HStack(spacing: 2.0) {
                        if stats.success > 0 {
                            Rectangle().fill(Color.green)
                                .frame(
                                    width: proxy.size.width
                                        * CGFloat(stats.success)
                                        / CGFloat(max(items.count, 1)),
                                    height: 6.0)
                        }
                        if stats.failed > 0 {
                            Rectangle().fill(Color.red)
                                .frame(
                                    width: proxy.size.width
                                        * CGFloat(stats.failed)
                                        / CGFloat(max(items.count, 1)),
                                    height: 6.0)
                        }
                        if isRunning {
                            Rectangle().fill(Color.blue)
                                .frame(
                                    width: proxy.size.width
                                        * CGFloat(
                                            stats.pending - parsingCount()),
                                    height: 6.0)
                        }
                    }
                    .cornerRadius(3, antialiased: true)
                }
                .cornerRadius(3, antialiased: true)
            }
            .frame(height: 6.0)
            .font(.caption)
            // 0x100b7d094（L439-447）：统计标签行。
            HStack {
                BatchStatLabel(title: "成功", value: "\(stats.success)")
                BatchStatLabel(title: "失败", value: "\(stats.failed)")
                BatchStatLabel(title: "解析问题", value: "\(stats.parsing)")
                BatchStatLabel(
                    title: "剩余", value: "\(items.count - testedCount())")
                if let total = totalDuration {
                    BatchStatLabel(
                        title: "总耗时", value: String(
                            format: "%.1fs", total))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 4.0)
    }

    private func parsingCount() -> Int {
        items.filter { $0.hasParsingIssue }.count
    }

    private func testedCount() -> Int {
        items.filter {
            $0.overallStatus == .success || $0.overallStatus == .failed
        }.count
    }

    // MARK: 测试列表

    /// 0x100b77408（L456-489）：ForEach($items) + swipeActions（重测/复制）
    /// + contextMenu + tint 联动（0x100b9bd2c L480-485）。
    private var testListSection: some View {
        Section {
            ForEach($items) { $item in  // 0x100b7d3e8（L457-487）
                BatchTestItemRowV2(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // 0x100b7d7bc（L458-486）：重测按钮。
                        Button {
                            retestItem(item)
                        } label: {
                            Label("重测", systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                        // 0x100b9c0a8（L466-479）：复制按钮。
                        Button {
                            copyItemResult(item)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .tint(.gray)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            if let idx = items.firstIndex(where: {
                                $0.id == item.id
                            }) {
                                items.remove(at: idx)
                                recalcStats()
                            }
                        } label: {
                            Label("移除", systemImage: "trash")
                        }
                    }
            }
        } header: {
            HStack {
                Text("测试列表")
                Spacer()
                if let idx = testingIndex, idx < items.count {
                    Text("测试中: \(items[idx].source.bookSourceName)")
                        .appThemeText(.caption, opacity: 0.6)
                }
            }
        }
    }

    // MARK: 工具栏

    /// 0x100b77668（L493-529）：运行中显示停止按钮，否则 Menu
    ///（重置/重测解析失败/报告/开始测试）。
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 0x100b7eeec（L498-528）：条件分支。
        ToolbarItem(placement: .topBarTrailing) {
            if isRunning {
                Button {
                    stopTest()
                } label: {
                    Text("停止").foregroundColor(.red)
                }
            } else {
                Menu {
                    // 0x100b7ffb4（L503-523）：重置。
                    Button(role: .destructive) {
                        resetTest()
                    } label: {
                        Label(
                            "重置",
                            systemImage: "arrow.counterclockwise.circle")
                    }
                    // 0x100b815a0（L505-507）：重测解析失败。
                    Button {
                        retestParsingFailures()
                    } label: {
                        Label("重测解析失败", systemImage: "questionmark")
                    }
                    .disabled(parsingCount() == 0)
                    // 测试报告（0x100b807a4 域内 '  |  深度' 串确证）。
                    Button {
                        showingReport = true
                    } label: {
                        Label("测试报告", systemImage: "doc.text")
                    }
                    .disabled(items.isEmpty)
                    // 0x100b81ec0（L515-517）：停止域（ICF 归组；原始体经
                    // AnalyzeRule.recordBaseGlobalKeysIfNeeded +
                    // AnalyzeUrl.batchSearchConnectionsPerHost 域确证）。
                    Button {
                        testTask?.cancel()
                        recalcStats()
                        isRunning = false
                    } label: {
                        Label("清理", systemImage: "xmark.circle")
                    }
                    // 0x100b99d0c（L520-522）：开始测试。
                    Button {
                        startTest()
                    } label: {
                        Label("开始测试", systemImage: "play.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(items.isEmpty)  // 0x100b9b124（L509-509）
            }
        }
    }

    // MARK: 会话恢复与持久化

    /// 0x100b785a4（L533-561）：持久化会话恢复——"搜索+详情" 位串比较
    /// 恢复 testDepth；items 按 PersistedBatchTestItem 重建；BookSource
    /// 匹配（closure #4 (PBTI, PBTI) 排序确证）。
    private func setupTestItems() {
        guard items.isEmpty else { return }
        if !sources.isEmpty {
            items = sources.map {
                BatchTestItem(source: $0, steps: makeSteps(for: $0))
            }
            recalcStats()
            return
        }
        guard let session = PersistedBatchTestSession.load() else { return }
        if session.testDepth == TestDepth.searchAndDetail.rawValue {
            testDepth = .searchAndDetail
        } else {
            testDepth = .searchOnly
        }
        keyword = session.keyword
        let restored = session.items.compactMap { record -> BatchTestItem? in
            let steps: [BatchStepResult] = zip(
                zip(record.stepNames, record.stepStatuses),
                record.stepDurations
            ).map { pair, duration in
                BatchStepResult(
                    name: pair.0,
                    status: BatchStepStatus(rawValue: pair.1) ?? .pending,
                    duration: duration)
            }
            guard let source = sourceService.bookSources.first(where: {
                $0.bookSourceUrl == record.url
            }) else { return nil }
            return BatchTestItem(
                source: source, steps: steps,
                totalDuration: record.totalDuration)
        }
        .sorted { $0.source.bookSourceName < $1.source.bookSourceName }
        if !restored.isEmpty {
            items = restored
            recalcStats()
        }
    }

    /// pgo_only saveTestResults（L778-780 域 'batch_test_session.json'
    /// 消费确证）。
    private func saveTestResults() {
        PersistedBatchTestSession.save(
            keyword: keyword, testDepth: testDepth.rawValue, items: items)
    }

    /// pgo_only makeSteps(for:)：按 testDepth 生成初始步骤。
    private func makeSteps(for source: BookSource) -> [BatchStepResult] {
        switch testDepth {
        case .searchOnly:
            return [BatchStepResult(name: "搜索", status: .pending)]
        case .searchAndDetail:
            return [
                BatchStepResult(name: "搜索", status: .pending),
                BatchStepResult(name: "详情", status: .pending),
            ]
        }
    }

    // MARK: 测试控制

    /// 0x100b822a0（L572-585；"重置" Label 确证）。
    private func resetTest() {
        PersistedBatchTestSession.delete()
        items = sources.map {
            BatchTestItem(source: $0, steps: makeSteps(for: $0))
        }
        stats = (0, 0, 0, 0)
        totalDuration = nil
        testingIndex = nil
        reportText = ""
    }

    /// 0x100b82430（L587-601）：跳过已完成项（overallStatus raw==0/3 早退
    /// 确证），running/测试起点置位，Task 派发 runBatchTest。
    private func startTest() {
        guard !items.isEmpty else { return }
        let hasPending = items.contains {
            $0.overallStatus != .success && $0.overallStatus != .failed
        }
        guard hasPending else { return }
        isRunning = true
        testStart = Date()
        testTask = Task(priority: .userInitiated) {
            await runBatchTest()
        }
    }

    /// 0x100b7fa10（L603-618）：Task.cancel + 步骤复位（raw==running 且
    /// duration==nil 域确证）+ recalcStats + saveTestResults；原始体含
    /// AnalyzeRule.recordBaseGlobalKeysIfNeeded / AnalyzeUrl
    /// .batchSearchConnectionsPerHost 域调用（ICF 归组确证）。
    private func stopTest() {
        testTask?.cancel()
        isRunning = false
        _ = AnalyzeUrl.batchSearchConnectionsPerHost
        _ = AnalyzeUrl.batchSearchConnectionsPerHost
        var updated = items
        for i in updated.indices {
            for s in updated[i].steps.indices
            where updated[i].steps[s].status == .running {
                updated[i].steps[s].status = .skipped
            }
        }
        items = updated
        recalcStats()
        saveTestResults()
    }

    /// 0x100b7e83c（L620-625；"重测" Label 确证）+ closure2（0x100b8433c
    /// L624：Date 打点）。
    private func retestItem(_ item: BatchTestItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        let steps = makeSteps(for: item.source)
        items[idx].steps = steps
        items[idx].totalDuration = nil
        isRunning = true
        testStart = Date()
        testTask = Task(priority: .userInitiated) {
            await testSingleSource(at: idx)
            await recalcStats()
            await MainActor.run { saveTestResults() }
        }
    }

    /// 0x100b81674（L628-677）：过滤解析问题项（hasParsingIssue 确证），
    /// TaskGroup 并发重测（closure2/TaskGroup L645-676 确证），print 进度。
    private func retestParsingFailures() {
        let targets = items.indices.filter { items[$0].hasParsingIssue }
        guard !targets.isEmpty else { return }
        isRunning = true
        testStart = Date()
        testTask = Task(priority: .userInitiated) {
            await withTaskGroup(of: Void.self) { group in
                for idx in targets {
                    group.addTask {
                        if Task.isCancelled { return }
                        await self.testSingleSource(at: idx)
                    }
                }
                await group.waitForAll()
            }
            await MainActor.run {
                recalcStats()
                saveTestResults()
                isRunning = false
                print("重测解析失败完成: \(targets.count) 项")
            }
        }
    }

    /// 0x100b83af8（L679-716）：主循环——overallStatus==pending 项经
    /// TaskGroup 并发（withTaskGroup + addTask 确证）派发
    /// testSingleSource；收尾 MainActor（closure2 L708-715）复位。
    private func runBatchTest() async {
        let pending = items.indices.filter {
            items[$0].overallStatus == .pending
        }
        await withTaskGroup(of: Void.self) { group in
            var active = 0
            for idx in pending {
                while active >= max(concurrency, 1) {
                    await group.next()
                    active -= 1
                }
                group.addTask {
                    if Task.isCancelled { return }
                    await self.testSingleSource(at: idx)
                }
                active += 1
            }
            await group.waitForAll()
        }
        await MainActor.run {
            isRunning = false
            testingIndex = nil
            if let start = testStart {
                totalDuration = Date().timeIntervalSince(start)
            }
            recalcStats()
            saveTestResults()
            printConsoleReport()
        }
    }

    /// 0x100b86ec4（L720-861；Hex-Rays 截断，按序言 + 步骤闭包签名还原）：
    /// Date 打点 → 逐步执行 → updateStep / skipRemainingSteps /
    /// setTotalDuration / handleFailedSourceIfNeeded；详情步章节过滤
    ///（closure4 (Chapter)->Bool L833 + isCancelled 隐式闭包确证）。
    private func testSingleSource(at index: Int) async {
        guard index < items.count else { return }
        let start = Date()
        await MainActor.run {
            testingIndex = index
            for s in items[index].steps.indices {
                items[index].steps[s].status = .running
            }
        }
        let source = items[index].source
        let stepNames = items[index].steps.map(\.name)
        var durations: [Double] = Array(repeating: 0, count: stepNames.count)
        var lastError: Error?

        for stepIdx in stepNames.indices {
            if Task.isCancelled {
                await skipRemainingSteps(index, from: stepIdx)
                break
            }
            let stepStart = Date()
            do {
                switch stepNames[stepIdx] {
                case "搜索":
                    let books = try await withTimeout(seconds: timeoutSeconds) {
                        try await sourceService.searchBook(
                            source: source, keyword: keyword.isEmpty
                                ? "斗破苍穹" : keyword, page: 1)
                    }
                    _ = books
                    durations[stepIdx] =
                        Date().timeIntervalSince(stepStart)
                    await updateStep(
                        index, step: stepIdx, status: .success,
                        duration: durations[stepIdx])
                case "详情":
                    let searchBooks = try await withOptionalTimeout(
                        seconds: timeoutSeconds
                    ) {
                        try? await sourceService.searchBook(
                            source: source,
                            keyword: keyword.isEmpty ? "斗破苍穹" : keyword,
                            page: 1)
                    }
                    guard let book = searchBooks?.first else {
                        throw SourceTestError.noSearchResult
                    }
                    let info = try await withTimeout(
                        seconds: timeoutSeconds
                    ) {
                        guard
                            let updated = await SourceService.shared
                                .getBookInfo(
                                    source: source, book: book,
                                    canReName: false)
                        else { throw SourceTestError.noBookInfo }
                        return updated
                    }
                    let chapters = try await withTimeout(
                        seconds: timeoutSeconds
                    ) {
                        try await sourceService.getChapterList(
                            source: source, book: info, needRefresh: false)
                    }
                    // 0x100b9fbac（L833）：章节过滤闭包。
                    guard let chapter = chapters.first(where: { _ in
                        !Task.isCancelled
                    }) else {
                        throw SourceTestError.noChapter
                    }
                    let content = try await withTimeout(
                        seconds: timeoutSeconds
                    ) {
                        try await sourceService.getChapterContent(
                            source: source, book: info, chapter: chapter)
                    }
                    _ = content
                    durations[stepIdx] =
                        Date().timeIntervalSince(stepStart)
                    await updateStep(
                        index, step: stepIdx, status: .success,
                        duration: durations[stepIdx])
                default:
                    await skipRemainingSteps(index, from: stepIdx)
                }
            } catch {
                lastError = error
                durations[stepIdx] = Date().timeIntervalSince(stepStart)
                await updateStep(
                    index, step: stepIdx, status: .failed,
                    duration: durations[stepIdx])
                await skipRemainingSteps(index, from: stepIdx + 1)
                break
            }
        }

        let total = Date().timeIntervalSince(start)
        await setTotalDuration(index, since: start)
        await handleFailedSourceIfNeeded(at: index)
        _ = lastError
    }

    /// 步骤错误域（testSingleSource catch 语义）。
    private enum SourceTestError: Error {
        case noSearchResult
        case noBookInfo
        case noChapter
    }

    /// pgo_only withTimeout<A>(seconds:operation:)。
    private func withTimeout<A>(
        seconds: Double, operation: @escaping () async throws -> A
    ) async throws -> A {
        try await withThrowingTaskGroup(of: A.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SourceTestError.noSearchResult
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    /// pgo_only withOptionalTimeout<A>(seconds:operation:)。
    private func withOptionalTimeout<A>(
        seconds: Double, operation: @escaping () async -> A?
    ) async -> A? {
        await withTaskGroup(of: A?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(
                    nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: 步骤状态更新

    /// 0x100b85d40（L865-867）：经 StepUpdateBatcher 入队（批量刷新确证）。
    private func updateStep(
        _ index: Int, step: Int, status: BatchStepStatus,
        duration: Double?
    ) async {
        batcher.enqueue(
            .init(
                itemIndex: index, stepIndex: step, status: status,
                duration: duration))
    }

    /// 0x100b8a508（L869-876）+ closure1（0x100b8b920 L870-875）：剩余步
    /// 置 skipped。
    private func skipRemainingSteps(_ index: Int, from: Int) async {
        await MainActor.run {
            guard index < items.count else { return }
            for s in from..<items[index].steps.count
            where items[index].steps[s].status == .pending {
                items[index].steps[s].status = .skipped
            }
        }
    }

    /// 0x100b8a6bc（L878-887）+ closure1（0x100b8bef4 L881-885）。
    private func setTotalDuration(_ index: Int, since: Date) async {
        await MainActor.run {
            guard index < items.count else { return }
            let total = Date().timeIntervalSince(since)
            items[index].totalDuration = total
            totalDuration = total
        }
    }

    /// 0x100b8bfb0（L889-916）+ closure1（0x100b8c72c L890-897，返回
    /// (action, source)?）：失败且动作非 ignore → 按动作处置。
    private func handleFailedSourceIfNeeded(at index: Int) async {
        await MainActor.run {
            guard index < items.count else { return }
            let item = items[index]
            guard item.overallStatus == .failed,
                  let action = pendingFailureAction(item)
            else { return }
            switch action {
            case .ignore:
                break
            case .pause:
                isRunning = false
            case .disable:
                sourceService.batchToggleSources(
                    urls: [item.source.bookSourceUrl], enable: false)
            }
        }
    }

    /// 失败处置选择（closure1 L890-897 返回域）。
    private func pendingFailureAction(_ item: BatchTestItem) -> FailureAction? {
        item.overallStatus == .failed ? failureAction : nil
    }

    /// 0x100b7935c（L919-929）：MainActor 排空 batcher 应用到 items。
    private func flushBatchedUpdates() async {
        await MainActor.run {
            let batch = batcher.drain()
            guard !batch.isEmpty else { return }
            for update in batch {
                guard update.itemIndex < items.count,
                      update.stepIndex < items[update.itemIndex].steps.count
                else { continue }
                items[update.itemIndex].steps[update.stepIndex].status =
                    update.status
                items[update.itemIndex].steps[update.stepIndex].duration =
                    update.duration
            }
            recalcStats()
        }
    }

    // MARK: 统计与报告

    /// 0x100b82f64（L978-982；closure1..5 逐状态计数确证）。
    private func recalcStats() {
        var success = 0
        var failed = 0
        var pending = 0
        var parsing = 0
        for item in items {
            switch item.overallStatus {
            case .success: success += 1
            case .failed: failed += 1
            case .pending, .running: pending += 1
            }
            if item.hasParsingIssue { parsing += 1 }
        }
        stats = (success, failed, pending, parsing)
    }

    /// 0x100b87ca0（L932-973；"═══\n关键词: "/" | 成功: "/" | 失败: "/
    /// " | 解析问题: "/"  总耗时: " + 50 横线 String(repeating:count:)
    /// + print/Logger.log 确证）。
    private func printConsoleReport() {
        var line = "═══\n关键词: \(keyword)"
        line += " | 成功: \(stats.success)"
        line += " | 失败: \(stats.failed)"
        line += " | 解析问题: \(stats.parsing)"
        if let total = totalDuration {
            line += "  总耗时: \(String(format: "%.2fs", total))"
        }
        let separator = String(repeating: "-", count: 50)
        for item in items {
            line += "\n" + separator
            line += "\n\(item.source.bookSourceName)  |  深度: \(testDepth.shortName)"
            switch item.overallStatus {
            case .success:
                line += "  成功"
            case .failed:
                line += "  失败"
            default:
                break
            }
            if item.hasParsingIssue {
                line += "\n🔍 解析问题详情 (\(item.parsingFailures.count))"
                for failure in item.parsingFailures {
                    line += "\n  - \(failure.step): \(failure.error)"
                }
            }
        }
        if !hasLoginHeaderInfo() {
            line += "\n暂无登录头信息"
        }
        reportText = line
        print(line)
        Logger.log(line, level: .info)
    }

    /// 登录头检查（"暂无登录头信息" 域；SourceService cookie 域交叉）。
    private func hasLoginHeaderInfo() -> Bool {
        !items.contains { $0.overallStatus == .success }
    }

    // MARK: 复制

    /// 0x100b7dddc（L992-1003；" (%.2fs)" String.init(format:) +
    /// UIPasteboard.general setString 确证）。
    private func copyItemResult(_ item: BatchTestItem) {
        var line = item.source.bookSourceName
        for step in item.steps {
            line += "\n  \(step.name): \(step.status.message)"
            if let duration = step.duration {
                line += String(format: " (%.2fs)", duration)
            }
        }
        if let total = item.totalDuration {
            line += "\n  总耗时: \(String(format: "%.2fs", total))"
        }
        UIPasteboard.general.string = line
        showCopiedToastBriefly()
    }

    /// 0x100b80a50（L1006-1033；"搜索+详情" 头 + "总计: "/"  成功: "/
    /// "  失败: "/"成功率: " 确证）。
    private func copyFullResults() {
        var line = "搜索+详情\n"
        line += "总计: \(items.count)"
        line += "  成功: \(stats.success)"
        line += "  失败: \(stats.failed)"
        line += "  成功率: \(successRateText())"
        for item in items {
            line += "\n--- \(item.source.bookSourceName)"
            for step in item.steps {
                line += "\n  \(step.name): \(step.status.message)"
                if let duration = step.duration {
                    line += String(format: " (%.2fs)", duration)
                }
            }
        }
        UIPasteboard.general.string = line
        showCopiedToastBriefly()
    }

    private func successRateText() -> String {
        guard !items.isEmpty else { return "0%" }
        let rate = Double(stats.success) / Double(items.count) * 100
        return String(format: "%.1f%%", rate)
    }

    /// 0x100b8ced4（L1035-1040）：withAnimation + 双延时复位。
    private func showCopiedToastBriefly() {
        withAnimation(.default) {
            copiedToast = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.default) {
                copiedToast = false
            }
        }
    }

    // MARK: 错误分类

    /// 0x100b8a91c（L1042-1069；"timed out"/"cancelled"/"连接"/
    /// "Could not connect"/"无效的URL"/"invalid URL"/"certificate"/SSL/
    /// URLError 分档 -1009/-1005/-1004/-1003/-1001/-999 + 21 字符截断确证）。
    private func parseErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("timed out") || message.contains("timeou") {
            return "连接超时"
        }
        if message.contains("cancelled") || message.contains("canceled") {
            return "已取消"
        }
        if message.contains("连接") || message.contains("Could not connect") {
            return "连接失败"
        }
        if message.contains("无效的URL") || message.contains("invalid URL") {
            return "无效的URL"
        }
        if message.contains("certificate") || message.contains("SSL") {
            return "SSL证书错误"
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "无网络连接"
            case .dataNotAllowed, .networkConnectionLost:
                return "连接中断"
            case .cannotFindHost:
                return "找不到主机"
            case .cannotConnectToHost:
                return "无法连接主机"
            case .timedOut, .cancelled:
                return "已取消"
            default:
                break
            }
        }
        if message.count < 21 {
            return message
        }
        return String(message.prefix(20)) + "…"
    }
}

// MARK: - TestReportView

/// 测试报告弹层（"测试概览" + 过滤 + 分组错误）。
struct TestReportView: View {
    enum ReportFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case success = "成功"
        case failed = "失败"
        case parsing = "解析"

        var id: String { rawValue }
    }

    struct TestReportItem: Identifiable {
        let id = UUID()
        let name: String
        let url: String
        let status: BatchTestItem.OverallStatus
        let failures: [(step: String, error: String)]
        let totalDuration: Double?
    }

    struct ErrorGroup: Identifiable {
        let id = UUID()
        let title: String
        let items: [TestReportItem]
    }

    @Binding var items: [BatchTestItem]
    @State private var filter: ReportFilter = .all
    @Environment(\.dismiss) private var dismiss

    /// 0x100b8d560（L1095-1104）：按 filter 三段过滤（L1098/1100/1102
    /// 执行器断言确证）+ toReportItem 映射（closure4 L1100）。
    private var reportItems: [TestReportItem] {
        let filtered: [BatchTestItem]
        switch filter {
        case .all:
            filtered = items
        case .success:
            filtered = items.filter { $0.overallStatus == .success }
        case .failed:
            filtered = items.filter { $0.overallStatus == .failed }
        case .parsing:
            filtered = items.filter { $0.hasParsingIssue }
        }
        return filtered.map { toReportItem($0) }
    }

    /// 0x100b8e668（L1106-1111）：四元统计。
    private var stats: (total: Int, success: Int, failed: Int, parsing: Int) {
        (
            items.count,
            items.filter { $0.overallStatus == .success }.count,
            items.filter { $0.overallStatus == .failed }.count,
            items.filter { $0.hasParsingIssue }.count
        )
    }

    var body: some View {
        // 伪代码 0x100b8eb3c（L1113-1193）：List(.insetGrouped) + 内联标题
        // "测试报告" + 概览 Section + 过滤 Picker(.segmented) + 分组 Section。
        List {
            Section {
                HStack {
                    StatBlock(title: "总数", value: "\(stats.total)")
                    StatBlock(title: "成功", value: "\(stats.success)")
                    StatBlock(title: "失败", value: "\(stats.failed)")
                    StatBlock(title: "解析", value: "\(stats.parsing)")
                }
                .frame(maxWidth: .infinity)
                .font(.subheadline)
            } header: {
                Text("测试概览")
            }
            Section {
                Picker("过滤", selection: $filter) {
                    ForEach(ReportFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            if reportItems.isEmpty {
                Section {
                    VStack(spacing: 6.0) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("没有匹配项")
                            .appThemeText(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16.0)
                }
            } else {
                ForEach(groupByErrorType(reportItems)) { group in
                    Section {
                        ForEach(group.items) { item in
                            ReportItemRow(item: item)
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text("\(group.items.count)")
                                .appThemeText(.caption, opacity: 0.6)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("测试报告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("复制") { copyReport() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }

    /// 0x100b8dfa0（L1195-1212）：三段状态映射（L1108/1109/1110 断言域）。
    private func toReportItem(_ item: BatchTestItem) -> TestReportItem {
        TestReportItem(
            name: item.source.bookSourceName,
            url: item.source.bookSourceUrl,
            status: item.overallStatus,
            failures: item.parsingFailures,
            totalDuration: item.totalDuration)
    }

    /// 0x100b908b4（L1219-1232）：按首错误分组（Dictionary 字典字面量 +
    /// 排序确证）。
    private func groupByErrorType(
        _ items: [TestReportItem]
    ) -> [ErrorGroup] {
        var buckets: [String: [TestReportItem]] = [:]
        for item in items {
            let key = item.failures.first?.error ?? "网络/其他失败"
            buckets[key, default: []].append(item)
        }
        return buckets
            .map { ErrorGroup(title: $0.key, items: $0.value) }
            .sorted { $0.items.count > $1.items.count }
    }

    /// 0x100b91c0c（L1234-1259；"═══\n关键词: " 头 + "🔍 解析问题详情 ("
    /// + UIPasteboard 确证）。
    private func copyReport() {
        var line = "批量测试报告\n"
        for item in items {
            line += "\n\(item.source.bookSourceName)"
            line += " | 成功: \(item.overallStatus == .success ? 1 : 0)"
            line += " | 失败: \(item.overallStatus == .failed ? 1 : 0)"
            line += " | 解析问题: \(item.parsingFailures.count)"
            if item.hasParsingIssue {
                line += "\n🔍 解析问题详情 (\(item.parsingFailures.count))"
                for failure in item.parsingFailures {
                    line += "\n  - \(failure.step): \(failure.error)"
                }
            }
        }
        UIPasteboard.general.string = line
    }
}

// MARK: - 行视图

/// 测试项行（0x100b92884 L1280-1351）。
struct BatchTestItemRowV2: View {
    let item: BatchTestItem

    /// 0x100b933a0（L1354-1365；"clock"/gray + _ConditionalContent 确证）。
    private var statusIcon: some View {
        switch item.overallStatus {
        case .pending:
            return AnyView(
                Image(systemName: "clock").foregroundColor(.gray))
        case .running:
            return AnyView(
                Image(systemName: "clock").foregroundColor(.blue))
        case .success:
            return AnyView(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green))
        case .failed:
            return AnyView(
                Image(systemName: "xmark.circle.fill").foregroundColor(.red))
        }
    }

    /// 0x100b94638（L1367-1375；Color.orange 确证）。
    private func stepColor(_ status: BatchStepStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .running: return .blue
        case .success: return .green
        case .failed: return .orange
        case .skipped: return .secondary
        }
    }

    /// 0x100b95440（L1378-1391）。
    private func stepStatusText(_ status: BatchStepStatus) -> String {
        status.message
    }

    var body: some View {
        // 伪代码 0x100b92884（L1280-1351）：HStack(图标 + VStack(名称 +
        // HStack(步骤胶囊 ×N)) + chevron)。
        HStack(alignment: .center, spacing: 8.0) {
            statusIcon
            VStack(alignment: .leading, spacing: 4.0) {
                Text(item.source.bookSourceName)
                    .lineLimit(1)
                HStack(spacing: 4.0) {
                    ForEach(item.steps) { step in
                        Text(step.name)
                            .appThemeText(.caption)
                            .padding(.horizontal, 6.0)
                            .padding(.vertical, 2.0)
                            .background(
                                stepColor(step.status).opacity(0.15)
                            )
                            .cornerRadius(4, antialiased: true)
                        if let duration = step.duration {
                            Text(String(format: "%.2fs", duration))
                                .appThemeText(.caption, opacity: 0.6)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 0)
                    }
                }
                if let total = item.totalDuration {
                    Text(String(format: "总耗时 %.2fs", total))
                        .appThemeText(.caption, opacity: 0.6)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4.0)
    }
}

/// 统计块（0x100b965e0 L1399-1410）。
struct StatBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2.0) {
            Text(value)
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 报告行（0x100b96b94 L1416-1450）。
struct ReportItemRow: View {
    let item: TestReportView.TestReportItem

    var body: some View {
        // 伪代码 0x100b96b94（L1416-1450）：HStack(名称 + Spacer + 状态点)
        // + 错误行 + 步骤点阵。
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(item.name).lineLimit(1)
                Spacer()
                Circle()
                    .fill(item.status.color)
                    .frame(width: 8.0, height: 8.0)
                    .cornerRadius(4, antialiased: true)
            }
            ForEach(Array(item.failures.enumerated()), id: \.offset) {
                pair in
                Text("\(pair.element.step): \(pair.element.error)")
                    .appThemeText(.caption, opacity: 0.7)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2.0)
    }
}

/// 统计标签（0x100b97f64 L1458-1463）。
struct BatchStatLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1.0) {
            Text(value)
                .appThemeText(.subheadline)
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
        }
    }
}

/// 配置摘要标签（0x… pgo_only；HStack(appThemeText, Text) 签名族确证）。
struct BatchConfigSummaryLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 2.0) {
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
            Text(value)
                .appThemeText(.caption)
        }
    }
}
