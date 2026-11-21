// 原路径: ReadMain/Views/Source/SourceManageViewModifiers.swift
// 证据:
//   - PGO: 22 条记录（index/task_functions.csv T-401-07 /
//     SourceManageViewModifiers.swift；3 个伪代码块 + 19 pgo_only）。
//     关键地址：SourceManageSearchableChromeModifier.body 0x100ced174
//     L11-28 / SourceManagePresentationsModifier.body 0x100cedda8 L41-59 /
//     SourceManageLifecycleModifier.body 0x100ceece4 L70-80
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/
//     SourceManageViewModifiers.c（1044 行）
//   - 字符串确证（位模式/指针）："重命名分组"（L308）/"新分组名"（L462）/
//     "操作不可撤销。" @ptr（L590，确认弹窗域确证）
//   - 事实：三扩展（View.sourceManageChrome/sourceManagePresentations/
//     sourceManageLifecycle，pgo_only）+ 三修饰体（chrome = searchable 导航
//     壳 / presentations = activeSheet 分发 / lifecycle = onAppear 刷新域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 修饰器结构: high（块体 + 域串确证）
//   - sheet 分发细节: medium（结构性还原，待真机对照）
// 还原: 2026-11-20

import SwiftUI

/// 管理页检索壳（0x100ced174 L11-28）。
struct SourceManageSearchableChromeModifier: ViewModifier {
    let searchText: Binding<String>

    func body(content: Content) -> some View {
        content
            .searchable(text: searchText, prompt: "搜索配置")
            .navigationBarTitleDisplayMode(.large)
    }
}

/// 管理页弹层分发（0x100cedda8 L41-59）。
struct SourceManagePresentationsModifier<Sheet: View>: ViewModifier {
    let activeSheet: Binding<SourceManageSheet?>
    let content: (SourceManageSheet) -> Sheet

    func body(content: Content) -> some View {
        // "重命名分组"/"新分组名"/"操作不可撤销。" 域确证（确认弹窗族）。
        content
            .sheet(item: activeSheet) { sheet in
                self.content(sheet)
            }
    }
}

/// 管理页生命周期（0x100ceece4 L70-80）。
struct SourceManageLifecycleModifier: ViewModifier {
    let searchText: String
    let filterOption: String
    let refresh: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: searchText) { _ in
                refresh()
            }
            .onChange(of: filterOption) { _ in
                refresh()
            }
            .onAppear {
                refresh()
            }
    }
}

extension View {

    /// sourceManageChrome（pgo_only 签名确证）。
    func sourceManageChrome(
        searchText: Binding<String>
    ) -> some View {
        modifier(SourceManageSearchableChromeModifier(searchText: searchText))
    }

    /// sourceManagePresentations（pgo_only 签名确证）。
    func sourceManagePresentations<Sheet: View>(
        activeSheet: Binding<SourceManageSheet?>,
        @ViewBuilder content: @escaping (SourceManageSheet) -> Sheet
    ) -> some View {
        modifier(
            SourceManagePresentationsModifier(
                activeSheet: activeSheet, content: content))
    }

    /// sourceManageLifecycle（pgo_only 签名确证）。
    func sourceManageLifecycle(
        searchText: String, filterOption: String, refresh: @escaping () -> Void
    ) -> some View {
        modifier(
            SourceManageLifecycleModifier(
                searchText: searchText, filterOption: filterOption,
                refresh: refresh))
    }
}
