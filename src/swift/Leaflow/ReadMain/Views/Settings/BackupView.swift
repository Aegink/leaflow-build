// 原路径: ReadMain/Views/Settings/BackupView.swift
// 证据:
//   - PGO: 138 条记录（index/task_functions.csv T-701-04 /
//     BackupView.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（body/备份目的地/自动备份/网盘同步/
//     同步内容/恢复确认域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     BackupView.c（4538 行）
//   - 块体确证（地址+行号域）：备份域六段（备份目的地/自动备份/
//     网盘同步/上次备份/导出/同步内容/确认恢复）
//   - 字符串域（位模式+指针，scratch/t70104_backup_strings.txt）：
//     '备份与同步' L297 / '确认恢复' L401 / '恢复' L475/L3360 /
//     '设备：' L1310 / 'App版本：' L1314 / '包含：' L1318 /
//     '备份目的地' L1530 / '自动备份' L1675 / '网盘同步' L1860 /
//     '上次备份' L2584 / '导出' L2742 / '同步内容' L3092 /
//     '预估大小' L3476 / '确定要从' L3843 / '立即退出' L4310
//   - 事实：备份域六段结构（目的地/自动备份/网盘同步/上次备份/
//     导出/同步内容）+ 恢复确认弹层（'确定要从' L3843 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（六段结构 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI
import UniformTypeIdentifiers

/// 备份与同步页（body 域确证：六段 settingsCardRow 结构）。
struct BackupView: View {

