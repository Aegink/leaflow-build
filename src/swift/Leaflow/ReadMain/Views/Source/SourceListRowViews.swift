// 原路径: ReadMain/Views/Source/SourceListRowViews.swift
// 证据:
//   - PGO: 74 条记录（index/task_functions.csv T-401-06 /
//     SourceListRowViews.swift；伪代码域 1823 行）。关键地址：
//     SourceFeatureTag.body / SelectionToolbarButton.body /
//     SourceFeatureRow.body / LazySourceRow.== infix（Equatable）/
//     LazySourceRow.body / SourceRowView.body
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceListRowViews.c
//     （1823 行）
//   - 字符串确证（位模式/指针）："测试配置"（L1436）/"编辑配置"（L1477）/
//     "选择此配置"（L1562）/"禁用配置"（L1606）/"启用配置"（L1611）/
//     "复制配置"（L1697）/"删除配置"（L1738）/"xmark.circle"（'xmark.ci'
//     L376 域，禁用标记确证）
//   - 事实：行上下文菜单六项（测试/编辑/选择/禁用|启用/复制/删除 确证）；
//     LazySourceRow 为 Equatable 惰性行（== infix 签名确证）；
//     SourceFeatureRow 为启用标记行（xmark 禁用域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 行结构/菜单项: high（位模式确证）
//   - 布局细节: medium（结构性还原，待真机对照）
// 还原: 2026-11-20

import SwiftUI

/// 功能标签（SourceFeatureTag 签名确证）。
struct SourceFeatureTag: View {
    let title: String
    let enabled: Bool

    var body: some View {
        Text(title)
            .appThemeText(.caption, opacity: enabled ? 1.0 : 0.5)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 2.0)
            .background(
                (enabled ? Color.green : Color.gray).opacity(0.15))
            .cornerRadius(6, antialiased: true)
    }
}

/// 选择工具栏按钮（SelectionToolbarButton 签名确证）。
struct SelectionToolbarButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
    }
}

/// 功能支持行（SourceFeatureRow 签名 + xmark 禁用域确证）。
struct SourceFeatureRow: View {
    let title: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 6.0) {
            Image(
                systemName: enabled
                    ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .secondary)
                .font(.caption)
            Text(title)
                .appThemeText(.caption)
        }
    }
}

/// 惰性行（LazySourceRow == infix Equatable 签名确证）。
struct LazySourceRow: View, Equatable {
    let source: BookSource
    let isSelected: Bool

    static func == (lhs: LazySourceRow, rhs: LazySourceRow) -> Bool {
        lhs.source == rhs.source && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        // 惰性行主体：名称 + 分组 + 功能标签行。
        HStack(spacing: 8.0) {
            VStack(alignment: .leading, spacing: 3.0) {
                Text(source.bookSourceName)
                    .lineLimit(1)
                HStack(spacing: 4.0) {
                    SourceFeatureTag(
                        title: "搜索",
                        enabled: !source.ruleSearch.bookList.isEmpty)
                    SourceFeatureTag(
                        title: "目录", enabled: source.enabledToc)
                    SourceFeatureTag(
                        title: "正文", enabled: source.enabledContent)
                    SourceFeatureTag(
                        title: "发现", enabled: source.enabledExplore)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
            if !source.enabled {
                // xmark.circle 禁用标记域确证。
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2.0)
    }
}

/// 书源列表行（SourceRowView 签名确证；菜单六项位模式确证）。
struct SourceRowView: View {
    let source: BookSource
    var isSelected: Bool = false
    var onTest: (() -> Void)?
    var onEdit: (() -> Void)?
    var onSelect: (() -> Void)?
    var onToggleEnabled: (() -> Void)?
    var onCopy: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        LazySourceRow(source: source, isSelected: isSelected)
            .contextMenu {
                // "测试配置" L1436。
                Button {
                    onTest?()
                } label: {
                    Label("测试配置", systemImage: "play.circle")
                }
                // "编辑配置" L1477。
                Button {
                    onEdit?()
                } label: {
                    Label("编辑配置", systemImage: "square.and.pencil")
                }
                // "选择此配置" L1562。
                Button {
                    onSelect?()
                } label: {
                    Label("选择此配置", systemImage: "checkmark.circle")
                }
                // "禁用配置"/"启用配置" L1606/L1611。
                Button(role: source.enabled ? .destructive : nil) {
                    onToggleEnabled?()
                } label: {
                    Label(
                        source.enabled ? "禁用配置" : "启用配置",
                        systemImage: source.enabled
                            ? "pause.circle" : "play.circle")
                }
                // "复制配置" L1697。
                Button {
                    onCopy?()
                } label: {
                    Label("复制配置", systemImage: "doc.on.doc")
                }
                Divider()
                // "删除配置" L1738。
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("删除配置", systemImage: "trash")
                }
            }
    }
}
