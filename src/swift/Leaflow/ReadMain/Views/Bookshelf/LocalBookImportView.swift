// 原路径: ReadMain/Views/Bookshelf/LocalBookImportView.swift
// 证据:
//   - PGO: 127 条记录（index/task_functions.csv T-601-07 /
//     LocalBookImportView.swift；伪代码域 9147 行）。关键域：
//     isImportMode（签名）/ localBookType getter / supportsChapterRules
//     （签名）/ fileURL getter 0x10048ed0c L65-70 / body 0x10048ef48
//     L76-135 / chapterPreviewSection 0x10049091c L235-256 / performSave
//     0x10049156c L349-389 / updateChapterPreview 0x100491e6c L334-341 /
//     loadInitialData 0x10049200c L286-330 / coverPreview 0x100497c5c
//     L261-282 / displayFileName 0x10049ba28 L72-74 / section 域
//     （coverSection/coverEditSection/bookInfoSection/chapterRuleSection/
//     previewTitles 签名确证）/ LocalBookFilenameMetadataParser 七件
//     （suggestion 0x10049…/parse L407-428/parseQuotedTitle L430-442/
//     parseExplicitAuthor L444-460/parseSeparated L462-477/
//     parseSpaceSeparated L479-499/resolve L501-523/isLikelyAuthor
//     L534-555/normalizedFileStem L402-405/removeAuthorMarker/clean）
//     BingImageSearchView（body 0x10049d35c L578-650/performSearch
//     0x1004a4d04 L662-677/downloadAndSelect 0x1004a0a18 L679-696/
//     placeholder 0x1004a0550 L652-660）/ BingImageSearchService
//     （search L709-723/parseImageResults L726-764）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     LocalBookImportView.c（9147 行）
//   - 字符串确证（位模式/指针）："作者：" L164/"-_—–|｜" L288（分隔符集）/
//     "书籍" L486/"书籍信息" L862/"目录规则" L882/"章节预览" L1043/
//     "清除封面" L1961/"从相册选择" L2019/"按固定长度分章" @ptr L2042/
//     "文件名" L2283/"匹配章节数" L2976/"... 共 " L3213/"索封面图片"
//     @ptr L7031/"正在搜索..." L7342/'"turl"\s*:\s*"([^"]+)"' @ptr L7422/
//     " 小说封面" L8308/'Safari/604.1' @ptr L8809（UA 域）/
//     '"murl"\s*:\s*"([^"]+)"' @ptr L8814/'kImportView.swift' @ptr L623
//   - 事实：导入域（四 Section 确证：封面/书籍信息/目录规则/章节预览）；
//     文件名解析域（七步解析链：quoted title → explicit author →
//     separated → space separated → resolve → isLikelyAuthor）；Bing
//     封面搜索域（"turl"/"murl" JSON 正则确证 + Safari UA）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导入主链/文件名解析: high（地址 + 正则域确证）
//   - Bing 搜索: high（"turl"/"murl" 正则指针确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI
import PhotosUI

/// 本地书类型（localBookType getter 域确证）。
enum LocalBookType: String {
    case txt = "TXT"
    case epub = "EPUB"
    case pdf = "PDF"

    /// supportsChapterRules getter（签名确证）。
    var supportsChapterRules: Bool {
        self == .txt
    }
}

/// 本地书导入视图。
struct LocalBookImportView: View {

    let fileURL: URL

    /// localBookType getter（签名域确证）。
    private var localBookType: LocalBookType {
        LocalBookType(
            rawValue: fileURL.pathExtension.uppercased()) ?? .txt
    }

    /// supportsChapterRules getter（签名确证）。
    private var supportsChapterRules: Bool {
        localBookType.supportsChapterRules
    }

    /// isImportMode getter（签名确证）。
    private var isImportMode: Bool {
        localBookType == .txt
    }

