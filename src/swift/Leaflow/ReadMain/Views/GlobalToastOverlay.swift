// 原路径: ReadMain/Views/GlobalToastOverlay.swift
// 证据:
//   - PGO: 15 个主函数（index/task_functions.csv T-101-05 / GlobalToastOverlay.swift），
//     地址：body 0x100cf4b40 L11-28（+closure #1 0x100cf5144 L12-26）/
//     toastCard 0x100cf5648 L31-48 / GlobalJSToastModifier.body 0x100cf5ca0
//     L75-105（+closure #1/#2/#3 0x100cf6564-0x100cf6bb8）/ showNextToast
//     0x100cf74b0 L114-127（+closure ×2）/ globalToastOverlay 扩展
//     0x100cfe3b4 L55-59（+closure 0x100cfe924）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/GlobalToastOverlay.c
//   - 关键调用：NSNotificationCenter.publisher(for:object:) ×2（L441/L460 确证）/
//     Notification.userInfo（L1249/L1297/L1419 确证）/ allowsHitTesting /
//     onTapGesture / DispatchQueue.main.asyncAfter（showNextToast closure #2）
//   - 事实：GlobalToastOverlay —— AppErrorPresenter.queue 顶层渲染
//     （allowsHitTesting(false) + toastCard(item)）；toastCard —— 卡片
//     （icon/tintColor 消费）；GlobalJSToastModifier —— JS 桥 toast：
//     两个通知 publisher（L441/L460）+ userInfo 取值（message/level）+
//     showNextToast 队列调度（asyncAfter）；globalToastOverlay() 扩展挂载
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body/toastCard/挂载扩展: high（builder 描述确证）
//   - JS toast 通知名与 userInfo 键: medium（publisher ×2 + userInfo 确证；键名待真机）
// 还原: 2026-11-19

import SwiftUI

/// 全局提示覆盖层（顶层挂载，消费 AppErrorPresenter.queue）。
struct GlobalToastOverlay: View {

    @ObservedObject private var presenter = AppErrorPresenter.shared

    var body: some View {
        // 伪代码 0x100cf4b40（L11-28）+ closure #1（0x100cf5144）。
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // allowsHitTesting(false)（closure #1 确证）：不拦截交互。
                Color.clear.allowsHitTesting(false)
                if let item = presenter.queue.first {
                    toastCard(item)
                        .padding(.top, proxy.safeAreaInsets.top + 12)
                        .onTapGesture {
                            presenter.dismiss()
                        }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 伪代码 0x100cf5648（L31-48）：单条提示卡片
    ///（icon/tintColor 消费确证）。
    private func toastCard(_ item: ToastItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.level.icon)
                .foregroundColor(item.level.tintColor)
            Text(item.message)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .background(item.level.tintColor.opacity(0.12).clipShape(Capsule()))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// JS 桥 toast 修饰（WebView 侧通知 → 队列调度）。
struct GlobalJSToastModifier: ViewModifier {

    @State private var pendingMessages: [ToastItem] = []
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: .jsToastWillShow)) { notification in
                // 伪代码 closure #2（0x100cf6634，L93-98）：
                // Notification.userInfo 取值（L1249 确证）。
                enqueueFrom(notification)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .jsToastDidHide)) { notification in
                // 伪代码 closure #3（0x100cf6bb8，L99-104）。
                enqueueFrom(notification)
            }
            .onChange(of: isShowing, initial: false) { _, showing in
                if !showing {
                    showNextToast()
                }
            }
            .overlay(alignment: .top) {
                if isShowing, let current = pendingMessages.first {
                    GlobalToastOverlay.toastCardStandalone(current)
                        .onTapGesture(count: 2) {
                            // closure #1（0x100cf6564，L77-91）：双击提前关闭。
                            isShowing = false
                        }
                }
            }
    }

    /// 通知载荷入队（userInfo 确证；键名待真机对照）。
    private func enqueueFrom(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let message = userInfo["message"] as? String ?? ""
        let levelName = userInfo["level"] as? String ?? "info"
        let level: ToastLevel
        switch levelName {
        case "success": level = .success
        case "warning": level = .warning
        case "error": level = .error
        default: level = .info
        }
        pendingMessages.append(
            ToastItem(message: message, level: level, duration: 2.5))
        if !isShowing {
            showNextToast()
        }
    }

    /// 伪代码 0x100cf74b0（L114-127）+ closure #2（0x100cf7a88，L121-126）：
    /// 队列头部上屏 + asyncAfter 定时关闭。
    private func showNextToast() {
        guard !pendingMessages.isEmpty else { return }
        isShowing = true
        let duration = pendingMessages.first?.duration ?? 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            MainActor.assumeIsolated {
                isShowing = false
            }
        }
    }
}

private extension GlobalToastOverlay {

    /// 单条独立渲染（JS toast 覆盖层复用）。
    static func toastCardStandalone(_ item: ToastItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.level.icon)
                .foregroundColor(item.level.tintColor)
            Text(item.message)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}

extension View {

    /// 伪代码 0x100cfe3b4（L55-59）+ closure（0x100cfe924）：
    /// 全局提示挂载扩展。
    func globalToastOverlay() -> some View {
        overlay {
            GlobalToastOverlay()
        }
    }
}

extension Notification.Name {
    /// JS toast 通知（publisher ×2 确证；名字为还原命名）。
    static let jsToastWillShow = Notification.Name("leafflow.jsToastWillShow")
    static let jsToastDidHide = Notification.Name("leafflow.jsToastDidHide")
}
