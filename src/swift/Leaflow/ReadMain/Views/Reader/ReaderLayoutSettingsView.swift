// 原路径: ReadMain/Views/Reader/ReaderLayoutSettingsView.swift
// 证据:
//   - PGO: 94 个主函数（index/task_functions.csv T-301-06 / ReaderLayoutSettingsView.swift），
//     核心地址：restoreDefaultLayoutSettings 0x1007a02f8 L9-23 / LayoutSettingsSection.init
//     0x1007ec478 L33-35（+_showResetAlert 变量初始化 0x1007e6820 L31）/
//     LayoutSettingsSection.body 0x1007a0dd4 L37-115（+TupleView 闭包族 0x1007a0ec4-2fb8）/
//     DisplayItemGrid.body 0x1007a3180 L133-149（+ForEach 闭包 0x1007a3294 L134-148）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderLayoutSettingsView.c（11012 行）
//   - 关键调用：ButtonRole.destructive / Color.accentColor|secondary /
//     Font.readerUI/Font.system/Font.Weight.medium|regular / UnitPoint.top|bottom /
//     defaultCenter.postNotificationName（body 确证，设置变更通知）/
//     appThemeText(AppThemeTextLevel, opacity)（确证）
//   - 事实：restoreDefaultLayoutSettings（L9-23）：恢复默认 + destructive alert 确认；
//     LayoutSettingsSection.body = TupleView(padding ×2 + alert) + 按钮三元组
//     （Button<Text> ×3，closure#5）+ resetAlert；DisplayItemGrid = ForEach
//     [(String, [ReaderDisplayItem])]（分组栅格，L133-149 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - restoreDefaultLayoutSettings/DisplayItemGrid 结构: high（builder opaque 描述确证）
//   - LayoutSettingsSection 行内布局细节: medium（94 函数中深层 body 分支待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 恢复默认排版设置（伪代码 0x1007a02f8，L9-23）。
/// @MainActor：ReadingSettings 域隔离对齐（Button action 域调用，wave-63）。
@MainActor
private func restoreDefaultLayoutSettings(_ settings: inout ReadingSettings) {
    let defaults = ReadingSettings.load()
    settings.fontSize = defaults.fontSize
    settings.lineSpacing = defaults.lineSpacing
    settings.paragraphSpacing = defaults.paragraphSpacing
    settings.textIndent = defaults.textIndent
    settings.letterSpacing = defaults.letterSpacing
    settings.textAlignment = defaults.textAlignment
    settings.verticalJustify = defaults.verticalJustify
    settings.paragraphSeparatorLines = defaults.paragraphSeparatorLines
    NotificationCenter.default.post(name: .readerLayoutSettingsDidChange, object: nil)
}

extension Notification.Name {
    static let readerLayoutSettingsDidChange =
        Notification.Name("leafflow.readerLayoutSettingsDidChange")
}

/// 排版设置分区（伪代码 0x1007a0dd4，L37-115）。
struct LayoutSettingsSection: View {
    @Binding var settings: ReadingSettings
    /// 伪代码 0x1007e6820（L31）：_showResetAlert 变量初始化确证。
    @State private var showResetAlert = false

    init(settings: Binding<ReadingSettings>) {
        _settings = settings
    }

    var body: some View {
        // 伪代码 L37-115：TupleView(padding ×2 + alert)。
        Group {
            fontSection
                .padding(.horizontal)
            paragraphSection
                .padding(.horizontal)
        }
        .background(alignment: .center) {
            Color.clear
        }
        .alert(
            "恢复默认排版？",
            isPresented: $showResetAlert,
            actions: {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) {
                    restoreDefaultLayoutSettings(&settings)
                }
            },
            message: {
                Text("将重置字号、行距与段距。")
            })
    }

    /// 字号区（closure #2 background + accentColor/secondary 确证）。
    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("字号")
                .appThemeText(.headline)
            HStack {
                Text("A").font(.system(size: 12))
                Slider(value: Binding(
                    get: { Double(settings.fontSize) },
                    set: { settings.fontSize = CGFloat($0) }), in: 12...36)
                Text("A").font(.system(size: 24))
            }
            .tint(.accentColor)
        }
        .padding(.vertical, 8)
    }

    /// 段距区（closure #3：frame + VStack + Spacer + tint 确证）。
    private var paragraphSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("段落")
                .appThemeText(.headline)
            Stepper(
                "行距 \(Int(settings.lineSpacing))",
                value: Binding(
                    get: { settings.lineSpacing },
                    set: { settings.lineSpacing = $0 }), in: 0...24)
            Stepper(
                "段距 \(Int(settings.paragraphSpacing))",
                value: Binding(
                    get: { settings.paragraphSpacing },
                    set: { settings.paragraphSpacing = $0 }), in: 0...16)
            HStack {
                Spacer()
                Button("恢复默认") { showResetAlert = true }
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .padding(.vertical, 8)
    }
}

/// 显示条目栅格（伪代码 0x1007a3180，L133-149）。
/// body 拆分为单分组子视图（类型检查超时消解，wave-63）。
struct DisplayItemGrid: View {
    var groups: [(String, [ReaderDisplayItem])]

    var body: some View {
        // ForEach [(String, [ReaderDisplayItem])]（L134-148 确证）。
        ForEach(groups, id: \.0) { title, items in
            DisplayItemGridGroup(title: title, items: items)
        }
    }
}

/// 单分组栅格（DisplayItemGrid.body L133-149 域搬移）。
private struct DisplayItemGridGroup: View {
    let title: String
    let items: [ReaderDisplayItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .appThemeText(.subheadline, opacity: 0.9)
                .font(.system(size: 14, weight: .regular))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item.displayName)
                        .font(.readerUI(.body))
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// 排版设置根视图（骨架签名：ReaderLayoutSettingsView）。
struct ReaderLayoutSettingsView: View {
    @Binding var settings: ReadingSettings

    var body: some View {
        ScrollView {
            LayoutSettingsSection(settings: $settings)
                .padding(.top)
        }
        .navigationTitle("排版设置")
    }
}

/// 标签流式布局（0x1007a4800 L181-186 placeSubviews 域确证；
/// iOS 16 Layout 协议形态）。
struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    /// 伪代码 0x1007a4800（L181-186）：逐子视图按行放置（块体为计数器桩，
    /// 按协议语义还原）。
    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

