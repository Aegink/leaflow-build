// 原路径: ReadMain/Services/BackupDestination.swift
// 证据:
//   - PGO: 53 条记录（index/task_functions.csv T-901-02 /
//     BackupDestination.swift；伪代码域 220 行）
//   - CovMap: 上述 L 区段（Store.init/persistActive/persistConfigs/
//     activeDisplayName/activeWebDAVConfig/config(for:)/remove/
//     setActive/upsert 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/BackupDestination.c
//     （1200 行）
//   - 块体确证（签名域）：
//     BackupDestinationStore.init / persistActive / persistConfigs /
//     activeDisplayName getter / activeWebDAVConfig getter /
//     config(for: UUID) / remove(UUID) / setActive(BackupDestination) /
//     upsert(WebDAVConfig)
//   - 事实：WebDAVConfig 五字段（init(id: UUID, name: String, url:
//     String, username: String, password: String, directory: String) +
//     remoteRootURL getter 签名域）+ 双目的地（icloud/webdav）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（九签名域 + 五字段签名域确证）
// 还原: 2026-11-20

import Foundation

/// WebDAV 配置（init 六参 + remoteRootURL getter 签名域确证）。
struct WebDAVConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var username: String
    var password: String
    var directory: String

    /// init 六参（0x 域签名确证）。
    init(
        id: UUID, name: String, url: String, username: String,
        password: String, directory: String
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
        self.directory = directory
    }

    /// remoteRootURL getter（签名域确证：directory 拼接域）。
    var remoteRootURL: URL? {
        var components = URLComponents(string: url)
        let trimmed = directory.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            components?.path = "/" + trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return components?.url
    }
}

/// 备份目的地（BackupDestination 域还原桥：icloud/webdav 双档）。
enum BackupDestination: String, Codable, CaseIterable {
    case icloud
    case webdav

    var displayName: String {
        self == .icloud ? "iCloud 云盘" : "WebDAV"
    }
}

/// 目的地仓库（init/persistActive/persistConfigs/setActive/upsert/
/// remove/config(for:) 签名域确证）。
@MainActor
final class BackupDestinationStore: ObservableObject {

    @Published var configs: [WebDAVConfig] = []
    @Published private(set) var active: BackupDestination = .icloud
    @Published var activeWebDAVID: UUID?

    private let defaults: UserDefaults

    private static let configsKey = "reader_backup_webdav_configs"
    private static let activeKey = "reader_backup_active_destination"

    /// init（签名域确证）。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    /// activeDisplayName getter（签名域确证）。
    var activeDisplayName: String {
        if active == .webdav,
           let id = activeWebDAVID,
           let config = config(for: id) {
            return config.name
        }
        return active.displayName
    }

    /// activeWebDAVConfig getter（签名域确证）。
    var activeWebDAVConfig: WebDAVConfig? {
        guard active == .webdav else { return nil }
        return activeWebDAVID.flatMap { config(for: $0) }
    }

    /// config(for: UUID)（签名域确证）。
    func config(for id: UUID) -> WebDAVConfig? {
        configs.first { $0.id == id }
    }

    /// upsert(WebDAVConfig)（签名域确证：id 相同替换，否则追加）。
    func upsert(_ config: WebDAVConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        persistConfigs()
    }

    /// remove(UUID)（签名域确证）。
    func remove(_ id: UUID) {
        configs.removeAll { $0.id == id }
        if activeWebDAVID == id {
            activeWebDAVID = nil
            persistActive()
        }
        persistConfigs()
    }

    /// setActive(BackupDestination)（签名域确证）。
    func setActive(_ destination: BackupDestination) {
        active = destination
        persistActive()
    }

    private func reload() {
        if let data = defaults.data(forKey: Self.configsKey),
           let stored = try? JSONDecoder().decode(
            [WebDAVConfig].self, from: data) {
            configs = stored
        }
        let raw = defaults.string(forKey: Self.activeKey)
        active = BackupDestination(rawValue: raw ?? "") ?? .icloud
        activeWebDAVID = nil
        if active == .webdav, let first = configs.first {
            activeWebDAVID = first.id
        }
    }

    /// persistActive（签名域确证）。
    private func persistActive() {
        defaults.set(active.rawValue, forKey: Self.activeKey)
    }

    /// persistConfigs（签名域确证）。
    private func persistConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: Self.configsKey)
        }
    }
}
