// 原路径: ReadMain/Services/ReadingStatisticsService.swift
// 证据:
//   - PGO: 73 条记录（index/task_functions.csv T-501-01 /
//     ReadingStatisticsService.swift；28 个伪代码块）。关键地址：
//     recordSession(bookFingerprint:bookName:durationSeconds:)
//     0x1003696e0 L100-128 / recordListeningSession 0x100369e6c L135-157 /
//     dailyStats(lastDays:) 0x10036a390 L162-199 / bookStats 0x10036ae18
//     L202-227 / dailyStats(year:month:) 0x10036b2dc L230-276 /
//     fileURL(for:)/loadRecords/saveRecords（L60-99 域）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadingStatisticsService.c
//     （6663 行）
//   - 字符串确证（位模式/指针）："[ReadingStats] 加载 " @ptr L203（载入日志）/
//     "写入阅读统计" @ptr L209（写盘日志）/"en_US_POSIX"（L5631，
//     DateFormatter locale 确证）/"%04d-%02d-"（L6489，月键格式确证）/
//     bookStats 大串 0x1012669B0（count 16）/0x101266990（count 22）
//   - 事实：fileURL(for: String)（per 键落盘，appendingPathComponent 确证）+
//     loadRecords（async，JSONDecoder iso8601 DateDecodingStrategy 确证）+
//     saveRecords（NSFileManager defaultManager + URL.path + 
//     Data.init(contentsOf:) 读回确证）；dailyStats(lastDays:) JSON 解码；
//     dailyStats(year:month:) 文件读 + '%04d-%02d-' 月键；统计域
//     （booksThisYear/totalSecondsThisYear/longestStreak/monthlyBreakdown/
//     streakDays/totalStats/todaySeconds/todayListeningSeconds/
//     todayProgress）签名确证；dailyGoalMinutes/yearlyGoalBooks get+set；
//     clearAllRecords ×3 ICF 副本；waitUntilReady
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 存储链/统计口径: high（块体 + 格式串确证）
//   - streak/月度聚合细节: medium-high（签名 + 日历域推断）
// 还原: 2026-11-20

import Foundation

// MARK: - 统计模型

/// 日统计（dailyStats 域确证）。
struct DailyStat: Codable, Identifiable, Equatable {
    var id: String { dayKey }
    let dayKey: String
    var readingSeconds: Int
    var listeningSeconds: Int

    var totalSeconds: Int {
        readingSeconds + listeningSeconds
    }
}

/// 书籍统计（bookStats 域确证）。
struct BookStat: Codable, Identifiable, Equatable {
    var id: String { bookFingerprint }
    let bookFingerprint: String
    let bookName: String
    var totalSeconds: Int
    var lastReadAt: Date
}

/// 汇总统计（totalStats 签名确证）。
struct TotalStat: Equatable {
    var totalSeconds: Int
    var totalBooks: Int
    var longestStreak: Int
    var currentStreak: Int
}

/// 单日会话记录（recordSession 域确证）。
struct ReadingSessionRecord: Codable {
    let bookFingerprint: String
    let bookName: String
    let dayKey: String
    var readingSeconds: Int
    var listeningSeconds: Int
    var updatedAt: Date
}

// MARK: - ReadingStatisticsService

/// 阅读统计服务（per 键落盘 + 日聚合）。
final class ReadingStatisticsService {

    static let shared = ReadingStatisticsService()

    private let lock = NSLock()
    private var records: [ReadingSessionRecord] = []
    private var loaded = false
    private var loadContinuations: [CheckedContinuation<Void, Never>] = []

