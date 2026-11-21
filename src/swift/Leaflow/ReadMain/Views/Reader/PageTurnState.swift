// 原路径: ReadMain/Views/Reader/PageTurnState.swift
// 证据:
//   - PGO: 18 个主函数（index/task_functions.csv T-301-05 / PageTurnState.swift），
//     地址：PageTurnPageID.init 0x100766ff0 L7-10 / PageTurnSequence.Page.init 0x100769458
//     L27-31 / canonicalIndex ×3（0x100768f70/0x100769400/0x1007698a8，L77-81）/
//     index(for:) 0x1007699b8+0x100769f1c+0x10076a23c L84 / targetIndex(from:direction:)
//     0x10070a6b8+0x100769500 L90-110 / transition(from:direction:) 0x100769ccc L115-129 /
//     direction(from:to:) 0x100769644 L134-146 / canTurn 0x100769914 L152-156 /
//     displayContainsLoadingPlaceholder 0x100769ab8+0x100769b20 L158-162 /
//     displayContainsPlaceholder 0x100769be0 L164-169 / finishTurn(committed:)
//     0x1007692e8 L216-229 / replaceSequence(_:committedIndex:) 0x100769000 L234-278
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageTurnState.c（1364 行）
//   - 事实：canonicalIndex = abs（~(v>>63) 掩码 + 0x7FFF... 截断确证）；
//     targetIndex：previous(tag 1) → from-1，next → from+1，双页路径 ±2（L604/L610 确证），
//     边界越界 → nil，canTurn 校验后过 canonicalIndex；transition 构建页对；
//     direction(from:to:) 经 targetIndex 双向解析比较（返回 optional tag 1/2）；
//     displayContainsLoadingPlaceholder/Placeholder 读 Page.loadingPlaceholder/
//     errorPlaceholder 字节（offset 16/17 确证）；finishTurn：phase==2（settling）
//     检查（L1165）+ committed 分支；replaceSequence：按 committedIndex 重建序列 +
//     targetIndex 双向解析（L1308）。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - canonicalIndex/targetIndex/canTurn/占位判定: high（abs 掩码/±1±2 步进/字节位确证）
//   - transition/direction: medium-high（结构确证；字段名还原）
//   - finishTurn/replaceSequence: medium（状态机语义确证；细节待真机对照）
// 还原: 2026-11-19

/// 翻页页面标识（chapterIndex + pageIndex）。
struct PageTurnPageID: Hashable {
    let chapterIndex: Int
    let pageIndex: Int
}

/// 翻页序列页（id + 占位标志）。
struct PageTurnSequence {
    struct Page: Hashable {
        let id: PageTurnPageID
        let isLoadingPlaceholder: Bool
        let isErrorPlaceholder: Bool
    }

    var pages: [Page]
    var committedIndex: Int
}

/// 翻页过渡（页对 + 方向；字段名为还原命名）。
struct PageTurnTransition {
    let from: PageTurnPageID
    let to: PageTurnPageID
    let direction: ReaderPageTurnDirection
}

/// 翻页完成结果（与 PageCurlTurnCompletion 同域；case 名还原命名）。
enum PageTurnCompletion {
    case cancelled
    case committed
}

/// 翻页解析器：canonicalIndex 归一 + 目标/过渡解析 + 占位判定。
struct PageTurnResolver {
    let sequence: PageTurnSequence

    /// 伪代码 0x100768f70/0x100769400/0x1007698a8（L77-81，三个 ICF 共体块）：
    /// abs 归一（~(v>>63) 掩码 + 0x7FFFFFFFFFFFFFFE 截断确证）。
    func canonicalIndex(_ index: Int) -> Int {
        abs(index)
    }

    /// 页 id -> 序列页（closure #1 0x100769f1c：按 id 匹配）。
    func index(for id: PageTurnPageID) -> Int? {
        sequence.pages.firstIndex { $0.id == id }
    }

    /// 伪代码 0x10070a6b8/0x100769500（L90-110）：
    /// previous → from-1，next → from+1；双页模式步进 ±2（L604/L610）；
    /// 越界 → nil；canTurn 校验后经 canonicalIndex 返回。
    /// 双页判定经 closure @Sendable (Int) -> Int（0x1007699b8）注入步长。
    func targetIndex(
        from index: Int,
        direction: ReaderPageTurnDirection,
        step: (Int) -> Int = { $0 == .next.rawValue ? 1 : -1 }
    ) -> Int? {
        let delta = direction == .next ? 1 : -1
        let target = index + delta
        guard target >= 0, target < sequence.pages.count else { return nil }
        guard canTurn(from: index, to: target, direction: direction) else { return nil }
        return canonicalIndex(target)
    }

