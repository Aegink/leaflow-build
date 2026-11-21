// 原路径: ReadMain/Views/Source/SourceDetailView.swift
// 证据:
//   - PGO: 26 条记录（index/task_functions.csv T-401-05 /
//     SourceDetailView.swift；12 个伪代码块 + 14 pgo_only）。关键地址：
//     body 0x100bb13e8 L10-54 / sheet 闭包1 0x100bb18d8 L12-36 /
//     LabeledContent 组 0x100bb1db8 L13-18 / 功能行组 0x100bb227c L26-35 /
//     工具栏 0x100bb266c L39-46
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceDetailView.c
//     （1026 行）
//   - 字符串确证（位模式）："基本信息" / "功能支持" / "未分组" /
//     "发现筛选" / "书籍详情" / "章节目录" / "正文内容" / "Cookie管理"
//   - 事实：LabeledContent ×4 基本信息组（源 URL/名称/分组/注释，closure1
//     L13-18 确证）+ SourceFeatureRow ×8 功能组（closure3 L26-35；七项
//     enabled 标志 + 书源类型确证）+ 注释 Section（Text 可选段）+ sheet
//     二级页（编辑/测试入口）+ 工具栏（closure2 L39-46）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 信息组/功能行结构: high（伪代码块体 + 位模式确证）
//   - 工具栏/sheet 出口细节: medium（结构性还原，待真机对照）
// 还原: 2026-11-20

import SwiftUI

/// 书源详情页。
struct SourceDetailView: View {

    let source: BookSource

    @State private var showingEditor = false
    @State private var showingTest = false

    var body: some View {
        // 伪代码 0x100bb13e8（L10-54）：List + 两个 Section + sheet。
        List {
            // closure1（0x100bb18d8 L12-36）：两个 Section。
            Section("基本信息") {
                // 0x100bb1db8（L13-18）：LabeledContent ×4。
                LabeledContent("源 URL", value: source.bookSourceUrl)
                LabeledContent("名称", value: source.bookSourceName)
                LabeledContent(
                    "分组",
                    value: source.bookSourceGroup ?? "未分组")
                LabeledContent(
                    "注释", value: source.bookSourceComment ?? "—")
            }
            // 注释可选段（Section<Text, Text> 可选确证）。
            if let comment = source.bookSourceComment,
               !comment.isEmpty {
                Section("备注") {
                    Text(comment)
                        .appThemeText(.caption, opacity: 0.7)
                }
            }
            Section("功能支持") {
                // 0x100bb227c（L26-35）：SourceFeatureRow ×8。
                SourceFeatureRow(
                    title: "搜索", enabled: !source.ruleSearch.bookList.isEmpty)
                SourceFeatureRow(
                    title: "发现筛选", enabled: source.enabledExplore)
                SourceFeatureRow(
                    title: "书籍详情", enabled: source.enabledBookInfo)
                SourceFeatureRow(
                    title: "章节目录", enabled: source.enabledToc)
                SourceFeatureRow(
                    title: "正文内容", enabled: source.enabledContent)
                SourceFeatureRow(
                    title: "Cookie管理", enabled: source.enabledCookieJar)
                SourceFeatureRow(
                    title: "书评", enabled: source.enabledReview)
                SourceFeatureRow(
                    title: "登录", enabled: source.loginUrl != nil)
            }
        }
        .navigationTitle(source.bookSourceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 0x100bb266c（L39-46）：测试/编辑入口。
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12.0) {
                    Button {
                        showingTest = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            EditableSourceView(source: source)
        }
        .sheet(isPresented: $showingTest) {
            SourceFullTestView(source: source)
        }
    }
}
