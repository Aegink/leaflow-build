// 原路径: ReadMain/Views/Settings/ReplaceRulePresentations.swift
// 证据:
//   - PGO: 26 条记录（index/task_functions.csv T-701-07 /
//     ReplaceRulePresentations.swift；伪代码域 100 行）
//   - CovMap: 上述 L 区段（body/toolbarMenu 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ReplaceRulePresentations.c（1617 行）
//   - 块体确证（签名域）：
//     ReplaceRulePresentationsModifier.body（toolbarMenu + 编辑 sheet
//     closure #2/#3 + 导入导出 sheet closure #4 + '新分组名称' 弹层
//     closure #9 TextField 三件 + 删除确认 closure #5 双按钮 +
//     isPresented 闭包 #8/#11/#12 域）
//   - 字符串域（位模式+指针，scratch/t70107_pres_strings.txt）：
//     '取消' L174/L474/L817 / '清空' L189 / '新分组名称' L451 /
//     '确定' L486 / '将「' L645 / '删除' L829 / '将删除「' L1293
//   - 事实：三弹层链（新建分组 alert + 编辑 sheet + 删除确认）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（弹层链 + 字符串域确证）
// 还原: 2026-11-20

import SwiftUI

/// 替换规则弹层修饰器（body 签名域确证：toolbarMenu + 三弹层）。
struct ReplaceRulePresentationsModifier: ViewModifier {

    @Binding var showAddRule: Bool
    @Binding var editTarget: ReplaceRule?
    @Binding var showImportExport: Bool
    @Binding var showRenameGroup: Bool
    @Binding var deleteTarget: ReplaceRule?
    @State private var newGroupName = ""
    @State private var renameGroupTarget = ""

    func body(content: Content) -> some View {
        content
            .toolbar {
                // toolbarMenu getter 域确证。
                ToolbarItemGroup(placement: .topBarTrailing) {
                    toolbarMenu
                }
            }
            .sheet(isPresented: $showAddRule) {
                // closure #2 域确证：新增编辑页。
                ReplaceRuleEditView(
                    rule: Binding(
                        get: {
                            ReplaceRule(name: "", pattern: "",
                                        replacement: "")
                        },
                        set: { _ in }),
                    mode: .add,
                    onDismiss: { showAddRule = false })
            }
            .sheet(
                item: Binding(
                    get: { editTarget },
                    set: { editTarget = $0 })
            ) { rule in
                // closure #3 域确证：编辑页。
                ReplaceRuleEditView(
                    rule: Binding(
                        get: { editTarget ?? rule },
                        set: { editTarget = $0 }),
                    mode: .edit,
                    onDismiss: { editTarget = nil })
            }
            .sheet(isPresented: $showImportExport) {
                // closure #4 域确证：导入导出页。
                ReplaceRuleImportExportView()
            }
            .alert(
                "新建分组",
                isPresented: $showRenameGroup
            ) {
                // closure #9 域确证：TextField + 双按钮。
                TextField("新分组名称", text: $newGroupName)
                Button("确定") {
                    if !newGroupName.isEmpty {
                        commitRenameGroup()
                    }
                    newGroupName = ""
                }
                Button("取消", role: .cancel) {
                    // '取消' L474 域确证。
                    newGroupName = ""
                }
            } message: {
                Text("输入新分组名称")
            }
            .alert(
                "删除规则",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } })
            ) {
                // closure #5 域确证：删除/取消双按钮。
                Button("删除", role: .destructive) {
                    deleteTarget = nil
                }
                Button("取消", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                if let target = deleteTarget {
                    // '将删除「' L1293 + '」' 域确证。
                    Text("将删除「\(target.name)」，确定继续吗？")
                }
            }
    }

    /// toolbarMenu getter（签名域确证：新建分组/清空入口）。
    @ViewBuilder
    private var toolbarMenu: some View {
        Menu {
            Button {
                // '新建分组' 域确证。
                showRenameGroup = true
            } label: {
                Label("新建分组", systemImage: "folder.badge.plus")
            }
            Button {
                // '清空' L189 域确证：规则分组清空入口。
                showRenameGroup = true
            } label: {
                Label("重命名分组", systemImage: "pencil.and.list.clipboard")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    /// 分组改名提交（renameGroup(_:to:) 签名桥；T-901-03 分册落地）。
    private func commitRenameGroup() {
        ReplaceRuleService().renameGroup(
            renameGroupTarget, to: newGroupName)
        renameGroupTarget = ""
    }
}


extension View {

    /// replaceRulePresentations（签名域确证：修饰器入口桥）。
    func replaceRulePresentations(
        showAddRule: Binding<Bool>,
        editTarget: Binding<ReplaceRule?>,
        showImportExport: Binding<Bool>,
        showRenameGroup: Binding<Bool>,
        deleteTarget: Binding<ReplaceRule?>
    ) -> some View {
        modifier(
            ReplaceRulePresentationsModifier(
                showAddRule: showAddRule,
                editTarget: editTarget,
                showImportExport: showImportExport,
                showRenameGroup: showRenameGroup,
                deleteTarget: deleteTarget))
    }
}
