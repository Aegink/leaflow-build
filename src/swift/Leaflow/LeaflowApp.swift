// 原路径: LeaflowApp.swift
// 证据:
//   - PGO: 39 个主函数（index/task_functions.csv T-101-01 / LeaflowApp.swift），
//     地址：AppInfo.marketingVersion 0x100d3b828 L10-12 / AppRuntime.isRunningUnitTests
//     0x100d43abc L25-27 / AppDebugConfiguration.apply 0x100d3ba10 L62-66 /
//     LeaflowApp.init 0x100d3bd54 L72-113（+closure 0x100d3bea0 L103-105）/
//     body closure 0x100d3c410 L116-139 / handleOpenURL 0x100d3ce88 L144-202
//     （+closure #2/#3/#4）/ handleCopiedFile 0x100d3e4f8 L205-343（+defer/closures）/
//     showImportTargetAlert 0x100d3dabc L347-375（+closures）/ performImport
//     0x100d40bd4 L378-390（+closure）/ highlightRuleImportMessage 0x100d3fc28
//     L392-408 / currentTopViewController 0x100d411e8 L418-430（+closure）/
//     topViewController(from:) 0x100d415a8 L432-451 / setupMemoryWarningObserver
//     0x100d3c0f4 L454-497（+closure）/ setupPersistenceFlushObservers 0x100d3c208
//     L500-546（+closure #1/#2/#4/#5/#6）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/LeaflowApp.c（3024 行）
//   - 关键调用：WebViewPool.release / NSNotificationCenter.addObserverForName:
//     (willResignActive, mainQueue) / URLComponents(queryItems) + URLQueryItem
//     name|value / SourceBrowserURLRouting.shouldOpenInHostApp / URL.isFileURL /
//     ChapterTitleStyleFileService.importPackageData / URLImportView.performImport /
//     SourceService / AppErrorPresenter.show(_:level:duration:)（ToastLevel_error）/
//     AutoBackupCoordinator.triggerIfDue / JSBridgeDeviceIdentifier.value /
//     Logger.enableQuietMode / AnalyzeRule.purgeUnexpectedGlobals /
//     UserDefaults synchronize（memory warning）/ UIAlertAction 双按钮
//   - 事实：init —— WebViewPool.release + 观察器装配（willResignActive → 持久化冲刷）；
//     handleOpenURL —— shouldOpenInHostApp 早退 → isFileURL → handleCopiedFile →
//     URLComponents queryItems 解析（name/value）→ Task 异步；
//     handleCopiedFile —— 复制文件导入（高亮规则/主题包/书源 JSON 分派）→
//     showImportTargetAlert（双按钮 → performImport）；
//     setupMemoryWarningObserver —— standardUserDefaults synchronize；
//     setupPersistenceFlushObservers —— AutoBackupCoordinator.triggerIfDue 等
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - init/观察器/URL 分派/导入链: high（调用链确证）
//   - handleCopiedFile 内部分派细节: medium-high
//   - body 结构: medium-high（builder opaque 描述确证）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 应用静态信息（pgo_only 命名空间）。
enum AppInfo {
    /// 伪代码 0x100d3b828（L10-12）：mainBundle marketingVersion。
    static var marketingVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

/// 运行时判定（pgo_only）。
enum AppRuntime {
    /// 伪代码 0x100d43abc（L25-27）。
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// 调试配置（伪代码 0x100d3ba10，L62-66）。
enum AppDebugConfiguration {
    static func apply() {
        // 三个调用确证：JSBridge 设备标识预热 / 规则全局清理 / 静默日志。
        _ = JSBridgeDeviceIdentifier.value
        AnalyzeRule.purgeUnexpectedGlobals()
        Logger.enableQuietMode()
    }
}

@main
struct LeaflowApp: App {

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 伪代码 0x100d3bd54（L72-113）：WebViewPool.release + 观察器装配。
        AppDebugConfiguration.apply()
        WebViewPool.release()
        setupMemoryWarningObserver()
        setupPersistenceFlushObservers()
        // closure #1（0x100d3bea0，L103-105）：willResignActive → mainQueue 持久化冲刷。
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main) { _ in
            Task { @MainActor in
                PersistenceFlushCoordinator.flushNow()
            }
        }
    }

    var body: some Scene {
        // 伪代码 0x100d3c410（L116-139）：根视图（Color 条件 + SplashOverlay + onOpenURL）。
        // 根视图为 MainTabView（主 Tab 域确证；RootAppView 包装层未还原）。
        WindowGroup {
            Group {
                if AppRuntime.isRunningUnitTests {
                    Color.clear
                } else {
                    MainTabView()
                        .onOpenURL { url in
                            handleOpenURL(url)
                        }
                        .systemAppearanceMonitor()
                        .splashOverlay()
                }
            }
        }
    }

    // MARK: URL 分派

    /// 伪代码 0x100d3ce88（L144-202）+ closure #2/#3/#4。
    /// shouldOpenInHostApp 早退 → isFileURL → handleCopiedFile →
    /// URLComponents queryItems 解析（name/value）→ Task 异步。
    private func handleOpenURL(_ url: URL) {
        guard !SourceBrowserURLRouting.shouldOpenInHostApp(url) else { return }
        if url.isFileURL {
            // 文件 URL → 复制导入路径（Task + priority 确证）。
            Task(priority: .userInitiated) {
                await handleOpenedFile(at: url)
            }
            return
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }
        // queryItems name/value 解析（确证）。
        let values = Dictionary(
            uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
        Task {
            await dispatchURLAction(scheme: url.scheme, values: values)
        }
    }

    /// 打开的本地文件：拷入容器后走复制导入链。
    private func handleOpenedFile(at url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let file = try CopiedFileImporter.importCopiedFile(at: url)
            await MainActor.run {
                handleCopiedFile(file)
            }
        } catch {
            AppErrorPresenter.shared.show(
                error.localizedDescription, level: .error, duration: 2.5)
        }
    }

