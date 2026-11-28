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
import UIKit

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
    @Binding var selectedFontName: String
    var fontService: CustomFontService = .shared
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var searchText = ""

    private var filteredCustomFonts: [CustomFontService.FontInfo] {
        guard !searchText.isEmpty else { return fontService.fonts }
        return fontService.fonts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredSystemFamilies: [String] {
        let families = UIFont.familyNames.sorted()
        guard !searchText.isEmpty else { return families }
        return families.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section("系统字体") {
                systemFontRow(name: "System", displayName: "系统字体")
                ForEach(filteredSystemFamilies, id: \.self) { family in
                    systemFontRow(name: family, displayName: family)
                }
            }
            Section("自定义字体") {
                if filteredCustomFonts.isEmpty {
                    Text(searchText.isEmpty ? "暂无自定义字体" : "无匹配字体")
                        .appThemeText(.caption, opacity: 0.55)
                }
                ForEach(filteredCustomFonts) { font in
                    fontRow(name: font.name, displayName: font.displayName)
                }
            }
            Section {
                Button {
                    showFileImporter = true
                } label: {
                    Label("导入字体文件", systemImage: "doc.badge.plus")
                }
                .tint(Color.accentColor)
                .accessibilityIdentifier("reader-font-import")
            }
        }
        .searchable(text: $searchText, prompt: "搜索字体")
        .navigationTitle("选择字体")
        .sheet(isPresented: $showFileImporter) {
            CopiedFilePicker(allowedContentTypes: [.font], allowsMultipleSelection: false) { urls in
                showFileImporter = false
                guard let url = urls.first else { return }
                switch fontService.importFont(from: url) {
                case .success(let font): selectedFontName = font.name; dismiss()
                case .failure(let error): importError = error.localizedDescription
                }
            }
        }
        .alert("字体导入失败", isPresented: Binding(get: { importError != nil },
            set: { if !$0 { importError = nil } })) {
                Button("确定", role: .cancel) { importError = nil }
            } message: { Text(importError ?? "") }
    }

    /// 系统字体行。
    private func systemFontRow(name: String, displayName: String) -> some View {
        Button {
            selectedFontName = name
            dismiss()
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
        .accessibilityIdentifier("reader-font-" + name)
    }

    /// 伪代码 0x1007cf540（L73-75）：fontRow（Font.custom 试渲染确证）。
    private func fontRow(name: String, displayName: String) -> some View {
        Button {
            selectedFontName = name
            dismiss()
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
        .accessibilityIdentifier("reader-font-" + name)
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
