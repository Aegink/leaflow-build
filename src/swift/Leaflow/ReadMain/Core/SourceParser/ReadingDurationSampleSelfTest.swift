// T-1602：注入单调时钟和隔离统计服务，验证实际增量存储，不等待真实时间。
import Foundation

enum ReadingDurationSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) {
        let identifier = "duration-sample-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        let defaults = UserDefaults(suiteName: identifier)!
        defer {
            defaults.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        do {
            let statistics = ReadingStatisticsService(storageDirectory: root.appendingPathComponent("statistics"),
                legacyDirectory: root.appendingPathComponent("legacy"), defaults: defaults)
            var uptime: TimeInterval = 100
            let tracker = ReadingDurationTracker(statistics: statistics, uptime: { uptime }, periodicSaveEnabled: false)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            func record(_ name: String) throws -> ReadingRecord? {
                try decoder.decode([ReadingRecord].self, from: statistics.encodedRecordsForBackup()).first { $0.bookFingerprint == name }
            }
            tracker.saveIncremental()
            emit("duration_without_session_no_epoch", ["0.0", "0"], [String(tracker.totalDuration), String(statistics.bookStats().count)])
            tracker.startSession(bookFingerprint: "first", bookName: "第一本")
            uptime = 101.4
            tracker.recordPageTurn(charCount: 300)
            tracker.recordChapterChange()
            tracker.saveIncremental()
            tracker.saveIncremental()
            emit("duration_incremental_no_double_count", ["1", "1", "1", "300"],
                [String(try record("first")?.readingSeconds ?? -1), String(try record("first")?.pageCount ?? -1),
                 String(try record("first")?.chapterCount ?? -1), String(try record("first")?.estimatedCharCount ?? -1)])
            uptime = 102.5
            tracker.saveIncremental()
            emit("duration_fraction_carried_forward", ["2"], [String(try record("first")?.readingSeconds ?? -1)])
            tracker.pauseSession()
            uptime = 500
            tracker.saveIncremental()
            tracker.recordPageTurn(charCount: 900)
            emit("duration_background_time_excluded", ["2", "1", "false"],
                [String(try record("first")?.readingSeconds ?? -1), String(tracker.pageTurnCount), String(tracker.isActivelyTracking)])
            tracker.resumeSession()
            uptime = 503.5
            tracker.endSession()
            let listening = ListeningDurationTracker(statistics: statistics, uptime: { uptime }, periodicSaveEnabled: false)
            var idleTimerStates: [Bool] = []
            let activity = DefaultReadAloudActivityTracker(listening: listening, setIdleTimerDisabled: { idleTimerStates.append($0) })
            activity.resume()
            listening.saveIncremental()
            emit("listening_no_owner_no_session", ["false", "0"], [String(listening.isActivelyTracking), String(idleTimerStates.count)])
            uptime = 600
            activity.start(metadata: .init(bookName: "听书甲", bookFingerprint: "audio-first"))
            uptime = 602.5
            listening.saveIncremental()
            listening.saveIncremental()
            emit("listening_incremental_no_double_count", ["2", "0"],
                [String(try record("audio-first")?.listeningSeconds ?? -1), String(try record("audio-first")?.readingSeconds ?? -1)])
            activity.pause()
            uptime = 800
            listening.saveIncremental()
            emit("listening_pause_excludes_silence", ["2", "false"],
                [String(try record("audio-first")?.listeningSeconds ?? -1), String(listening.isActivelyTracking)])
            activity.resume()
            uptime = 803.5
            activity.end()
            emit("listening_activity_end_flush", ["6", "true,false,true,false"],
                [String(try record("audio-first")?.listeningSeconds ?? -1), idleTimerStates.map(String.init).joined(separator: ",")])
            activity.start(metadata: .init(bookName: "听书乙", bookFingerprint: "audio-second"))
            uptime = 806.5
            activity.start(metadata: .init(bookName: "听书丙", bookFingerprint: "audio-third"))
            emit("listening_switch_saves_previous_book", ["3", "6"],
                [String(try record("audio-second")?.listeningSeconds ?? -1), String(try record("audio-first")?.listeningSeconds ?? -1)])
            uptime = 808.5
            activity.end()
            activity.end()
            emit("listening_repeated_end_idempotent", ["2", "false"],
                [String(try record("audio-third")?.listeningSeconds ?? -1), String(listening.isActivelyTracking)])
            emit("duration_end_flushes_once", ["6", "false"],
                [String(try record("first")?.readingSeconds ?? -1), String(tracker.isActivelyTracking)])
            tracker.endSession()
            emit("duration_repeated_end_idempotent", ["6"], [String(try record("first")?.readingSeconds ?? -1)])
            uptime = 503.5
            tracker.startSession(bookFingerprint: "second", bookName: "第二本")
            uptime = 505.5
            tracker.startSession(bookFingerprint: "second", bookName: "第二本")
            uptime = 507.5
            tracker.startSession(bookFingerprint: "third", bookName: "第三本")
            emit("duration_book_switch_separates_totals", ["6", "4", "0.0"],
                [String(try record("first")?.readingSeconds ?? -1), String(try record("second")?.readingSeconds ?? -1), String(tracker.totalDuration)])
            uptime = 400
            tracker.saveIncremental()
            emit("duration_clock_regression_clamped", ["0.0", "true"], [String(tracker.totalDuration), String(try record("third") == nil)])
            uptime = 510
            tracker.recordPageTurn(charCount: 100)
            uptime = 520
            tracker.recordPageTurn(charCount: 100)
            uptime = 530
            tracker.recordPageTurn(charCount: 100)
            emit("duration_page_rate_estimate", ["10.0", "2"],
                [String(tracker.estimatedSecondsPerPage ?? -1), String(tracker.estimateRemainingMinutes(remainingPages: 12) ?? -1)])
            tracker.endSession()
        } catch { emit("duration_incremental_no_double_count", ["通过"], [error.localizedDescription]) }
    }
}
