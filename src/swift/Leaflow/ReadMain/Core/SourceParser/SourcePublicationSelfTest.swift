// T-1602：复现629批IPS的设置通知→重载→Published链，所有UI发布必须在主线程。
import Foundation
import Combine

enum SourcePublicationSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("source-publication-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var source = BookSource(bookSourceUrl: "https://sample.invalid/publication", bookSourceName: "线程发布样本")
            source.storageKind = .local
            try JSONEncoder().encode([source]).write(to: directory.appendingPathComponent("BookSources.json"))
            let service = SourceService(storageDirectory: directory)
            let recorded = PublicationRecorder()
            let observation = service.$bookSources.dropFirst().sink { _ in recorded.record() }
            defer { observation.cancel() }
            await Task.detached { await service.loadLocalSources() }.value
            emit("source_background_load_publishes_on_main", ["true", "0", "线程发布样本"],
                [String(recorded.count > 0), String(recorded.violations), service.bookSources.first?.bookSourceName ?? ""])
            let before = recorded.count
            await Task.detached { NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil) }.value
            await ReadAloudSampleSelfTest.until { recorded.count > before }
            emit("source_settings_notification_publishes_on_main", ["true", "0"],
                [String(recorded.count > before), String(recorded.violations)])
            source.bookSourceName = "保存发布样本"
            let snapshot = source
            let saved = await Task.detached { await service.saveBookSources([snapshot]) }.value
            emit("source_background_save_publishes_on_main", ["true", "0", "保存发布样本"],
                [String(saved), String(recorded.violations), service.bookSources.first?.bookSourceName ?? ""])
            emit("source_publication_setup", ["成功"], ["成功"])
        } catch { emit("source_publication_setup", ["成功"], [error.localizedDescription]) }
    }
}

private final class PublicationRecorder {
    private let lock = NSLock()
    private var events = 0
    private var failures = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return events }
    var violations: Int { lock.lock(); defer { lock.unlock() }; return failures }
    func record() {
        lock.lock()
        events += 1
        if !Thread.isMainThread { failures += 1 }
        lock.unlock()
    }
}
