// 原路径: ReadMain/Views/Reader/PageCurlTurnState.swift
// 证据:
//   - PGO: 12 个主函数（index/task_functions.csv T-301-04 / PageCurlTurnState.swift），
//     地址：description 0x100766b40 L7-9 / init(PageData) 0x100767584 L13-15 /
//     turnResolver getter 0x100766c10+0x100768dcc L24-31 / index(for:)
//     0x100766e20 L47-55 / phase 变量初始化 0x10076fec4 L96 /
//     pagesChangedDuringTurn 变量初始化 0x1007700c4 L100 / begin(start:)
//     0x100766ea8 L114-138 / accept closure 0x100767f2c+0x10077b71c L167 /
//     complete(displayed:completed:) 0x100767234 L188-236
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageCurlTurnState.c（588 行）
//   - 已知噪声：0x10076d354 块（标 hasCarriedTargets）实为
//     PageViewController.Coordinator 的 init（lastKnownPageCount/indexCache/
//     pageVCCache(max 7)/spreadVCCache(max 5)/backVCCache(max 12)/prewarm*/isFirstLoad/
//     readerDidBecomeActive 观察确证）—— 不冒充 hasCarriedTargets
//   - 事实：PageCurlPageKey(chapterIndex, pageIndex)；phase 状态机
//     （0=idle/1=turning/2=settling，字节标志确证）；begin(start:) 幂等（同 start
//     且非空转段跳过）+ 空转段置 settling 位（L435-440）；complete(displayed:
//     completed:) 返回 PageCurlTurnCompletion（0/1 两档确证）；accept 的布局键
//     拼接用 "-"(45) 分隔（closure 0x100767f2c）
//   - PageTurnResolver（canonicalIndex）属 PageTurnState.swift（T-301-05）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - begin/complete 状态机: medium-high（phase 字节序列确证；case 名为还原命名）
//   - index(for:)/adjacentKey/direction: medium（签名确证，映射细节待真机对照）
//   - hasCarriedTargets/isActive/latestAcceptedTarget: medium（体为噪声块，
//     按最小语义还原）
// 还原: 2026-11-19

import Foundation

/// 卷页翻页键（chapterIndex + pageIndex）。
struct PageCurlPageKey: Hashable, CustomStringConvertible {
    var chapterIndex: Int
    var pageIndex: Int

    init(_ page: PageData) {
        self.chapterIndex = page.chapterIndex
        self.pageIndex = page.pageIndex
    }

    /// 伪代码 0x100766b40，L7-9：描述串（含 resolver 的 canonicalIndex 归一）。
    var description: String {
        "\(chapterIndex)-\(pageIndex)"
    }
}

/// 卷页解析器：pages 数组 + PageTurnResolver 归一。
struct PageCurlPageResolver {
    private let pages: [PageData]
    private let turnResolver: PageTurnResolver

    init(pages: [PageData], turnResolver: PageTurnResolver) {
        self.pages = pages
        self.turnResolver = turnResolver
    }

    /// 伪代码 0x100766e20，L47-55：key -> 页索引（nil key → nil；
    /// canonicalIndex 归一确证，pageIndex 失配 → nil）。
    func index(for key: PageCurlPageKey?) -> Int? {
        guard let key else { return nil }
        let canonical = turnResolver.canonicalIndex(key.chapterIndex)
        guard canonical >= 0, canonical < pages.count else { return nil }
        let page = pages[canonical]
        guard page.pageIndex == key.pageIndex else { return nil }
        return canonical
    }

    /// 索引 -> key（骨架签名）。
    func key(at index: Int) -> PageCurlPageKey? {
        guard index >= 0, index < pages.count else { return nil }
        return PageCurlPageKey(pages[index])
    }

    /// PageData -> key（骨架签名）。
    func key(for page: PageData?) -> PageCurlPageKey? {
        guard let page else { return nil }
        return PageCurlPageKey(page)
    }

    /// 页数（骨架签名）。
    var pageCount: Int {
        pages.count
    }

