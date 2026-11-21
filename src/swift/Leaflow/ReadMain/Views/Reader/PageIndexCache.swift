// 原路径: ReadMain/Views/Reader/PageIndexCache.swift
// 证据:
//   - PGO: 3 个主函数（index/task_functions.csv T-301-04 / PageIndexCache.swift），
//     地址：update(with:) 0x1007682a0 L22-33 / readerPagesShareStorage closure
//     0x100768878 L7-9 / index(forLayoutId:) 0x100768954 L40-42；
//     另有 pgo_only：index(for: String)、readerPagesShareStorage 主体
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageIndexCache.c（216 行）
//   - 事实：update(with:) 同页数且 layoutId 命中当前页 → false（无变化）；
//     否则替换 pages 并重建两个 String->Int 字典（"chapterIndex-pageIndex" 描述键
//     与 layoutId 键，分隔符 "-"(45) 确证）→ true；
//     index(forLayoutId:) 为字典查找返回 Int?
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - update/index: high（字典重建 + "-" 键拼接确证）
//   - readerPagesShareStorage: medium（closure 签名确证，存储同一性比较细节待真机对照）
// 还原: 2026-11-19

/// 页索引缓存：按 "chapterIndex-pageIndex" 描述键与 layoutId 双字典索引 [PageData]。
final class PageIndexCache {
    private(set) var pages: [PageData] = []
    /// "chapterIndex-pageIndex" -> 页索引（伪代码 L145-L156：description "-" 拼接键）。
    private var indexByDescription: [String: Int] = [:]
    /// layoutId -> 页索引（伪代码 L156-L190：layoutId 键字典）。
    private var indexByLayoutId: [String: Int] = [:]

    /// 伪代码 0x1007682a0，L22-33。
    /// 页数相同且当前页（按 layoutId 查找）命中 → false；
    /// 否则替换 pages 并重建双字典 → true。
    @discardableResult
    func update(with newPages: [PageData]) -> Bool {
        if pages.count == newPages.count,
           let currentPageId = pages.first?.layoutId,
           let currentIndex = indexByLayoutId[currentPageId],
           currentIndex == 0 {
            return false
        }
        pages = newPages
        indexByDescription.removeAll(keepingCapacity: true)
        indexByLayoutId.removeAll(keepingCapacity: true)
        for (index, page) in newPages.enumerated() {
            indexByDescription["\(page.chapterIndex)-\(page.pageIndex)"] = index
            indexByLayoutId[page.layoutId] = index
        }
        return true
    }

    /// 伪代码 0x100768954，L40-42：layoutId 字典查找。
    func index(forLayoutId layoutId: String) -> Int? {
        indexByLayoutId[layoutId]
    }

    /// pgo_only（签名确证）：description 键查找。
    func index(for description: String) -> Int? {
        indexByDescription[description]
    }
}

/// 两页数组是否共享底层存储（PGO：readerPagesShareStorage + UnsafeBufferPointer
/// closure 确证；存储同一性按首元素地址近似，细节待真机对照）。
func readerPagesShareStorage(_ lhs: [PageData], _ rhs: [PageData]) -> Bool {
    guard !lhs.isEmpty, !rhs.isEmpty else { return false }
    return lhs.withUnsafeBufferPointer { lbuf in
        rhs.withUnsafeBufferPointer { rbuf in
            lbuf.baseAddress == rbuf.baseAddress
        }
    }
}
