// 原路径: ReadMain/Views/Reader/PageCurlTurnState.swift。
// 类型表10262：phase/startKey/direction/acceptedTargets/pagesChangedDuringTurn。
// 0x100766ea8开始、0x100766ff0接受、0x100767234完成、0x100766e20重置。
// PGO存在交错标签，按汇编字段与调用方复核；证据见t1602_page_curl_probe.txt。

struct PageCurlPageKey: Hashable, CustomStringConvertible {
    let chapterIndex: Int
    let pageIndex: Int

    init(chapterIndex: Int, pageIndex: Int) {
        self.chapterIndex = chapterIndex
        self.pageIndex = pageIndex
    }

    init(_ page: PageData) {
        self.init(chapterIndex: page.chapterIndex, pageIndex: page.pageIndex)
    }

    // 0x100766a38：两个整数前分别追加ch和p。
    var description: String { "ch\(chapterIndex)p\(pageIndex)" }
    var pageID: PageTurnPageID { .init(chapterIndex: chapterIndex, pageIndex: pageIndex) }
}

struct PageCurlPageResolver {
    private let pages: [PageData]
    private let turnResolver: PageTurnResolver

    init(pages: [PageData], turnResolver: PageTurnResolver) {
        self.pages = pages
        self.turnResolver = turnResolver
    }

    init(pages: [PageData], isDoublePage: Bool) {
        self.init(pages: pages, turnResolver: PageTurnResolver(sequence: PageTurnSequence(
            pages: pages.map {
                .init(id: PageCurlPageKey($0).pageID,
                    isLoadingPlaceholder: $0.isLoadingPlaceholder,
                    isErrorPlaceholder: $0.isErrorPlaceholder)
            }, isDoublePage: isDoublePage)))
    }

    // 0x100766d34：按完整页键查找，章节号不能用作全局数组下标。
    func index(for key: PageCurlPageKey?) -> Int? {
        guard let key, let index = turnResolver.index(for: key.pageID) else { return nil }
        return turnResolver.canonicalIndex(index)
    }

    // 0x100766b40：先做边界与双页归一，再读取真实页键。
    func key(at index: Int) -> PageCurlPageKey? {
        let canonical = turnResolver.canonicalIndex(index)
        guard pages.indices.contains(canonical) else { return nil }
        return PageCurlPageKey(pages[canonical])
    }

    // 0x100766c10：双页时回到跨页起始键，未知页保留自身身份。
    func key(for page: PageData?) -> PageCurlPageKey? {
        guard let page else { return nil }
        let key = PageCurlPageKey(page)
        guard turnResolver.sequence.isDoublePage, let index = index(for: key) else { return key }
        return self.key(at: index)
    }

    var pageCount: Int { pages.count }

    func adjacentKey(from key: PageCurlPageKey, direction: ReaderPageTurnDirection) -> PageCurlPageKey? {
        guard let source = index(for: key),
              let target = turnResolver.targetIndex(from: source, direction: direction) else { return nil }
        return self.key(at: target)
    }

    func direction(from start: PageCurlPageKey, to target: PageCurlPageKey) -> ReaderPageTurnDirection? {
        for direction in [ReaderPageTurnDirection.previous, .next] {
            if adjacentKey(from: start, direction: direction) == target { return direction }
        }
        return nil
    }
}

enum PageCurlTurnPhase: Int {
    case idle = 0
    case tracking = 1
    case carrying = 2
}

// 0x100767234的X0/X1为页键、X2为剩余目标数组；W3高位区分结果，低位保留页集变化。
// case名称为语义命名；不能将该返回值压成Bool或丢掉关联值。
enum PageCurlTurnCompletion: Equatable {
    case unchanged(displayed: PageCurlPageKey, carriedTargets: [PageCurlPageKey])
    case committed(displayed: PageCurlPageKey, carriedTargets: [PageCurlPageKey], pagesChanged: Bool)
    case cancelled
    case unresolved
}

struct PageCurlTurnState {
    private(set) var phase: PageCurlTurnPhase = .idle
    private(set) var startKey: PageCurlPageKey?
    private(set) var direction: ReaderPageTurnDirection?
    private(set) var acceptedTargets: [PageCurlPageKey] = []
    private(set) var pagesChangedDuringTurn = false

    var hasCarriedTargets: Bool { phase == .carrying && !acceptedTargets.isEmpty }
    var isActive: Bool { phase == .tracking }
    var latestAcceptedTarget: PageCurlPageKey? { acceptedTargets.last }

    mutating func begin(start: PageCurlPageKey) {
        switch phase {
        case .idle:
            startKey = start
            phase = .tracking
        case .tracking:
            break
        case .carrying:
            guard startKey != start else { return }
            guard let index = acceptedTargets.firstIndex(of: start) else {
                reset()
                startKey = start
                phase = .tracking
                return
            }
            acceptedTargets = Array(acceptedTargets.dropFirst(index + 1))
            startKey = start
            pagesChangedDuringTurn = false
            if acceptedTargets.isEmpty {
                phase = .tracking
                direction = nil
            }
        }
    }

    mutating func accept(
        target: PageCurlPageKey, start: PageCurlPageKey,
        directionFrom: (PageCurlPageKey, PageCurlPageKey) -> ReaderPageTurnDirection?
    ) -> Bool {
        if startKey == nil {
            startKey = start
            phase = .tracking
        }
        guard let origin = startKey else { return false }
        if target == origin || acceptedTargets.contains(target) { return true }
        let anchor = latestAcceptedTarget ?? origin
        guard target != anchor else { return false }
        if let nextDirection = directionFrom(anchor, target),
           direction == nil || direction == nextDirection {
            direction = nextDirection
            acceptedTargets.append(target)
            phase = .tracking
            return true
        }
        // 携带旧目标时允许从已显示页重新定向；活跃手势中禁止反向追加。
        if phase == .carrying, let newDirection = directionFrom(origin, target) {
            direction = newDirection
            acceptedTargets = [target]
            phase = .tracking
            return true
        }
        return false
    }

    mutating func complete(displayed: PageCurlPageKey?, completed: Bool) -> PageCurlTurnCompletion {
        guard completed else { reset(); return .cancelled }
        guard let displayed else { reset(); return .unresolved }
        if displayed == startKey {
            let carried = acceptedTargets
            if carried.isEmpty {
                reset()
            } else {
                phase = .carrying
                pagesChangedDuringTurn = false
            }
            return .unchanged(displayed: displayed, carriedTargets: carried)
        }
        let changed = pagesChangedDuringTurn
        let carried: [PageCurlPageKey]
        if let index = acceptedTargets.firstIndex(of: displayed) {
            carried = Array(acceptedTargets.dropFirst(index + 1))
        } else {
            carried = []
        }
        if carried.isEmpty {
            reset()
        } else {
            phase = .carrying
            startKey = displayed
            acceptedTargets = carried
            pagesChangedDuringTurn = false
        }
        return .committed(displayed: displayed, carriedTargets: carried, pagesChanged: changed)
    }

    mutating func notePagesChanged() { pagesChangedDuringTurn = true }

    mutating func reset() {
        phase = .idle
        startKey = nil
        direction = nil
        acceptedTargets.removeAll()
        pagesChangedDuringTurn = false
    }
}
