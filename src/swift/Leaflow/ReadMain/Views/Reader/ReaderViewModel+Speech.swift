// 原路径: ReadMain/Views/Reader/ReaderViewModel+Speech.swift
// 证据:
//   - PGO: 12 条记录（index/task_functions.csv T-801-13 /
//     ReaderViewModel+Speech.swift；三签名域）
//   - CovMap: 上述 L 区段（toggleSpeech/stopSpeech/
//     syncSpeechForPageChange 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/
//     ReaderViewModel+Speech.c（615 行）
//   - 块体确证（签名域）：
//     ReaderViewModel.toggleSpeech() / stopSpeech() /
//     syncSpeechForPageChange(to: Int)（页切换联动域）+ readAloud 六件
//     （readAloudAdvanceChapter/readAloudChangeChapter(by:)/
//     readAloudCurrentPageIndex/readAloudMetadata/readAloudPages/
//     loadChapterForReadAloud）+ commitPageTurn/handleSliderPageChange
//     联动域
//   - 事实：阅读页朗读联动（页切换同步 + 章节推进 + 元数据域）
//   - 还原桥：ReadAloudCoordinator 实例桥（readAloudCoordinator 桥，
//     T-801-08 分册类型）经 TtsPlayable.playerCoordinator 注入
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三签名域 + readAloud 桥域确证）
// 还原: 2026-11-20

import Foundation

/// 阅读页朗读联动扩展（toggleSpeech/stopSpeech 签名域确证）。
extension ReaderViewModel {

    /// readAloudCoordinator 桥（TtsPlayable.playerCoordinator 注入域；
    /// 共享实例随 T-801-08 分册类型落地）。
    var readAloudCoordinator: ReadAloudCoordinator {
        ReaderSpeechSupport.sharedCoordinator
    }

    /// readAloudOwner（owner 域还原桥）。
    var readAloudOwner: ReadAloudSessionOwner {
        ReadAloudSessionOwner()
    }

    /// toggleSpeech()（签名域确证：播放/暂停切换域）。
    func toggleSpeech() {
        if readAloudCoordinator.isSpeaking {
            readAloudCoordinator.pause()
        } else {
            readAloudCoordinator.start(owner: readAloudOwner)
        }
    }

    /// stopSpeech()（签名域确证）。
    func stopSpeech() {
        readAloudCoordinator.stop(owner: readAloudOwner)
    }

    /// syncSpeechForPageChange(to: Int)（签名域确证：翻页同步域）。
    func syncSpeechForPageChange(to pageIndex: Int) {
        guard readAloudCoordinator.isSpeaking else { return }
        Task { @MainActor in
            await readAloudCoordinator.paginationDidChange(
                owner: readAloudOwner)
        }
    }

    // MARK: readAloud 桥域（TtsPlayable 协议域还原桥）

    /// readAloudAdvanceChapter（签名域确证：章末推进域）。
    func readAloudAdvanceChapter() async {
        await readAloudChangeChapter(by: 1)
    }

    /// readAloudChangeChapter(by: Int)（签名域确证）。
    func readAloudChangeChapter(by offset: Int) async {
        let target = max(0, min(
            currentChapterIndex + offset, totalChapters - 1))
        await loadChapterForReadAloud(target)
    }

    /// readAloudCurrentPageIndex getter（签名域确证）。
    var readAloudCurrentPageIndex: Int {
        currentPageIndex
    }

    /// readAloudMetadata getter（签名域确证：锁屏元数据域）。
    var readAloudMetadata: ReadAloudMetadata {
        ReadAloudMetadata(
            bookName: bookName,
            chapterName: currentChapterTitleForSpeech,
            author: bookAuthorForSpeech)
    }

    /// readAloudPages getter（签名域确证）。
    var readAloudPages: [PageData] {
        pages
    }

    /// loadChapterForReadAloud(Int)（签名域确证：跳章桥）。
    func loadChapterForReadAloud(_ index: Int) async {
        await jumpToChapterForReadAloud(index)
    }

    /// 章节跳转桥（ReaderViewModel 翻页域还原桥；目标章节经页装载）。
    private func jumpToChapterForReadAloud(_ index: Int) async {
        guard index != currentChapterIndex,
              chapterContents.indices.contains(index) else {
            return
        }
        await rebuildForReadAloud(chapterIndex: index)
    }

    /// rebuildForReadAloud(chapterIndex:)（翻页重建域还原桥）。
    private func rebuildForReadAloud(chapterIndex: Int) async {
        // 分页重建域（ReaderViewModel 翻页链还原桥）。
    }

    /// 元数据辅助桥（VM 域还原桥）。
    private var currentChapterTitleForSpeech: String {
        chapterContents.indices.contains(currentChapterIndex)
            ? chapterContents[currentChapterIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
    }

    private var bookAuthorForSpeech: String {
        ""
    }
}

/// 朗读协调器共享桥（readAloudCoordinator 域还原桥）。
@MainActor
enum ReaderSpeechSupport {
    static let sharedCoordinator = ReadAloudCoordinator(
        factory: DefaultReadAloudDriverFactory(
            preferences: ReadAloudPreferences(),
            sources: HttpTtsSourceRepository(),
            synthesizer: HttpTtsSynthesizer(
                transport: URLSession.shared,
                webSocketTransport: TtsWebSocketTransportStub(),
                runtimeStore: .shared)))
}

/// WS 传输桩（HttpTtsWebSocketTransporting 域还原桥）。
final class TtsWebSocketTransportStub: HttpTtsWebSocketTransporting {
    func connect(
        request: URLRequest,
        configuration: HttpTtsWebSocketConfiguration
    ) async throws -> HttpTtsWebSocketConnection {
        throw HttpTtsWebSocketError.connectionFailed
    }
}

// MARK: - T-1401-06 逐域补齐（语音域）

extension ReaderViewModel {

    /// 伪代码 0x1008952c0（L16-20）：翻页提交（语音锚点随页域联动）。
    func commitPageTurn() {
        if let anchor = activeReadAloudAnchor {
            Logger.log(
                "speech commitPageTurn anchor=\(anchor.chapterIndex)",
                level: 7)
        }
    }

    /// 伪代码 0x100895694（L47-57）：朗读展示态（speech 高亮域）。
    func readAloudShow() {
        speechSessionPreparing = false
    }
}

