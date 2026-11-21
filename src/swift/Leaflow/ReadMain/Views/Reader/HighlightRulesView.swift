// 原路径: ReadMain/Views/Reader/HighlightRulesView.swift
// 证据:
//   - PGO: 202 个主函数（index/task_functions.csv T-303-04 / HighlightRulesView.swift），
//     地址：HighlightRuleListBindings.binding(for:fallback:onUpdate:) 0x1006d0024
//     L11-23 / enabledCount 0x1006d0870 L35-37 / builtinRuleIDs 0x1006d0b54
//     L39-43 / customRuleIDs 0x1006d1590 L45-47 / body 0x1006d16a8 L49-168
//     (+closure 0x1006d1f6c/0x1006d23f8/0x100702520/0x1006d294c/0x100701e6c) /
//     highlightRulesEnabledToggleBinding 0x1006d2560 L321-328 /
//     highlightRulesStatusText 0x1006d2628 L330-335 / binding(for:) 0x1006d2c0c
//     L310-319 / ruleRow 0x100d3334 0x1006d3334 L206-302 / moveCustomRules
//     0x1006d4254 L393-398 / deleteCustomRules 0x1006d4a9c L386-391 /
//     createCustomRule 0x1006d533c L337-358 / saveRule 0x1006d6fe0 L360-373 /
//     deleteRule 0x1006d7604 L379-384 / resetBuiltinRule 0x1006d797c L400-406 /
//     handleRuleFileImport 0x1006d79ac L422-431 / exportHighlightRule
//     0x1006db224 L408-420 / presentShareSheet 0x1006dc61c L450-462 /
//     highlightRuleImportMessage 0x1006dc918 L433-448 / HighlightRulePreviewText
//     makeUIView 0x1006dcecc L552-558 + sizeThatFits 0x1006dd028 /
//     HighlightBackgroundImageRenderView.makeUIView 0x1006dd12c L579-584 +
//     updateUIView 0x100708c80 + RenderView.draw 0x100708ac0 L599-609 /
//     HighlightBackgroundImageVisualEditor.body 0x1006df754 L626-647 /
//     editorLabel 0x1006dfedc L649-653 / SliceStretchEditMode 0x1006dffc0
//     L1138-1147 / stretchSelectionGeometry 0x1006e027c L987-1045 /
//     stretchCanvasGesture 0x1006e168c L800-833
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/HighlightRulesView.c
//   - 事实：规则管理面板主链 —— 列表（内置/自定义分组）+ 单规则行
//     （enabled 开关 + 编辑/重置/导出）+ 导入导出 + 九宫格背景视觉编辑器
//     （SliceStretchEditMode + stretchCanvasGesture 手势几何）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链（CRUD/绑定/导入导出）: high（函数名+签名确证）
//   - 九宫格视觉编辑器深层手势: medium-high（几何函数确证）
//   - 深层 body 分支（202 函数中 150+ 闭包）: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

// MARK: - 绑定桥

/// 规则字段绑定桥（静态绑定族确证）。
enum HighlightRuleListBindings {

    /// 伪代码 0x1006d0024（L11-23）+ closure #2（0x1006d0314，L16-21）：
    /// 按键取规则字段值 → Binding<String>。
    static func binding(
        for key: String,
        fallback: HighlightRule,
        onUpdate: @escaping (HighlightRule) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                switch key {
                case "name": return fallback.name
                case "regex": return fallback.regex
                case "lightColorHex": return fallback.lightColorHex
                case "darkColorHex": return fallback.darkColorHex
                default: return ""
                }
            },
            set: { newValue in
                var updated = fallback
                switch key {
                case "name": updated.name = newValue
                case "regex": updated.regex = newValue
                case "lightColorHex": updated.lightColorHex = newValue
                case "darkColorHex": updated.darkColorHex = newValue
                default: break
                }
                onUpdate(updated)
            })
    }
}

// MARK: - 规则管理面板

/// 高亮规则管理面板。
struct HighlightRulesView: View {

