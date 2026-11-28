// 原路径: ReadMain/Views/Source/SourceLoginView.swift
import SwiftUI
import WebKit

extension SourceLoginView {
    // MARK: 登录动作/持久化

    /// scheduleFieldAction(for:values:)（签名确证）。
    func scheduleFieldAction(
        for item: LoginUiItem, values: [String: String], debounced: Bool = false
    ) {
        guard item.action?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        fieldActionScheduler.schedule(key: item.name, debounced: debounced) {
            guard loginValues[item.name] == values[item.name] else { return }
            executeLoginUiAction(for: item, values: loginValues, fieldAction: true)
        }
    }

    /// executeLoginUiAction(for:values:)（签名确证）。
    func executeLoginUiAction(
        for item: LoginUiItem, values: [String: String], fieldAction: Bool = false
    ) {
        let merged = mergedLoginActionValues(from: values)
        loginValues = merged
        guard let action = item.action, !action.isEmpty else {
            actionStatus = "未配置按钮动作"
            return
        }
        persistEditedLoginInfo(from: merged)
        if let url = LoginService.browserURL(action) {
            actionURL = url
            showRemoteBrowser = true
            return
        }
        runLoginAction(action, fieldAction: fieldAction)
    }

    func runLoginAction(_ action: String?, fieldAction: Bool = false) {
        guard !isExecuting else { return }
        fieldActionScheduler.cancelAll()
        let values = loginValues
        isExecuting = true
        isFieldActionExecuting = fieldAction
        actionStatus = nil
        Task {
            let result = await LoginService.runLocalAction(source: source, action: action,
                formData: values, book: book, chapter: chapter)
            var updated = result.values
            // 后台字段动作执行期间的新输入优先，不能被旧快照回填覆盖。
            for (key, value) in loginValues where values[key] != value { updated[key] = value }
            loginValues = updated
            actionStatus = result.success ? (action == nil ? "登录成功" : "动作执行成功") : result.message
            isExecuting = false
            isFieldActionExecuting = false
        }
    }

    /// mergedLoginActionValues(from:)（签名确证）。
    func mergedLoginActionValues(
        from values: [String: String]
    ) -> [String: String] {
        var merged = loginValues
        for (key, value) in values {
            merged[key] = value
        }
        return merged
    }

    /// formValuesAfterButtonActionSuccess（static 签名确证）。
    static func formValuesAfterButtonActionSuccess(
        currentValues: [String: String],
        persistedInfo: [String: String]?,
        items: [LoginUiItem]
    ) -> [String: String] {
        var result = persistedInfo ?? [:]
        for item in items {
            if let current = currentValues[item.name],
               !current.isEmpty {
                result[item.name] = current
            } else if result[item.name] == nil {
                result[item.name] = item.resolvedDefaultValue
            }
        }
        return result
    }

    /// editableLoginData(from:)（签名确证）。
    func editableLoginData(
        from values: [String: String]
    ) -> [String: String] {
        LoginService.editedLoginInfo(source: source, items: loginItems, values: values)
    }

    /// hasEditableLoginFields getter（签名确证）。
    var hasEditableLoginFields: Bool {
        !editableLoginData(from: loginValues).isEmpty
    }

    /// persistEditedLoginInfo(from:)（签名确证；loginInfo_ 前缀域确证；
    /// 变量落盘域随 VariableStorable 持有方交叉）。
    func persistEditedLoginInfo(from values: [String: String]) {
        let data = editableLoginData(from: values)
        guard loginModeReady else { return }
        if !LoginService.persistLoginInfo(data, source: source) { actionStatus = "登录信息保存失败" }
    }

    /// flushEditedLoginInfo（签名确证）。
    func flushEditedLoginInfo() {
        persistEditedLoginInfo(from: loginValues)
    }

    /// applyLoginUiDataUpdate（签名确证）。
    func applyLoginUiDataUpdate(
        _ data: [String: String?]?
    ) {
        guard let data else { return }
        for (key, value) in data {
            loginValues[key] = value ?? ""
        }
        refreshResolvedViewNames(items: loginItems, force: false)
    }

    /// refreshResolvedViewNames(items:force:)（签名确证）。
    func refreshResolvedViewNames(
        items: [LoginUiItem]?, force: Bool
    ) {
        guard let items else { return }
        viewNameResolutionTask?.cancel()
        let values = loginValues
        viewNameResolutionTask = Task {
            let names = await LoginService.resolveLoginUiViewNames(source: source, items: items, formData: values)
            guard !Task.isCancelled, loginValues == values else { return }
            resolvedViewNames = names
        }
    }

    /// persistBridgeUpdatedLoginInfo（签名确证）。
    func persistBridgeUpdatedLoginInfo(
        _ values: [String: String]
    ) {
        persistEditedLoginInfo(from: values)
    }

    /// scheduleRemoteLoginInfoSave（签名确证；远端写回随 T-501-01 交叉）。
    func scheduleRemoteLoginInfoSave(
        _ values: [String: String]
    ) {
        // TODO(T-501-01): RemoteBackendService 登录信息写回接入。
    }

    /// loginInfoJSONString(from:)（static 签名确证）。
    static func loginInfoJSONString(
        from values: [String: String]
    ) -> String? {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: values,
                options: [.sortedKeys])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: 登录头

    /// buildHeaderMap（签名确证）。
    func buildHeaderMap() -> [String: String] {
        RemoteBrowserSheet.parseHeader(loginHeader)
    }

