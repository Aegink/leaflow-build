// 原路径: ReadMain/Views/ReadingStatsView.swift
// 证据:
//   - PGO: 158 条记录（index/task_functions.csv T-501-05 /
//     ReadingStatsView.swift；伪代码域 12410 行）。关键地址：
//     body 0x100d011cc L17-38 / statsScrollContent 0x100d01ea0 L40-55 /
//     todayHeroCard 0x100d02d60 L61-156 / monthCalendarCard 0x100d06960
//     L229-334 / monthSummaryItem 0x100d147b0 L336-345 / shiftMonth
//     0x100d0c728 L347-351 / monthTitle 0x100d0c970 L353-356 / rankGradient
//     （签名域）/ recordCell 0x100d164a8 L553-564 / legendDot 0x100d095c4
//     L698-703 / summaryNum 0x100d0e044 L705-710 / fmt 0x100d09460 L737-741 /
//     fmtLarge / fmtChars 0x100d19720 L749-751 / deltaPercent /
//     weekDayShort / OverviewChip.body 0x100d1b880 L759-773；卡片族
//     （todayHeroCard/weekSparkCard/trendChartCard/monthCalendarCard/
//     yearProgressCard/personalRecordsCard/bookRankingCard 签名确证）+
//     heroMetric/heroDivider/cumulativeStrip/sectionHeader；
//     StatCard/StatRow/TransparentGroupBoxStyle（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/ReadingStatsView.c
//     （12410 行）
//   - 字符串确证（位模式/指针）："阅读统计" L206 标题/"gearshape" L353 域/
//     "%04d-%02d-" L2407（月键格式，与 T-501-01 统计服务同源）/
//     "vs 上周" L3637/"天活跃" L4435/"最佳单日" L6081/"最长连续" L6153/
//     "最多翻页" L6294/"近30日" L7030/"个人纪录" L7161/"书籍排行" L7351/
//     "已完成 " L7937/"查看全部 " L10570/"总时长" L11476/"活跃天" L11521；
//     图标域 character.cursor.ibeam L6802/chart.bar.fill L7030/trophy.fill
//     L7161/list.number L7351/book.fill L11147/headphones L11206/
//     flame.fill L11272/chevron. L10604
//   - 事实：统计服务交叉（T-501-01 ReadingStatisticsService：dailyStats/
//     dailyStats(year:month:)/bookStats/longestStreak/streakDays/
//     todaySeconds/todayListeningSeconds/todayProgress/totalStats/
//     monthlyBreakdown 全域签名对应）；月历卡 shiftMonth/monthTitle 域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 统计卡结构/文案: high（签名族 + 位模式确证）
//   - 图表形状: medium（结构性还原；spark/趋势细节待真机）
// 还原: 2026-11-20

import SwiftUI

/// 阅读统计主页。
struct ReadingStatsView: View {

    // 统计域（T-501-01 ReadingStatisticsService 全域交叉确证）。
    @State private var monthYear: Int = Calendar.current.component(
        .year, from: Date())
    @State private var monthMonth: Int = Calendar.current.component(
        .month, from: Date())

    private let stats = ReadingStatisticsService.shared

