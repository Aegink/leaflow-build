// 原路径: ReadMain/Views/Reader/PageTransitionStyle.swift
// 证据:
//   - PGO: 2 个主函数（index/task_functions.csv T-301-04 / PageTransitionStyle.swift），
//     地址：layerOrder(for:) 0x100768a5c L15-22 / visualState(direction:progress:)
//     0x100768acc L27-54；另有 pgo_only：usesTransparentPageBackground/settlesImmediately
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageTransitionStyle.c（67 行）
//   - 事实：layerOrder 三分支返回 0/1/2（direction tag==1 -> 2；a1==1 -> 0；否则 1）；
//     visualState 打包两字段返回（0|0 / 1|0 / 0|256，0x100=第二字段置位）
//   - 注：本类型此前被误置于 ReaderPaginator.swift（T-302 提交），本次按 PGO 归属迁回
//     本文件并修正签名（layerOrder -> PageTransitionLayerOrder、visualState ->
//     PageTransitionVisualState），原位置已删除重复声明
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（分支结构确证；case 名与字段名为还原命名，待真机对照）
// 还原: 2026-11-19

/// 翻页过渡样式。
enum PageTransitionStyle {
    case slide
    case curl
    case none

    /// 层级顺序（伪代码 0x100768a5c，L15-22）。
    /// direction 的 tag==1（previous）→ 2；否则样式 tag==1（curl）→ 0；其余 → 1。
    func layerOrder(for direction: ReaderPageTurnDirection) -> PageTransitionLayerOrder {
        switch self {
        case .curl:
            return direction == .previous ? .backdrop : .incoming
        case .slide:
            return .outgoing
        case .none:
            return .incoming
        }
    }

    /// 视觉状态（伪代码 0x100768acc，L27-54）。
    /// 打包返回两字段：direction tag==1 → (0, 0)；样式 tag==1 → (1, 0)；
    /// 其余 → (0, 256)（第二字段 0x100 置位）。
    /// 字段语义（位移量/透明背景标志）为还原命名，待真机对照。
    func visualState(
        direction: ReaderPageTurnDirection, progress: Double
    ) -> PageTransitionVisualState {
        switch self {
        case .curl:
            return PageTransitionVisualState(offsetField: 0, flagField: 0)
        case .slide:
            return PageTransitionVisualState(offsetField: 1, flagField: 0)
        case .none:
            return PageTransitionVisualState(offsetField: 0, flagField: 256)
        }
    }

    /// 透明页背景（pgo_only getter，签名确证）。
    var usesTransparentPageBackground: Bool {
        self == .curl
    }

    /// 立即落定（pgo_only getter，签名确证）。
    var settlesImmediately: Bool {
        self == .none
    }
}

/// 层级顺序（PGO：PageTransitionLayerOrder，三分支 0/1/2）。
enum PageTransitionLayerOrder: Int {
    case incoming = 0
    case outgoing = 1
    case backdrop = 2
}

/// 视觉状态（PGO：PageTransitionVisualState，打包两字段）。
/// 字段语义为还原命名（位移档位 + 0x100 标志位），待真机对照。
struct PageTransitionVisualState {
    var offsetField: Int
    var flagField: Int
}
