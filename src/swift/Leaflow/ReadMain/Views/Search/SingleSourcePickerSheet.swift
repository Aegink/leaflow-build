// 原路径: ReadMain/Views/Search/SingleSourcePickerSheet.swift
// 证据:
//   - PGO: 25 条记录（index/task_functions.csv T-501-07 /
//     SingleSourcePickerSheet.swift；伪代码域 2122 行）。关键域：
//     filteredSources getter（closure (BookSource)->Bool 三段谓词域）/
//     groupedSources getter（closure #3 ((key, value)) -> (group, sources)
//     字典分组确证）/ "选择配置" L603 域确证
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/
//     SingleSourcePickerSheet.c（2122 行）
//   - 事实：双 getter——filteredSources（搜索词 + 分组过滤三段谓词）+
//     groupedSources（字典分组映射）；选中回调
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（签名族 + 分组闭包确证）
// 还原: 2026-11-20

import SwiftUI

/// 单源选择面板（"选择配置" L603 域确证）。
struct SingleSourcePickerSheet: View {

    let sources: [BookSource]
    let onSelect: (BookSource?) -> Void

    @State private var searchText: String = ""
    @State private var selectedGroup: String = "全部分组"
    @Environment(\.dismiss) private var dismiss

    /// filteredSources getter（closure (BookSource)->Bool 三段谓词域确证）。
    private var filteredSources: [BookSource] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return sources.filter { source in
            let groupOK = selectedGroup == "全部分组"
                || source.bookSourceGroup == selectedGroup
            let queryOK =
                query.isEmpty
                || source.bookSourceName.localizedCaseInsensitiveContains(query)
                || source.bookSourceUrl.localizedCaseInsensitiveContains(query)
            return groupOK && queryOK && source.enabled
        }
    }

    /// groupedSources getter（closure #3 ((key, value)) -> (group, sources)
    /// 字典分组确证）。
    private var groupedSources: [(group: String, sources: [BookSource])] {
        var buckets: [String: [BookSource]] = [:]
        for source in filteredSources {
            let group = source.bookSourceGroup ?? "未分组"
            buckets[group, default: []].append(source)
        }
        return buckets
            .map { (group: $0.key, sources: $0.value) }
            .sorted { $0.group < $1.group }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("选择配置", text: $searchText)
                        .autocorrectionDisabled()
                    Picker("分组", selection: $selectedGroup) {
                        Text("全部分组").tag("全部分组")
                        ForEach(
                            Array(Set(sources.compactMap(\.bookSourceGroup)))
                                .sorted(), id: \.self
                        ) { group in
                            Text(group).tag(group)
                        }
                    }
                }
                ForEach(groupedSources, id: \.group) { bucket in
                    Section(bucket.group) {
                        ForEach(
                            bucket.sources, id: \.bookSourceUrl
                        ) { source in
                            Button {
                                onSelect(source)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(source.bookSourceName)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        onSelect(nil)
                        dismiss()
                    }
                }
            }
        }
    }
}