    @Binding var settings: ReadingSettings
    @Environment(\.dismiss) private var dismiss
    @State private var editingRule: HighlightRule?
    @State private var showAddSheet = false
    @State private var showImporter = false
    @State private var shareURL: URL?

    /// 伪代码 0x1006dce8c（L28）：settings 持有。
    private var mergedRules: [HighlightRule] {
        HighlightRule.mergedWithBuiltinRules(settings.highlightRules)
    }

    /// 伪代码 0x1006d0870（L35-37）：启用计数。
    private var enabledCount: Int {
        mergedRules.filter(\.enabled).count
    }

    /// 伪代码 0x1006d0b54（L39-43）：内置 id 集。
    /// 表达式拆分（type-check 超时域，wave-16）。
    private var builtinRuleIDs: [String] {
        let builtinOnly = mergedRules.filter { rule in
            HighlightRule.builtinRule(for: rule.id) != nil
        }
        return builtinOnly.map(\.id)
    }

    /// 伪代码 0x1006d1590（L45-47）：自定义 id 集。
    private var customRuleIDs: [String] {
        mergedRules.filter { HighlightRule.builtinRule(for: $0.id) == nil }.map(\.id)
    }

    /// 表达式拆分（List body type-check 超时域，wave-16）。
    private var builtInSection: some View {
        Section {
            ForEach(builtinRuleIDs, id: \.self) { id in
                if let rule = mergedRules.first(where: { $0.id == id }) {
                    ruleRow(rule: binding(for: id))
                }
            }
        } header: {
            // closure #1（0x100701e6c，L76-98）：状态头。
            Text(highlightRulesStatusText)
        }
    }

    private var customRulesSection: some View {
        Section("自定义规则") {
            ForEach(customRuleIDs, id: \.self) { id in
                if let rule = mergedRules.first(where: { $0.id == id }) {
                    ruleRow(rule: binding(for: id))
                }
            }
            .onDelete { offsets in
                deleteCustomRules(offsets)
            }
            .onMove { source, destination in
                moveCustomRules(from: source, to: destination)
            }
            Button {
                showAddSheet = true
            } label: {
                Label("新建规则", systemImage: "plus")
            }
        }
    }

