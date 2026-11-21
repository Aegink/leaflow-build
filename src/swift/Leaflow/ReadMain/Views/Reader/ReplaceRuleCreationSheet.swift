// 原路径: ReadMain/Views/Reader/ReplaceRuleCreationSheet.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-12 / ReplaceRuleCreationSheet.swift），
//     地址：_replacement 变量初始化 0x100753628/0x100753868 L9 /
//     init(sourceText:onSave:) 0x10075364c/0x100753988 L12-16 /
//     body 0x1008b2ef0 L18-50（+toolbar 闭包 0x1008b32d8 L19-49 / Section 闭包
//     0x1008b3424 L20-34 / TextField 闭包 0x1008b356c L21-23 / appThemeText 闭包
//     0x1008b39c0 L29-33 / toolbar buildBlock 闭包 0x1008b3df8 L37-48 / Button 闭包
//     0x1008b3f0c L38-40 + MainActor 闭包 0x1008b41ac L39-39）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReplaceRuleCreationSheet.c（709 行）
//   - 事实：body = Form/Section(Text + TextField ×2) + toolbar（cancellationAction/
//     confirmationAction 按钮确证）；Button 闭包 whitespaces 裁剪（确证）；
//     TextField 闭包 Font.caption + String._fromSubstring（占位文本确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（builder opaque 描述确证）
// 还原: 2026-11-19

import SwiftUI

/// 阅读器内替换规则创建弹层。
struct ReplaceRuleCreationSheet: View {
    var sourceText: String
    var onSave: (String, String) -> Void
    @Environment(\\.dismiss) private var dismiss
    @State private var replacementText = ""

    init(sourceText: String, onSave: @escaping (String, String) -> Void) {
        self.sourceText = sourceText
        self.onSave = onSave
    }

    var body: some View {
        // 伪代码 0x1008b2ef0（L18-50）。
        NavigationStack {
            Form {
                Section("替换为") {
                    TextField("替换文本", text: $replacementText)
                        .font(.caption)
                }
                Section("原文") {
                    Text(sourceText)
                        .appThemeText(.body)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // whitespaces 裁剪确证（0x1008b3f0c，L38-40）。
                        let trimmed = replacementText.trimmingCharacters(in: .whitespaces)
                        onSave(sourceText, trimmed)
                        dismiss()
                    }
                    .disabled(replacementText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("创建替换规则")
        }
    }
}
