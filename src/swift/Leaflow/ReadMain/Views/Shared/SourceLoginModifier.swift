// 原路径: ReadMain/Views/Shared/SourceLoginModifier.swift
// 证据:
//   - PGO: 21 个主函数（index/task_functions.csv T-401-03 / SourceLoginModifier.swift），
//     地址：body 0x100b6afa4 L22-89 / closure1 0x100b6b2a8 L25-27（登录态复位
//     Task）/ closure2 0x100b6b3c4 L27-34（BookSource onAppear → 远程登录检查
//     Task）/ closure3 0x100b6b624 L36-43（Task 派发）/ closure4 0x100b6bc40
//     L43-56（RemoteBrowserRequest → 表单态写入）/ closure1-in-4 0x100b6bcac
//     L48-50（URL → RemoteBrowserRequest 构造写入）/ closure5 0x100b6bec0
//     L57-61（userInfo AnyHashable 0x74736575716572 = "request" 位模式确证，
//     动态_cast RemoteBrowserRequest 后写入态）/ closure6 0x100b6c238 L63-67
//     （通知 → 置位 + RemoteBackendService.urlEncode）/ closure8 0x100b6c38c
//     L73-83（(Bool, Bool)：true→置位+urlEncode、false→复位+retainWebSocket）/
//     closure9 0x100b6da28 L84-88（SplashOverlayView.resolveSplash 兜底，
//     double 返回 0.0）/ sourceLogin 真身 0x1003f8834 L100-108（另 10 个
//     ICF 特化副本：0x100484d64/0x1004c1754/0x1004c18b0/0x1004c9890/
//     0x100550680/0x100595d38/0x100597e30/0x1005e1228/0x10080c7f0/0x1008eb510）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Shared/SourceLoginModifier.c
//     （1247 行）
//   - 事实：私有状态三件（PGO 变量确证）：_lastLoginSourceUrl /
//     _lastLoginSourceStateKey / _wsRetained；body 经 JSBrowserRequest.tryHandle
//     (sourceStateKey:presentationContext:) 桥接（implicit closure #1 复用确证）+
//     @Bindable AppThemeManager；14.0 间距常量（0x402C000000000000）与
//     VerticalAlignment.center（sourceLogin 真身确证）；
//     AppThemeContentCardStyleModifier keyPath 注入（真身确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 状态机/联动闭包: high（urlEncode/retainWebSocket/"request" 位模式确证）
//   - body 视图树形状: medium（结构性还原；SwiftUI 树与通知名细节待真机对照）
//   - sourceLogin 扩展: medium-high（真身块体确证，11 副本按 ICF 归组）
// 还原: 2026-11-20

import SwiftUI

/// 书源登录修饰器：远程浏览器表单 + 登录态 + WebSocket 联动状态机。
struct SourceLoginModifier: ViewModifier {

    /// 登录请求表单态（closure4 确证）。
    @State private var browserRequest: RemoteBrowserRequest?

    /// 上次登录源 url（PGO _lastLoginSourceUrl 变量确证）。
    @State private var lastLoginSourceUrl: String?

    /// 登录源状态键（PGO _lastLoginSourceStateKey 变量确证）。
    @State private var lastLoginSourceStateKey: String?

    /// WebSocket 保持标记（PGO _wsRetained 变量确证）。
    @State private var wsRetained = false

    /// 主题绑定（body @Bindable AppThemeManager 确证）。
    private let theme = AppThemeManager.shared

    /// 伪代码 0x100b6afa4（L22-89）：MainActor body——登录桥
    ///（JSBrowserRequest.tryHandle(sourceStateKey:presentationContext:) 复用
    /// 确证）+ 远程浏览器表单 + WebSocket 联动 + Splash 兜底。
    /// 视图树形状按结构性还原；通知名待真机对照（见分册仍不清楚）。
    func body(content: Content) -> some View {
        content
            // closure3（0x100b6b624，L36-43）：前置 Task 派发。
            .onAppear(perform: dispatchLoginPreflight)
            // closure1（0x100b6b2a8，L25-27）：登录态复位 Task
            //（双 State 写空，Book.== 域哨兵确证）。
            .task { await resetLoginState() }
            // closure5（0x100b6bec0，L57-61）：表单态变化联动
            //（通知 facets 见 handleLoginRequestNotification）。
            .onChange(of: browserRequest) { oldValue, newValue in
                handleBrowserRequestChange(oldValue, newValue)
            }
            // closure8（0x100b6c38c，L73-83）：WebSocket 联动。
            .onChange(of: wsRetained) { oldValue, newValue in
                handleWebSocketChange(oldValue, newValue)
            }
            // closure9（0x100b6da28，L84-88）：Splash 兜底（resolveSplash 确证）。
            .background(splashProbe)
    }