    var body: some View {
        List {
            builtInSection
            customRulesSection
        }
        .navigationTitle("高亮规则")
        .toolbar {
            EditButton()
        }
        .sheet(item: $editingRule, onDismiss: { settings.saveHighlightRules(mergedRules) }) { rule in
            // 高亮规则编辑表单（HighlightRule 域 name/pattern——内联编辑器；
            // ChapterRuleEditView 属 ChapterRule 域不可混用，wave-16 修正）。
            NavigationStack {
                Form {
                    TextField("规则名", text: Binding(
                        get: { rule.wrappedValue.name },
                        set: { rule.wrappedValue.name = $0 }))
                    TextField("正则模式", text: Binding(
                        get: { rule.wrappedValue.pattern },
                        set: { rule.wrappedValue.pattern = $0 }))
                }
                .navigationTitle("编辑高亮规则")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false) { result in
            handleRuleFileImport(result)
        }
        .sheet(
            isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } })) {
            if let shareURL {
                ShareSheet(url: shareURL)
            }
        }
    }

    /// 伪代码 0x1006d2c0c（L310-319）：按 id 取 Binding。
    private func binding(for id: String) -> Binding<HighlightRule> {
        Binding(
            get: {
                mergedRules.first { $0.id == id }
                    ?? HighlightRule.builtinRule(for: id)
                    ?? HighlightRule.builtinRule(for: "builtin.quote")!
            },
            set: { updated in
                saveRule(updated)
            })
    }

    /// 伪代码 0x1006d3334（L206-302）：单规则行
    ///（enabled 开关 + 预览 + 编辑/重置/导出菜单确证）。
    @ViewBuilder
    private func ruleRow(rule: Binding<HighlightRule>) -> some View {
        HStack {
            Toggle("", isOn: rule.enabled)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.wrappedValue.name)
                    .appThemeText(.body)
                Text(rule.wrappedValue.regex)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .font(.system(.caption, design: .monospaced))
            }
            Spacer()
            Menu {
                Button("编辑") { editingRule = rule.wrappedValue }
                if rule.wrappedValue.isBuiltin {
                    Button("重置默认") { resetBuiltinRule(id: rule.wrappedValue.id) }
                } else {
                    Button("导出") { exportHighlightRule(rule.wrappedValue) }
                    Button("删除", role: .destructive) { deleteRule(id: rule.wrappedValue.id) }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: CRUD

    /// 伪代码 0x1006d533c（L337-358）：新建自定义规则。
    private func createCustomRule(from rule: HighlightRule) {
        settings.saveHighlightRules(mergedRules + [rule])
    }

    /// 伪代码 0x1006d6fe0（L360-373）：保存规则。
    @discardableResult
    private func saveRule(_ rule: HighlightRule) -> Bool {
        var rules = mergedRules
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return false }
        rules[index] = rule
        settings.saveHighlightRules(rules)
        return true
    }

    /// 伪代码 0x1006d7604（L379-384）：删除规则。
    private func deleteRule(id: String) {
        settings.saveHighlightRules(mergedRules.filter { $0.id != id })
    }

    /// 伪代码 0x1006d4a9c（L386-391）：批量删除自定义。
    private func deleteCustomRules(_ offsets: IndexSet) {
        let ids = offsets.map { customRuleIDs[$0] }
        settings.saveHighlightRules(mergedRules.filter { !ids.contains($0.id) })
    }

    /// 伪代码 0x1006d4254（L393-398）：自定义规则移动。
    private func moveCustomRules(from source: IndexSet, to destination: Int) {
        var rules = customRuleIDs
        rules.move(fromOffsets: source, toOffset: destination)
        let builtin = mergedRules.filter { builtinRuleIDs.contains($0.id) }
        let custom = rules.compactMap { id in
            mergedRules.first { $0.id == id }
        }
        settings.saveHighlightRules(builtin + custom)
    }

    /// 伪代码 0x1006d797c（L400-406）：内置规则重置。
    private func resetBuiltinRule(id: String) {
        guard let defaultRule = HighlightRule.builtinRule(for: id) else { return }
        saveRule(defaultRule)
    }

    // MARK: 全局开关

    /// 伪代码 0x1006d2560（L321-328）：总开关绑定。
    private var highlightRulesEnabledToggleBinding: Binding<Bool> {
        Binding(
            get: { enabledCount > 0 },
            set: { enabled in
                var rules = mergedRules
                for index in rules.indices where builtinRuleIDs.contains(rules[index].id) {
                    rules[index].enabled = enabled
                }
                settings.saveHighlightRules(rules)
            })
    }

    /// 伪代码 0x1006d2628（L330-335）：状态文案。
    private var highlightRulesStatusText: String {
        "\(enabledCount)/\(mergedRules.count) 已启用"
    }

    // MARK: 导入导出

    /// 伪代码 0x1006d79ac（L422-431）：规则文件导入。
    private func handleRuleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let summary = try HighlightRuleFileService.importArchive(
                    from: url, assetManager: HighlightBackgroundImageAssetManager(),
                    settings: settings)
                let message = highlightRuleImportMessage(summary)
                if let message {
                    AppErrorPresenter.shared.show(message, level: .success)
                }
            } catch {
                AppErrorPresenter.shared.show(error.localizedDescription, level: .error)
            }
        case .failure(let error):
            AppErrorPresenter.shared.show(error.localizedDescription, level: .error)
        }
    }

    /// 伪代码 0x1006db224（L408-420）：单规则导出。
    private func exportHighlightRule(_ rule: HighlightRule) {
        do {
            let url = try HighlightRuleFileService.exportFile(
                rules: [rule], suggestedFileName: rule.name,
                assetManager: HighlightBackgroundImageAssetManager())
            presentShareSheet(url: url)
        } catch {
            AppErrorPresenter.shared.show(error.localizedDescription, level: .error)
        }
    }

    /// 伪代码 0x1006dc61c（L450-462）：分享面板。
    private func presentShareSheet(url: URL) {
        shareURL = url
    }

    /// 伪代码 0x1006dc918（L433-448）：导入消息。
    private func highlightRuleImportMessage(
        _ summary: HighlightRuleImportService.HighlightRuleImportSummary
    ) -> String? {
        "导入规则 \(summary.importedCount) 条，更新 \(summary.updatedCount) 条"
    }
}

