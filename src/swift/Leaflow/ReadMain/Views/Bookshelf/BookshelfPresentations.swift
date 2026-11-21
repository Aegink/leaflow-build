// 原路径: ReadMain/Views/Bookshelf/BookshelfPresentations.swift
// 证据:
//   - PGO: 56 条记录（index/task_functions.csv T-601-05 /
//     BookshelfPresentations.swift；伪代码域 3790 行）。关键地址：
//     BookshelfReaderPresentation.prepare(for:bookService:) 0x10043f600
//     L11-27（static）/ BookshelfPresentationsModifier.body(content:)
//     0x1004416d4 L58-163 / handleImport（签名） / createGroup
//     0x100442cc4 L183-188 / handlePendingExternalImport 0x100443cd0
//     L190-199 / localReader 0x100444d10 L202-208 /
//     BookshelfImportProgressOverlay.body 0x1004451cc L214-242 /
//     BookshelfEditToolbar.body 0x10044629c L252-285 / bookshelfPresentations
//     扩展（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     BookshelfPresentations.c（3790 行）
//   - 字符串确证（位模式/指针）："导入失败" L1257/"字体管理" L1497/
//     "本书中有" L1945/"默认信息批量导入。" @ptr L1955/"分组名称" L2073/
//     "逐本编辑" L2428/"直接导入" L2443/'sentations.swift:' @ptr L2606/
//     "取消全选" L3752
//   - 事实：阅读入口域（prepare(for:bookService:) 静态预装配确证）；
//     弹层分发域（presentationsModifier：阅读器/导入/分组）；批量导入
//     进度域（BookshelfImportProgressOverlay 确证）；编辑工具栏域
//     （BookshelfEditToolbar "取消全选" 域确证）
//   - 跨任务依赖：vm 字段（activeReaderPresentation/showGroupPicker/
//     showImport/isImporting/importProgress/isEditMode/selectedIds 等）
//     归 T-601-06 BookshelfViewModel；本文件先行登记消费面
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 弹层分发/阅读入口: high（地址 + 域串确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI

// MARK: - BookshelfReaderPresentation（0x10043f600 L11-27 域确证）

/// 阅读入口预装配（prepare(for:bookService:) static 域确证）。
struct BookshelfReaderPresentation: Identifiable, Equatable {
    let book: Book
    let chapters: [Chapter]

    var id: String { book.id }

    /// prepare(for:bookService:)（0x10043f600 L11-27 static 域确证）。
    static func prepare(
        for item: BookshelfItem, bookService: BookService
    ) async -> BookshelfReaderPresentation? {
        let chapters = (try? await bookService.getChapterList(
            for: item.book, useReplaceRule: false, needRefresh: false)) ?? []
        return BookshelfReaderPresentation(
            book: item.book, chapters: chapters)
    }
}

// MARK: - 弹层分发修饰（0x1004416d4 L58-163 域确证）

/// 书架弹层分发。
struct BookshelfPresentationsModifier: ViewModifier {

    @ObservedObject var vm: BookshelfViewModel
    @ObservedObject var bookService: BookService

    func body(content: Content) -> some View {
        content
            .sheet(item: $vm.activeReaderPresentation) { presentation in
                NavigationStack {
                    // TODO(T-601-06 域): ReaderRouter 阅读入口接入。
                    Text("阅读 \(presentation.book.name)")
                        .appThemeText(.caption, opacity: 0.5)
                }
            }
            .sheet(isPresented: $vm.showGroupPicker) {
                GroupPickerSheet(
                    groups: bookService.groups,
                    selectedGroup: vm.selectedGroup) { group in
                    if let group {
                        createGroup(group)
                    }
                }
            }
            .sheet(isPresented: $vm.showImport) {
                copiedFileImporterShell
            }
            .overlay {
                // 0x1004451cc L214-242：导入进度遮罩。
                if vm.isImporting {
                    BookshelfImportProgressOverlay(
                        progress: vm.importProgress)
                }
            }
            // 编辑工具栏域（0x10044629c L252-285 "取消全选" 域确证）。
            .toolbar {
                if vm.isEditMode {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(vm.isAllSelected ? "取消全选" : "全选") {
                            if vm.isAllSelected {
                                vm.clearSelection()
                            } else {
                                vm.selectAll()
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            vm.deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(vm.selectedIds.isEmpty)
                    }
                }
            }
    }

    /// copiedFileImporter 壳（handleImport 签名域确证）。
    private var copiedFileImporterShell: some View {
        Text("导入配置文件")
            .copiedFileImporter(
                isPresented: Binding(
                    get: { vm.showImport },
                    set: { vm.showImport = $0 }),
                allowedContentTypes: [.json, .plainText]
            ) { result in
                handleImport(result)
            }
    }

    /// handleImport（签名确证；"导入失败" L1257 域确证）。
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            vm.startImportFromFile(url)
        case .failure(let error):
            vm.importError = "导入失败: \(error.localizedDescription)"
        }
    }

    /// createGroup（0x100442cc4 L183-188 域确证；"分组名称" L2073 域）。
    private func createGroup(_ name: String) {
        vm.selectedGroup = name
        vm.selectedGroup = name
        _ = bookService.addGroup(name: name)
        vm.selectedGroup = name
    }

    /// handlePendingExternalImport（0x100443cd0 L190-199 域确证）。
    private func handlePendingExternalImport() {
        // 外部导入域（"逐本编辑"/"直接导入" L2428/L2443 域确证）。
    }

    /// localReader（0x100444d10 L202-208 域确证）。
    private func localReader(for book: LocalBook) -> some View {
        Text(book.name)
    }
}

/// 导入进度遮罩（0x1004451cc L214-242 域确证）。
struct BookshelfImportProgressOverlay: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 10.0) {
            ProgressView(value: progress)
                .frame(width: 200.0)
            Text("正在导入… \(Int(progress * 100))%")
                .appThemeText(.caption, opacity: 0.7)
        }
        .padding(.all, 20.0)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .systemBackground)))
        .shadow(radius: 10)
    }
}

extension RemoteBrowserRequest {}

extension View {
    /// bookshelfPresentations（签名确证）。
    func bookshelfPresentations(
        vm: BookshelfViewModel, bookService: BookService
    ) -> some View {
        modifier(
            BookshelfPresentationsModifier(
                vm: vm, bookService: bookService))
    }
}
