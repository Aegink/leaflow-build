// 原路径: ReadMain/Views/Reader/PageIndexCache.swift。
// 类型表10304及0x1007682a0：可选数组快照、页身份/布局双索引。
// 0x1007682f0先比数量再比存储地址；0x100768954的PGO标签错误，实际仅返回数组地址。

final class PageIndexCache {
    private var pagesSnapshot: [PageData]?
    private var indexByDescription: [String: Int] = [:]
    private var indexByLayoutId: [String: Int] = [:]

    var pages: [PageData] { pagesSnapshot ?? [] }

    @discardableResult
    func update(with newPages: [PageData]) -> Bool {
        if let previous = pagesSnapshot, readerPagesShareStorage(previous, newPages) { return false }
        pagesSnapshot = newPages
        indexByDescription.removeAll(keepingCapacity: true)
        indexByLayoutId.removeAll(keepingCapacity: true)
        for (index, page) in newPages.enumerated() {
            indexByDescription["\(page.chapterIndex)-\(page.pageIndex)"] = index
            indexByLayoutId[page.layoutId] = index
        }
        return true
    }

    func index(forLayoutId layoutId: String) -> Int? { indexByLayoutId[layoutId] }
    func index(for description: String) -> Int? { indexByDescription[description] }
}

// 数量相等且缓冲区地址相同才可跳过；等长换章和正文修改均需更新快照。
func readerPagesShareStorage(_ lhs: [PageData], _ rhs: [PageData]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return lhs.withUnsafeBufferPointer { left in
        rhs.withUnsafeBufferPointer { right in left.baseAddress == right.baseAddress }
    }
}
