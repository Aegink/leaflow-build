// 原路径: ReadMain/Core/ReaderLayoutConfig.swift
// 分册只改变边界，函数、规模、桩仍计入原始文件。
import Foundation
import UIKit
import SwiftUI

/// 类型表2918及0x1001f83fc：使用单调时钟，仅保存本次新增的秒数和计数。
final class ReadingDurationTracker {
    static let shared = ReadingDurationTracker()
    private var activeSegmentStartUptime: TimeInterval?
    private var accumulatedDuration: TimeInterval = 0
    private(set) var currentBookFingerprint: String?
    private var currentBookName: String?
    private(set) var pageTurnCount = 0
    private var sessionChapterCount = 0
    private(set) var accumulatedCharCount = 0
    private var lastSavedDurationSeconds = 0
    private var lastSavedPageCount = 0
    private var lastSavedChapterCount = 0
    private var lastSavedCharCount = 0
    private var pageTurnSamples: [TimeInterval] = []
    private var periodicSaveTimer: Timer?
    private let statistics: ReadingStatisticsService
    private let uptime: () -> TimeInterval
    private let periodicSaveEnabled: Bool

    init(statistics: ReadingStatisticsService = .shared,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         periodicSaveEnabled: Bool = true) {
        self.statistics = statistics
        self.uptime = uptime
        self.periodicSaveEnabled = periodicSaveEnabled
    }

    deinit { periodicSaveTimer?.invalidate() }

    var isActivelyTracking: Bool { currentBookFingerprint != nil && activeSegmentStartUptime != nil }
    var totalDuration: TimeInterval {
        accumulatedDuration + (activeSegmentStartUptime.map { max(0, uptime() - $0) } ?? 0)
    }

    func startSession(bookFingerprint: String, bookName: String) {
        if currentBookFingerprint == bookFingerprint {
            resumeSession()
            return
        }
        endSession()
        currentBookFingerprint = bookFingerprint
        currentBookName = bookName
        accumulatedDuration = 0
        pageTurnCount = 0
        sessionChapterCount = 0
        accumulatedCharCount = 0
        lastSavedDurationSeconds = 0
        lastSavedPageCount = 0
        lastSavedChapterCount = 0
        lastSavedCharCount = 0
        pageTurnSamples.removeAll()
        activeSegmentStartUptime = uptime()
        startPeriodicSave()
    }

    /// 旧调用桥只有已有书籍身份时才能恢复，禁止制造无归属会话。
    func startTracking() { resumeSession() }

    func pauseSession() {
        guard let started = activeSegmentStartUptime else { return }
        accumulatedDuration += max(0, uptime() - started)
        activeSegmentStartUptime = nil
        saveIncremental()
        stopPeriodicSave()
    }

    func resumeSession() {
        guard currentBookFingerprint != nil, activeSegmentStartUptime == nil else { return }
        activeSegmentStartUptime = uptime()
        startPeriodicSave()
    }

    func endSession() {
        pauseSession()
        saveIncremental()
        stopPeriodicSave()
        currentBookFingerprint = nil
        currentBookName = nil
    }

    func saveIncremental() {
        guard let fingerprint = currentBookFingerprint, let name = currentBookName else { return }
        let duration = Int(totalDuration)
        let seconds = duration - lastSavedDurationSeconds
        guard seconds > 0 else { return }
        statistics.recordSession(bookFingerprint: fingerprint, bookName: name,
            durationSeconds: seconds, pageCount: pageTurnCount - lastSavedPageCount,
            chapterCount: sessionChapterCount - lastSavedChapterCount,
            estimatedCharCount: accumulatedCharCount - lastSavedCharCount)
        lastSavedDurationSeconds = duration
        lastSavedPageCount = pageTurnCount
        lastSavedChapterCount = sessionChapterCount
        lastSavedCharCount = accumulatedCharCount
    }

    func recordPageTurn(charCount: Int) {
        guard isActivelyTracking else { return }
        pageTurnCount += 1
        accumulatedCharCount += max(0, charCount)
        pageTurnSamples.append(uptime())
        if pageTurnSamples.count > 20 { pageTurnSamples.removeFirst(pageTurnSamples.count - 20) }
    }

    func recordChapterChange() {
        guard isActivelyTracking else { return }
        sessionChapterCount += 1
    }

    var estimatedSecondsPerPage: Double? {
        guard pageTurnSamples.count >= 3 else { return nil }
        let average = (pageTurnSamples.last! - pageTurnSamples.first!) / Double(pageTurnSamples.count - 1)
        return average > 3 && average < 600 ? average : nil
    }

    func estimateRemainingMinutes(remainingPages: Int) -> Int? {
        guard let perPage = estimatedSecondsPerPage else { return nil }
        return Int(perPage * Double(max(remainingPages, 0)) / 60)
    }