    /// scheme 动作分派（queryItems 解析确证）。
    private func dispatchURLAction(scheme: String?, values: [String: String]) async {
        _ = scheme
        _ = values
        // 具体动作（书源跳转/阅读跳转）待真机对照。
    }

    // MARK: 复制文件导入

    /// 伪代码 0x100d3e4f8（L205-343）+ defer 闭包（0x100d43664）。
    /// 按 pathExtension（小写）分派（8 处 pathExtension/lowercased 确证）：
    /// .qihighlight（"ght" 字面量 0xEB…746867 + importPackageData L1265）→
    /// ChapterTitleStyleFileService.importPackageData(_:sourceName:into:assetManager:)；
    /// .json → String(contentsOf) → showImportTargetAlert；其余扩展名待真机对照。
    private func handleCopiedFile(_ file: CopiedImportFile) {
        defer {
            // defer 闭包（0x100d43664，L207）：临时清理。
        }
        let ext = file.url.pathExtension.lowercased()
        if ext == "qihighlight" {
            do {
                let data = try Data(contentsOf: file.url)
                // 签名按 PGO：ChapterTitleStyleFileService.importPackageData(
                //   _: Data, sourceName: String, into: inout ChapterTitleStyleLibrary,
                //   assetManager: ChapterTitleAssetManager) throws -> ChapterTitleStyleImportSummary
                // （primaryName getter 确证）。
                // Library/AssetManager 类型属 T-303-01 分册（本轮后续任务落地后接真调用；
                // 此处先完成文件读取与错误路径，服务调用占位注释，不冒充已实现）。
                _ = data
            } catch {
                AppErrorPresenter.shared.show(
                    error.localizedDescription, level: .error, duration: 2.5)
            }
        } else if ext == "json" {
            guard let json = try? String(contentsOf: file.url, encoding: .utf8) else { return }
            showImportTargetAlert(jsonString: json)
        } else {
            // 其余扩展名（.qitheme/.styles/.red 等）分派待真机对照。
        }
    }

    /// 伪代码 0x100d3dabc（L347-375）+ closures（0x100d40c38/0x100d42e54/0x100d413c8/0x100d41478）。
    /// UIAlertController 双按钮（addAction 确证）→ performImport(jsonString:targetRemote:)。
    private func showImportTargetAlert(jsonString: String) {
        guard let top = currentTopViewController() else { return }
        let alert = UIAlertController(
            title: "导入内容",
            message: "检测到复制的内容，请选择导入目标",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "书源（在线）", style: .default) { _ in
            Task { @MainActor in
                await performImport(jsonString: jsonString, targetRemote: true)
            }
        })
        alert.addAction(UIAlertAction(title: "书源（本地）", style: .default) { _ in
            Task { @MainActor in
                await performImport(jsonString: jsonString, targetRemote: false)
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        top.present(alert, animated: true)
    }

    /// 伪代码 0x100d40bd4（L378-390）+ closure（0x100d414f4）：
    /// URLImportView.performImport + SourceService 域；失败 →
    /// AppErrorPresenter.show(level: .error)（ToastLevel_error 确证）。
    private func performImport(jsonString: String, targetRemote: Bool) async {
        do {
            _ = try await URLImportView.performImport(
                jsonString: jsonString, targetRemote: targetRemote)
        } catch {
            AppErrorPresenter.shared.show(
                error.localizedDescription, level: .error, duration: 2.5)
        }
    }

    /// 伪代码 0x100d3fc28（L392-408）：高亮规则导入结果消息。
    private func highlightRuleImportMessage(
        _ result: HighlightRuleImportResult?
    ) -> String? {
        guard let result else { return nil }
        return "导入 \(result.importedCount) 条高亮规则"
    }

    // MARK: 顶层控制器定位

    /// 伪代码 0x100d411e8（L418-430）+ closure（0x100d439d4，L420）。
    private func currentTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return nil
        }
        return topViewController(from: window.rootViewController)
    }

    /// 伪代码 0x100d415a8（L432-451）：
    /// presented → visible/selected → children 递归（选择子链确证）。
    private func topViewController(from base: UIViewController?) -> UIViewController? {
        guard var top = base else { return nil }
        if let presented = top.presentedViewController {
            top = presented
        }
        if let navigation = top as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = top as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        for child in top.children where child is UINavigationController || child is UITabBarController {
            return topViewController(from: child)
        }
        return top
    }

    // MARK: 观察器

    /// 伪代码 0x100d3c0f4（L454-497）+ closure（0x100d41d88，L459-496）：
    /// 内存警告 → UserDefaults synchronize（确证）。
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil) { _ in
            UserDefaults.standard.synchronize()
        }
    }

    /// 伪代码 0x100d3c208（L500-546）+ closure #1/#2/#4/#5/#6：
    /// 持久化冲刷观察器组（AutoBackupCoordinator.triggerIfDue /
    /// JSBridgeDeviceIdentifier.value 预热确证）。
    private func setupPersistenceFlushObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main) { _ in
            Task { @MainActor in
                AutoBackupCoordinator.shared.triggerIfDue()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main) { _ in
            Task { @MainActor in
                _ = JSBridgeDeviceIdentifier.value
                PersistenceFlushCoordinator.flushNow()
            }
        }
    }
}

/// 持久化冲刷协调（观察器闭包共体；实现域待分册落地）。
@MainActor
enum PersistenceFlushCoordinator {
    static func flushNow() {
        // 冲刷体（ReaderPageDebug/LRUCache 落盘）待分册落地。
    }
}
