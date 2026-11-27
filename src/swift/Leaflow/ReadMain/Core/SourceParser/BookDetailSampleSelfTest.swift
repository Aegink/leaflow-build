// T-1602：详情生产状态变换、书架身份与来源选择；落盘/冷启动另由UI实测覆盖。
import Foundation

enum BookDetailSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) {
        let service = SourceService()
        let sourceURL = "https://sample.invalid/detail-state"
        var source = BookSource(bookSourceUrl: sourceURL, bookSourceName: "本地详情源")
        source.storageKind = .local
        var remote = source
        remote.storageKind = .remote
        remote.bookSourceName = "远程详情源"
        service.bookSources = [remote, source]
        var book = Book(bookUrl: "/book", name: "详情状态样本", bookSourceUrl: sourceURL,
            durChapterIndex: 3, group: "原分组", sourceStorageKind: .local)
        book.id_ = "持久化编号"
        var stored = book
        stored.id_ = "另一个编号"
        stored.durChapterIndex = 8
        var otherSource = stored
        otherSource.bookSourceUrl = sourceURL + "/other"
        emit("detail_bookshelf_identity", ["8", "/book", "/book"],
            [String(BookDetailState.bookshelfBook(for: book, bookshelf: [otherSource, stored])?.durChapterIndex ?? -1),
             BookDetailState.identity(Book(bookUrl: "/book")),
             BookDetailState.identity(Book(bookUrl: "/book", bookSourceUrl: ""))])
        emit("detail_source_storage_selection", ["本地详情源"],
            [BookDetailState.source(for: book, service: service)?.bookSourceName ?? ""])
        let fallback = BookDetailState.stateSource(for: Book(bookSourceUrl: sourceURL + "/missing"), service: service)
        emit("detail_state_source_fallback", [sourceURL + "/missing", "local", "true"],
            [fallback?.bookSourceUrl ?? "", fallback?.storageKind.rawValue ?? "",
             String(BookDetailState.stateSource(for: Book(), service: service) == nil)])
        book.putVariable("unrelated", value: "保留")
        let audio = BookDetailState.selectingType(1, in: book)
        emit("detail_type_variable", ["1", "保留", "持久化编号", "3"],
            [audio.getVariable("bookType") ?? "", audio.getVariable("unrelated") ?? "", audio.id,
             String(audio.durChapterIndex ?? -1)])
        emit("detail_type_reader_consistency", ["true", "true", "2"],
            [String(ReaderRouter.isAudioSource(audio, sourceService: service)),
             String(ReaderRouter.isMangaSource(BookDetailState.selectingType(2, in: book), sourceService: service)),
             String(BookDetailState.selectedType(BookDetailState.selectingType(2, in: book), service: service))])
        let skipped = BookDetailState.togglingUpdate(in: audio)
        let resumed = BookDetailState.togglingUpdate(in: skipped)
        emit("detail_update_toggle", ["true", "true", "false", "1"],
            [skipped.getVariable("skipUpdate") ?? "", String(resumed.getVariable("skipUpdate") == nil),
             String(BookDetailState.skipsUpdate(resumed)), resumed.getVariable("bookType") ?? ""])
        var wrongCase = book
        wrongCase.putVariable("skipUpdate", value: "TRUE")
        emit("detail_update_exact_value", ["false"], [String(BookDetailState.skipsUpdate(wrongCase))])
        let custom = BookDetailState.settingCustomVariable(" 自定义值\n", in: skipped)
        emit("detail_custom_preserves_metadata", [" 自定义值\n", "1", "true", "保留", "原分组"],
            [custom.getVariable("custom") ?? "", custom.getVariable("bookType") ?? "",
             custom.getVariable("skipUpdate") ?? "", custom.getVariable("unrelated") ?? "", custom.group ?? ""])
        let cleared = BookDetailState.settingCustomVariable("", in: custom)
        emit("detail_custom_empty_removes_only_custom", ["true", "1", "true"],
            [String(cleared.getVariable("custom") == nil), cleared.getVariable("bookType") ?? "",
             cleared.getVariable("skipUpdate") ?? ""])
        emit("detail_group_normalization", ["true", "true", "分组甲"],
            [String(BookDetailState.normalizedGroup(nil) == nil), String(BookDetailState.normalizedGroup(" \n") == nil),
             BookDetailState.normalizedGroup(" \n分组甲\n ") ?? ""])
        let previous = BookSource.readState("sourceVariable_", source: source)
        defer { BookSource.writeState("sourceVariable_", source: source, value: previous) }
        BookDetailState.saveSourceVariable("{\"tab\":\"漫画\"}", source: source)
        emit("detail_source_variable_read_write", ["{\"tab\":\"漫画\"}", "true"],
            [BookDetailState.sourceVariable(source), String(ReaderRouter.isMangaSource(book, sourceService: service))])
        BookDetailState.saveSourceVariable(" \n", source: source)
        emit("detail_source_variable_preserves_whitespace", [" \n"], [BookDetailState.sourceVariable(source)])
        BookDetailState.saveSourceVariable("", source: source)
        emit("detail_source_variable_remove", ["true", "", ""],
            [String(BookSource.readState("sourceVariable_", source: source) == nil),
             BookDetailState.sourceVariable(source), BookDetailState.sourceVariable(nil)])
    }
}
