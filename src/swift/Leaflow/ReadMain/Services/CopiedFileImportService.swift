// 原路径: ReadMain/Services/CopiedFileImportService.swift
// 证据:
//   - PGO: 32 条记录（index/task_functions.csv T-901-03 /
//     CopiedFileImportService.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（init(stagingDirectory:startAccessing:)/
//     copyFiles/copyFile/removeAbandonedCopies 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/
//     CopiedFileImportService.c（924 行）
//   - 块体确证（签名域）：
//     init(stagingDirectory: URL, startAccessing: ...) / copyFiles(
//     ...多参域) / copyFile(URL) throws / removeAbandonedCopies()
//   - 事实：外部文件拷贝桥（安全域书签 → 暂存目录 + 遗留清理域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（四签名域确证）
// 还原: 2026-11-20

import Foundation

/// 外部文件拷贝服务（init/copyFiles/copyFile/removeAbandonedCopies
/// 签名域确证）。
final class CopiedFileImportService {

    private let stagingDirectory: URL
    private let startAccessing: (URL) -> Bool

    /// init(stagingDirectory:startAccessing:)（签名域确证）。
    init(
        stagingDirectory: URL,
        startAccessing: @escaping (URL) -> Bool = { $0
            .startAccessingSecurityScopedResource() }
    ) {
        self.stagingDirectory = stagingDirectory
        self.startAccessing = startAccessing
    }

    /// copyFiles（签名域确证：多文件拷贝，返回暂存 URL 列表）。
    func copyFiles(from sourceURLs: [URL]) throws -> [URL] {
        try fileManager.createDirectory(
            at: stagingDirectory, withIntermediateDirectories: true)
        var copied: [URL] = []
        for source in sourceURLs {
            copied.append(try copyFile(source))
        }
        return copied
    }

    /// copyFile(URL) throws（签名域确证：安全域 + 拷贝域）。
    func copyFile(_ source: URL) throws -> URL {
        let secured = startAccessing(source)
        defer { if secured { source.stopAccessingSecurityScopedResource() } }
        let fileName = uniqueName(for: source.lastPathComponent)
        let destination = stagingDirectory.appendingPathComponent(fileName)
        try fileManager.copyItem(at: source, to: destination)
        return destination
    }

    /// removeAbandonedCopies（签名域确证：遗留暂存清理域）。
    func removeAbandonedCopies() {
        guard let children = try? fileManager.contentsOfDirectory(
            at: stagingDirectory, includingPropertiesForKeys: [
                .contentModificationDateKey,
            ]) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-86_400)
        for child in children {
            guard let values = try? child.resourceValues(forKeys: [
                .contentModificationDateKey,
            ]), let modified = values.contentModificationDate,
                modified < cutoff else {
                continue
            }
            try? fileManager.removeItem(at: child)
        }
    }

    private var fileManager: FileManager {
        FileManager.default
    }

    private func uniqueName(for originalName: String) -> String {
        let ext = (originalName as NSString).pathExtension
        let stem = (originalName as NSString).deletingPathExtension
        return "\(stem)_\(UUID().uuidString.prefix(8)).\(ext)"
    }
}


// MARK: - 复制导入文件载体（CopiedImportFile pickerCopy 构造域确证）

/// 复制导入文件（CopiedImportFile pickerCopy 构造域确证；deinit L20-22）。
final class CopiedImportFile {

    let sourceURL: URL

    /// 伪代码 CopiedImportFile(pickerCopy:)（closure 链确证）。
    init(pickerCopy url: URL) {
        sourceURL = url
    }

    /// 伪代码 0x1003119f8（L5）：id varinit（Foundation.UUID 域确证）。
    var id: UUID {
        UUID()
    }

}
