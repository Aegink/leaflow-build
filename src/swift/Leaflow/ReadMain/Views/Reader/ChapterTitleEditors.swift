// 原路径: ReadMain/Views/Reader/ChapterTitleEditors.swift
// 证据:
//   - PGO: 51 个主函数（index/task_functions.csv T-303-03 / ChapterTitleEditors.swift），
//     地址：ChapterTitlePreviewView.body 0x1006a6168 L15-35（+closure 0x1006a645c/
//     0x1006b0b7c/0x1006a6568） / requestSnapshot 0x1006b0bc4 L37-58 /
//     ChapterNumberRegexEditorView.matchResult 0x1006a6a8c L75-86
//     （NSRegularExpression 确证） / body 0x1006a78d4 L93-164 /
//     ChapterTitleHTMLEditorView.body 0x1006acaa0 L176-232 / tokenButton
//     0x1006ada8c L234-245（Font.readerUI+Weight.medium/caption2 确证） /
//     ChapterTitleFontPickerView.body 0x1006aeb34 L257-281 / previewFont
//     0x1006af280 L300-303 / fontRow 0x1006ba330 L283-298
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ChapterTitleEditors.c
//   - 事实：编辑器四件 —— 预览（GeometryReader + requestSnapshot）、正则编辑
//     （matchResult 实时试配）、HTML 编辑（token 插入按钮）、字体选择（fontRow）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链: high（函数名/选择子确证）
//   - 深层布局: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 章节标题预览（快照渲染）。
struct ChapterTitlePreviewView: View {

    var config: ChapterTitleConfig
    var chapterIndex: Int

    @State private var snapshot: UIImage?

    var body: some View {
        // 伪代码 0x1006a6168（L15-35）+ closure #1（0x1006a645c）。
        GeometryReader { proxy in
            ZStack {
                if let snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(height: proxy.size.height)
        }
        .onAppear {
            requestSnapshot()
        }
        .onChange(of: config, initial: false) { _, _ in
            requestSnapshot()
        }
    }

    /// 伪代码 0x1006b0bc4（L37-58）：快照请求（ChapterTitleSnapshotService 域确证）。
    private func requestSnapshot() {
        ChapterTitleSnapshotService.shared.renderSnapshotAsync(
            template: config.templateHTML ?? "{{chapterName}}",
            title: "第一章 测试标题",
            chapterIndex: chapterIndex,
            width: 320,
            settings: ReadingSettings.load()) { image in
            snapshot = image
        }
    }
}

/// 章节号正则编辑器（实时试配确证）。
struct ChapterNumberRegexEditorView: View {

    @Binding var regex: String
    @State private var sampleTitle = "第一章 测试标题"

    /// 伪代码 0x1006a6a8c（L75-86）：实时试配（NSRegularExpression 确证）。
    /// 返回 (number, name) 两段。
    private var matchResult: (number: String, name: String)? {
        guard let pattern = try? NSRegularExpression(pattern: regex) else { return nil }
        let nsTitle = sampleTitle as NSString
        guard let match = pattern.firstMatch(
            in: sampleTitle, options: [],
            range: NSRange(location: 0, length: nsTitle.length)) else { return nil }
        let number = match.numberOfRanges > 1
            ? nsTitle.substring(with: match.range(at: 1)) : nsTitle.substring(with: match.range)
        let name = match.numberOfRanges > 2
            ? nsTitle.substring(with: match.range(at: 2)) : ""
        return (number, name)
    }

    var body: some View {
        // 伪代码 0x1006a78d4（L93-164）。
        Form {
            Section("示例标题") {
                TextField("示例", text: $sampleTitle)
            }
            Section("正则") {
                TextField("正则表达式", text: $regex)
                    .font(.system(.body, design: .monospaced))
                if let result = matchResult {
                    Label("章节号：\(result.number)", systemImage: "number")
                        .font(.caption)
                    if !result.name.isEmpty {
                        Label("章名：\(result.name)", systemImage: "text")
                            .font(.caption)
                    }
                } else {
                    Label("不匹配", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("章节号正则")
    }
}

/// 标题 HTML 编辑器（token 插入确证）。
struct ChapterTitleHTMLEditorView: View {

    @Binding var html: String

    var body: some View {
        // 伪代码 0x1006acaa0（L176-232）。
        VStack(alignment: .leading, spacing: 8) {
            // token 行（tokenButton ×N 确证）。
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tokenButton(title: "章节号", token: "{{chapterNumber}}")
                    tokenButton(title: "章名", token: "{{chapterName}}")
                    tokenButton(title: "宽", token: "{{width}}")
                    tokenButton(title: "高", token: "{{height}}")
                    tokenButton(title: "字体", token: "{{chapterNumberFont}}")
                }
                .padding(.horizontal)
            }
            TextEditor(text: $html)
                .font(.system(.body, design: .monospaced))
                .padding()
        }
        .navigationTitle("HTML")
    }

    /// 伪代码 0x1006ada8c（L234-245）：token 按钮
    ///（Font.readerUI + Weight.medium + caption2 确证）。
    private func tokenButton(title: String, token: String) -> some View {
        Button {
            html += token
        } label: {
            Text(title)
                .font(.readerUI(.caption, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

/// 标题字体选择器（fontRow/previewFont 确证）。
struct ChapterTitleFontPickerView: View {

    var fonts: [CustomFontService.FontInfo]
    @Binding var selectedFontName: String

    var body: some View {
        // 伪代码 0x1006aeb34（L257-281）。
        List {
            Section {
                fontRow(name: "System", displayName: "系统字体")
                ForEach(fonts) { font in
                    fontRow(name: font.name, displayName: font.displayName)
                }
            } header: {
                Text("字体")
            }
        }
    }

    /// 伪代码 0x1006ba330（L283-298）：字体行（previewFont 消费确证）。
    @ViewBuilder
    private func fontRow(name: String, displayName: String) -> some View {
        Button {
            selectedFontName = name
        } label: {
            HStack {
                Text(displayName)
                    .font(previewFont(for: name))
                Spacer()
                if selectedFontName == name {
                    Image(systemName: "checkmark")
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 伪代码 0x1006af280（L300-303）：预览字体（Font.body 回退确证）。
    private func previewFont(for name: String) -> Font {
        if name == "System" || name.isEmpty {
            return .body
        }
        return .custom(name, size: 16)
    }
}
