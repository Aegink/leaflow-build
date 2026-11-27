// T-1602：原版NSFileCoordinator归档与manifest根定位，验证完整目录往返。
import Foundation

enum BackupArchiveSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("backup-archive-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            let source = root.appendingPathComponent("原始备份")
            let resources = source.appendingPathComponent("Books/中文目录")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            let manifest = Data(#"{"version":1,"sample":"固定备份","counts":{"books":1}}"#.utf8)
            try manifest.write(to: source.appendingPathComponent("manifest.json"))
            let bytes = Data([0, 1, 255, 13, 10, 128])
            try bytes.write(to: resources.appendingPathComponent("封面.bin"))
            try "固定嵌套正文".write(to: resources.appendingPathComponent("书籍.txt"), atomically: true, encoding: .utf8)
            let archive = root.appendingPathComponent("output.zip")
            try Data("旧归档".utf8).write(to: archive)
            try ZipUtility.createZip(from: source, to: archive)
            let destination = root.appendingPathComponent("extracted")
            try ZipUtility.extractZip(from: archive, to: destination)
            let backup = BackupService()
            let restored = try backup.resolveBackupRoot(in: destination)
            emit("backup_archive_nested_binary", ["true", "固定嵌套正文"],
                [String(try Data(contentsOf: restored.appendingPathComponent("Books/中文目录/封面.bin")) == bytes),
                 try String(contentsOf: restored.appendingPathComponent("Books/中文目录/书籍.txt"), encoding: .utf8)])
            emit("backup_archive_manifest_bytes", ["true"], [String(try Data(contentsOf: restored.appendingPathComponent("manifest.json")) == manifest)])
            emit("backup_root_direct_manifest", [source.path], [try backup.resolveBackupRoot(in: source).path])
            let preview = try backup.previewBackup(from: archive)
            emit("backup_archive_preview_manifest", ["固定备份", "1"], [preview["sample"] as? String ?? "", String(preview["version"] as? Int ?? -1)])
            let empty = root.appendingPathComponent("no-manifest")
            try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
            var rejected = false
            do { _ = try backup.resolveBackupRoot(in: empty) } catch { rejected = true }
            emit("backup_root_missing_rejected", ["true", "0"], [String(rejected),
                String(try FileManager.default.contentsOfDirectory(at: empty, includingPropertiesForKeys: nil).count)])
            try "更新正文".write(to: resources.appendingPathComponent("书籍.txt"), atomically: true, encoding: .utf8)
            try ZipUtility.createZip(from: source, to: archive)
            let second = root.appendingPathComponent("second")
            try ZipUtility.extractZip(from: archive, to: second)
            let secondRoot = try backup.resolveBackupRoot(in: second)
            emit("backup_archive_overwrite", ["更新正文"], [try String(contentsOf: secondRoot.appendingPathComponent("Books/中文目录/书籍.txt"), encoding: .utf8)])
            var missingRejected = false
            do { try ZipUtility.createZip(from: root.appendingPathComponent("missing"), to: root.appendingPathComponent("missing.zip")) }
            catch { missingRejected = true }
            emit("backup_archive_missing_source", ["true"], [String(missingRejected)])
            let emptyArchive = root.appendingPathComponent("empty.zip")
            try ZipUtility.createZip(from: empty, to: emptyArchive)
            let emptyOutput = root.appendingPathComponent("empty-output")
            try ZipUtility.extractZip(from: emptyArchive, to: emptyOutput)
            let entries = FileManager.default.enumerator(at: emptyOutput, includingPropertiesForKeys: [.isRegularFileKey])
            let files = (entries?.allObjects as? [URL] ?? []).filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            emit("backup_empty_directory_roundtrip", ["0"], [String(files.count)])
        } catch { emit("backup_archive_nested_binary", ["通过"], [error.localizedDescription]) }
    }
}