    private func startPeriodicSave() {
        stopPeriodicSave()
        guard periodicSaveEnabled else { return }
        // 0x1001f89b0：每60秒保存；弱引用不延长阅读会话寿命。
        periodicSaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.saveIncremental()
        }
    }

    private func stopPeriodicSave() {
        periodicSaveTimer?.invalidate()
        periodicSaveTimer = nil
    }
}

/// 正文就绪后计时；离开页面或后台暂停，旧页面不能结束新书的会话。
struct ReadingStatisticsLifecycleModifier: ViewModifier {
    let bookFingerprint: String?
    let bookName: String
    let pageIndex: Int
    let chapterIndex: Int
    let charCount: Int
    let isReady: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .onAppear { visible = true; synchronize() }
            .onDisappear {
                visible = false
                if ownsSession { ReadingDurationTracker.shared.endSession() }
            }
            .onChange(of: isReady) { _, _ in synchronize() }
            .onChange(of: bookFingerprint) { _, _ in synchronize() }
            .onChange(of: scenePhase) { _, _ in synchronize() }
            .onChange(of: pageIndex) { _, _ in
                if ownsSession && isReady { ReadingDurationTracker.shared.recordPageTurn(charCount: charCount) }
            }
            .onChange(of: chapterIndex) { _, _ in
                if ownsSession && isReady { ReadingDurationTracker.shared.recordChapterChange() }
            }
    }

    private var ownsSession: Bool {
        bookFingerprint != nil && ReadingDurationTracker.shared.currentBookFingerprint == bookFingerprint
    }

    private func synchronize() {
        let tracker = ReadingDurationTracker.shared
        if visible, isReady, scenePhase == .active, let bookFingerprint {
            tracker.startSession(bookFingerprint: bookFingerprint, bookName: bookName)
        } else if ownsSession { tracker.pauseSession() }
    }
}

// MARK: - 听书时长跟踪

/// 听书时长跟踪（0x1001f8e48/0x1001f9018/0x1001f9080/0x1001ef300 域；
/// 与 ReadingDurationTracker 同构，音频会话域）。
final class ListeningDurationTracker {
    static let shared = ListeningDurationTracker()
    private var accumulatedDuration: TimeInterval = 0
    private var sessionStart: TimeInterval?
    private var bookFingerprint: String?
    private var bookName: String?
    private var lastSavedSeconds = 0
    private var periodicSaveTimer: Timer?
    private let statistics: ReadingStatisticsService
    private let uptime: () -> TimeInterval
    private let periodicSaveEnabled: Bool

    init(statistics: ReadingStatisticsService = .shared,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         periodicSaveEnabled: Bool = true) {
        self.statistics = statistics
        self.uptime = uptime
        self.periodicSaveEnabled = periodicSaveEnabled
    }

    deinit { periodicSaveTimer?.invalidate() }
    var isActivelyTracking: Bool { bookFingerprint != nil && sessionStart != nil }
    var totalDuration: TimeInterval { accumulatedDuration + (sessionStart.map { max(0, uptime() - $0) } ?? 0) }

    /// 0x1001f8e48：同书继续，换书先结算原会话。
    func startSession(bookFingerprint: String, bookName: String) {
        guard !bookFingerprint.isEmpty else { return }
        if self.bookFingerprint == bookFingerprint { self.bookName = bookName; resumeSession(); return }
        endSession()
        self.bookFingerprint = bookFingerprint
        self.bookName = bookName
        accumulatedDuration = 0
        lastSavedSeconds = 0
        resumeSession()
    }

    func pauseSession() {
        guard let start = sessionStart else { return }
        accumulatedDuration += max(uptime() - start, 0)
        sessionStart = nil
        saveIncremental()
        periodicSaveTimer?.invalidate()
        periodicSaveTimer = nil
    }

    func resumeSession() {
        guard bookFingerprint != nil, sessionStart == nil else { return }
        sessionStart = uptime()
        if periodicSaveEnabled {
            periodicSaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.saveIncremental()
            }
        }
    }

    func endSession() {
        pauseSession()
        saveIncremental()
        bookFingerprint = nil
        bookName = nil
    }

    /// 0x1001f90c4：整数累计秒数减去上次保存值，传给recordListeningSession。
    func saveIncremental() {
        guard let bookFingerprint, let bookName else { return }
        let seconds = Int(totalDuration)
        guard seconds > lastSavedSeconds else { return }
        statistics.recordListeningSession(bookFingerprint: bookFingerprint, bookName: bookName,
            listeningSeconds: seconds - lastSavedSeconds)
        lastSavedSeconds = seconds
    }
}
