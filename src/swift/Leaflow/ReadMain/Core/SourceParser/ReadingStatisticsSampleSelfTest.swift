// T-1602：类型表4807/4829及备份0x1002b9f34，统计数组存储与备份往返。
import Foundation

enum ReadingStatisticsSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let identifier = "reading-stats-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        let defaults = UserDefaults(suiteName: identifier)!
        defer {
            defaults.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        do {
            let docs = root.appendingPathComponent("documents")
            let support = root.appendingPathComponent("support")
            let storage = support.appendingPathComponent("ReadingStatistics")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let original = Data(#"[{"bookFingerprint":"original","bookName":"原版字段样本","date":"2024-02-28","durationSeconds":45,"pageCount":3,"chapterCount":1,"estimatedCharCount":900,"listeningSeconds":15,"modifiedAt":"2024-02-28T12:00:00Z"}]"#.utf8)
            let originalRecord = try decoder.decode([ReadingRecord].self, from: original)[0]
            emit("stats_original_record_fields", ["2024-02-28", "45", "3", "1", "900", "15"],
                [originalRecord.dayKey, String(originalRecord.readingSeconds), String(originalRecord.pageCount),
                 String(originalRecord.chapterCount), String(originalRecord.estimatedCharCount), String(originalRecord.listeningSeconds)])
            let object = try JSONSerialization.jsonObject(with: encoder.encode(originalRecord)) as? [String: Any] ?? [:]
            emit("stats_original_encoded_keys", ["bookFingerprint,bookName,chapterCount,date,durationSeconds,estimatedCharCount,listeningSeconds,modifiedAt,pageCount"],
                [object.keys.sorted().joined(separator: ",")])
            try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
            try original.write(to: storage.appendingPathComponent("records.json"))
            var timestamp = ReadingStatisticsService.date(from: "2024-02-29")!
            let service = ReadingStatisticsService(storageDirectory: storage, legacyDirectory: docs, defaults: defaults, now: { timestamp })
            await service.waitUntilReady()
            emit("stats_initial_read_is_ready", ["60"], [String(service.bookStats().first?.totalSeconds ?? -1)])
            service.recordSession(bookFingerprint: "original", bookName: "原版字段样本", durationSeconds: 30,
                                  pageCount: 2, chapterCount: 1, estimatedCharCount: 600)
            service.recordListeningSession(bookFingerprint: "original", bookName: "原版字段样本", listeningSeconds: 20)
            timestamp = ReadingStatisticsService.date(from: "2024-03-01")!
            service.recordSession(bookFingerprint: "original", bookName: "原版字段样本", durationSeconds: 10)
            let restarted = ReadingStatisticsService(storageDirectory: storage, legacyDirectory: docs, defaults: defaults)
            let records = try decoder.decode([ReadingRecord].self, from: restarted.encodedRecordsForBackup())
            emit("stats_cross_day_cold_restart", ["3", "120"], [String(records.count), String(restarted.bookStats().first?.totalSeconds ?? -1)])
            let leapDay = records.first { $0.dayKey == "2024-02-29" }!
            emit("stats_reading_listening_same_day", ["30", "20", "2", "1", "600"],
                [String(leapDay.readingSeconds), String(leapDay.listeningSeconds), String(leapDay.pageCount),
                 String(leapDay.chapterCount), String(leapDay.estimatedCharCount)])
            emit("stats_month_boundary", ["2", "1"], [String(restarted.dailyStats(year: 2024, month: 2).count),
                                                       String(restarted.dailyStats(year: 2024, month: 3).count)])
            service.recordSession(bookFingerprint: "ignored", bookName: "无时长", durationSeconds: -1)
            service.recordListeningSession(bookFingerprint: "ignored", bookName: "无时长", listeningSeconds: 0)
            emit("stats_nonpositive_sessions_ignored", ["3"], [String(try decoder.decode([ReadingRecord].self, from: service.encodedRecordsForBackup()).count)])

            let backup = BackupService(documentsDirectory: docs, applicationSupportDirectory: support, defaults: defaults)
            let tree = root.appendingPathComponent("tree")
            try backup.exportDataTree(to: tree, categories: [.readingStats], incremental: false)
            emit("stats_backup_original_file_name", ["manifest.json,reading_stats.json"],
                [try FileManager.default.contentsOfDirectory(atPath: tree.path).sorted().joined(separator: ",")])
            let restoredSupport = root.appendingPathComponent("restored-support")
            let restore = BackupService(documentsDirectory: root.appendingPathComponent("restored-documents"),
                                        applicationSupportDirectory: restoredSupport, defaults: defaults)
            let archive = root.appendingPathComponent("stats.zip")
            try ZipUtility.createZip(from: tree, to: archive)
            try await restore.restoreBackup(from: archive, categories: [.readingStats])
            let restoredStorage = restoredSupport.appendingPathComponent("ReadingStatistics")
            let restored = ReadingStatisticsService(storageDirectory: restoredStorage, legacyDirectory: docs, defaults: defaults)
            emit("stats_archive_restored_service_reads", ["120", "3"],
                [String(restored.bookStats().first?.totalSeconds ?? -1),
                 String(try decoder.decode([ReadingRecord].self, from: restored.encodedRecordsForBackup()).count)])
            emit("stats_backup_size_matches_file", ["true"],
                [String(backup.estimateBackupSize(categories: [.readingStats]) == Int64(try Data(contentsOf: storage.appendingPathComponent("records.json")).count))])
            try Data(#"[{"bad":"schema"}]"#.utf8).write(to: tree.appendingPathComponent("reading_stats.json"))
            let restoredFile = restoredStorage.appendingPathComponent("records.json")
            let before = try Data(contentsOf: restoredFile)
            var rejected = false
            do { try restore.importDataTree(from: tree, categories: [.readingStats]) } catch { rejected = true }
            emit("stats_invalid_restore_preserves_destination", ["true", "true"],
                [String(rejected), String(try Data(contentsOf: restoredFile) == before)])

            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            try Data(#"{"bookFingerprint":"legacy","bookName":"旧记录","dayKey":"2024-01-01","readingSeconds":17,"listeningSeconds":4,"updatedAt":"2024-01-01T12:00:00Z"}"#.utf8)
                .write(to: docs.appendingPathComponent("reading_stats_legacy.json"))
            let migratedStorage = root.appendingPathComponent("migrated")
            let migrated = ReadingStatisticsService(storageDirectory: migratedStorage, legacyDirectory: docs, defaults: defaults)
            emit("stats_legacy_record_migration", ["21"], [String(migrated.bookStats().first?.totalSeconds ?? -1)])
            migrated.clearAllRecords()
            let cleared = ReadingStatisticsService(storageDirectory: migratedStorage, legacyDirectory: docs, defaults: defaults)
            emit("stats_clear_does_not_reimport_legacy", ["0", "[]"],
                [String(cleared.bookStats().count), String(decoding: try Data(contentsOf: migratedStorage.appendingPathComponent("records.json")), as: UTF8.self)])
            try Data("{".utf8).write(to: migratedStorage.appendingPathComponent("records.json"))
            let damaged = ReadingStatisticsService(storageDirectory: migratedStorage, legacyDirectory: docs, defaults: defaults)
            damaged.recordSession(bookFingerprint: "new", bookName: "新会话", durationSeconds: 10)
            emit("stats_corrupt_storage_not_overwritten", ["true", "{"],
                [String(damaged.lastStorageError != nil), String(decoding: try Data(contentsOf: migratedStorage.appendingPathComponent("records.json")), as: UTF8.self)])
        } catch { emit("stats_archive_restored_service_reads", ["通过"], [error.localizedDescription]) }
    }
}
