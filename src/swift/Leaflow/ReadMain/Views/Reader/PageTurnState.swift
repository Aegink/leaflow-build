// 原路径: ReadMain/Views/Reader/PageTurnState.swift。
// 类型表10322-10350：sequence/currentIndex/transition；不存在phase字段。
// 0x100769500目标、0x100769914占位策略、0x10076921c开始、0x1007692e8结束、
// 0x100769000序列重定位。PGO标签交错，已按字段和指令复核。

struct PageTurnPageID: Hashable {
    let chapterIndex: Int
    let pageIndex: Int
}

struct PageTurnSequence {
    struct Page: Hashable {
        let id: PageTurnPageID
        let isLoadingPlaceholder: Bool
        let isErrorPlaceholder: Bool
    }

    let pages: [Page]
    let isDoublePage: Bool
}

struct PageTurnTransition: Equatable {
    let sourceID: PageTurnPageID
    let targetID: PageTurnPageID
    let direction: ReaderPageTurnDirection
    var sourceIndex: Int
    var targetIndex: Int
}

enum PageTurnCompletion: Equatable {
    case cancelled(index: Int)
    case committed(index: Int)

    var index: Int {
        switch self {
        case .cancelled(let index), .committed(let index): return index
        }
    }
}

enum PageTurnRebaseResult: Equatable {
    case updated(index: Int)
    case preserved(PageTurnTransition)
    case cancelled(index: Int)
}

struct PageTurnResolver {
    let sequence: PageTurnSequence

    // 负数夹到0，不是abs；双页索引对齐到偶数。
    func canonicalIndex(_ index: Int) -> Int {
        guard !sequence.pages.isEmpty else { return 0 }
        let bounded = min(max(index, 0), sequence.pages.count - 1)
        return sequence.isDoublePage ? bounded & ~1 : bounded
    }

    func index(for id: PageTurnPageID) -> Int? {
        sequence.pages.firstIndex { $0.id == id }
    }

    func targetIndex(from index: Int, direction: ReaderPageTurnDirection) -> Int? {
        guard !sequence.pages.isEmpty else { return nil }
        let source = canonicalIndex(index)
        let step = sequence.isDoublePage ? 2 : 1
        let (target, overflow) = source.addingReportingOverflow(direction == .next ? step : -step)
        guard !overflow, sequence.pages.indices.contains(target),
              canTurn(from: source, to: target, direction: direction) else { return nil }
        return canonicalIndex(target)
    }

    func transition(from index: Int, direction: ReaderPageTurnDirection) -> PageTurnTransition? {
        let source = canonicalIndex(index)
        guard let target = targetIndex(from: source, direction: direction) else { return nil }
        return PageTurnTransition(sourceID: sequence.pages[source].id,
            targetID: sequence.pages[target].id, direction: direction,
            sourceIndex: source, targetIndex: target)
    }

    func direction(from: PageTurnPageID, to: PageTurnPageID) -> ReaderPageTurnDirection? {
        guard let source = index(for: from), let target = index(for: to) else { return nil }
        for direction in [ReaderPageTurnDirection.next, .previous] {
            if targetIndex(from: source, direction: direction) == target { return direction }
        }
        return nil
    }

    func canTurn(from: Int, to: Int, direction: ReaderPageTurnDirection) -> Bool {
        guard sequence.pages.indices.contains(from), sequence.pages.indices.contains(to) else { return false }
        guard displayContainsLoadingPlaceholder(at: from) else { return true }
        return direction == .previous && !displayContainsPlaceholder(at: to)
    }

    func displayedIndices(at index: Int) -> [Int] {
        guard !sequence.pages.isEmpty else { return [] }
        let first = canonicalIndex(index)
        let last = sequence.isDoublePage ? min(first + 1, sequence.pages.count - 1) : first
        return Array(first...last)
    }

    func displayContainsLoadingPlaceholder(at index: Int) -> Bool {
        displayedIndices(at: index).contains { sequence.pages[$0].isLoadingPlaceholder }
    }

    func displayContainsPlaceholder(at index: Int) -> Bool {
        displayedIndices(at: index).contains {
            sequence.pages[$0].isLoadingPlaceholder || sequence.pages[$0].isErrorPlaceholder
        }
    }
}

struct PageTurnState {
    private(set) var sequence: PageTurnSequence
    private(set) var currentIndex: Int
    private(set) var transition: PageTurnTransition?

    init(sequence: PageTurnSequence, committedIndex: Int = 0) {
        self.sequence = sequence
        currentIndex = PageTurnResolver(sequence: sequence).canonicalIndex(committedIndex)
    }

    mutating func beginTurn(_ direction: ReaderPageTurnDirection) -> PageTurnTransition? {
        guard transition == nil else { return nil }
        transition = PageTurnResolver(sequence: sequence).transition(from: currentIndex, direction: direction)
        return transition
    }

    mutating func finishTurn(committed: Bool) -> PageTurnCompletion? {
        guard let transition else { return nil }
        self.transition = nil
        let resolver = PageTurnResolver(sequence: sequence)
        if committed, let target = resolver.index(for: transition.targetID) {
            currentIndex = resolver.canonicalIndex(target)
            return .committed(index: currentIndex)
        }
        currentIndex = resolver.canonicalIndex(resolver.index(for: transition.sourceID) ?? currentIndex)
        return .cancelled(index: currentIndex)
    }

    mutating func replaceSequence(_ newSequence: PageTurnSequence, committedIndex: Int) -> PageTurnRebaseResult {
        sequence = newSequence
        let resolver = PageTurnResolver(sequence: newSequence)
        currentIndex = resolver.canonicalIndex(committedIndex)
        guard var transition else { return .updated(index: currentIndex) }
        if let source = resolver.index(for: transition.sourceID),
           let target = resolver.index(for: transition.targetID),
           currentIndex == resolver.canonicalIndex(source),
           resolver.targetIndex(from: source, direction: transition.direction) == target {
            transition.sourceIndex = currentIndex
            transition.targetIndex = resolver.canonicalIndex(target)
            self.transition = transition
            return .preserved(transition)
        }
        self.transition = nil
        return .cancelled(index: currentIndex)
    }
}
