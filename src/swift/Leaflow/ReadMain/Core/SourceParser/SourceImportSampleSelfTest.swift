// T-1602：实际调用生产导入/落盘/重载，仅隔离目录与远程 I/O。
import Foundation

enum SourceImportSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: directory) }
            let service = SourceService(storageDirectory: directory)
            let malformed = ["{", "{}", "[]", "[{}]", "{\"bookSourceUrl\":\"https://sample.invalid\"}"]
            var rejected = true
            for text in malformed {
                let count = await service.importSourcesAsync(from: text, storageKind: .local)
                rejected = rejected && count == -1 && service.bookSources.isEmpty
            }
            emit("source_import_validation", ["true", "false"],
                [String(rejected), String(manager.fileExists(atPath: service.sourcesFileURL.path))])

            let first = await service.importSourcesAsync(from: json("第一版"), storageKind: .local)
            let firstDisk = service.loadSourcesFromDisk()
            emit("source_import_local_roundtrip", ["1", "1", "第一版", "local"],
                [String(first), String(firstDisk.count), firstDisk.first?.bookSourceName ?? "",
                    firstDisk.first?.storageKind.rawValue ?? ""])

            let update = await service.importSourcesAsync(from: "[" + json("第二版") + "]", storageKind: .local)
            emit("source_import_duplicate_update", ["0", "1", "第二版"],
                [String(update), String(service.bookSources.count), service.bookSources.first?.bookSourceName ?? ""])

            let third = await service.importSourcesAsync(from: json("第三版"), storageKind: .local)
            let backup = try JSONDecoder().decode([BookSource].self, from: Data(contentsOf: service.sourcesBackupURL))
            emit("source_import_backup_rotation", ["0", "第三版", "第二版"],
                [String(third), service.loadSourcesFromDisk().first?.bookSourceName ?? "",
                    backup.first?.bookSourceName ?? ""])

            let reloaded = SourceService(storageDirectory: directory)
            await reloaded.loadLocalSources()
            await reloaded.loadLocalSources()
            emit("source_import_reload_idempotent", ["1", "第三版"],
                [String(reloaded.bookSources.filter { $0.storageKind == .local }.count),
                    reloaded.bookSources.first(where: { $0.storageKind == .local })?.bookSourceName ?? ""])

            let failedDirectory = directory.appendingPathComponent("普通文件")
            try Data().write(to: failedDirectory)
            let failedWrite = SourceService(storageDirectory: failedDirectory)
            let failedCount = await failedWrite.importSourcesAsync(from: json("不能保存"), storageKind: .local)
            emit("source_import_write_failure", ["-1", "0", "true"],
                [String(failedCount), String(failedWrite.bookSources.count),
                    String(failedWrite.lastImportError?.isEmpty == false)])

            let remoteDirectory = directory.appendingPathComponent("remote")
            let probe = SourceImportProbe()
            let remote = SourceService(storageDirectory: remoteDirectory, saveRemoteSources: { sources in
                await probe.save(sources)
            })
            let task = Task { @MainActor in
                await remote.importSourcesAsync(from: json("远程版"), storageKind: .remote)
            }
            await probe.waitForStart()
            let duplicate = await remote.importSourcesAsync(from: json("不应发送"), storageKind: .remote)
            var unrelated = BookSource(bookSourceUrl: "https://sample.invalid/unrelated", bookSourceName: "并发编辑")
            unrelated.storageKind = .local
            remote.bookSources.append(unrelated)
            probe.release()
            let remoteCount = await task.value
            emit("source_import_remote_commit", ["1", "remote", "false"],
                [String(remoteCount), probe.sources.first?.storageKind.rawValue ?? "",
                    String(manager.fileExists(atPath: remote.sourcesFileURL.path))])
            emit("source_import_reentry_latest_list", ["-1", "2", "并发编辑", "远程版"],
                [String(duplicate), String(remote.bookSources.count), remote.bookSources.first?.bookSourceName ?? "",
                    remote.bookSources.last?.bookSourceName ?? ""])

            // 同 URL 的本地/远程域分别保留，导入文件的 storageKind 不得篡改用户目标。
            service.bookSources.append(contentsOf: probe.sources)
            let scoped = await service.importSourcesAsync(from: json("本地更新"), storageKind: .local)
            let localDisk = service.loadSourcesFromDisk()
            emit("source_import_storage_isolation", ["0", "2", "1", "local"],
                [String(scoped), String(service.bookSources.count), String(localDisk.count),
                    localDisk.first?.storageKind.rawValue ?? ""])

            let remoteFailure = SourceService(storageDirectory: remoteDirectory, saveRemoteSources: { _ in
                throw URLError(.cannotConnectToHost)
            })
            let failedRemote = await remoteFailure.importSourcesAsync(from: json("不能上传"), storageKind: .remote)
            emit("source_import_remote_failure", ["-1", "0", "false"],
                [String(failedRemote), String(remoteFailure.bookSources.count),
                    String(manager.fileExists(atPath: remoteFailure.sourcesFileURL.path))])
        } catch {
            emit("source_import_setup", ["成功"], [error.localizedDescription])
            return
        }
        emit("source_import_setup", ["成功"], ["成功"])
    }

    private static func json(_ name: String) -> String {
        #"{"bookSourceUrl":"https://sample.invalid/import","bookSourceName":""#
            + name + #"","storageKind":"remote","searchUrl":"/search?q={{key}}"}"#
    }
}

@MainActor
private final class SourceImportProbe {
    var sources: [BookSource] = []
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var saveWaiter: CheckedContinuation<Void, Never>?

    func save(_ sources: [BookSource]) async {
        self.sources = sources
        started = true
        startWaiter?.resume()
        startWaiter = nil
        await withCheckedContinuation { saveWaiter = $0 }
    }

    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func release() {
        saveWaiter?.resume()
        saveWaiter = nil
    }
}
