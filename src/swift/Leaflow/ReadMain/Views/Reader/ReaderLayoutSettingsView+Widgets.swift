// 原路径: ReadMain/Views/Reader/ReaderLayoutSettingsView.swift
// 类型表10667与0x1008b48e0：页面内编辑、选中/新增面板、百分比坐标与readerEnterWidgetEditMode。
import SwiftUI

extension Notification.Name {
    static let readerEnterWidgetEditMode = Notification.Name("readerEnterWidgetEditMode")
}

struct ReaderWidgetEditingModifier: ViewModifier {
    @Binding var settings: ReadingSettings
    let bookName: String
    let chapterTitle: String
    @State private var isEditing = false

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isEditing)
            .overlay {
                if isEditing {
                    WidgetEditOverlay(settings: $settings, bookName: bookName, chapterTitle: chapterTitle) {
                        settings.save()
                        settings.typographyRevision += 1
                        isEditing = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .readerEnterWidgetEditMode)) { _ in isEditing = true }
    }
}

struct WidgetEditOverlay: View {
    @Binding var settings: ReadingSettings
    let bookName: String
    let chapterTitle: String
    let onDismiss: () -> Void
    @State private var selectedWidgetID: UUID?
    @State private var showEditPanel = false
    @State private var isFirstPage = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.clear.contentShape(Rectangle())
                ForEach(settings.layoutWidgets.filter { $0.pageScope.shouldShow(isFirstPage: isFirstPage) }) { widget in
                    Text(previewText(widget))
                        .font(.system(size: max(1, widget.fontSize)))
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedWidgetID == widget.id ? Color.accentColor : Color.secondary))
                        .position(x: geometry.size.width * widget.xPercent, y: geometry.size.height * widget.yPercent)
                        .accessibilityIdentifier("reader-widget-" + widget.id.uuidString)
                        .onTapGesture { selectedWidgetID = widget.id; showEditPanel = true }
                        .gesture(DragGesture(coordinateSpace: .named("widget-canvas"))
                            .onChanged { gesture in
                                guard let index = settings.layoutWidgets.firstIndex(where: { $0.id == widget.id }),
                                      geometry.size.width > 0, geometry.size.height > 0 else { return }
                                selectedWidgetID = widget.id
                                settings.layoutWidgets[index].xPercent = min(1, max(0, gesture.location.x / geometry.size.width))
                                settings.layoutWidgets[index].yPercent = min(1, max(0, gesture.location.y / geometry.size.height))
                            }
                            .onEnded { _ in settings.save() })
                }
                HStack {
                    Button("添加组件") {
                        let widget = LayoutWidget(item: "customText", xPercent: 0.5, yPercent: 0.9,
                            customText: "自定义文本", textAlignment: .center)
                        settings.layoutWidgets.append(widget)
                        selectedWidgetID = widget.id
                        showEditPanel = true
                    }
                    .accessibilityIdentifier("reader-widget-add")
                    Spacer()
                    Toggle("章节首页", isOn: $isFirstPage).fixedSize()
                    Button("完成", action: onDismiss).accessibilityIdentifier("reader-widget-done")
                }
                .padding()
                .background(.regularMaterial)
            }
            .coordinateSpace(name: "widget-canvas")
        }
        .sheet(isPresented: $showEditPanel, onDismiss: { settings.save() }) {
            if let id = selectedWidgetID, let index = settings.layoutWidgets.firstIndex(where: { $0.id == id }) {
                WidgetEditPanel(widget: $settings.layoutWidgets[index]) {
                    settings.layoutWidgets.removeAll { $0.id == id }
                    showEditPanel = false
                }
            }
        }
    }

    private func previewText(_ widget: LayoutWidget) -> String {
        switch widget.item {
        case "customText": return widget.customText?.isEmpty == false ? widget.customText! : "自定义文本"
        case "bookName": return bookName
        case "chapterTitle", "chapterTitleShort": return chapterTitle
        case "currentTime": return ReaderWidgetDisplayItem.dateFormatter.string(from: Date())
        default: return ReaderDisplayItem(rawValue: widget.type)?.displayName ?? widget.item
        }
    }
}

private struct WidgetEditPanel: View {
    @Binding var widget: LayoutWidget
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    DisplayItemGrid(selection: Binding(
                        get: { ReaderDisplayItem(rawValue: widget.type) ?? .customText },
                        set: { item in
                            widget.item = ["time": "currentTime", "progress": "pageProgress"][item.rawValue] ?? item.rawValue
                        }), groups: [("内容", [.customText, .bookName, .chapterTitle]), ("阅读", [.time, .progress])])
                    if widget.item == "customText" {
                        TextField("自定义文本", text: Binding(get: { widget.customText ?? "" }, set: { widget.customText = $0 }))
                            .accessibilityIdentifier("reader-widget-custom-text")
                    }
                    Picker("显示页面", selection: $widget.pageScope) {
                        Text("所有页").tag(WidgetPageScope.allPages)
                        Text("章节首页").tag(WidgetPageScope.firstPageOnly)
                        Text("普通页").tag(WidgetPageScope.normalPageOnly)
                    }
                }
                Section("位置与外观") {
                    slider("水平位置", value: $widget.xPercent, range: 0...1)
                    slider("垂直位置", value: $widget.yPercent, range: 0...1)
                    slider("字号", value: $widget.fontSize, range: 8...32)
                    slider("不透明度", value: $widget.opacity, range: 0...1)
                    Picker("对齐", selection: $widget.textAlignment) {
                        Text("左对齐").tag(WidgetTextAlignment.leading)
                        Text("居中").tag(WidgetTextAlignment.center)
                        Text("右对齐").tag(WidgetTextAlignment.trailing)
                    }
                    TextField("颜色（HEX，可留空）", text: Binding(get: { widget.customColorHex ?? "" }, set: { widget.customColorHex = $0.isEmpty ? nil : $0 }))
                }
                Button("删除组件", role: .destructive, action: onDelete)
            }
            .navigationTitle("编辑组件")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.accessibilityIdentifier("reader-widget-panel-done") } }
        }
    }

    private func slider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Slider(value: value, in: range).accessibilityIdentifier("reader-widget-" + title)
        }
    }
}
