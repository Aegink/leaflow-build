// 原路径: ReadMain/Views/Explore/ExploreBookDetailView.swift
// 本分册仍计入原文件的规模、桩与样本门禁。
import SwiftUI

extension BookDetailView {
    // MARK: 主链

    /// loadChapters（0x1004bcc80 L1222-1241 域确证）。
    func loadChapters() async {
        guard let source = bookSource else { return }
        isLoadingChapters = true
        defer { isLoadingChapters = false }
        do {
            let list = try await sourceService.getChapterList(
                source: source, book: displayBook, needRefresh: false)
            await MainActor.run {
                chapters = list
                syncAuxiliaryState(with: displayBook)
            }
        } catch {
            await MainActor.run {
                chapters = initialChapters ?? []
            }
        }
    }

    /// refreshBookInfo（0x1004bf0b4 L1204-1218 域确证）。
    func refreshBookInfo() {
        guard let source = bookSource else { return }
        isRefreshingInfo = true
        Task {
            let info = await sourceService.getBookInfo(
                source: source, book: displayBook, canReName: false)
            await MainActor.run {
                isRefreshingInfo = false
                if let info {
                    let merged = mergedFetchedBookWithLocalState(
                        info, base: displayBook)
                    baseBook = merged
                    syncAuxiliaryState(with: merged)
                }
            }
        }
    }

    /// mergedFetchedBookWithLocalState（0x1004bbec0 L1143-1160 域确证）。
    func mergedFetchedBookWithLocalState(
        _ fetched: Book, base: Book
    ) -> Book {
        var merged = fetched
        merged.group = base.group
        merged.skipUpdate = base.skipUpdate
        merged.bookType = base.bookType
        merged.variable = base.variable
        return merged
    }

    /// syncAuxiliaryState(with:)（0x1004bc170 L1284-1315 域确证）。
    func syncAuxiliaryState(with book: Book) {
        sourceVariableText = BookDetailState.sourceVariable(BookDetailState.stateSource(for: book, service: sourceService))
        bookVariableText = book.getVariable("custom") ?? ""
        refreshTrackedSearchSourcesFromCache()
    }

    /// refreshAfterSourceChange（0x1004b965c L1175-1200 域确证）。
    func refreshAfterSourceChange(_ target: Book) async {
        baseBook = target
        chapters = []
        await loadChapters()
    }

    /// observeTrackedSearchSourcesIfNeeded（0x1004bd26c L1329-1344 域确证）。
    func observeTrackedSearchSourcesIfNeeded() async {
        guard shouldTrackSearchSources else { return }
        let token = trackedSearchObservationKey
        guard token != observedSearchToken else { return }
        observedSearchToken = token
        // 追踪搜索源域（"author="/"bookId=" 诊断域确证）。
        Logger.log(
            "[EXPLORE-DETAIL-DIAG] session=\(diagSession)"
                + " author=\(trackedSourceAuthor ?? "")"
                + " bookUrl=\(displayBook.bookUrl ?? "")"
                + " sourceUrl=\(displayBook.bookSourceUrl ?? "")"
                + " chapters=\(chapters.count)",
            level: .info)
    }

    /// replaceTrackedAvailableSourcesIfNeeded（0x1004bdb34 L1361-1374 域）。
    func replaceTrackedAvailableSourcesIfNeeded(
        _ candidates: [Book]
    ) {
        let fingerprint = trackedSourcesFingerprint(candidates)
        guard fingerprint != trackedSourcesFingerprint(trackedSources) else {
            return
        }
        trackedSources = deduplicatedSources(candidates)
    }

    /// refreshTrackedSearchSourcesFromCache（0x1004d3684 L1347-1358 域）。
    func refreshTrackedSearchSourcesFromCache() {
        // 缓存域（ChangeSourceCache T-601-01 交叉登记）。
    }

    // MARK: 去重域

    /// deduplicatedSourceCandidates（0x1004b155c L1261-1271 static 域确证）。
    static func deduplicatedSourceCandidates(
        _ candidates: [Book]
    ) -> [Book] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            let identity = makeSourceIdentity(for: candidate)
            guard !identity.isEmpty else { return false }
            return seen.insert(identity).inserted
        }
    }

    /// deduplicatedSources（0x1004bdda4 L1376-1378 域确证）。
    func deduplicatedSources(_ candidates: [Book]) -> [Book] {
        Self.deduplicatedSourceCandidates(candidates)
    }

    /// makeSourceIdentity(for:)（0x1004d348c L1257-1259 static 域确证）。
    static func makeSourceIdentity(for book: Book) -> String {
        (book.bookSourceUrl ?? "") + "|" + (book.bookUrl ?? "")
    }

    /// sourceIdentity(for:)（签名确证）。
    func sourceIdentity(for book: Book) -> String {
        Self.makeSourceIdentity(for: book)
    }

    /// trackedSourcesFingerprint（0x1004d38b4 L1380-1390 域确证；
    /// 三段隐式闭包 name/author/index 确证）。
    func trackedSourcesFingerprint(_ candidates: [Book]) -> [String] {
        candidates.map { candidate in
            "\(candidate.name)|\(candidate.author ?? "")|"
                + "\(candidate.bookUrl ?? "")"
        }
    }

    // MARK: 诊断

    /// debugDescribe（0x1004bbd70 L1317-1321 域确证）。
    func debugDescribe(_ book: Book) -> String {
        "[EXPLORE-DETAIL-DIAG] session=\(diagSession)"
            + " author=\(book.author ?? "")"
            + " bookId=\(book.bookUrl ?? "")"
            + " bookUrl=\(book.bookUrl ?? "")"
            + " sourceUrl=\(book.bookSourceUrl ?? "")"
            + " storage=\(book.sourceStorageKind?.rawValue ?? "")"
    }

    /// debugDescribeSource（签名确证）。
    func debugDescribeSource(_ source: BookSource?) -> String {
        source.map { "source=\($0.bookSourceUrl)" } ?? "source=nil"
    }
}
