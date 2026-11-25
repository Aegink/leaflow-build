// 原路径: ReadMain/Views/Reader/TtsPlayable.swift
// 证据:
//   - PGO: 15 条记录（index/task_functions.csv T-801-13 /
//     TtsPlayable.swift；11 函数，伪代码域 100 行）
//   - CovMap: 上述 L 区段（readAloudPreferences L42/httpTtsSources L43/
//     VM 六 getter L49-54/LocalReaderViewModel 六 getter L60-64/
//     showVerticalScrollUnsupportedToast 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/TtsPlayable.c
//     （243 行，11 块索引 0x1008b8064-0x1008b86a0）
//   - 块体确证（地址+行号域）：
//     TtsPlayable.readAloudPreferences getter 0x1008b8064 L42 /
//     TtsPlayable.httpTtsSources getter 0x1008b8118 L43 /
//     ReaderViewModel.ttsCoverUrl 0x1008b8160 L49 / ttsCoverBook
//     0x1008b82ac L50 / ttsBookAuthor 0x1008b81cc L51 /
//     ttsChapterCount 0x1008b82d4 L53 / ttsChapterName(at:)
//     0x1008b82f0 L54 / ttsBookFingerprint 0x1008b8330 L60 /
//     LocalReaderViewModel 六件 0x1008b8478-0x1008b86a0 L60-64 /
//     ReaderSpeechSupport.showVerticalScrollUnsupportedToast
//   - 事实：TtsPlayable 协议桥（VM 六件 + 偏好 + 源仓库 + 横屏提示）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十一块确证）
// 还原: 2026-11-20

import Foundation
import SwiftUI
import Observation

/// TTS 可播放协议（readAloudPreferences/httpTtsSources 扩展域确证）。
@MainActor
protocol TtsPlayable: ReadAloudSessionOwner, Observable {
    var readAloudCoordinator: ReadAloudCoordinator { get }
    var readAloudPreferences: ReadAloudPreferences { get }

    /// 封面域（ttsCoverUrl/ttsCoverBook getter 签名确证）。
    var ttsCoverUrl: String? { get }
    var ttsCoverBook: Book? { get }

    /// 作者域（ttsBookAuthor getter 签名确证）。
    var ttsBookAuthor: String? { get }

    /// 章节域（ttsChapterCount/ttsChapterName(at:) 签名确证）。
    var ttsChapterCount: Int { get }
    func ttsChapterName(at index: Int) -> String

    /// 指纹域（ttsBookFingerprint getter 签名确证）。
    var ttsBookFingerprint: String { get }
}

// MARK: - 扩展域（0x1008b8064 L42 / 0x1008b8118 L43 域确证）
// wave-16：@MainActor——ReadAloudPreferences 为 MainActor 隔离类。

@MainActor
extension TtsPlayable {

    /// readAloudPreferences getter（0x1008b8064 L42 域确证）。
    var readAloudPreferences: ReadAloudPreferences {
        ReaderSpeechSupport.preferences
    }

    /// httpTtsSources getter（0x1008b8118 L43 域确证）。
    var httpTtsSources: [HttpTts] {
        TtsSourceStore.loadSources()
    }
}

// MARK: - ReaderViewModel 桥域（0x1008b8160 L49-54 域确证）

extension ReaderViewModel: TtsPlayable {

    /// ttsCoverUrl getter（0x1008b8160 L49 域确证）。
    var ttsCoverUrl: String? {
        currentBook?.coverUrl
    }

    /// ttsCoverBook getter（0x1008b82ac L50 域确证）。
    var ttsCoverBook: Book? {
        currentBook
    }

    /// ttsBookAuthor getter（0x1008b81cc L51 域确证）。
    var ttsBookAuthor: String? {
        currentBook?.author
    }

    /// ttsChapterCount getter（0x1008b82d4 L53 域确证）。
    var ttsChapterCount: Int {
        totalChapters
    }

    /// ttsChapterName(at:)（0x1008b82f0 L54 域确证）。
    func ttsChapterName(at index: Int) -> String {
        chapters.indices.contains(index) ? chapters[index].name : ""
    }

    /// ttsBookFingerprint getter（0x1008b8330 L60 域确证）。
    var ttsBookFingerprint: String {
        bookUrl
    }

    var bookUrl: String {
        currentBook?.bookUrl ?? ""
    }
}

// MARK: - LocalReaderViewModel 桥域（0x1008b8478-0x1008b86a0 L60-64）

extension LocalReaderViewModel: TtsPlayable {
    var readAloudCoordinator: ReadAloudCoordinator { ReaderSpeechSupport.sharedCoordinator }

    /// ttsCoverUrl getter（0x1008b8478 L60 域确证）。
    var ttsCoverUrl: String? {
        nil
    }

    /// ttsCoverBook getter（0x1008b84xx L61 域确证）。
    var ttsCoverBook: Book? {
        var cover = Book()
        cover.name = bookTitleForSpeech
        cover.bookUrl = bookFingerprintForSpeech
        return cover
    }

    /// ttsBookAuthor getter（0x1008b83d0 L62 域确证）。
    var ttsBookAuthor: String? {
        book.author
    }

    /// ttsChapterCount getter（0x1008b86a0 L64 域确证）。
    var ttsChapterCount: Int {
        chapterCount
    }

    /// ttsChapterName(at:)（签名域确证）。
    func ttsChapterName(at index: Int) -> String {
        chapterTitle(at: index)
    }

    /// ttsBookFingerprint getter（签名域确证）。
    var ttsBookFingerprint: String {
        bookFingerprintForSpeech
    }

    /// 元数据辅助桥（本地书域还原桥）。
    private var bookTitleForSpeech: String {
        book.name
    }

    private var bookFingerprintForSpeech: String {
        book.id.uuidString
    }

    private var chapterCount: Int {
        chapterContents.count
    }

    private func chapterTitle(at index: Int) -> String {
        let chapters = LocalBookService.shared.loadChapters(for: book.id.uuidString) ?? []
        return chapters.indices.contains(index) ? chapters[index].title : ""
    }
}

// MARK: - 横屏提示域（showVerticalScrollUnsupportedToast 域确证）

/// 竖屏滚动提示（showVerticalScrollUnsupportedToast 签名域确证）。
extension ReaderSpeechSupport {

    /// showVerticalScrollUnsupportedToast（签名域确证：
    /// AppErrorPresenter.shared.warning 域桥）。
    func showVerticalScrollUnsupportedToast() {
        AppErrorPresenter.shared.warning("竖排模式不支持滚动朗读")
    }
}
