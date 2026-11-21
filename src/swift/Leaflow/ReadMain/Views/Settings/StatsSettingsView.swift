// 原路径: ReadMain/Views/Settings/StatsSettingsView.swift
// 证据:
//   - PGO: 94 条记录（index/task_functions.csv T-701-08 /
//     StatsSettingsView.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（body/formatDuration/totalRecords/
//     totalStats 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     StatsSettingsView.c（3296 行）
//   - 块体确证（签名域）：
//     body getter / formatDuration(_: Int) / totalRecords getter /
//     totalStats getter
//   - 字符串域（位模式+指针，scratch/t70108_stats_strings.txt）：
//     '显示' L769 / '每日目标' L812/L1151 / '年度目标' L857 /
//     '连续天数' L900 / '数据概览' L944 / '数据管理' L977 /
//     '未设定' L1162/L1748 / ' 分钟' L1179 / '1小时' L1324 /
//     '2小时' L1329 / '4小时' L1334 / '12本' L1948 / '24本' L1954 /
//     '52本' L1959 / '100本' L1964 / '1 分钟' L2125 / '统计记录数'
//     L2347 / '统计天数' L2489 / '统计书籍' L2630 / '累计阅读'
//     L2761 / '小时' L2846 / '分钟' L2857 / '清空' L3064 /
//     '取消' L3079 / '累计听书' L3180
//   - 事实：目标域（分钟/本数档位确证）+ 数据概览四卡 +
//     清空确认
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（四签名域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// 统计设置页（body/formatDuration/totalStats 签名域确证）。
struct StatsSettingsView: View {

    @State private var dailyGoalMinutes = 30
    @State private var yearlyGoalBooks = 12
    @State private var showClearConfirm = false

    private let statsService = ReadingStatisticsService.shared

    var body: some View {
        Form {
            overviewSection
            goalSection
            dataSection
        }
        .navigationTitle("统计")
        .onAppear {
            dailyGoalMinutes = statsService.dailyGoalMinutes
            yearlyGoalBooks = statsService.yearlyGoalBooks
        }
    }

    // MARK: 数据概览（'数据概览' L944 + '统计记录数' L2347 /
    // '统计天数' L2489 / '统计书籍' L2630 / '累计阅读' L2761 /
    // '累计听书' L3180 域确证）

    @ViewBuilder
    private var overviewSection: some View {
        Section("数据概览") {
            statRow(
                "统计记录数", value: "\(totalRecords)",
                systemImage: "list.bullet")
            statRow(
                "统计天数", value: "\(totalStats.longestStreak)",
                systemImage: "calendar")
            statRow(
                "统计书籍", value: "\(totalStats.totalBooks)",
                systemImage: "books.vertical")
            statRow(
                "累计阅读",
                value: formatDuration(totalStats.totalSeconds),
                systemImage: "clock")
            statRow(
                "连续天数", value: "\(totalStats.currentStreak)",
                systemImage: "flame")
        }
    }

    // MARK: 目标域（'每日目标' L812 / '年度目标' L857 + '1小时'/'2
    // 小时'/'4小时' L1324-1334 + '12本'/'24本'/'52本'/'100本'
    // L1948-1964 档位域确证）

    @ViewBuilder
    private var goalSection: some View {
        Section("目标") {
            Picker(selection: $dailyGoalMinutes) {
                Text("未设定").tag(0)
                Text("30 分钟").tag(30)
                Text("1小时").tag(60)
                Text("2小时").tag(120)
                Text("4小时").tag(240)
            } label: {
                Text("每日目标")
            }
            .onChange(of: dailyGoalMinutes) { newValue in
                statsService.dailyGoalMinutes = newValue
            }
            Picker(selection: $yearlyGoalBooks) {
                Text("未设定").tag(0)
                Text("12本").tag(12)
                Text("24本").tag(24)
                Text("52本").tag(52)
                Text("100本").tag(100)
            } label: {
                Text("年度目标")
            }
            .onChange(of: yearlyGoalBooks) { newValue in
                statsService.yearlyGoalBooks = newValue
            }
        }
    }

    // MARK: 数据管理（'数据管理' L977 / '清空' L3064 / '取消' L3079
    // 域确证）

    @ViewBuilder
    private var dataSection: some View {
        Section("数据管理") {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("清空统计数据", systemImage: "trash")
            }
        }
        .alert(
            "清空统计数据",
            isPresented: $showClearConfirm
        ) {
            Button("清空", role: .destructive) {
                statsService.clearAllRecords()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清空全部统计数据吗？此操作不可恢复。")
        }
    }

    /// statRow 桥（AppThemeSettingsLabel 域）。
    @ViewBuilder
    private func statRow(
        _ title: String, value: String, systemImage: String
    ) -> some View {
        HStack {
            AppThemeSettingsLabel(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    /// totalRecords getter（签名域确证）。
    private var totalRecords: Int {
        // 记录数按日聚合域估算（service dailyStats 链）。
        statsService.dailyStats(lastDays: 3650).count
    }

    /// totalStats getter（签名域确证）。
    private var totalStats: TotalStat {
        statsService.totalStats()
    }

    /// formatDuration(_: Int)（签名域确证：'小时'/'分钟' 双单位域）。
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes > 0 ? " \(minutes)分钟" : "")"
        }
        return "\(minutes)分钟"
    }
}