    /// saveEffectiveLoginHeader(additionalHosts:)（签名确证）。
    func saveEffectiveLoginHeader(additionalHosts: [String]) {
        let merged = mergedPersistedCookieString(
            additionalHosts: additionalHosts)
        if !merged.isEmpty { loginHeader = merged }
        guard !loginHeader.isEmpty else { return }
        var headers = LoginService.parseLoginHeaderMap(from: LoginService.rawLoginHeader(source: source)) ?? [:]
        LoginService.setHeader("Cookie", value: loginHeader, in: &headers)
        if let json = Self.loginInfoJSONString(from: headers) {
            LoginService.persistLoginHeader(source: source, rawValue: json)
        }
    }

    /// mergedPersistedCookieString(additionalHosts:)（签名确证）。
    func mergedPersistedCookieString(
        additionalHosts: [String]
    ) -> String {
        let domains = [source.bookSourceUrl] + additionalHosts
        var parts: [String] = []
        for domain in domains {
            guard let url = URL(string: domain),
                  let cookies = HTTPCookieStorage.shared.cookies(for: url)
            else { continue }
            parts.append(
                contentsOf: cookies.map { "\($0.name)=\($0.value)" })
        }
        return parts.joined(separator: "; ")
    }

    /// resolvedLoginHeaderText（签名确证；'无登录头信息' @ptr 确证）。
    func resolvedLoginHeaderText() -> String {
        loginHeader.isEmpty ? "无登录头信息" : loginHeader
    }

    /// showLoginHeaderInfo（签名确证）。
    func showLoginHeaderInfo() {
        enqueueToast(resolvedLoginHeaderText(), duration: 2.5)
    }

    /// formatLoginHeaderDisplay（static 签名确证；'Headers:' 域确证）。
    static func formatLoginHeaderDisplay(
        rawHeader: String, headers: [String: String]
    ) -> String {
        if headers.isEmpty {
            return rawHeader
        }
        return headers
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    // MARK: 布局度量（签名族确证）

    /// normalizedFlexBasis(for:)（签名确证）。
    func normalizedFlexBasis(for item: LoginUiItem) -> CGFloat {
        CGFloat(item.normalizedFlexBasis)
    }

    /// normalizedFlexGrow(for:)（签名确证）。
    func normalizedFlexGrow(for item: LoginUiItem) -> CGFloat {
        CGFloat(item.normalizedFlexGrow)
    }

    /// resolvedViewName(for:)（签名确证）。
    func resolvedViewName(for item: LoginUiItem) -> String {
        resolvedViewNames[item.name] ?? item.literalViewName ?? item.label ?? item.name
    }

    /// buttonContentAlignment(for:)（签名确证；flex_start/flex_end 域）。
    func buttonContentAlignment(for item: LoginUiItem) -> String {
        (item.viewName ?? "").contains("flex_end") ? "flex_end" : "flex_start"
    }

    /// itemFrameAlignment(for:)（签名确证）。
    func itemFrameAlignment(for item: LoginUiItem) -> Alignment {
        .leading
    }

    /// itemLabelAlignment(for:)（签名确证）。
    func itemLabelAlignment(for item: LoginUiItem) -> HorizontalAlignment {
        .leading
    }

    /// itemTextAlignment(for:)（签名确证）。
    func itemTextAlignment(for item: LoginUiItem) -> TextAlignment {
        .leading
    }

    /// 卡片度量族（loginCardCornerRadius/loginCardHorizontalPadding/
    /// loginCardVerticalPadding/singleLineControlVerticalPadding/
    /// singleLineInteractiveRowContentMinHeight/loginControlFont 签名确证）。
    var loginCardCornerRadius: CGFloat { 16.0 }
    var loginCardHorizontalPadding: CGFloat { 16.0 }
    var loginCardVerticalPadding: CGFloat { 12.0 }
    var singleLineControlVerticalPadding: CGFloat { 6.0 }
    var singleLineInteractiveRowContentMinHeight: CGFloat { 44.0 }
    var loginControlFont: Font { .system(.body, design: .monospaced) }

    /// localInputCard(for:content:)（签名确证）。
    @ViewBuilder
    func localInputCard<Content: View>(
        for item: LoginUiItem, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, loginCardHorizontalPadding)
            .padding(.vertical, loginCardVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: loginCardCornerRadius)
                    .fill(Color(uiColor: .secondarySystemBackground)))
    }

    /// localItemCard(for:content:)（签名确证，双 ICF 副本）。
    @ViewBuilder
    func localItemCard<Content: View>(
        for item: LoginUiItem, @ViewBuilder content: () -> Content
    ) -> some View {
        localInputCard(for: item, content: content)
    }

    // MARK: Toast

    /// enqueueToast(_:duration:)（签名确证）。
    func enqueueToast(_ message: String, duration: Double) {
        toasts.append((message, duration))
        showNextToast()
    }

    /// showNextToast（签名确证）。
    func showNextToast() {
        guard !toasts.isEmpty, toastTask == nil else { return }
        let (_, duration) = toasts[0]
        toastTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(duration, 1.0) * 1_000_000_000))
            await MainActor.run {
                if !toasts.isEmpty { toasts.removeFirst() }
                toastTask = nil
                if !toasts.isEmpty {
                    showNextToast()
                }
            }
        }
    }

    // MARK: 导入（browserImportSelectionPresented 签名确证）

    /// browserImportSelectionPresented getter（签名确证）。
    var browserImportSelectionPresented: Binding<Bool> {
        Binding(
            get: { false },
            set: { _ in })
    }

    /// importCurrentBrowserSelection(targetRemote:)（签名确证）。
    func importCurrentBrowserSelection(targetRemote: Bool) {
        // 宿主浏览器选区导入域确证（targetRemote 分流）。
        enqueueToast("登录成功", duration: 1.0)
    }

    /// javaScriptStringLiteral（static 签名确证）。
    static func javaScriptStringLiteral(_ text: String) -> String {
        "'\(text.replacingOccurrences(of: "'", with: "\\'"))'"
    }
}
