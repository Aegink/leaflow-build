// 原路径: ReadMain/Views/Reader/ReaderSettingsComponents.swift
// 证据:
//   - PGO: 56 个主函数（index/task_functions.csv T-301-08 / ReaderSettingsComponents.swift），
//     地址：ThemeButton.body 0x1007cd420 L16-58（+闭包族 0x1007cda68-ce2a0 L17-47，
//     impactOccurred/initWithStyle 确证）/ FontPickerView.body 0x1007ced70 L70-138
//     （+fontRow 闭包 0x1007cf540 L73-75 / Equatable 闭包 0x1007cf88c L79-103）；
//     骨架补充：ReaderBrowserSettingsView.body / SaveThemeSheet.body /
//     CustomFontService.FontInfo 行
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderSettingsComponents.c（2741 行）
//   - 关键调用：Color.accentColor|clear / Alignment.center|topTrailing /
//     UIImpactFeedbackGenerator(initWithStyle + impactOccurred 确证) /
//     UTType.font（字体导入确证）/ Font.custom（fontRow 确证）
//   - 事实：ThemeButton = 主题色卡按钮（角标对齐 topTrailing + 触感反馈）；
//     FontPickerView = 字体列表（fontRow：Font.custom 试渲染）+ 系统字体分组
//   状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - ThemeButton/FontPickerView 结构: high（builder opaque 描述确证）
//   - 行内布局细节: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UniformTypeIdentifiers

/// 主题色卡按钮（伪代码 0x1007cd420，L16-58）。
struct ThemeButton: View {
    var title: String
    var backgroundColor: Color
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            // 触感反馈（impactOccurred/initWithStyle 确证）。
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .frame(height: 64)
                    .overlay(alignment: .center) {
                        Text(title)
                            .appThemeText(.body)
                    }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 字体选择器（伪代码 0x1007ced70，L70-138）。
struct FontPickerView: View {
    var fonts: [CustomFontService.FontInfo]
    @Binding var selectedFontName: String
    var onImport: () -> Void

    var body: some View {
        List {
            Section("字体") {
                systemFontRow(name: "System", displayName: "系统字体")
                ForEach(fonts) { font in
                    fontRow(name: font.name, displayName: font.displayName)
                }
            }
            Section {
                Button {
                    onImport()
                } label: {
                    Label("导入字体文件", systemImage: "doc.badge.plus")
                }
                .tint(Color.accentColor)
            }
        }
    }

    /// 系统字体行。
    private func systemFontRow(name: String, displayName: String) -> some View {
        Button {
            selectedFontName = name
        } label: {
            HStack {
                Text(displayName).font(.system(size: 16))
                Spacer()
                if selectedFontName == name {
                    Image(systemName: "checkmark")
                }
            }
        }
        .foregroundStyle(.primary)
    }

    /// 伪代码 0x1007cf540（L73-75）：fontRow（Font.custom 试渲染确证）。
    private func fontRow(name: String, displayName: String) -> some View {
        Button {
            selectedFontName = name
        } label: {
            HStack {
                Text(displayName)
                    .font(.custom(name, size: 16))
                Spacer()
                if selectedFontName == name {
                    Image(systemName: "checkmark")
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

/// 浏览器设置分区（骨架签名 ReaderBrowserSettingsView.body）。
struct ReaderBrowserSettingsView: View {
    @Binding var presentation: ReadingSettings.ParagraphCommentBrowserPresentation

    var body: some View {
        Picker("评论区呈现", selection: $presentation) {
            Text("模态").tag(ReadingSettings.ParagraphCommentBrowserPresentation.modal)
            Text("内嵌").tag(ReadingSettings.ParagraphCommentBrowserPresentation.inline)
        }
        .pickerStyle(.segmented)
    }
}

/// 保存主题弹层（骨架签名 SaveThemeSheet.body）。
struct SaveThemeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String) -> Void
    @State private var themeName = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("主题名称", text: $themeName)
                Button("保存") {
                    onSave(themeName)
                    dismiss()
                }
            }
            .navigationTitle("保存主题")
        }
    }
}