    private let decoder: JSONDecoder = {
        // iso8601 DateDecodingStrategy 确证。
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init() {}

    // MARK: 存储（fileURL/loadRecords/saveRecords 域确证）

    /// fileURL(for:)（签名确证；appendingPathComponent 确证）。
    private static func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
        return FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0].appendingPathComponent("reading_stats_\(safeKey).json")
    }

    /// loadRecords（async 签名确证；"[ReadingStats] 加载 " @ptr L203）。
    private func loadRecords() async {
        guard !loaded else { return }
        loaded = true
        let files = (try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0],
            includingPropertiesForKeys: nil)) ?? []
        var loadedRecords: [ReadingSessionRecord] = []
        for file in files where file.lastPathComponent.hasPrefix("reading_stats_") {
            if let data = try? Data(contentsOf: file),
               let record = try? decoder.decode(
                    ReadingSessionRecord.self, from: data) {
                loadedRecords.append(record)
            }
        }
        lock.lock()
        records = loadedRecords
        lock.unlock()
        Logger.log(
            "[ReadingStats] 加载 \(loadedRecords.count) 条", level: .info)
        for continuation in loadContinuations {
            continuation.resume()
        }
        loadContinuations.removeAll()
    }

    /// saveRecords（"写入阅读统计" @ptr L209 确证）。
    private func saveRecords() {
        lock.lock()
        let snapshot = records
        lock.unlock()
        for record in snapshot {
            let url = Self.fileURL(for: record.bookFingerprint)
            if let data = try? encoder.encode(record) {
                try? data.write(to: url, options: .atomic)
            }
        }
        Logger.log("写入阅读统计", level: .info)
    }

    /// waitUntilReady（签名确证）。
    func waitUntilReady() async {
        if loaded { return }
        await withCheckedContinuation { continuation in
            lock.lock()
            if loaded {
                lock.unlock()
                continuation.resume()
                return
            }
            loadContinuations.append(continuation)
            lock.unlock()
        }
    }

    // MARK: 记录（recordSession 0x1003696e0 L100-128 域确证）

    /// recordSession(bookFingerprint:bookName:durationSeconds:)（签名确证）。
    func recordSession(
        bookFingerprint: String, bookName: String, durationSeconds: Int
    ) {
        appendSession(
            bookFingerprint: bookFingerprint, bookName: bookName,
            readingSeconds: durationSeconds, listeningSeconds: 0)
    }

    /// recordListeningSession（0x100369e6c L135-157 签名确证）。
    func recordListeningSession(
        bookFingerprint: String, bookName: String, listeningSeconds: Int
    ) {
        appendSession(
            bookFingerprint: bookFingerprint, bookName: bookName,
            readingSeconds: 0, listeningSeconds: listeningSeconds)
    }

    private func appendSession(
        bookFingerprint: String, bookName: String, readingSeconds: Int,
        listeningSeconds: Int
    ) {
        let dayKey = Self.todayKey()
        lock.lock()
        if let index = records.firstIndex(where: {
            $0.bookFingerprint == bookFingerprint
                && $0.dayKey == dayKey
        }) {
            records[index].readingSeconds += readingSeconds
            records[index].listeningSeconds += listeningSeconds
            records[index].updatedAt = Date()
        } else {
            records.append(
                ReadingSessionRecord(
                    bookFingerprint: bookFingerprint, bookName: bookName,
                    dayKey: dayKey, readingSeconds: readingSeconds,
                    listeningSeconds: listeningSeconds, updatedAt: Date()))
        }
        lock.unlock()
        saveRecords()
    }

    // MARK: 日期键（todayKey/dateKey/date 签名确证）

    /// todayKey（static 签名确证）。
    static func todayKey() -> String {
        dateKey(for: Date())
    }

    /// dateKey(for:)（static 签名确证；"%04d-%02d-" 月键格式 + 日域）。
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// date(from:)（static 签名确证）。
    static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    // MARK: 目标（dailyGoalMinutes/yearlyGoalBooks get+set 签名确证）

    var dailyGoalMinutes: Int {
        get {
            UserDefaults.standard.integer(forKey: "dailyGoalMinutes")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "dailyGoalMinutes")
        }
    }

    var yearlyGoalBooks: Int {
        get {
            UserDefaults.standard.integer(forKey: "yearlyGoalBooks")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "yearlyGoalBooks")
        }
    }

    // MARK: 聚合（dailyStats 0x10036a390 L162-199 + 0x10036b2dc L230-276
    // bookStats 0x10036ae18 L202-227 域确证）

    /// dailyStats(lastDays:)（0x10036a390 L162-199 确证）。
    func dailyStats(lastDays: Int) -> [DailyStat] {
        aggregate { dayKey in
            // `date >= X ?? false` 会把 ?? 绑到比较右元——先解包再比较。
            guard let date = Self.date(from: dayKey),
                  let cutoff = Calendar.current.date(
                      byAdding: .day, value: -lastDays, to: Date())
            else { return false }
            return date >= cutoff
        }
    }

    /// dailyStats(year:month:)（0x10036b2dc L230-276 确证）。
    func dailyStats(year: Int, month: Int) -> [DailyStat] {
        let prefix = String(format: "%04d-%02d-", year, month)
        return aggregate { dayKey in
            dayKey.hasPrefix(prefix)
        }
    }

    private func aggregate(_ include: (String) -> Bool) -> [DailyStat] {
        lock.lock()
        let snapshot = records
        lock.unlock()
        var buckets: [String: DailyStat] = [:]
        for record in snapshot where include(record.dayKey) {
            var stat = buckets[record.dayKey] ?? DailyStat(
                dayKey: record.dayKey, readingSeconds: 0,
                listeningSeconds: 0)
            stat.readingSeconds += record.readingSeconds
            stat.listeningSeconds += record.listeningSeconds
            buckets[record.dayKey] = stat
        }
        return buckets.values.sorted { $0.dayKey < $1.dayKey }
    }

    /// bookStats（0x10036ae18 L202-227 确证）。
    func bookStats() -> [BookStat] {
        lock.lock()
        let snapshot = records
        lock.unlock()
        var buckets: [String: BookStat] = [:]
        for record in snapshot {
            let existing = buckets[record.bookFingerprint]
            let total = (existing?.totalSeconds ?? 0)
                + record.readingSeconds + record.listeningSeconds
            let lastAt = max(existing?.lastReadAt ?? .distantPast, record.updatedAt)
            buckets[record.bookFingerprint] = BookStat(
                bookFingerprint: record.bookFingerprint,
                bookName: record.bookName, totalSeconds: total,
                lastReadAt: lastAt)
        }
        return buckets.values.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// booksThisYear（签名确证）。
    func booksThisYear() -> Int {
        let year = Calendar.current.component(.year, from: Date())
        let set = Set(
            inYear(year).map(\.bookFingerprint))
        return set.count
    }

    /// totalSecondsThisYear（签名确证）。
    func totalSecondsThisYear() -> Int {
        let year = Calendar.current.component(.year, from: Date())
        return inYear(year).reduce(0) {
            $0 + $1.readingSeconds + $1.listeningSeconds
        }
    }

    private func inYear(_ year: Int) -> [ReadingSessionRecord] {
        let prefix = String(format: "%04d", year)
        lock.lock()
        let snapshot = records
        lock.unlock()
        return snapshot.filter { $0.dayKey.hasPrefix(prefix) }
    }

    /// longestStreak（签名确证）。
    func longestStreak() -> Int {
        let days = Set(aggregate { _ in true }.map(\.dayKey))
        let dates = days.compactMap { Self.date(from: $0) }.sorted()
        var longest = 0
        var current = 0
        var previous: Date?
        for date in dates {
            if let previous,
               Calendar.current.dateComponents(
                   [.day], from: previous, to: date).day == 1 {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = date
        }
        return longest
    }

    /// streakDays（签名确证）。
    func streakDays() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = Date()
        let keys = Set(aggregate { _ in true }.map(\.dayKey))
        while keys.contains(Self.dateKey(for: cursor)) {
            streak += 1
            guard let previous = calendar.date(
                byAdding: .day, value: -1, to: cursor)
            else { break }
            cursor = previous
        }
        return streak
    }

    /// monthlyBreakdown(year:)（签名确证）。
    func monthlyBreakdown(
        year: Int
    ) -> [(month: Int, totalSeconds: Int, totalBooks: Int)] {
        var result: [(month: Int, totalSeconds: Int, totalBooks: Int)] = []
        for month in 1...12 {
            let stats = dailyStats(year: year, month: month)
            let total = stats.reduce(0) { $0 + $1.totalSeconds }
            let prefix = String(format: "%04d-%02d-", year, month)
            let books = Set(
                inYear(year).filter {
                    $0.dayKey.hasPrefix(prefix)
                }.map(\.bookFingerprint))
            result.append((month: month, totalSeconds: total, totalBooks: books.count))
        }
        return result
    }

    /// totalStats（签名确证）。
    func totalStats() -> TotalStat {
        TotalStat(
            totalSeconds: totalSecondsThisYear(),
            totalBooks: booksThisYear(),
            longestStreak: longestStreak(),
            currentStreak: streakDays())
    }

    // MARK: 今日域（todaySeconds/todayListeningSeconds/todayProgress 签名确证）

    func todaySeconds() -> Int {
        let key = Self.todayKey()
        return aggregate { $0 == key }.first?.readingSeconds ?? 0
    }

    func todayListeningSeconds() -> Int {
        let key = Self.todayKey()
        return aggregate { $0 == key }.first?.listeningSeconds ?? 0
    }

    func todayProgress() -> Double {
        let goal = dailyGoalMinutes
        guard goal > 0 else { return 0 }
        let minutes = Double(todaySeconds() + todayListeningSeconds()) / 60.0
        return min(minutes / Double(goal), 1.0)
    }

    /// clearAllRecords（×3 ICF 副本签名确证）。
    func clearAllRecords() {
        lock.lock()
        records.removeAll()
        lock.unlock()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0],
            includingPropertiesForKeys: nil)) ?? []
        for file in files
        where file.lastPathComponent.hasPrefix("reading_stats_") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