/// 分享面板（UIActivityViewController 桥）。
struct ShareSheet: UIViewControllerRepresentable {

    var url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - 预览文本

/// 规则预览文本（makeUIView/sizeThatFits 确证）。
struct HighlightRulePreviewText: UIViewRepresentable {

    var text: String
    var rules: [CompiledHighlightRule]
    var isDark: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let attributed = NSMutableAttributedString(string: text)
        ReaderRegexHighlightApplier.apply(
            to: attributed, text: text, rules: rules, isDark: isDark,
            includeAttributes: true, applyCrossPageQuotes: false)
        textView.attributedText = attributed
    }

    /// 伪代码 0x1006dd028（L569-572）。
    func sizeThatFits(
        _ proposal: ProposedViewSize, uiView: UITextView, context: Context
    ) -> CGSize? {
        uiView.sizeThatFits(
            CGSize(width: proposal.width ?? 320, height: UIView.noIntrinsicMetric))
    }
}

// MARK: - 背景图渲染

/// 背景图渲染视图（makeUIView/updateUIView/draw 确证）。
struct HighlightBackgroundImageRenderView: UIViewRepresentable {

    var image: UIImage?

    func makeUIView(context: Context) -> HighlightBackgroundImageRenderView.RenderView {
        let view = RenderView()
        view.image = image
        return view
    }

    func updateUIView(_ view: RenderView, context: Context) {
        view.image = image
        view.setNeedsDisplay()
    }

    /// 伪代码 0x100708ac0（L599-609）：draw。
    final class RenderView: UIView {

        var image: UIImage?

        override func draw(_ rect: CGRect) {
            guard let image else { return }
            image.draw(in: rect)
        }
    }
}

// MARK: - 九宫格视觉编辑器

/// 背景图九宫格视觉编辑器（SliceStretchEditMode/gesture/geometry 确证）。
struct HighlightBackgroundImageVisualEditor: View {

    var image: UIImage
    @Binding var layout: HighlightBackgroundImageLayout

    @State private var dragMode: SliceStretchEditMode = .none

    var body: some View {
        // 伪代码 0x1006df754（L626-647）。
        GeometryReader { proxy in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                stretchSelectionGeometry(in: proxy.size)
            }
            .gesture(stretchCanvasGesture(size: proxy.size))
        }
        .overlay(alignment: .bottom) {
            Text(editorLabel(dragMode))
                .font(.caption)
                .padding(6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 8)
        }
    }

    /// 伪代码 0x1006dfedc（L649-653）：编辑模式标签。
    private func editorLabel(_ mode: SliceStretchEditMode) -> String {
        switch mode {
        case .none: return "拖动切片边缘"
        case .top: return "调整上切片"
        case .bottom: return "调整下切片"
        case .left: return "调整左切片"
        case .right: return "调整右切片"
        }
    }

    /// 伪代码 0x1006dffc0（L1138-1147）：编辑模式。
    enum SliceStretchEditMode {
        case none
        case top
        case bottom
        case left
        case right
    }

    /// 伪代码 0x1006e027c（L987-1045）：切片选择几何。
    private func stretchSelectionGeometry(in size: CGSize) -> some View {
        Rectangle()
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .frame(width: size.width, height: size.height)
            .opacity(dragMode == .none ? 0 : 0.4)
    }

    /// 伪代码 0x1006e168c（L800-833）：画布手势。
    private func stretchCanvasGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragMode == .none {
                    dragMode = value.translation.height < 0 ? .top : .bottom
                }
            }
            .onEnded { _ in
                dragMode = .none
            }
    }
}