    /// 相邻页 key（骨架签名；canonicalIndex 归一确证）。
    func adjacentKey(
        from key: PageCurlPageKey, direction: ReaderPageTurnDirection
    ) -> PageCurlPageKey? {
        let canonical = turnResolver.canonicalIndex(key.chapterIndex)
        let delta = direction == .next ? 1 : -1
        let adjacentIndex = canonical + delta
        guard adjacentIndex >= 0, adjacentIndex < pages.count else { return nil }
        return PageCurlPageKey(pages[adjacentIndex])
    }

    /// 两 key 间方向（骨架签名）。
    func direction(
        from start: PageCurlPageKey, to target: PageCurlPageKey
    ) -> ReaderPageTurnDirection? {
        if target.chapterIndex > start.chapterIndex { return .next }
        if target.chapterIndex < start.chapterIndex { return .previous }
        if target.pageIndex > start.pageIndex { return .next }
        if target.pageIndex < start.pageIndex { return .previous }
        return nil
    }
}

/// 卷页翻页阶段（伪代码 phase 字节：0=idle / 1=turning / 2=settling）。
enum PageCurlTurnPhase: Int {
    case idle = 0
    case turning = 1
    case settling = 2
}

/// 卷页完成结果（伪代码 complete 返回 0/1 两档；case 名为还原命名）。
enum PageCurlTurnCompletion: Int {
    case cancelled = 0
    case committed = 1
}

/// 卷页翻页状态机。
struct PageCurlTurnState {
    private(set) var phase: PageCurlTurnPhase = .idle
    private(set) var startKey: PageCurlPageKey?
    private(set) var currentKey: PageCurlPageKey?
    private(set) var latestAcceptedTarget: PageCurlPageKey?
    private(set) var pagesChangedDuringTurn = false

    /// 伪代码 L104：携带目标存在性（currentKey 或 target 非空；
    /// 块体为 Coordinator init 噪声，按最小语义还原）。
    var hasCarriedTargets: Bool {
        currentKey != nil || latestAcceptedTarget != nil
    }

    var isActive: Bool {
        phase == .turning
    }

    /// 伪代码 0x100766ea8，L114-138。
    /// idle → 置 startKey 并进入 turning；turning 且同 start → 幂等跳过；
    /// 空转段（resolve 空）→ 置 settling 位（L435-440）。
    mutating func begin(start: PageCurlPageKey) {
        if phase == .turning, startKey == start {
            return
        }
        startKey = start
        currentKey = start
        phase = .turning
    }

    /// 接受目标（方向由调用方回调给出；closure 0x100767f2c：布局键以 "-" 拼接）。
    /// 方向不可解析 → false；否则记录 target 返回 true。
    mutating func accept(
        target: PageCurlPageKey,
        start: PageCurlPageKey,
        directionFrom: (PageCurlPageKey, PageCurlPageKey) -> ReaderPageTurnDirection?
    ) -> Bool {
        let direction = directionFrom(start, target)
        guard direction != nil else { return false }
        latestAcceptedTarget = target
        currentKey = target
        return true
    }

    /// 伪代码 0x100767234，L188-236：完成翻页。
    /// completed=false → 清状态返回 cancelled；
    /// completed=true → committed；displayed 与当前不一致时按 displayed 重解析
    /// （伪代码 L543-L575 的 resolver 失败分支）。
    mutating func complete(
        displayed: PageCurlPageKey?, completed: Bool
    ) -> PageCurlTurnCompletion {
        defer {
            phase = .idle
            startKey = nil
            currentKey = nil
            latestAcceptedTarget = nil
        }
        if completed, displayed != nil {
            currentKey = displayed
            return .committed
        }
        return .cancelled
    }

    /// 伪代码 L100-104：页集在翻页期间变化标记。
    mutating func notePagesChanged() {
        pagesChangedDuringTurn = true
    }

    /// 重置（骨架签名）。
    mutating func reset() {
        phase = .idle
        startKey = nil
        currentKey = nil
        latestAcceptedTarget = nil
        pagesChangedDuringTurn = false
    }
}
