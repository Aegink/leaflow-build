// 原路径: ReadMain/Views/Shared/View+SystemOverlays.swift
// 证据:
//   - PGO: 0 主函数 / 3 条 pgo_only 记录（index/task_functions.csv T-101-06 /
//     View+SystemOverlays.swift）：View.immersiveSystemOverlays(hidden: Bool) -> some
//     ×3（ICF 共体实例）—— 无独立地址（视图修饰内联）
//   - CovMap: 0 插桩行（扩展声明无函数体）
//   - IDA: 无独立伪代码
//   - 事实：immersiveSystemOverlays —— 全屏沉浸式系统覆盖层控制
//     （hidden 驱动状态栏/home indicator 隐藏；调用域：阅读器全屏模式）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（签名确证；修饰链按语义还原）
// 还原: 2026-11-19

import SwiftUI

extension View {

    /// pgo_only（×3 共体实例）：沉浸式系统覆盖层。
    /// hidden = true → 隐藏状态栏/底部 home 指示。
    /// preferredScreenEdgesDeferringSystemGestures 属 UIViewController 域
    /// （非 SwiftUI 修饰）——覆盖意图由 persistentSystemOverlays 承载
    /// （wave-16）。
    func immersiveSystemOverlays(hidden: Bool) -> some View {
        self
            .statusBarHidden(hidden)
            .persistentSystemOverlays(hidden ? .hidden : .automatic)
    }
}