    /// closure9（0x100b6da28，L84-88）：resolveSplash 探针（double 兜底 0.0）。
    private var splashProbe: some View {
        Color.clear.onAppear {
            _ = SplashOverlayView.resolveSplash()
        }
    }

    // MARK: 状态机（闭包语义承接）

    /// closure1（0x100b6b2a8，L25-27）：登录态复位——两次 State 写空。
    private func resetLoginState() async {
        lastLoginSourceUrl = nil
        lastLoginSourceStateKey = nil
    }

    /// closure3（0x100b6b624，L36-43）：Task 派发（续体 sub_100B6B6AC，
    /// 体未展开）——登录检查前置任务占位。
    private func dispatchLoginPreflight() {
        Task { await resetLoginState() }
    }

    /// closure2（0x100b6b3c4，L27-34）：源出现——登录态非空即复位，
    /// 并以捕获源派发 MainActor 登录检查 Task（sub_100D3A2C8 域）。
    private func handleSourceAppear(_ source: BookSource) {
        guard lastLoginSourceStateKey != nil else { return }
        lastLoginSourceStateKey = nil
        let captured = source
        Task { await checkRemoteLogin(for: captured) }
    }

    /// closure2 捕获 Task 终点：远程登录检查（体未展开，
    /// 待 RemoteBackendService 分册交叉）。
    private func checkRemoteLogin(for source: BookSource) async {}

    /// closure4（0x100b6bc40，L43-56）：表单态写入。
    private func presentBrowserSheet(_ request: RemoteBrowserRequest) {
        browserRequest = request
    }

    /// closure1-in-4（0x100b6bcac，L48-50）：URL → RemoteBrowserRequest
    /// 构造写入（url + 状态键两字段对确证）。
    private func openLoginURL(_ url: URL) {
        presentBrowserSheet(RemoteBrowserRequest(url: url))
    }

    /// closure5（0x100b6bec0，L57-61）：通知 facet——userInfo["request"]
    /// 取 RemoteBrowserRequest（AnyHashable "request" 位模式确证），
    /// 动态_cast 成功即写入表单态；通知名待真机对照。
    private func handleLoginRequestNotification(_ notification: Notification) {
        guard let raw = notification.userInfo?["request"] else { return }
        guard let request = raw as? RemoteBrowserRequest else { return }
        presentBrowserSheet(request)
    }

    /// closure5（0x100b6bec0，L57-61）：签名 facet——(旧值, 新值) 变化联动
    ///（Hex-Rays 签名 (RemoteBrowserRequest?, RemoteBrowserRequest?) 确证）。
    private func handleBrowserRequestChange(
        _ oldValue: RemoteBrowserRequest?, _ newValue: RemoteBrowserRequest?
    ) {
        guard let newValue = newValue else { return }
        presentBrowserSheet(newValue)
    }

    /// closure6（0x100b6c238，L63-67）：通知到达且 wsRetained 未置位时
    /// 置位并 urlEncode（RemoteBackendService.urlEncode 确证）；
    /// 通知名待真机对照。
    private func handleConnectionNotification(_ notification: Notification) {
        guard !wsRetained else { return }
        wsRetained = true
        RemoteBackendService.shared.urlEncode("")
    }

    /// closure8（0x100b6c38c，L73-83）：(Bool, Bool) 联动——
    /// 新值 true 且未置位 → 置位 + urlEncode；
    /// 新值 false 且已置位 → 复位 + retainWebSocket。
    private func handleWebSocketChange(_ oldValue: Bool, _ newValue: Bool) {
        if newValue {
            guard !wsRetained else { return }
            wsRetained = true
            RemoteBackendService.shared.urlEncode("")
        } else {
            guard wsRetained else { return }
            wsRetained = false
            RemoteBackendService.shared.retainWebSocket()
        }
    }
}

/// View 扩展：书源登录入口（真身 0x1003f8834，L100-108；另 10 个调用点
/// ICF 特化副本已按 T-201-01 事实 42 模式归组登记）。
extension View {

    /// 伪代码 0x1003f8834（L100-108）：BookActionSheetView 域结构——
    /// VerticalAlignment.center + 14.0 间距（0x402C000000000000 确证）+
    /// AppThemeContentCardStyleModifier keyPath 注入 + @Bindable AppThemeManager +
    /// onChange(of: Int) 状态联动。
    func sourceLogin(
        source: Binding<BookSource?>,
        isRemoteMode: Bool,
        book: Book?,
        chapter: Chapter?,
        onDismiss: (() -> Void)?
    ) -> some View {
        modifier(SourceLoginModifier())
            .onChange(of: source.wrappedValue?.bookSourceUrl ?? "") { _, _ in
                // 真身 onChange(of: Int) 状态联动域（键值映射体未展开）。
            }
    }
}
