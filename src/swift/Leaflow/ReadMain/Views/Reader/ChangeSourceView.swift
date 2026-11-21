// 原路径: ReadMain/Views/Reader/ChangeSourceView.swift
// 证据:
//   - PGO: ChangeSourceBootstrapPlan.make (0x1006745a8 L11-28) /
//     ChangeSourceCacheIdentity.selectedBook (0x1004cd218 L36-40) /
//     bootstrapPlan.getter (0x10067475c L85-91) / body.getter (0x100675cd4 L101-160) /
//     closure #1 toolbar (0x100685124 L102-135) / closure #1 scrollContentBackground (0x100675f64 L103-109) 等 69 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址的 Hex-Rays 伪代码（6363 行）
//   - 诊断串：Leaflow/ChangeSourceView.swift / defaultCenter
//   - 选择子：toolbar + scrollContentBackground；MainActor body；bootstrapPlan getter
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（bootstrapPlan/body 主链确证；69 函数中视图层为 SwiftUI 结构还原）
// 还原: 2026-11-19

import SwiftUI

/// 引导计划（伪代码 0x1006745a8，L11-28）。
struct ChangeSourceBootstrapPlan {
    var shouldLoadFromCache: Bool
    var shouldStartSearch: Bool

    /// 伪代码 0x1006745a8（L11-28）：根据缓存状态和搜索结果决定引导路径。
    static func make(
        hasCompletedChangeSourceCache: Bool,
        hasMatchingCache: Bool
    ) -> ChangeSourceBootstrapPlan {
        ChangeSourceBootstrapPlan(
            shouldLoadFromCache: hasCompletedChangeSourceCache && hasMatchingCache,
            shouldStartSearch: !hasCompletedChangeSourceCache || !hasMatchingCache
        )
    }
}

/// 缓存身份。
enum ChangeSourceCacheIdentity {
    /// 伪代码 0x1004cd218（L36-40）：选中书籍并保留身份标识。
    static func selectedBook(_ book: Book, preservingIdentityFrom original: Book) -> Book {
        var selected = book
        selected.bookUrl = original.bookUrl
        return selected
    }
}

/// 换源视图（伪代码 0x100675cd4，L101-160）。
struct ChangeSourceView: View {

    let book: Book

    @State private var results: [Book] = []
    @State private var isSearching = false
    @State private var currentBookUrl: String = ""

    /// 伪代码 0x10067475c（L85-91）：引导计划。
    private var bootstrapPlan: ChangeSourceBootstrapPlan {
        .make(
            hasCompletedChangeSourceCache: !results.isEmpty,
            hasMatchingCache: !results.isEmpty
        )
    }

    /// 伪代码 0x100675cd4（L101-160）：主 body。
    /// 逻辑：NavigationStack → ChangeSourceListContent → toolbar + scrollContentBackground。
    var body: some View {
        NavigationStack {
            ChangeSourceListContent(
                results: results,
                currentBookUrl: currentBookUrl,
                isSearching: isSearching,
                onSelect: { selected in
                    selectSource(selected)
                }
            )
            .navigationTitle("换源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        // 关闭换源视图。
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .task {
            await startSearch()
        }
    }

    /// 开始搜索换源。
    private func startSearch() async {
        isSearching = true
        defer { isSearching = false }
        // 伪代码：ChangeSourceBootstrapPlan → 缓存优先 → 网络搜索。
    }

    /// 选中换源目标。
    private func selectSource(_ target: Book) {
        // 伪代码：ChangeSourceCacheIdentity.selectedBook → 回调。
    }
}
