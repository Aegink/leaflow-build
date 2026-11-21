// 原路径: ReadMain/Views/Settings/WebDAVEditView.swift
// 证据:
//   - PGO: 36 条记录（index/task_functions.csv T-701-10 /
//     WebDAVEditView.swift；伪代码域 100 行）
//   - CovMap: 上述 L 区段（body/connectionSection/testSection 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     WebDAVEditView.c（2422 行）
//   - 块体确证（签名域）：
//     body getter / buildConfig() / canSave getter /
//     connectionSection getter / save() / testConnection() /
//     testSection getter / init(existing: WebDAVConfig?, onSave:
//     (WebDAVConfig) -> Void) 签名域
//   - 字符串域（位模式+指针，scratch/t70110_strings.txt）：
//     '编辑' L510 / '添加' L515 / '编辑 WebDAV' L523 / '取消' L606 /
//     '保存' L690 / '用户名' L1076 / '备份目录' L1142 / '连接信息'
//     L1290 / '密码' L1481/L1524 / '连接成功' L2153 / '测试连接'
//     L2346
//   - 事实：WebDAVConfig 五字段域（url/username/password/directory/
//     name，BackupDestination.swift init 签名域交叉）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（八签名域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// WebDAV 编辑页（body/buildConfig/canSave/save/testConnection
/// 签名域确证）。
struct WebDAVEditView: View {

    var existing: WebDAVConfig?
    var onSave: (WebDAVConfig) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var directory = ""
    @State private var testStatus: TestStatus = .idle

    /// 测试状态（'连接成功' L2153 / '测试连接' L2346 域确证）。
    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                testSection
            }
            .navigationTitle(existing == nil ? "添加" : "编辑 WebDAV")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // '取消' L606 域确证。
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // '保存' L690 域确证。
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadExisting()
            }
        }
    }

    // MARK: 连接信息（'连接信息' L1290 / '用户名' L1076 / '密码'
    // L1481 / '备份目录' L1142 域确证）

    @ViewBuilder
    private var connectionSection: some View {
        Section("连接信息") {
            TextField("名称", text: $name)
            TextField("https://dav.example.com", text: $serverURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("用户名", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("密码", text: $password)
            TextField("备份目录", text: $directory)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    // MARK: 测试域（testSection 签名域确证）

    @ViewBuilder
    private var testSection: some View {
        Section {
            Button {
                testConnection()
            } label: {
                HStack {
                    // '测试连接' L2346 域确证。
                    Text("测试连接")
                    if testStatus == .testing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(!canSave || testStatus == .testing)
        } footer: {
            switch testStatus {
            case .idle:
                EmptyView()
            case .testing:
                EmptyView()
            case .success:
                // '连接成功' L2153 域确证。
                Text("连接成功").foregroundStyle(.green)
            case .failure(let message):
                Text("连接失败：\(message)").foregroundStyle(.red)
            }
        }
    }

    // MARK: 状态域（buildConfig/canSave/save/testConnection 签名域）

    /// canSave getter（签名域确证：URL+用户名非空）。
    private var canSave: Bool {
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// buildConfig()（签名域确证：五字段构造）。
    private func buildConfig() -> WebDAVConfig {
        WebDAVConfig(
            id: existing?.id ?? UUID(),
            name: name.isEmpty ? "WebDAV" : name,
            url: serverURL,
            username: username,
            password: password,
            directory: directory)
    }

    /// save()（签名域确证）。
    private func save() {
        onSave(buildConfig())
        dismiss()
    }

    /// testConnection()（签名域确证：PROPFIND 测试桥）。
    private func testConnection() {
        testStatus = .testing
        let config = buildConfig()
        Task {
            do {
                // listTree() 探测桥（T-901-04 WebDAVClient 分册）。
                let client = try WebDAVClient(config: config)
                _ = try await client.listTree()
                let ok = true
                await MainActor.run {
                    testStatus = ok
                        ? .success : .failure("服务器拒绝响应")
                }
            } catch {
                await MainActor.run {
                    testStatus = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        name = existing.name
        serverURL = existing.url
        username = existing.username
        password = existing.password
        directory = existing.directory
    }
}
