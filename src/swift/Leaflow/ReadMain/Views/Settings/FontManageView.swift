// 原路径: ReadMain/Views/Settings/FontManageView.swift
// 证据:
//   - PGO: 54 条记录（index/task_functions.csv T-701-06 /
//     FontManageView.swift；伪代码域 120 行）
//   - CovMap: 上述 L 区段（body/fontRow/confirmDelete/handleImport 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     FontManageView.c（1829 行）
//   - 块体确证（签名域）：
//     body getter / fontRow(_: FontInfo) / confirmDelete(_: FontInfo) /
//     handleImport(_: Result<FontInfo, FontImportError>) /
//     fontDetailText(_: FontInfo)
//   - 字符串域（位模式，scratch/t70106_font_strings.txt）：
//     '取消' L717 / '删除' L729/L1504 / '字体「' L941 /
//     '」吗？' L990
//   - 事实：字体列表 + 文件导入 + 删除确认（'字体「...」吗？' 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（五签名域 + 字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// 字体管理页（body/fontRow/confirmDelete 签名域确证）。
struct FontManageView: View {

    @State private var fonts: [CustomFontService.FontInfo] = []
    @State private var deleteTarget: CustomFontService.FontInfo?
    @State private var importFailed = false

    var body: some View {
        List {
            Section {
                ForEach(fonts) { font in
                    fontRow(font)
                }
                .onDelete { offsets in
                    // '删除' L1504 域确证：滑动删除。
                    for offset in offsets {
                        let font = fonts[offset]
                        CustomFontService.shared.deleteFont(font)
                    }
                    reload()
                }
            } header: {
                Text("自定义字体")
            } footer: {
                Text("支持 ttf / otf / ttc / woff / woff2")
            }
        }
        .navigationTitle("字体管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let fileURL = importFontFileURL {
                    Button {
                        let result = CustomFontService.shared
                            .importFontFromLocalFile(fileURL)
                        handleImport(result)
                    } label: {
                        Text("导入")
                    }
                }
            }
        }
        .onAppear {
            reload()
        }
        .alert(
            "删除字体",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } })
        ) {
            Button("删除", role: .destructive) {
                // confirmDelete 签名域确证。
                if let target = deleteTarget {
                    confirmDelete(target)
                }
            }
            Button("取消", role: .cancel) {
                // '取消' L717 域确证。
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                // '字体「' L941 + '」吗？' L990 域确证。
                Text("确定要删除字体「\(target.managementDisplayName)」吗？")
            }
        }
        .alert(
            "导入失败",
            isPresented: $importFailed
        ) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("字体导入失败，请检查文件格式")
        }
    }

    /// fontRow(_: FontInfo)（签名域确证）。
    @ViewBuilder
    private func fontRow(_ font: CustomFontService.FontInfo) -> some View {
        Button {
            deleteTarget = font
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(font.managementDisplayName)
                        .foregroundStyle(.primary)
                    Text(fontDetailText(font))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// fontDetailText(_: FontInfo)（签名域确证：原始文件名 + 家族名）。
    private func fontDetailText(_ font: CustomFontService.FontInfo)
        -> String {
        var parts: [String] = []
        if let family = font.familyName {
            parts.append("家族：\(family)")
        }
        parts.append("文件：\(font.importDisplayFileName)")
        return parts.joined(separator: " · ")
    }

    /// confirmDelete(_: FontInfo)（签名域确证）。
    private func confirmDelete(_ font: CustomFontService.FontInfo) {
        CustomFontService.shared.deleteFont(font)
        deleteTarget = nil
        reload()
    }

    /// handleImport(_: Result<FontInfo, FontImportError>)
    /// （签名域确证：成功重载 + 失败告警）。
    private func handleImport(
        _ result: Result<CustomFontService.FontInfo,
            CustomFontService.FontImportError>
    ) {
        switch result {
        case .success:
            reload()
        case .failure:
            importFailed = true
        }
    }

    private var importFontFileURL: URL? {
        nil
    }

    private func reload() {
        fonts = CustomFontService.shared.reloadPersistedFonts(
            pruneMissingFiles: true)
    }
}
