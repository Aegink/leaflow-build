// T-1602：原ID解码、仓库合并、管理选择和备份往返，隔离持久化样本。
import Foundation

enum HttpTtsRepositorySampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "tts-repository-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        func source(_ id: Int64, _ name: String, _ path: String = "same") -> HttpTts {
            HttpTts(numericId: id, name: name, url: "https://sample.invalid/\(path)")
        }
        func decode(_ id: String) throws -> HttpTts {
            try JSONDecoder().decode(HttpTts.self, from: Data(
                "{\"name\":\"固定朗读源\",\"url\":\"https://sample.invalid/tts\"\(id)}".utf8))
        }
        do {
            emit("tts_id_fnv_fixed_vectors", ["5472609002491880229", "2607821981565500683", "8568882549994028021"],
                ["", "hello", "固定朗读源"].map { String(HttpTts.stableNumericId(for: $0)) })
            emit("tts_id_missing_null_empty_name_fallback", Array(repeating: "8568882549994028021", count: 3),
                try ["", ",\"id\":null", ",\"id\":\"\""].map { String(try decode($0).id) })
            emit("tts_id_explicit_numeric_preserved", ["-42", "0", "9007199254740993"],
                try [",\"id\":-42", ",\"id\":0", ",\"id\":\"9007199254740993\""].map { String(try decode($0).id) })
            emit("tts_id_external_string_hash", ["5861614267305397068"], [String(try decode(",\"id\":\"external-key\"").id)])
            emit("tts_model_url_script_markers", ["true", "true", "false"],
                ["@js:result", "<js>result</js>", "https://sample.invalid"].map {
                    String(HttpTts(numericId: 1, name: "脚本判断", url: $0, jsLib: "const x=1").hasJsScript)
                })

            let a = source(42, "甲"), b = source(420, "乙")
            let oldData = try JSONEncoder().encode([a])
            defaults.set(oldData, forKey: "reader_tts_sources")
            let runtime = HttpTtsRuntimeStore(defaults: defaults)
            let cache = HttpTtsAudioCache()
            let repository = HttpTtsSourceRepository(defaults: defaults, runtimeStore: runtime, audioCache: cache)
            emit("tts_repository_migrates_original_key", ["42", "true"],
                [String(repository.sources.first?.id ?? -1), String(defaults.data(forKey: "HttpTtsSources") == oldData)])
            defaults.set(try JSONEncoder().encode([b]), forKey: "HttpTtsSources")
            repository.reload()
            emit("tts_repository_original_key_precedence", ["420"], repository.sources.map { String($0.id) })
            defaults.set(Data("{".utf8), forKey: "HttpTtsSources")
            repository.reload()
            emit("tts_repository_corrupt_original_no_legacy_resurrection", ["0"], [String(repository.sources.count)])
            defaults.removeObject(forKey: "HttpTtsSources")
            defaults.set(Data("{".utf8), forKey: "reader_tts_sources")
            repository.reload()
            emit("tts_repository_invalid_legacy_not_migrated", ["true", "0"],
                [String(defaults.object(forKey: "HttpTtsSources") == nil), String(repository.sources.count)])

            try repository.add(a)
            try repository.add(b)
            emit("tts_repository_same_url_distinct_names", ["42", "420"], repository.sources.map { String($0.id) })
            var rejected = 0
            do { try repository.add(source(42, "丙")) } catch { rejected += 1 }
            do { try repository.add(source(43, "甲")) } catch { rejected += 1 }
            do { try repository.update(id: 42, with: source(43, "乙")) } catch { rejected += 1 }
            do { try repository.update(id: 42, with: source(42, "\n ")) } catch { rejected += 1 }
            emit("tts_repository_conflicts_leave_sources_intact", ["4", "true"],
                [String(rejected), String(repository.sources == [a, b])])
            cache.insert(Data([1]), source: a, text: "正文", speechRate: 1)
            cache.insert(Data([2]), source: b, text: "正文", speechRate: 1)
            runtime.setLoginInfo("甲认证", sourceID: 42)
            try repository.update(id: 42, with: source(99, "甲更新", "changed"))
            emit("tts_repository_update_identity_and_cache", ["42", "甲更新", "1", "甲认证"],
                [String(repository.sources[0].id), repository.sources[0].name, String(cache.count), runtime.loginInfo(sourceID: 42) ?? ""])
            let merged = HttpTtsSourceRepository.merging([source(420, "甲更新", "name-first")], into: repository.sources)
            emit("tts_repository_merge_name_before_id", ["42", "420", "https://sample.invalid/name-first", "乙"],
                [String(merged[0].id), String(merged[1].id), merged[0].url, merged[1].name])
            let count = repository.importSources(from: String(decoding: try JSONEncoder().encode(
                [source(9, "甲更新", "imported"), source(420, "乙改名"), source(7, "丙")]), as: UTF8.self))
            emit("tts_repository_import_merge_and_restart", ["3", "42:甲更新", "420:乙改名", "7:丙"],
                [String(count)] + HttpTtsSourceRepository(defaults: defaults).sources.map { "\($0.id):\($0.name)" })
            emit("tts_repository_invalid_import_no_change", ["0", "3"],
                [String(repository.importSources(from: "{")), String(repository.sources.count)])
            runtime.setLoginInfo("乙认证", sourceID: 420)
            cache.insert(Data([1]), source: a, text: "正文", speechRate: 1)
            cache.insert(Data([2]), source: b, text: "正文", speechRate: 1)
            repository.delete(id: 42)
            emit("tts_repository_delete_runtime_cache_boundary", ["true", "乙认证", "1", "true"],
                [String(runtime.loginInfo(sourceID: 42) == nil), runtime.loginInfo(sourceID: 420) ?? "", String(cache.count),
                 String(repository.source(id: 42) == nil)])
            runtime.setLoginInfo("仓外保留", sourceID: 999)
            repository.deleteAll()
            emit("tts_repository_delete_all_owned_sources_only", ["0", "0", "true", "仓外保留"],
                [String(repository.sources.count), String(cache.count), String(runtime.loginInfo(sourceID: 420) == nil),
                 runtime.loginInfo(sourceID: 999) ?? ""])

            let large = source(9007199254740993, "大ID")
            try repository.add(large)
            defaults.set(large.id, forKey: "reader_tts_current")
            let preferences = ReadAloudPreferences(defaults: defaults)
            var changes = 0
            let bridge = TtsSourceStore(repository: repository, preferences: preferences, didChange: { changes += 1 })
            _ = bridge.loadSources()
            emit("tts_selection_legacy_int64_migration", ["9007199254740993", "http", "true"],
                [String(bridge.currentSourceID ?? -1), preferences.selectedEngine.rawValue,
                 String(defaults.object(forKey: "reader_tts_current") == nil)])
            bridge.setCurrent(nil)
            defaults.set(large.id, forKey: "reader_tts_current")
            let coldPreferences = ReadAloudPreferences(defaults: defaults)
            coldPreferences.migrateLegacySourceSelection(using: repository)
            emit("tts_selection_explicit_system_blocks_legacy", ["system", "1"],
                [coldPreferences.selectedEngine.rawValue, String(changes)])
            bridge.setCurrent(large.id)
            emit("tts_selection_playback_preferences_cold_roundtrip", ["9007199254740993", "2"],
                [String(ReadAloudPreferences(defaults: defaults).selectedHTTPSourceID ?? -1), String(changes)])
            try bridge.save(source(17, "大ID改名"), originalID: large.id)
            emit("tts_selection_edit_keeps_selected_identity", ["9007199254740993", "大ID改名", "3"],
                [String(bridge.currentSourceID ?? -1), repository.source(id: large.id)?.name ?? "", String(changes)])

            let backup = BackupService(documentsDirectory: root.appendingPathComponent("docs"),
                applicationSupportDirectory: root.appendingPathComponent("support"), defaults: defaults)
            let exported = root.appendingPathComponent("exported")
            try backup.exportDataTree(to: exported, categories: [.ttsSources], incremental: false)
            bridge.delete(large.id)
            emit("tts_selection_delete_returns_system", ["system", "4", "0"],
                [preferences.selectedEngine.rawValue, String(changes), String(repository.sources.count)])
            try backup.importDataTree(from: exported, categories: [.ttsSources])
            emit("tts_repository_backup_restore_original_key", ["9007199254740993:大ID改名"],
                bridge.loadSources().map { "\($0.id):\($0.name)" })
            let file = root.appendingPathComponent("文件朗读源.json")
            try JSONEncoder().encode(source(8, "文件源")).write(to: file)
            emit("tts_repository_file_import_real_bytes", ["1", "文件源"],
                [String(try bridge.importFile(file)), repository.source(id: 8)?.name ?? ""])
            try Data("{".utf8).write(to: file)
            var invalidFileRejected = false
            do { _ = try bridge.importFile(file) } catch { invalidFileRejected = true }
            emit("tts_repository_invalid_file_preserves_existing", ["true", "2"],
                [String(invalidFileRejected), String(bridge.loadSources().count)])
            let shelfURL = root.appendingPathComponent("docs/bookshelf_data/bookshelf.json")
            try FileManager.default.createDirectory(at: shelfURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("[]".utf8).write(to: shelfURL)
            try Data(#"[{"name":"不可提前覆盖"}]"#.utf8).write(to: exported.appendingPathComponent("bookshelf.json"))
            try Data(#"[{"id":42,"name":"缺URL"}]"#.utf8).write(to: exported.appendingPathComponent("tts_sources.json"))
            var malformedRejected = false
            do { try backup.importDataTree(from: exported, categories: [.bookshelf, .ttsSources]) }
            catch { malformedRejected = true }
            emit("tts_repository_backup_schema_preflight", ["true", "[]", "2"],
                [String(malformedRejected), String(decoding: try Data(contentsOf: shelfURL), as: UTF8.self),
                 String(bridge.loadSources().count)])
            emit("tts_repository_setup", ["成功"], ["成功"])
        } catch { emit("tts_repository_setup", ["成功"], [error.localizedDescription]) }
    }
}