    @State private var autoBackupEnabled = false
    @State private var cloudSyncEnabled = false
    @State private var lastBackupText = ""
    @State private var estimatedSizeText = ""
    @State private var confirmRestoreTarget: String?
    @State private var isExporting = false
    @State private var selectedSummary = ""
    @State private var showImporter = false
    @State private var restoreFile: URL?
    @State private var restoreDirectory: URL?
    @State private var previewSummary = ""
    @State private var isRestoring = false
    @State private var operationMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                destinationSection
                autoBackupSection
                cloudSyncSection
                lastBackupSection
                syncContentSection
                restoreSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("备份与同步")
        .onAppear {
            autoBackupEnabled = UserDefaults.standard.bool(forKey: "reader_auto_backup_enabled")
            cloudSyncEnabled = UserDefaults.standard.bool(forKey: "reader_cloud_sync_enabled")
            refreshSummary()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.zip]) { result in
            switch result {
            case .success(let url): prepareRestore(url)
            case .failure(let error): operationMessage = error.localizedDescription
            }
        }
        .onDisappear {
            if !isRestoring { clearRestoreFile() }
        }
        .alert(
            "确认恢复",
            isPresented: Binding(
                get: { confirmRestoreTarget != nil },
                set: { if !$0 { confirmRestoreTarget = nil } })
        ) {
            Button("恢复", role: .destructive) {
                performRestore()
            }
            Button("取消", role: .cancel) {
                confirmRestoreTarget = nil
                clearRestoreFile()
            }
        } message: {
            if let target = confirmRestoreTarget {
                // '确定要从' L3843 域确证：恢复来源确认串。
                Text("确定要从「\(target)」恢复吗？\n\(previewSummary)\n恢复后所选分类的数据将被覆盖。")
            }
        }
    }

    /// 类型表12549与restoreSection：先选择文件并读取清单，再确认恢复。
    private var restoreSection: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Button { showImporter = true } label: {
                    HStack {
                        AppThemeSettingsLabel("从备份文件恢复", systemImage: "arrow.counterclockwise")
                        Spacer()
                        if isRestoring { ProgressView() }
                    }
                }
                .accessibilityIdentifier("backup-import-restore")
                .disabled(isRestoring || isExporting)
                if !operationMessage.isEmpty {
                    Text(operationMessage).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("backup-operation-result")
                }
            }
        }
    }

    // MARK: 备份目的地（'备份目的地' L1530 域确证）

    private var destinationSection: some View {
        settingsCardRow(topGap: 16) {
            HStack {
                AppThemeSettingsLabel("备份目的地", systemImage: "externaldrive")
                Spacer()
                Text("本机")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    // MARK: 自动备份（'自动备份' L1675 域确证）

    private var autoBackupSection: some View {
        settingsCardRow(topGap: 12) {
            Toggle(isOn: $autoBackupEnabled) {
                AppThemeSettingsLabel("自动备份", systemImage: "clock.arrow.circlepath")
            }
            .onChange(of: autoBackupEnabled) { enabled in
                AutoBackupCoordinator.shared.setEnabled(enabled)
            }
        }
    }

    // MARK: 网盘同步（'网盘同步' L1860 域确证）

    private var cloudSyncSection: some View {
        settingsCardRow(topGap: 12) {
            // T-1601-E2：网盘同步入口 → CloudDriveSettingsView
            //（网盘目的地的增删改在此页；此前整页零引用）。
            HStack {
                NavigationLink {
                    CloudDriveSettingsView()
                } label: {
                    AppThemeSettingsLabel(
                        "网盘同步", systemImage: "cloud")
                }
                .buttonStyle(.plain)
                Spacer()
                Toggle("", isOn: $cloudSyncEnabled)
                    .labelsHidden()
                    .onChange(of: cloudSyncEnabled) { enabled in
                        CloudSyncController.shared.setEnabled(enabled)
                    }
            }
        }
    }

    // MARK: 上次备份（'上次备份' L2584 / '导出' L2742 域确证）

    private var lastBackupSection: some View {
        settingsCardRow(topGap: 12) {
            HStack {
                AppThemeSettingsLabel("上次备份", systemImage: "externaldrive.badge.timemachine")
                Spacer()
                Text(lastBackupText.isEmpty ? "无记录" : lastBackupText)
                    .foregroundStyle(.secondary)
                Button {
                    performExport()
                } label: {
                    // '导出' L2742 域确证。
                    if isExporting {
                        ProgressView()
                    } else {
                        Text("导出")
                            .appThemeAccent()
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isExporting)
            }
        }
    }

    // MARK: 同步内容（'同步内容' L3092 / '预估大小' L3476 / '设备：'
    // L1310 / 'App版本：' L1314 / '包含：' L1318 域确证）

    private var syncContentSection: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                NavigationLink {
                    SyncCategoriesView()
                } label: {
                    HStack {
                        AppThemeSettingsLabel(
                            "同步内容", systemImage: "list.bullet")
                        Spacer()
                        Text("预估大小 \(estimatedSizeText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("backup-sync-categories")
                // '设备：'/'App版本：'/'包含：' 摘要域确证。
                Text("设备：\(deviceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("App版本：\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("包含：\(selectedSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deviceName: String {
        UIDevice.current.name
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? ""
        return version
    }

    private func refreshSummary() {
        let selected = BackupSyncPreferences().selectedCategories
        selectedSummary = SyncCategory.allCases.filter { selected.contains($0) }.map(\.displayName).joined(separator: "、")
        let coordinator = AutoBackupCoordinator.shared
        if let last = coordinator.lastBackupDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            lastBackupText = formatter.string(from: last)
        } else {
            lastBackupText = ""
        }
        let size = BackupService.shared.estimateBackupSize(
            categories: selected)
        estimatedSizeText = ByteCountFormatter.string(
            fromByteCount: size, countStyle: .file)
    }

    private func performExport() {
        isExporting = true
        operationMessage = ""
        Task {
            defer { isExporting = false }
            do {
                let url = try await BackupService.shared.exportBackup(
                    categories: BackupSyncPreferences().selectedCategories)
                let activity = UIActivityViewController(
                    activityItems: [url], applicationActivities: nil)
                UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                    .first?
                    .present(activity, animated: true)
            } catch {
                operationMessage = error.localizedDescription
            }
        }
    }

    private func performRestore() {
        guard let restoreFile, !isRestoring else { return }
        let categories = BackupSyncPreferences().selectedCategories
        isRestoring = true
        operationMessage = ""
        Task {
            defer { isRestoring = false; clearRestoreFile() }
            do {
                try await BackupService.shared.restoreBackup(from: restoreFile, categories: categories)
                operationMessage = "恢复完成，请重新启动应用以载入恢复的数据。"
                refreshSummary()
            } catch { operationMessage = "恢复失败：" + error.localizedDescription }
        }
    }

    private func prepareRestore(_ source: URL) {
        clearRestoreFile()
        operationMessage = ""
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("backup-selection-" + UUID().uuidString)
        restoreDirectory = directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let copied = try CopiedFileImportService(stagingDirectory: directory).copyFile(source)
            let manifest = try BackupService.shared.previewBackup(from: copied)
            let included = (manifest["categories"] as? [String] ?? []).compactMap(SyncCategory.init(rawValue:))
            previewSummary = "包含：" + included.map(\.displayName).joined(separator: "、")
            restoreFile = copied
            confirmRestoreTarget = source.lastPathComponent
        } catch {
            clearRestoreFile()
            operationMessage = "无法读取备份：" + error.localizedDescription
        }
    }

    private func clearRestoreFile() {
        restoreFile = nil
        if let restoreDirectory { try? FileManager.default.removeItem(at: restoreDirectory) }
        restoreDirectory = nil
    }
}