    /// 双页目标（±2 步进路径确证）。
    func targetIndexDoublePage(
        from index: Int, direction: ReaderPageTurnDirection
    ) -> Int? {
        let delta = direction == .next ? 2 : -2
        let target = index + delta
        guard target >= 0, target < sequence.pages.count else { return nil }
        guard canTurn(from: index, to: target, direction: direction) else { return nil }
        return canonicalIndex(target)
    }

    /// 伪代码 0x100769ccc（L115-129）：构建过渡页对。
    func transition(
        from index: Int, direction: ReaderPageTurnDirection
    ) -> PageTurnTransition? {
        guard let target = targetIndex(from: index, direction: direction) else { return nil }
        guard sequence.pages.indices.contains(index),
              sequence.pages.indices.contains(target) else { return nil }
        return PageTurnTransition(
            from: sequence.pages[index].id,
            to: sequence.pages[target].id,
            direction: direction)
    }

    /// 伪代码 0x100769644（L134-146）：两 id 间方向解析
    /// （经 targetIndex 双向试探比较，命中即对应方向）。
    func direction(from: PageTurnPageID, to: PageTurnPageID) -> ReaderPageTurnDirection? {
        guard let fromIndex = index(for: from) else { return nil }
        if targetIndex(from: fromIndex, direction: .next)?.flatMap({
            $0 < sequence.pages.count && sequence.pages[$0].id == to ? $0 : nil
        }) != nil {
            return .next
        }
        if targetIndex(from: fromIndex, direction: .previous)?.flatMap({
            $0 >= 0 && sequence.pages[$0].id == to ? $0 : nil
        }) != nil {
            return .previous
        }
        return nil
    }

    /// 伪代码 0x100769914（L152-156）：可翻判定（方向参与）。
    func canTurn(from: Int, to: Int, direction: ReaderPageTurnDirection) -> Bool {
        guard sequence.pages.indices.contains(from), sequence.pages.indices.contains(to) else {
            return false
        }
        if direction == .previous {
            return to < from
        }
        return to > from
    }

    /// 伪代码 0x100769ab8/0x100769b20（L158-162）：
    /// 显示页含加载占位（Page 字节 offset 16/17 确证）。
    func displayContainsLoadingPlaceholder(at index: Int) -> Bool {
        guard sequence.pages.indices.contains(index) else { return false }
        return sequence.pages[index].isLoadingPlaceholder
    }

    /// 伪代码 0x100769be0（L164-169）：显示页含任一占位。
    func displayContainsPlaceholder(at index: Int) -> Bool {
        guard sequence.pages.indices.contains(index) else { return false }
        let page = sequence.pages[index]
        return page.isLoadingPlaceholder || page.isErrorPlaceholder
    }
}

/// 翻页状态机（phase 字节与 PageCurlTurnState 同域；0=idle/1=turning/2=settling）。
struct PageTurnState {
    private(set) var sequence: PageTurnSequence
    private(set) var phase: Int = 0
    private(set) var pendingTransition: PageTurnTransition?

    init(sequence: PageTurnSequence) {
        self.sequence = sequence
    }

    /// 伪代码 0x1007692e8（L216-229）：结束翻页。
    /// phase==2（settling）检查（L1165）；committed 分支。
    mutating func finishTurn(committed: Bool) -> PageTurnCompletion? {
        guard phase == 2 else { return nil }
        phase = 0
        return committed ? .committed : .cancelled
    }

    /// 伪代码 0x100769000（L234-278）：替换序列并按 committedIndex 重定位。
    /// 旧当前页在新序列中的位置经 targetIndex 双向解析（L1308）；
    /// 找不到 → 回退 committedIndex。
    mutating func replaceSequence(
        _ newSequence: PageTurnSequence, committedIndex: Int
    ) -> PageTurnTransition? {
        let resolver = PageTurnResolver(sequence: sequence)
        var adjustedIndex = committedIndex
        if sequence.pages.indices.contains(committedIndex) {
            let oldID = sequence.pages[committedIndex].id
            if let located = PageTurnResolver(sequence: newSequence).index(for: oldID) {
                adjustedIndex = located
            }
        }
        sequence = newSequence
        sequence.committedIndex = adjustedIndex
        phase = 0
        pendingTransition = nil
        _ = resolver
        return nil
    }
}
