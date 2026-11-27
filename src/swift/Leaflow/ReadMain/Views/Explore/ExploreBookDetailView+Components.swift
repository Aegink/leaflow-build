// 原路径: ReadMain/Views/Explore/ExploreBookDetailView.swift
// 本分册仍计入原文件的规模、桩与样本门禁。
import SwiftUI

extension BookDetailView {
    // MARK: 头部

    /// headerSection（0x1004b6584 L440-485 域确证）。
    var headerSection: some View {
        HStack(alignment: .top, spacing: 12.0) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 90.0, height: 120.0)
                .overlay {
                    Image(systemName: "book.fill")
                        .foregroundColor(.secondary)
                }
            VStack(alignment: .leading, spacing: 6.0) {
                Text(displayBook.name)
                    .appThemeText(.title)
                if let author = displayBook.author {
                    Label(author, systemImage: "person.fill")
                        .appThemeText(.caption, opacity: 0.7)
                }
                // 源状态域（"源变量" L3597 域交叉）。
                HStack(spacing: 6.0) {
                    SourceFeatureTag(
                        title: hasLogin ? "已登录" : "未登录",
                        enabled: hasLogin)
                    if let storage = displayBook.sourceStorageKind {
                        Text(storage.label)
                            .appThemeText(.caption, opacity: 0.6)
                    }
                }
                // "更新于 " L8090 域确证。
                if let update = displayBook.lastChapter {
                    Text("更新于 \(update)")
                        .appThemeText(.caption, opacity: 0.6)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    /// metadataBar（0x1004b6c70 L560-576 域确证）。
    var metadataBar: some View {
        HStack(spacing: 8.0) {
            groupMetadataItem
            metadataDivider
            bookTypeMetadataItem
            metadataDivider
            updateMetadataItem
        }
        .padding(.vertical, 6.0)
    }

    /// metadataDivider（0x1004c8628 L578-582 域确证）。
    var metadataDivider: some View {
        Divider().frame(height: 24.0)
    }

    /// metadataLabel(icon:title:value:color:)（签名确证）。
    func metadataLabel(
        icon: String, title: String, value: String, color: Color
    ) -> some View {
        HStack(spacing: 6.0) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1.0) {
                Text(title)
                    .appThemeText(.caption, opacity: 0.6)
                Text(value)
                    .appThemeText(.caption)
            }
        }
    }

    /// groupMetadataItem（0x1004c2f18 L584-597 域确证）。
    var groupMetadataItem: some View {
        metadataLabel(
            icon: "folder.fill", title: "分组",
            value: normalizedBookshelfGroupName(displayBook.group),
            color: .blue)
    }

    /// bookTypeMetadataItem（0x1004df6ec L599-621 域确证）。
    var bookTypeMetadataItem: some View {
        metadataLabel(
            icon: currentBookTypeOption.icon,
            title: "类型", value: currentBookTypeOption.title,
            color: currentBookTypeOption.color)
    }

    /// updateMetadataItem（0x1004c3998 L623-636 域确证；"skipUpdate" L3058）。
    var updateMetadataItem: some View {
        metadataLabel(
            icon: BookDetailState.skipsUpdate(displayBook) ? "bell.slash" : "bell.fill",
            title: "更新", value: updateToggleValue, color: .orange)
    }

    // MARK: 动作行

