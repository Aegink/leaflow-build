// 原路径: ReadMain/Views/Reader/LocalPDFReaderView.swift
// 证据:
//   - PGO: 61 个主函数（index/task_functions.csv T-304-03 / LocalPDFReaderView.swift），
//     地址：_showMenu 初始化 0x10070e764 L6 / body 0x10070e834 L20-87 /
//     readerContent 0x10070f5a4 L90-113 / menuOverlay 0x10070fec4 L145-154 /
//     VM.loadBook 0x100710198 L408-449 / VM.preloadPages 0x100710c00 L466-473 /
//     VM.currentDirectoryIndex 0x100711674 L392-395
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/LocalPDFReaderView.c
//   - 事实：PDF 阅读根视图 —— body（PDFKit 页渲染 + 菜单覆盖）+ VM 加载
//     （PDFPageImageSource.inspectDocument/directoryChapters 链确证）+ 页预载
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 根结构/加载链: high（函数名确证）
//   - 深层布局: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI
import PDFKit

/// 本地 PDF 阅读根视图。
struct LocalPDFReaderView: View {

    var book: LocalBook

    @State private var showMenu = false
    @State private var currentPageIndex = 0
    @State private var pageCount = 0
    @State private var pages: [UIImage] = []
    @State private var isLoading = false

    var body: some View {
        // 伪代码 0x10070e834（L20-87）。
        GeometryReader { geometry in
            ZStack {
                readerContent(geometry: geometry)
                if isLoading {
                    ProgressView()
                }
                if showMenu {
                    menuOverlay(geometry: geometry)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showMenu.toggle()
            }
        }
        .task {
            await loadBook()
        }
    }

    /// 伪代码 0x10070f5a4（L90-113）：PDF 内容（横向滚动页列）。
    @ViewBuilder
    private func readerContent(geometry: GeometryProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pages.indices, id: \.self) { index in
                    if let image = pages.indices.contains(index) ? pages[index] : nil {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width)
                    } else {
                        ProgressView()
                            .frame(width: geometry.size.width)
                    }
                }
            }
        }
    }

    /// 伪代码 0x10070fec4（L145-154）：菜单覆盖层。
    @ViewBuilder
    private func menuOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                Text("第 \(currentPageIndex + 1) / \(pageCount) 页")
                    .font(.caption)
                Spacer()
                Button {
                    showMenu = false
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
            .padding()
            Spacer()
        }
        .background(.ultraThinMaterial.opacity(0.001))
    }

    // MARK: VM 逻辑

    /// 伪代码 VM.loadBook 0x100710198（L408-449）：
    /// PDFPageImageSource.inspectDocument → directoryChapters → 首屏页渲染。
    private func loadBook() async {
        isLoading = true
        defer { isLoading = false }
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else { return }
        // 本地 PDF 路径（book.fileURL 域，T-601 交叉）。
        let candidates = [
            documents.appendingPathComponent("\(book.id).pdf"),
            documents.appendingPathComponent(book.name + ".pdf"),
        ]
        guard let url = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else { return }
        guard let metadata = PDFPageImageSource.inspectDocument(at: url) else { return }
        pageCount = metadata.pageCount
        await preloadPages(around: 0)
    }

    /// 伪代码 VM.preloadPages 0x100710c00（L466-473）：邻接页预载。
    private func preloadPages(around index: Int) async {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else { return }
        let candidates = [
            documents.appendingPathComponent("\(book.id).pdf"),
            documents.appendingPathComponent(book.name + ".pdf"),
        ]
        guard let url = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }), let document = PDFDocument(url: url) else { return }
        let radius = 2
        for offset in -radius...radius {
            let target = index + offset
            guard target >= 0, target < document.pageCount,
                  pages.indices.contains(target) == false else { continue }
            if let image = PDFPageImageSource.renderPage(
                document: document, pageIndex: target, maxPixelSize: 2048) {
                if pages.count <= target {
                    pages.append(contentsOf: repeatElement(UIImage(), count: target + 1 - pages.count))
                }
                pages[target] = image
            }
        }
    }

    /// 伪代码 VM.currentDirectoryIndex 0x100711674（L392-395）。
    private var currentDirectoryIndex: Int {
        currentPageIndex
    }
}

/// 本地 PDF 阅读模型（0x100717348/0x100711828/0x1007119dc 域；
/// MainActor executor 断言确证——"Leaflow/LocalPDFReaderView.swift"
/// L76/L80 域）。
@MainActor
final class LocalPDFReaderViewModel: ObservableObject {

    /// 当前页（jumpToPage 域消费）。
    @Published var currentPage: Int = 0
    /// 总页数。
    @Published var pageCount: Int = 0
    /// 进度持久化键（bookId 绑定域推断）。
    var progressKey: String = ""

    /// 伪代码 0x100717348（L451-456）：跳页——"left" 方向域
    ///（0x7466656C 确证）+ 页码钳制。
    func jumpToPage(_ page: Int) {
        currentPage = min(max(page, 0), max(pageCount - 1, 0))
    }

    /// 伪代码 0x100711828（L458-464）：跳目录项——State wrappedValue 域 +
    /// closure #7 in LocalPDFReaderView.body 域 + ReadingDurationTracker
    /// .endSession() 尾调域确证。
    func jumpToDirectoryItem(_ pageIndex: Int) {
        jumpToPage(pageIndex)
        ReadingDurationTracker.shared.endSession()
    }

    /// 伪代码 0x1007119dc（L475-482）：保存进度——ReadingDurationTracker
    /// .pauseSession() 域确证 + UserDefaults 快照。
    func saveProgress() {
        ReadingDurationTracker.shared.pauseSession()
        UserDefaults.standard.set(currentPage, forKey: progressKey)
    }
}