    /// displayFileName getter（0x10049ba28 L72-74 域确证）。
    private var displayFileName: String {
        fileURL.lastPathComponent
    }

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var chapterPattern: String = ""
    @State private var chapterPreview: [String] = []
    @State private var fileContent: String = ""
    @State private var selectedCover: UIImage?
    @State private var showBingSearch = false
    @State private var showPhotoPicker = false
    @State private var isSaving = false
    @State private var useFixedLength = false
    @State private var importError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x10048ef48（L76-135）：四 Section Form。
        Form {
            coverSection
            bookInfoSection
            if supportsChapterRules {
                chapterRuleSection
                chapterPreviewSection
            }
        }
        .navigationTitle(displayFileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("导入") { performSave() }
                    .accessibilityIdentifier("local-book-import-save")
                    .disabled(title.isEmpty || isSaving)
            }
        }
        .onAppear {
            Task { await loadInitialData() }
        }
        .onChange(of: chapterPattern) { _, value in updateChapterPreview(pattern: value) }
        .alert("导入失败", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("确定") { importError = nil }
        } message: { Text(importError ?? "") }
        .sheet(isPresented: $showBingSearch) {
            BingImageSearchView { image in
                selectedCover = image
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: Binding(
                get: { nil as PhotosPickerItem? },
                set: { if $0 != nil { showPhotoPicker = false } }),
            matching: .images)
        .onChange(of: selectedCover) { _ in }
    }

    // MARK: Section 域（签名确证）

    /// coverSection getter（签名确证）。
    private var coverSection: some View {
        Section("封面") {
            coverPreview
            PhotosPicker(
                selection: Binding(
                    get: { nil as PhotosPickerItem? },
                    set: { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(
                                type: Data.self) {
                                await MainActor.run {
                                    selectedCover = UIImage(data: data)
                                }
                            }
                        }
                    }),
                matching: .images) {
                // "从相册选择" L2019 域确证。
                Label("从相册选择", systemImage: "photo")
            }
            Button {
                showBingSearch = true
            } label: {
                // "索封面图片" @ptr L7031 域确证。
                Label("搜索封面图片", systemImage: "magnifyingglass")
            }
            if selectedCover != nil {
                // "清除封面" L1961 域确证。
                Button(role: .destructive) {
                    selectedCover = nil
                } label: {
                    Label("清除封面", systemImage: "xmark.bin")
                }
            }
        }
    }

    /// coverPreview getter（0x100497c5c L261-282 域确证）。
    private var coverPreview: some View {
        HStack {
            Spacer()
            if let selectedCover {
                Image(uiImage: selectedCover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80.0, height: 112.0)
                    .cornerRadius(6, antialiased: true)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 80.0, height: 112.0)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundColor(.secondary)
                    }
            }
            Spacer()
        }
    }

    /// bookInfoSection getter（签名确证；"书籍信息" L862 域）。
    private var bookInfoSection: some View {
        Section("书籍信息") {
            // "文件名" L2283 域确证。
            HStack {
                Text("文件名")
                Spacer()
                Text(displayFileName)
                    .appThemeText(.caption, opacity: 0.6)
                    .lineLimit(1)
            }
            TextField("书名", text: $title)
            TextField("作者", text: $author)
        }
    }

    /// chapterRuleSection getter（签名确证；"目录规则" L882 域）。
    private var chapterRuleSection: some View {
        Section("目录规则") {
            TextField("章节正则（可选）", text: $chapterPattern)
                .autocorrectionDisabled()
                .disabled(useFixedLength)
            Toggle("按固定长度分章", isOn: $useFixedLength)
            Text("导入后可在编辑页中随时更换规则。")
                .appThemeText(.caption, opacity: 0.5)
        }
    }

    /// chapterPreviewSection getter（0x10049091c L235-256 域确证）。
    private var chapterPreviewSection: some View {
        Section("章节预览") {
            // "匹配章节数" L2976 域确证。
            Text("匹配章节数: \(chapterPreview.count)")
                .appThemeText(.caption, opacity: 0.6)
            ForEach(chapterPreview.prefix(10), id: \.self) { title in
                Text(title)
                    .appThemeText(.caption)
                    .lineLimit(1)
            }
            if chapterPreview.count > 10 {
                // "... 共 " L3213 域确证。
                Text("... 共 \(chapterPreview.count) 章")
                    .appThemeText(.caption, opacity: 0.5)
            }
        }
    }

    // MARK: 数据装载（0x10049200c L286-330 域确证）

    /// loadInitialData（0x10049200c L286-330 域确证）。
    private func loadInitialData() async {
        let suggestion = LocalBookFilenameMetadataParser.suggestion(
            for: fileURL)
        await MainActor.run {
            if title.isEmpty {
                title = suggestion.title
            }
            if author.isEmpty {
                author = suggestion.author ?? ""
            }
        }
        if supportsChapterRules {
            let result = await LocalBookService.shared
                .detectChapterPatternForImport(url: fileURL)
            await MainActor.run {
                fileContent = result.content
                chapterPattern = result.pattern ?? ""
                updateChapterPreview(pattern: chapterPattern)
            }
        } else if localBookType == .epub {
            let url = fileURL
            let metadata = await Task.detached(priority: .userInitiated) {
                try? SimpleEpubParser.parse(epubURL: url)
            }.value
            await MainActor.run {
                if title == suggestion.title, let value = metadata?.title { title = value }
                if author == (suggestion.author ?? ""), let value = metadata?.author { author = value }
                if selectedCover == nil, let data = metadata?.coverData { selectedCover = UIImage(data: data) }
            }
        }
    }

    /// updateChapterPreview（0x100491e6c L334-341 域确证）。
    private func updateChapterPreview(pattern: String) {
        chapterPreview = LocalBookService.shared.previewChapterTitles(
            content: fileContent, pattern: pattern)
    }

    /// performSave（0x10049156c L349-389 域确证）。
    private func performSave() {
        isSaving = true
        Task {
            let result = await LocalBookService.shared.importBook(
                from: fileURL, title: title, author: author.isEmpty
                    ? nil : author, coverData: selectedCover?.pngData(),
                chapterPattern: useFixedLength ? "" : chapterPattern)
            await MainActor.run {
                isSaving = false
                if result != nil {
                    dismiss()
                } else {
                    importError = "无法读取书籍或保存导入数据。"
                }
            }
        }
    }
}
