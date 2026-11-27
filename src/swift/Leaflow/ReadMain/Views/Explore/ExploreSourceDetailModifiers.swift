// 原路径: ReadMain/Views/Explore/ExploreSourceDetailModifiers.swift
// 证据:
//   - PGO: 58 条记录（index/task_functions.csv T-501-03 /
//     ExploreSourceDetailModifiers.swift；伪代码域 4846 行）。关键域：
//     _exploreJavaOpenAction(from:source:infoValues:)/
//     ExploreBrowserSheetContent.body / ExploreOpenedExploreRouteContent.body /
//     ExploreOpenedSearchRouteContent.body / ExploreSourceDetailChromeModifier
//     .body(content:) / ExploreSourceDetailTrailingToolbar.body /
//     ExploreSourceDetailLifecycleModifier.body(content:) /
//     ExploreSourceDetailPresentationsModifier.body(content:)
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/
//     ExploreSourceDetailModifiers.c（4846 行）
//   - 字符串确证（位模式/指针）："书签页网格布局" @ptr L511/"书签设置"
//     L1478/"输入内容" L3998/"login.dismiss.refresh" @ptr L4505/
//     "正在加载分类..." @ptr L4620/"gearshape"（'gearshap' L1540）/
//     "chevron." L2210 域；"Leaflow/JsExtensions.swift" @ptr L364（桥域
//     交叉确证）
//   - 事实：java.open 动作域（_exploreJavaOpenAction + JsExtensions 桥交叉）；
//     浏览器面板内容体（ExploreBrowserSheetContent）；双路由内容体
//     （ExploreOpenedExploreRoute/ExploreOpenedSearchRoute）；四修饰体
//     （chrome/trailingToolbar/lifecycle/presentations）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 修饰器/路由内容: high（签名族 + 域串确证）
//   - 布局细节: medium（结构性还原，待真机对照）
// 还原: 2026-11-20

import SwiftUI
import WebKit

// MARK: - java.open 动作

/// java.open 动作结果（ExploreJavaOpenAction 域确证）。
enum ExploreJavaOpenAction {
    case openURL(URL)
    case search(keyword: String)
    case none
}

/// _exploreJavaOpenAction（签名确证；JsExtensions 桥域交叉确证）。
func _exploreJavaOpenAction(
    from notification: Notification, source: BookSource,
    infoValues: [String: String]
) -> ExploreJavaOpenAction {
    if let url = notification.userInfo?["url"] as? URL {
        return .openURL(url)
    }
    if let keyword = notification.userInfo?["keyword"] as? String {
        return .search(keyword: keyword)
    }
    return .none
}

// MARK: - 浏览器面板内容

/// 浏览器面板内容体（body 签名确证；"login.dismiss.refresh" @ptr 域）。
struct ExploreBrowserSheetContent: View {
    let request: RemoteBrowserRequest
    let onCookiesCaptured: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RemoteBrowserWebView(
                request: request,
                onHostAppNavigation: nil,
                onCookies: { header in
                    onCookiesCaptured?(header)
                })
            .navigationTitle(request.url.host ?? "浏览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 路由内容体

/// 已打开浏览路由内容体（body 签名确证）。
struct ExploreOpenedExploreRouteContent: View {
    let route: ExploreOpenRoute
    @State private var html: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if let url = URL(string: route.url) {
                RemoteBrowserWebView(
                    request: RemoteBrowserRequest(url: url),
                    onHostAppNavigation: nil,
                    onCookies: nil)
            } else {
                Text(route.displayTitle)
                    .appThemeText(.caption, opacity: 0.6)
            }
        }
        .navigationTitle(route.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 已打开搜索路由内容体（body 签名确证）。
struct ExploreOpenedSearchRouteContent: View {
    let route: ExploreSearchRoute

    var body: some View {
        VStack(spacing: 8.0) {
            Text(route.displayTitle)
                .appThemeText(.headline)
            Text("关键词: \(route.keyword)")
                .appThemeText(.caption, opacity: 0.6)
            Spacer()
        }
        .padding(.all, 16.0)
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 修饰体

/// 详情页 chrome（body(content:) 签名确证）。
struct ExploreSourceDetailChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// 尾部工具栏（body getter 签名确证）。
struct ExploreSourceDetailTrailingToolbar: View {
    var body: some View {
        // "书签设置"/"gearshape" 域确证。
        Image(systemName: "gearshape")
    }
}

/// 生命周期修饰（body(content:) 签名确证）。
struct ExploreSourceDetailLifecycleModifier: ViewModifier {
    let onAppear: () -> Void
    let onDisappear: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
    }
}

/// 弹层分发修饰（body(content:) 签名确证；"输入内容" L3998/
/// "正在加载分类..." @ptr 域确证）。
struct ExploreSourceDetailPresentationsModifier: ViewModifier {
    @Binding var selectedBook: ExploreSelectedBook?
    @Binding var pendingReadBook: Book?
    let onReadBookFromDetail: (Book) -> Void
    @Binding var filterSheet: Bool
    @Binding var browserRequest: RemoteBrowserRequest?
    @Binding var openRoute: ExploreOpenRoute?
    @Binding var searchRoute: ExploreSearchRoute?
    let source: BookSource
    var preparedTextReader: ReaderViewModel? = nil
    @State private var readingBook: Book?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $readingBook) { book in
                ReaderRouter(book: book, preparedTextReader: preparedTextReader)
                    .id(book.id)
            }
            .sheet(item: $selectedBook) { selection in
                NavigationStack {
                    BookDetailView(book: selection.book, availableSources: [], onRead: onReadBookFromDetail,
                        initialChapters: preparedTextReader?.chapters,
                        sourceService: preparedTextReader?.sourceService ?? .shared)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { selectedBook = nil }
                                .accessibilityIdentifier("explore-detail-close")
                        }
                    }
                }
                .id(selection.id)
            }
            .task(id: selectedBook?.id) {
                guard let book = ExploreReaderRequest.takePending(
                    isDetailPresented: selectedBook != nil, pending: &pendingReadBook) else { return }
                // 0x10053d4d0→0x100542448：详情退出后延迟0.35秒，重新选书会取消旧交接。
                do { try await Task.sleep(nanoseconds: 350_000_000) }
                catch { return }
                guard !Task.isCancelled, selectedBook == nil, readingBook == nil else { return }
                readingBook = book
            }
            .sheet(isPresented: $filterSheet) {
                NavigationStack {
                    Text("正在加载分类...")
                        .appThemeText(.caption, opacity: 0.6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .sheet(item: $browserRequest) { request in
                ExploreBrowserSheetContent(request: request) { _ in }
            }
            .sheet(item: $openRoute) { route in
                NavigationStack {
                    ExploreOpenedExploreRouteContent(route: route)
                }
            }
            .sheet(item: $searchRoute) { route in
                NavigationStack {
                    ExploreOpenedSearchRouteContent(route: route)
                }
            }
    }
}

extension RemoteBrowserRequest: Identifiable {
    var id: String {
        url.absoluteString + (sourceStateKey ?? "")
    }
}

/// 类型表8015：每次选择创建独立呈现身份，重复打开同一书也能重新初始化详情。
struct ExploreSelectedBook: Identifiable {
    let id = UUID()
    let book: Book
}

enum ExploreReaderRequest {
    static func takePending(isDetailPresented: Bool, pending: inout Book?) -> Book? {
        guard !isDetailPresented else { return nil }
        defer { pending = nil }
        return pending
    }
}
