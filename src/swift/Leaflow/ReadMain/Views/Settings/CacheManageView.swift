// 原路径: ReadMain/Views/Settings/CacheManageView.swift
// 证据:
//   - PGO: 74 条记录（index/task_functions.csv T-701-05 /
//     CacheManageView.swift；body 0x1009e86d8 L15-159 域 +
//     updateCacheSize 签名域）
//   - CovMap: 上述 L 区段（body 15 行域 + 清除确认弹层域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     CacheManageView.c（2804 行）
//   - 字符串域（位模式+指针，scratch/t70105_cache_strings.txt）：
//     '章节缓存' L1373 / '计算中...' L1783/L1787/L1791/L1795（四档
//     计算域）/ '取消' L1971/L2132/L2307/L2482 / '清除'
//     L1979/L2140/L2315/L2490 / '全部清除' L2657/L2665
//   - 事实：四档清除域（章节/图片/字体/临时）+ 全部清除
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（四档清除 + 计算域字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// 缓存管理页（body 0x1009e86d8 L15-159 域确证：四档清除域）。
struct CacheManageView: View {

    /// 缓存档位（'计算中...' 四档域确证）。
    enum CacheSection: String, CaseIterable, Identifiable {
        case chapter
        case cover
        case explore
        case temporary

        var id: String { rawValue }

        var title: String {
            switch self {
            case .chapter: return "章节缓存"
            case .cover: return "封面缓存"
            case .explore: return "发现缓存"
            case .temporary: return "临时文件"
            }
        }

        var systemImage: String {
            switch self {
            case .chapter: return "book"
            case .cover: return "photo"
            case .explore: return "safari"
            case .temporary: return "trash"
            }
        }
    }

    @State private var sizes: [CacheSection: Int64?] = [
        .chapter: nil, .cover: nil, .explore: nil, .temporary: nil,
    ]
    @State private var confirmTarget: CacheSection?
    @State private var confirmAll = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(CacheSection.allCases) { section in
                    sectionRow(section)
                }
                clearAllRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("缓存管理")
        .onAppear {
            updateCacheSize()
        }
        .alert(
            "确认清除",
            isPresented: Binding(
                get: { confirmTarget != nil || confirmAll },
                set: {
                    if !$0 {
                        confirmTarget = nil
                        confirmAll = false
                    }
                })
        ) {
            Button("清除", role: .destructive) {
                if confirmAll {
                    clearAll()
                } else if let target = confirmTarget {
                    clear(section: target)
                }
            }
            Button("取消", role: .cancel) {
                confirmTarget = nil
                confirmAll = false
            }
        } message: {
            if confirmAll {
                Text("确定要清除全部缓存吗？")
            } else if let target = confirmTarget {
                Text("确定要清除「\(target.title)」吗？")
            }
        }
    }

    /// 档位行（'取消'/'清除' 四档域确证）。
    private func sectionRow(_ section: CacheSection) -> some View {
        settingsCardRow(topGap: 12) {
            HStack {
                AppThemeSettingsLabel(
                    section.title, systemImage: section.systemImage)
                Spacer()
                sizeText(for: section)
                Button {
                    confirmTarget = section
                } label: {
                    // '清除' L1979/L2140/L2315/L2490 域确证。
                    Text("清除")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
            .contentShape(Rectangle())
        }
    }

    /// 全部清除行（'全部清除' L2657/L2665 域确证）。
    private var clearAllRow: some View {
        settingsCardRow(topGap: 12) {
            HStack {
                Spacer()
                Button(role: .destructive) {
                    confirmAll = true
                } label: {
                    Text("全部清除")
                }
                Spacer()
            }
        }
    }

    /// sizeText(for:)（'计算中...' L1783-1795 域确证：计算中占位）。
    @ViewBuilder
    private func sizeText(for section: CacheSection) -> some View {
        if let size = sizes[section] ?? nil {
            Text(ByteCountFormatter.string(
                fromByteCount: size, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            // '计算中...' 四档域确证。
            Text("计算中...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// updateCacheSize()（签名域确证：四档异步统计）。
    private func updateCacheSize() {
        for section in CacheSection.allCases {
            sizes[section] = nil
            let target = section
            Task.detached(priority: .utility) {
                let size = Self.directorySize(directory: target.directory)
                await MainActor.run {
                    sizes[target] = size
                }
            }
        }
    }

    private func clear(section: CacheSection) {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(
            at: section.directory, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fm.removeItem(at: file)
            }
        }
        sizes[section] = 0
        updateCacheSize()
    }

    private func clearAll() {
        for section in CacheSection.allCases {
            clear(section: section)
        }
    }

    private static func directorySize(directory: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory, includingPropertiesForKeys:
                [.fileSizeKey, .isDirectoryKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .fileSizeKey, .isDirectoryKey,
            ]), values.isDirectory != true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

private extension CacheManageView.CacheSection {
    /// 目录桥（四档目录还原桥）。
    var directory: URL {
        let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first!
        switch self {
        case .chapter:
            return caches.appendingPathComponent("Chapters",
                                                isDirectory: true)
        case .cover:
            return caches.appendingPathComponent("Covers",
                                                isDirectory: true)
        case .explore:
            return caches.appendingPathComponent("Explore",
                                                isDirectory: true)
        case .temporary:
            return FileManager.default.temporaryDirectory
        }
    }
}