    var body: some View {
        // 伪代码 0x100d011cc（L17-38）：ScrollView 统计卡主链。
        ScrollView {
            statsScrollContent
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("阅读统计")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // "gearshape" 域确证。
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "gearshape")
            }
        }
    }

    /// statsScrollContent getter（0x100d01ea0 L40-55 域确证）。
    private var statsScrollContent: some View {
        VStack(spacing: 12.0) {
            todayHeroCard
            weekSparkCard
            trendChartCard
            monthCalendarCard
            yearProgressCard
            personalRecordsCard
            bookRankingCard
        }
        .padding(.all, 12.0)
    }

    // MARK: 今日英雄卡（0x100d02d60 L61-156 域确证）

    /// todayHeroCard getter（0x100d02d60 L61-156 域确证）。
    private var todayHeroCard: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            HStack {
                // "总时长"/"活跃天" L11476/L11521 域确证。
                heroMetric(
                    icon: "clock.fill", label: "总时长",
                    value: fmt(stats.todaySeconds()))
                heroDivider
                heroMetric(
                    icon: "headphones", label: "听书",
                    value: fmt(stats.todayListeningSeconds()))
                heroDivider
                heroMetric(
                    icon: "flame.fill", label: "活跃天",
                    value: "\(stats.streakDays())")
            }
            // 今日目标进度（todayProgress 域确证）。
            ProgressView(value: stats.todayProgress())
                .tint(.blue)
            Text("已完成 \(Int(stats.todayProgress() * 100))%")
                .appThemeText(.caption, opacity: 0.6)
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    /// heroMetric(icon:label:value:)（签名确证）。
    private func heroMetric(
        icon: String, label: String, value: String
    ) -> some View {
        VStack(spacing: 2.0) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(value)
                .appThemeText(.headline)
            Text(label)
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity)
    }

    /// heroDivider getter（签名确证）。
    private var heroDivider: some View {
        Divider().frame(height: 36.0)
    }

    // MARK: 周趋势卡

    /// weekSparkCard getter（签名域确证；"vs 上周" L3637 域确证）。
    private var weekSparkCard: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack {
                Text("近30日")
                    .appThemeText(.headline)
                Spacer()
                Text(deltaText())
                    .appThemeText(.caption, opacity: 0.6)
            }
            HStack(alignment: .bottom, spacing: 4.0) {
                let stats30 = stats.dailyStats(lastDays: 30)
                let peak = max(stats30.map(\.totalSeconds).max() ?? 1, 1)
                ForEach(stats30) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                        .frame(
                            height: CGFloat(day.totalSeconds)
                                / CGFloat(peak) * 60.0 + 4.0)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64.0)
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    /// 环比文案（"vs 上周" 域确证；deltaPercent 签名确证）。
    private func deltaText() -> String {
        let recent = stats.dailyStats(lastDays: 7).reduce(0) {
            $0 + $1.totalSeconds
        }
        let previous = stats.dailyStats(lastDays: 14).reduce(0) {
            $0 + $1.totalSeconds
        } - recent
        guard previous > 0 else { return "vs 上周 —" }
        let ratio = Double(recent - previous) / Double(previous) * 100
        return "vs 上周 \(String(format: "%+.0f%%", ratio))"
    }

    /// 趋势卡（trendChartCard 签名确证；"chart.bar.fill" L7030 域）。
    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Label("近30日", systemImage: "chart.bar.fill")
                .appThemeText(.headline)
            HStack(spacing: 12.0) {
                legendDot(color: .blue, text: "阅读")
                legendDot(color: .purple, text: "听书")
            }
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    /// legendDot(color:text:)（0x100d095c4 L698-703 域确证）。
    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4.0) {
            Circle().fill(color).frame(width: 8.0, height: 8.0)
            Text(text)
                .appThemeText(.caption, opacity: 0.7)
        }
    }

    // MARK: 月历卡（0x100d06960 L229-334 域确证）

    /// monthCalendarCard getter（0x100d06960 L229-334 域确证）。
    private var monthCalendarCard: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle(year: monthYear, month: monthMonth))
                    .appThemeText(.headline)
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            let monthStats = stats.dailyStats(
                year: monthYear, month: monthMonth)
            let buckets = Dictionary(
                uniqueKeysWithValues: monthStats.map {
                    ($0.dayKey, $0.totalSeconds)
                })
            let baseDate = Calendar.current.date(
                from: DateComponents(year: monthYear, month: monthMonth))
                ?? Date()
            let daysInMonth = Calendar.current.range(
                of: .day, in: .month, for: baseDate)?.count ?? 30
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()), count: 7),
                spacing: 4.0) {
                ForEach(1...daysInMonth, id: \.self) { day in
                    let key = String(
                        format: "%04d-%02d-%02d", monthYear, monthMonth, day)
                    let seconds = buckets[key] ?? 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            seconds > 0
                                ? Color.blue.opacity(
                                    min(Double(seconds) / 3600.0, 1.0))
                                : Color(uiColor: .tertiarySystemFill))
                        .frame(height: 22.0)
                        .overlay {
                            Text("\(day)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                }
            }
            // 月汇总域（monthSummaryItem L336-345 签名确证）。
            HStack {
                monthSummaryItem(
                    "月时长",
                    fmt(monthStats.reduce(0) { $0 + $1.totalSeconds }))
                monthSummaryItem("天活跃", "\(monthStats.count)")
            }
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    /// monthSummaryItem（0x100d147b0 L336-345 域确证）。
    private func monthSummaryItem(
        _ label: String, _ value: String
    ) -> some View {
        VStack(spacing: 1.0) {
            Text(value)
                .appThemeText(.subheadline)
            Text(label)
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity)
    }

    /// shiftMonth（0x100d0c728 L347-351 域确证）。
    private func shiftMonth(_ delta: Int) {
        var components = DateComponents()
        components.year = monthYear
        components.month = monthMonth + delta
        if let date = Calendar.current.date(from: components) {
            monthYear = Calendar.current.component(.year, from: date)
            monthMonth = Calendar.current.component(.month, from: date)
        }
    }

    /// monthTitle(year:month:)（0x100d0c970 L353-356 域确证）。
    private func monthTitle(year: Int, month: Int) -> String {
        String(format: "%04d年%02d月", year, month)
    }

    // MARK: 年度卡

    /// yearProgressCard getter（签名域确证；"已完成 " L7937 域确证）。
    private var yearProgressCard: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Label("年度目标", systemImage: "flag.checkered")
                .appThemeText(.headline)
            let total = stats.totalStats()
            let goal = max(stats.yearlyGoalBooks, 1)
            ProgressView(value: Double(total.totalBooks) / Double(goal))
                .tint(.green)
            Text(
                "已完成 \(total.totalBooks)/\(goal) 本 · 总时长 "
                    + fmtLarge(total.totalSeconds))
                .appThemeText(.caption, opacity: 0.6)
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    // MARK: 纪录卡（"最佳单日" L6081/"最长连续" L6153/"最多翻页" L6294 域）

    /// personalRecordsCard getter（签名域确证）。
    private var personalRecordsCard: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Label("个人纪录", systemImage: "trophy.fill")
                .appThemeText(.headline)
            HStack {
                recordCell("最佳单日", fmt(bestDaySeconds()))
                recordCell("最长连续", "\(stats.longestStreak()) 天")
                recordCell("最多翻页", fmtChars(topDayReadingSeconds()))
            }
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    /// recordCell（0x100d164a8 L553-564 域确证）。
    private func recordCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2.0) {
            Text(value)
                .appThemeText(.subheadline)
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func bestDaySeconds() -> Int {
        stats.dailyStats(lastDays: 90).map(\.totalSeconds).max() ?? 0
    }

    private func topDayReadingSeconds() -> Int {
        stats.dailyStats(lastDays: 90).map(\.readingSeconds).max() ?? 0
    }

    // MARK: 排行卡（"书籍排行" L7351 + "list.number" L7351 + rankGradient 域）

    /// bookRankingCard getter（签名域确证；"查看全部 " L10570 域确证）。
    private var bookRankingCard: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Label("书籍排行", systemImage: "list.number")
                .appThemeText(.headline)
            let ranking = Array(stats.bookStats().prefix(5))
            ForEach(Array(ranking.enumerated()), id: \.1.id) { index, stat in
                HStack(spacing: 8.0) {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(rankGradient(index).first ?? .blue)
                    Text(stat.bookName)
                        .lineLimit(1)
                    Spacer()
                    Text(fmtLarge(stat.totalSeconds))
                        .appThemeText(.caption, opacity: 0.7)
                }
            }
            if stats.bookStats().count > 5 {
                Button("查看全部 \(stats.bookStats().count) 本") {
                    // TODO(T-501-05 域): 全量排行页接入。
                }
                .appThemeText(.caption)
            }
        }
        .padding(.all, 14.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassStatCardStyle()
    }

    /// rankGradient（签名确证：金银铜渐变色域）。
    private func rankGradient(_ index: Int) -> [Color] {
        switch index {
        case 0: return [.yellow, .orange]
        case 1: return [.gray, .gray.opacity(0.6)]
        case 2: return [.orange, .brown]
        default: return [.blue, .blue.opacity(0.6)]
        }
    }

    // MARK: 格式化（fmt/fmtLarge/fmtChars/deltaPercent/weekDayShort 签名确证）

    /// fmt（0x100d09460 L737-741 域确证：分钟口径）。
    private func fmt(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)时\(minutes % 60)分"
        }
        return "\(minutes)分钟"
    }

    /// fmtLarge（签名确证：万级缩写）。
    private func fmtLarge(_ seconds: Int) -> String {
        let hours = seconds / 3600
        if hours >= 10000 {
            return String(format: "%.1f万小时", Double(hours) / 10000)
        }
        return "\(hours)小时"
    }

    /// fmtChars（0x100d19720 L749-751 域确证）。
    private func fmtChars(_ seconds: Int) -> String {
        "\(seconds / 60) 分"
    }

    /// summaryNum（0x100d0e044 L705-710 域确证）。
    private func summaryNum(_ value: String, label: String) -> some View {
        VStack(spacing: 1.0) {
            Text(value)
                .appThemeText(.headline)
            Text(label)
                .appThemeText(.caption, opacity: 0.6)
        }
    }
}

// MARK: - 卡样式

extension View {
    /// glassStatCardStyle（签名确证）。
    func glassStatCardStyle() -> some View {
        self
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(14, antialiased: true)
    }
}

/// 概览芯片（OverviewChip.body 0x100d1b880 L759-773 域确证）。
struct OverviewChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6.0) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
            Text(value)
                .appThemeText(.caption)
        }
        .padding(.horizontal, 10.0)
        .padding(.vertical, 6.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10, antialiased: true)
    }
}

/// 统计卡（StatCard.body 签名确证）。
struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4.0) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(value)
                .appThemeText(.headline)
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10, antialiased: true)
    }
}

/// 统计行（StatRow.body 签名确证）。
struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

/// 透明分组框样式（TransparentGroupBoxStyle.makeBody 签名确证）。
struct TransparentGroupBoxStyle: GroupBoxStyle {
    func makeBody(
        configuration: GroupBoxStyleConfiguration
    ) -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            configuration.label
            configuration.content
        }
        .padding(.all, 12.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }
}