    /// actionButtonsRow（签名确证；"开始阅读" L4660 + "书架" L4967 域）。
    var actionButtonsRow: some View {
        HStack(spacing: 10.0) {
            Button {
                onRead(displayBook)
            } label: {
                Label("开始阅读", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                if isInBookshelf {
                    deleteConfirmBook = displayBook
                } else {
                    bookService.addBook(displayBook, useReplaceRule: true, preferredCoverUrl: nil)
                }
            } label: {
                Label(
                    isInBookshelf ? "在书架" : "书架",
                    systemImage: isInBookshelf ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("book-detail-shelf")
        }
        .disabled(!ready)
    }

    // MARK: 章节

    /// chapterOverview（0x1004b6e04 L705-782 域确证）。
    @ViewBuilder
    var chapterOverview: some View {
        infoCard(icon: "list.bullet", title: "目录") {
            if isLoadingChapters {
                HStack(spacing: 8.0) {
                    ProgressView()
                    Text("加载目录中...")
                        .appThemeText(.caption, opacity: 0.6)
                }
            } else if chapters.isEmpty {
                Text("暂无目录信息")
                    .appThemeText(.caption, opacity: 0.6)
            } else {
                let visible = chaptersExpanded
                    ? chapters : Array(chapters.prefix(6))
                ForEach(
                    Array(visible.enumerated()), id: \.1.index
                ) { index, chapter in
                    chapterRow(
                        chapter,
                        label: chapter.name,
                        isFirst: index == 0 && !chaptersExpanded,
                        isLast: index == visible.count - 1)
                }
                Button {
                    chaptersExpanded.toggle()
                } label: {
                    // "展开全部" L6626 域确证。
                    Text(chaptersExpanded ? "收起" : "展开全部")
                        .appThemeText(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// chapterRow（0x1004cabbc L784-807 域确证；"lock.fill" L8459 VIP 域）。
    @ViewBuilder
    func chapterRow(
        _ chapter: Chapter, label: String, isFirst: Bool, isLast: Bool
    ) -> some View {
        Button {
            readFromChapter(chapter)
        } label: {
            HStack {
                Text(label)
                    .lineLimit(1)
                Spacer()
                if chapter.isVip || chapter.showsLockedIndicator {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6.0)
        }
        .buttonStyle(.plain)
    }

    /// readFromChapter（0x1004ba124 L809-830 域确证）。
    func readFromChapter(_ chapter: Chapter) {
        var target = displayBook
        target.durChapterTitle = chapter.name
        onRead(target)
    }

    // MARK: 换源卡

    /// inlineSourcesCard（0x1004b83c0 L877-925 域确证）。
    @ViewBuilder
    var inlineSourcesCard: some View {
        infoCard(icon: "arrow.triangle.swap", title: "换源") {
            VStack(spacing: 4.0) {
                ForEach(
                    Array(inlineSourceRows.enumerated()), id: \.1.bookUrl
                ) { index, candidate in
                    inlineSourceRow(
                        candidate,
                        isLast: index == inlineSourceRows.count - 1)
                }
                if shouldShowInlineSourceOverflowButton {
                    // "查看全部 N 个来源" L10312 + L9806 域确证。
                    Button {
                        // TODO(T-601-01): 换源列表页接入（ChangeSourceView）。
                    } label: {
                        Text("查看全部 \(inlineSourceTotalCount) 个来源")
                            .appThemeText(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    /// inlineSourceRow（0x1004ddfdc L928-998 域确证）。
    @ViewBuilder
    func inlineSourceRow(_ candidate: Book, isLast: Bool) -> some View {
        Button {
            Task { await refreshAfterSourceChange(candidate) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2.0) {
                    HStack(spacing: 6.0) {
                        Text(sourceName(for: candidate))
                            .lineLimit(1)
                        if let kind = candidate.sourceStorageKind {
                            sourceModeTag(for: kind)
                        }
                    }
                    if let latest = candidate.lastChapter {
                        Text(latest)
                            .appThemeText(.caption, opacity: 0.6)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if candidate.bookUrl == displayBook.bookUrl {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 6.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// sourceModeTag(for:)（0x1004cedc4 L1001-1019 域确证）。
    @ViewBuilder
    func sourceModeTag(for kind: StorageKind) -> some View {
        Text(kind.label)
            .appThemeText(.caption)
            .padding(.horizontal, 6.0)
            .padding(.vertical, 1.0)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(4, antialiased: true)
    }

    /// sourceName(for:)（签名确证）。
    func sourceName(for book: Book) -> String {
        guard let url = book.bookSourceUrl else { return "未知来源" }
        return BookDetailState.source(for: book, service: sourceService)?.bookSourceName
            ?? simplifiedBookSourceUrl(url)
    }

    /// simplifiedBookSourceUrl（签名确证；"https://" L9457 域确证）。
    func simplifiedBookSourceUrl(_ url: String) -> String {
        var trimmed = url
        for prefix in ["https://", "http://"] where trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    /// sourceName getter（签名确证）。
    var sourceName: String? {
        bookSource?.bookSourceName
    }

    // MARK: 信息卡

    /// infoCard(icon:title:content:)（签名确证）。
    @ViewBuilder
    func infoCard<Content: View>(
        icon: String, title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Label(title, systemImage: icon)
                .appThemeText(.headline)
            content()
        }
        .padding(.all, 12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    /// introCard（签名确证）。
    @ViewBuilder
    func introCard(_ text: String) -> some View {
        if !text.isEmpty {
            infoCard(icon: "doc.plaintext", title: "简介") {
                Text(text)
                    .appThemeText(.caption, opacity: 0.8)
            }
        }
    }

}
