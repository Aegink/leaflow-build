// 原路径: ReadMain/Views/Bookshelf/BookActionSheetView.swift
// PGO: 信息/动作/缓存/变量编辑域，地址与原始分册内各段注释对应。
import SwiftUI

extension BookActionSheetView {
    // MARK: 信息卡（0x1003f8b10 L380-445 域确证）

    /// bookInfoCard getter（0x1003f8b10 L380-445 域确证）。
    var bookInfoCard: some View {
        HStack(spacing: 10.0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 50.0, height: 70.0)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundColor(.secondary)
                }
            VStack(alignment: .leading, spacing: 4.0) {
                Text(latestBook.name)
                    .appThemeText(.headline)
                if let author = latestBook.author {
                    Text(author)
                        .appThemeText(.caption, opacity: 0.6)
                }
                if let source = bookSource?.bookSourceName {
                    // "building.columns" @ptr L4879 域确证。
                    Label(source, systemImage: "building.columns")
                        .appThemeText(.caption, opacity: 0.6)
                }
                if hasLogin {
                    Text("已登录")
                        .appThemeText(.caption)
                        .foregroundColor(.green)
                }
            }
            Spacer()
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    /// bookTypePicker（0x1003f8c14 L460-492 域确证；"bookType" L4005 域）。
    var bookTypePicker: some View {
        Picker("类型", selection: .constant(book.bookType)) {
            Text("文本").tag(0)
            Text("音频").tag(8)
            Text("图片").tag(16)
        }
        .pickerStyle(.segmented)
    }

    // MARK: 动作按钮（0x1003f9334 L500-556 域确证）

    /// actionButtons getter（0x1003f9334 L500-556 域确证）。
    var actionButtons: some View {
        VStack(spacing: 8.0) {
            Button {
                onRead(latestBook)
            } label: {
                Label("开始阅读", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            // 0x10040b328 L558-584 actionButton 签名确证。
            actionButton(icon: "pin.fill", title: "置顶") {
                bookService.togglePinned(book.id)
            }
            actionButton(icon: "arrow.triangle.2.circlepath", title: "刷新目录") {
                refreshChapterList()
            }
            actionButton(icon: "info.circle", title: "刷新书籍信息") {
                refreshBookInfo()
            }
            actionButton(icon: "photo", title: "换封面") {
                showChangeCover = true
            }
            actionButton(icon: "pencil", title: "编辑书籍") {
                // 编辑域（"编辑书籍" L314 确证）→ BookEditView。
                showBookEdit = true
            }
        }
    }

    /// actionButton(icon:title:action:)（0x10040b328 L558-584 域确证）。
    private func actionButton(
        icon: String, title: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    // MARK: 缓存域（0x1003f9434 L588-655 域确证）

    /// downloadAllSection getter（0x1003f9434 L588-655 域确证）。
    var downloadAllSection: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            if let progress = progressText {
                HStack {
                    ProgressView(value: Double(
                        CacheDownloadManager.shared.cachedCount))
                    Text(progress)
                        .appThemeText(.caption, opacity: 0.6)
                }
            } else {
                Button {
                    downloadAllChapters()
                } label: {
                    // "arrow.down.circle" @ptr L6073 域确证。
                    Label("缓存全部章节", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                // "可能需要较长时间。" @ptr L9463 域确证。
                Text("可能需要较长时间。")
                    .appThemeText(.caption, opacity: 0.5)
            }
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    // MARK: 高级域（0x1003f95c8 L659-688 域确证）

    /// advancedOptions getter（0x1003f95c8 L659-688 域确证）。
    var advancedOptions: some View {
        VStack(spacing: 4.0) {
            advancedRow(icon: "curlybraces", title: "源变量") {
                sourceVariableText = currentSourceVariable()
                showVariableEditor = true
            }
            advancedRow(icon: "curlybraces.square", title: "书籍变量") {
                bookVariableText = book.variable ?? ""
                showBookVariableEditor = true
            }
            advancedRow(icon: "bell.slash", title: "跳过更新") {
                toggleSkipUpdate()
            }
            advancedRow(icon: "arrow.triangle.2.circlepath", title: "刷新章节") {
                refreshChapterList()
            }
            advancedRow(icon: "trash", title: "清除缓存") {
                clearBookCache()
            }
            Button("从书架删除", role: .destructive) { showDeleteConfirm = true }
            advancedRow(icon: "pencil.and.list.clipboard", title: "配置登录") {
                // TODO(T-401-06 域): SourceLoginView 接入。
            }
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    /// advancedRow(icon:title:action:)（0x100412258 L690-713 域确证）。
    private func advancedRow(
        icon: String, title: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24.0)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: 动作域（0x10040319c L717-730 + 0x1004034cc L734-755 域确证）

    /// refreshChapterList（0x10040319c L717-730 域确证）。
    private func refreshChapterList() {
        Task {
            _ = try? await bookService.getChapterList(
                for: book, useReplaceRule: false, needRefresh: true)
        }
    }

    /// refreshBookInfo（0x1004034cc L734-755 域确证）。
    private func refreshBookInfo() {
        guard let source = bookSource else { return }
        Task {
            _ = await sourceService.getBookInfo(
                source: source, book: book, canReName: false)
        }
    }

    /// toggleSkipUpdate（0x1004036b4 L759-764 域确证；"skipUpdate" L3989）。
    private func toggleSkipUpdate() {
        var updated = book
        updated.skipUpdate = !(updated.skipUpdate ?? false)
        bookService.updateBook(updated)
    }

    /// clearBookCache（0x1003fc0ec L768-770 域确证）。
    private func clearBookCache() {
        ChapterCacheService.shared.clearCache(bookUrl: book.bookUrl ?? "")
    }

    /// downloadAllChapters（0x1003fc6ec L774-780 域确证）。
    private func downloadAllChapters() {
        CacheDownloadManager.shared.start(
            book: book, bookService: bookService,
            chapterCache: ChapterCacheService.shared)
    }

    // MARK: 变量编辑器（0x1004120a0 L784-831 域确证）

    /// variableEditorSheet（0x1004120a0 L784-831 域确证）。
    var variableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("源变量")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $sourceVariableText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveSourceVariable() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("源变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showVariableEditor = false }
                }
            }
        }
    }

    /// bookVariableEditorSheet（0x1003fab88 L835-882 域确证；
    /// "书籍变量 (bookVariable)" @ptr L10381 域确证）。
    var bookVariableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("书籍变量 (bookVariable)")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $bookVariableText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveBookVariable() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("书籍变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showBookVariableEditor = false }
                }
            }
        }
    }

    /// saveSourceVariable（0x1004097d4 L886-893 域确证）。
    private func saveSourceVariable() {
        // TODO(T-501-01 交叉): RemoteBackendService.setVariable 写回。
        showVariableEditor = false
    }

    /// saveBookVariable（签名确证）。
    private func saveBookVariable() {
        var updated = book
        updated.variable = bookVariableText
        bookService.updateBook(updated)
        showBookVariableEditor = false
    }

    /// saveBingCoverLocally（0x1003faff4 L895-909 域确证）。
    private func saveBingCoverLocally(
        _ image: UIImage, bookId: String
    ) {
        guard let data = image.pngData() else { return }
        LocalBookCoverCache.shared.saveCover(data: data, for: bookId)
    }

}
