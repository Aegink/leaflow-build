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
                    .disabled(title.isEmpty || isSaving)
            }
        }
        .onAppear {
            Task { await loadInitialData() }
        }
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
            Toggle("按固定长度分章", isOn: .constant(false))
                .disabled(true)
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
                    ? nil : author, coverData: selectedCover?.pngData())
            await MainActor.run {
                isSaving = false
                if result != nil {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - 文件名元数据解析（签名域确证）

/// 文件名元数据解析器（七步链确证）。
enum LocalBookFilenameMetadataParser {

    /// suggestion(for:)（签名确证）。
    static func suggestion(
        for url: URL
    ) -> (title: String, author: String?) {
        parse(from: normalizedFileStem(for: url))
    }

    /// normalizedFileStem（0x100497c5c… static 域确证）。
    static func normalizedFileStem(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    /// parse(from:)（0x10049939c L407-428 static 域确证）。
    static func parse(from stem: String) -> (title: String, author: String?) {
        // parseQuotedTitle L430-442 域确证。
        if let quoted = parseQuotedTitle(stem) {
            return (title: quoted.title, author: quoted.author)
        }
        // parseExplicitAuthor L444-460 域确证。
        if let explicit = parseExplicitAuthor(stem) {
            return (title: explicit.title, author: explicit.author)
        }
        // parseSeparated L462-477 域确证。
        let separators = CharacterSet(charactersIn: "-_—–|｜")
        let parts = stem
            .components(separatedBy: separators)
            .map { clean($0) }
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            return resolve(parts: parts)
        }
        // parseSpaceSeparated L479-499 域确证。
        let spaceParts = stem
            .components(separatedBy: .whitespaces)
            .map { clean($0) }
            .filter { !$0.isEmpty }
        if spaceParts.count >= 2 {
            return resolve(parts: spaceParts)
        }
        return (title: clean(stem), author: nil)
    }

    /// parseQuotedTitle（0x100499778 L430-442 static 域确证）。
    static func parseQuotedTitle(
        _ stem: String
    ) -> (title: String, author: String?)? {
        guard let open = stem.firstIndex(of: "《"),
              let close = stem.firstIndex(of: "》"),
              open < close
        else { return nil }
        let title = String(stem[stem.index(after: open)..<close])
        let tail = String(stem[stem.index(after: close)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let author = tail.isEmpty ? nil : clean(tail)
        return (
            title: title,
            author: (author?.isEmpty ?? true) ? nil : author)
    }

    /// parseExplicitAuthor（0x100499dd0 L444-460 static 域确证）。
    static func parseExplicitAuthor(
        _ stem: String
    ) -> (title: String, author: String?)? {
        guard let range = stem.range(of: "作者：") ?? stem.range(of: "作者:") else {
            return nil
        }
        let authorPart = String(stem[range.upperBound...])
        let titlePart = String(stem[..<range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_—– "))
        return (title: clean(titlePart), author: clean(authorPart))
    }

    /// parseSeparated（0x10049a46c L462-477 static 域确证）。
    static func parseSeparated(
        _ stem: String
    ) -> (title: String, author: String?)? {
        nil
    }

    /// parseSpaceSeparated（0x10049ad2c L479-499 static 域确证）。
    static func parseSpaceSeparated(
        _ stem: String
    ) -> (title: String, author: String?)? {
        nil
    }

    /// resolve(parts:)（0x10049bdf4 L501-523 static 域确证）。
    static func resolve(
        parts: [String]
    ) -> (title: String, author: String?) {
        guard let first = parts.first else {
            return (title: "", author: nil)
        }
        if parts.count >= 2, isLikelyAuthor(parts[1]) {
            return (title: first, author: parts[1])
        }
        return (title: first, author: nil)
    }

    /// isLikelyAuthor（0x10049c5c0 L534-555 static 域确证）。
    static func isLikelyAuthor(_ text: String) -> Bool {
        text.count <= 10 && !text.contains("第")
    }

    /// removeAuthorMarker（static 签名确证）。
    static func removeAuthorMarker(_ text: String) -> String {
        text.replacingOccurrences(of: "作者：", with: "")
            .replacingOccurrences(of: "作者:", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// clean（static 签名确证）。
    static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Bing 封面搜索（签名域确证）

/// Bing 图片搜索视图。
struct BingImageSearchView: View {

    let onSelect: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [BingImageResult] = []
    @State private var isSearching = false

    /// placeholder getter（0x1004a0550 L652-660 域确证）。
    private var placeholder: String {
        "搜索封面图片"
    }

    var body: some View {
        // 0x10049d35c L578-650 域确证。
        NavigationStack {
            VStack(spacing: 12.0) {
                HStack {
                    TextField(placeholder, text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button {
                        performSearch()
                    } label: {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(query.isEmpty || isSearching)
                }
                .padding(.horizontal, 16.0)
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible()), count: 3),
                        spacing: 8.0) {
                        ForEach(results) { result in
                            Button {
                                Task { await downloadAndSelect(result) }
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(uiColor: .tertiarySystemFill))
                                    .aspectRatio(0.72, contentMode: .fit)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 12.0)
                }
            }
            .navigationTitle("搜索封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    /// performSearch（0x1004a4d04 L662-677 域确证）。
    private func performSearch() {
        let query = query.trimmingCharacters(in: .whitespaces) + " 小说封面"
        isSearching = true
        Task {
            let found = try? await BingImageSearchService.search(
                query: query, count: 30)
            await MainActor.run {
                results = found ?? []
                isSearching = false
            }
        }
    }

    /// downloadAndSelect（0x1004a0a18 L679-696 域确证）。
    private func downloadAndSelect(_ result: BingImageResult) async {
        guard let url = URL(string: result.url),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data)
        else { return }
        await MainActor.run {
            onSelect(image)
            dismiss()
        }
    }
}

/// Bing 图片结果（parseImageResults 域确证）。
struct BingImageResult: Identifiable, Codable {
    var id: String { url }
    let url: String
    let thumbnailUrl: String?
}

/// Bing 图片搜索服务（search L709-723 + parseImageResults L726-764 域确证）。
enum BingImageSearchService {

    /// search(query:count:)（0x1004a1754 L709-723 static 域确证）。
    static func search(
        query: String, count: Int
    ) async throws -> [BingImageResult] {
        // "turl"/"murl" JSON 正则确证。
        var components = URLComponents(string: "https://www.bing.com/images/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "\(count)"),
        ]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        // 'Safari/604.1' @ptr L8809 UA 域确证。
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                + "Version/15.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return parseImageResults(from: html, count: count)
    }

    /// parseImageResults(from:count:)（0x1004a1d50 L726-764 static 域确证）。
    static func parseImageResults(
        from html: String, count: Int
    ) -> [BingImageResult] {
        var results: [BingImageResult] = []
        // '"turl"\s*:\s*"([^"]+)"' @ptr L7422 域确证。
        guard
            let turlRegex = try? NSRegularExpression(
                pattern: "\"turl\"\\s*:\\s*\"([^\"]+)\""),
            let murlRegex = try? NSRegularExpression(
                pattern: "\"murl\"\\s*:\\s*\"([^\"]+)\"")
        else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let murls = murlRegex.matches(in: html, range: range)
        for match in murls.prefix(count) {
            guard let urlRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            let url = String(html[urlRange])
                .replacingOccurrences(of: "\\/", with: "/")
            results.append(BingImageResult(url: url, thumbnailUrl: nil))
        }
        return results
    }
}
