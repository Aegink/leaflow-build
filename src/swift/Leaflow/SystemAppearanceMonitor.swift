// 原路径: SystemAppearanceMonitor.swift
// 证据:
//   - PGO: 28 个主函数（index/task_functions.csv T-101-07 / SystemAppearanceMonitor.swift），
//     地址：EventGate.specifiedStyle 0x100d43f24 L14-21 / Dispatcher.dispatch(_:source:)
//     0x100d44000 L31-44 / Dispatcher.resolvedSystemUserInterfaceStyle 0x100d442f4
//     L66-86（+closure #3 0x100d44ac0 / closure #4 0x100d46374）/
//     Dispatcher.specifiedStyle 0x10044f98 0x100d44f98 L62-64 /
//     MonitorModifier.body 0x100d4509c L91-105（+closure #2/#3）/
//     SystemAppearanceProbe.makeUIViewController 0x100d45304 L116-118 /
//     ProbeViewController.refreshSceneRegistrations 0x100d4535c L149-163 /
//     viewDidLoad 0x100d45838 L132-137 / viewDidAppear 0x100d4594c L139-142 /
//     viewDidLayoutSubviews 0x100d45b18 L144-147
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/SystemAppearanceMonitor.c（2298 行）
//   - 关键字面量：dispatch 日志 "dark"(1802658148)/"light"(0x746867696C)/
//     " source "(0x3D656372756F7320)/"使所有设置生效。"（7 字 CJK，sub_100058040
//     L132 确证）
//   - 关键调用：EventGate.specifiedStyle 判定 → Logger.log →
//     AppThemeManager.applyObservedSystemAppearance(_:source:) +
//     ThemeManager.applyObservedSystemAppearance(_:source:)（双调用确证）；
//     resolvedStyle —— UIApplication.connectedScenes 按 activationState 过滤 +
//     traitCollection（L154-395 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - dispatch/双主题管理器分发: high（字面量/调用链确证）
//   - resolvedStyle 场景遍历: high（activationState/traitCollection 确证）
//   - Probe 生命周期细节: medium（生命周期函数确证；注册细节待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 系统外观事件闸门（pgo_only 命名空间；指定样式才放行）。
enum SystemAppearanceEventGate {

    /// 伪代码 0x100d43f24（L14-21）：指定样式归一。
    /// 非 unspecified 的样式放行；unspecified → 回落到当前 trait。
    static func specifiedStyle(_ style: UIUserInterfaceStyle) -> UIUserInterfaceStyle {
        if style == .unspecified {
            return UITraitCollection.current.userInterfaceStyle
        }
        return style
    }
}

/// 系统外观分发器。
final class SystemAppearanceDispatcher {

    /// 伪代码 0x100d44000（L31-44）：
    /// EventGate 判定 → 日志（"dark"/"light" + " source " + 源名）
    /// → AppThemeManager.applyObservedSystemAppearance(_:source:) +
    ///   ThemeManager.applyObservedSystemAppearance(_:source:)（双调用确证）
    /// → 返回是否分发；
    /// 闸门不放行 → 日志（"使所有设置生效。" 7 字 CJK 确证）→ false。
    @discardableResult
    func dispatch(_ style: UIUserInterfaceStyle, source: String) -> Bool {
        let effective = SystemAppearanceEventGate.specifiedStyle(style)
        let allowed = effective != .unspecified
        if allowed {
            let name = effective == .dark ? "dark" : "light"
            Logger.log("\(name) source \(source)", level: .info)
            _ = AppThemeManager.applyObservedSystemAppearance(effective, source: source)
            _ = ThemeManager.applyObservedSystemAppearance(effective, source: source)
        } else {
            Logger.log("外观未指定，使所有设置生效。", level: .info)
        }
        return allowed
    }

    /// pgo_only specifiedStyle（签名确证）：委托闸门。
    static func specifiedStyle(_ style: UIUserInterfaceStyle) -> UIUserInterfaceStyle {
        SystemAppearanceEventGate.specifiedStyle(style)
    }

    /// 伪代码 0x100d442f4（L66-86 + closure #3/#4）：
    /// 前台 scene 的窗口 trait 归一（activationState 过滤 + traitCollection 确证）。
    static func resolvedSystemUserInterfaceStyle() -> UIUserInterfaceStyle? {
        let activeScenes = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
        for scene in activeScenes {
            if let window = scene.windows.first(where: \\.isKeyWindow) {
                return window.traitCollection.userInterfaceStyle
            }
        }
        return nil
    }
}

/// 系统外观监视修饰（trait 变化 → 分发）。
struct SystemAppearanceMonitorModifier: ViewModifier {

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .onChange(of: colorScheme, initial: true) { _, newScheme in
                // closure #2（0x100d45178，L98-101）：异步分发。
                let style: UIUserInterfaceStyle =
                    newScheme == .dark ? .dark : .light
                Task { @MainActor in
                    _ = SystemAppearanceDispatcher().dispatch(
                        style, source: "colorScheme")
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification)) { _ in
                // closure #3（0x100d451a8，L102-104）：回前台重探。
                Task { @MainActor in
                    if let style = SystemAppearanceDispatcher
                        .resolvedSystemUserInterfaceStyle() {
                        _ = SystemAppearanceDispatcher().dispatch(
                            style, source: "didBecomeActive")
                    }
                }
            }
            // 探针 VC（不可见 trait 观察，L116-163 确证）。
            .background(SystemAppearanceProbe())
            .allowsHitTesting(true)
    }
}

/// 外观探针（不可见 Representable；makeUIViewController 确证）。
struct SystemAppearanceProbe: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UIViewController {
        SystemAppearanceProbeViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

/// 探针控制器（生命周期确证；trait 变化即分发）。
final class SystemAppearanceProbeViewController: UIViewController {

    private let dispatcher = SystemAppearanceDispatcher()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshSceneRegistrations()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshSceneRegistrations()
    }

    /// 伪代码 0x100d4535c（L149-163）：场景注册刷新 + trait 分发。
    func refreshSceneRegistrations() {
        guard let style = SystemAppearanceDispatcher
            .resolvedSystemUserInterfaceStyle() else { return }
        _ = dispatcher.dispatch(style, source: "probe")
    }
}

extension View {

    /// 骨架签名 systemAppearanceMonitor()（LeaflowApp body 调用确证）。
    func systemAppearanceMonitor() -> some View {
        modifier(SystemAppearanceMonitorModifier())
    }
}
