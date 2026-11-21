// 原路径: ReadMain/Views/Settings/AboutSettingsView.swift
// 证据:
//   - PGO: 37 条记录（index/task_functions.csv T-701-04 /
//     AboutSettingsView.swift；伪代码域 60 行）
//   - CovMap: 上述 L 区段（body 域 + settingsCardRow 双行域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     AboutSettingsView.c（3664 行）
//   - 块体确证（地址+行号域）：
//     body getter 0x 域（TupleView 双 settingsCardRow：版本号行
//     textSelection 域 + Link 行 appThemeAccent 域）
//   - 字符串域（位模式+指针，scratch/t70104_about_strings.txt）：
//     '版本号' L111 / '关于' L776 / '搜索主题' L1241 / '主题切换'
//     L1261 / '界面效果' L1459 / '阅读界面' L1680 / '缓存管理' L2208 /
//     '默认封面' L2845 / '导入失败' L2985/L3514 / '启动图' L3381
//     （L1241-3514 域为设置列表内联行，归 T-701-11 交叉）
//   - 事实：本视图 = 双 settingsCardRow（版本号可选中 + 关于链接行）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（settingsCardRow 双行 + Link 域确证）
// 还原: 2026-11-20

import SwiftUI

/// 关于页（body 0x 域确证：版本号行 + 关于链接行）。
struct AboutSettingsView: View {

    @State private var appVersion = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // closure #1 域确证：双 settingsCardRow 元组。
                versionRow
                aboutRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("关于")
        .onAppear {
            loadVersion()
        }
    }

    /// 版本号行（closure #1 textSelection 域确证）。
    private var versionRow: some View {
        // closure #1 域确证：AppThemeSettingsLabel + Spacer +
        // textSelection 文本。
        settingsCardRow(topGap: 16) {
            HStack {
                AppThemeSettingsLabel(
                    title: "版本号", systemImage: "info.circle")
                Spacer()
                Text(appVersion)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 关于链接行（closure #2 Link 域确证）。
    private var aboutRow: some View {
        // closure #2 域确证：Link + appThemeAccent 着色。
        Link(destination: URL(string: "https://www.qireader.app")!) {
            HStack {
                AppThemeSettingsLabel(
                    title: "关于", systemImage: "safari")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .appThemeAccent(opacity: 0.4)
            }
        }
        .buttonStyle(.plain)
        .settingsCardRow(topGap: 12)
    }

    private func loadVersion() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"]
            as? String ?? ""
        appVersion = build.isEmpty ? version : "\(version) (\(build))"
    }
}
