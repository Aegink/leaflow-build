// 原路径: ReadMain/Views/Source/SourceLoginView.swift
// 证据:
//   - PGO: 494 条记录（index/task_functions.csv T-401-06 /
//     SourceLoginView.swift；伪代码域 27044 行）。关键地址域：
//     JSBrowserRequest（handled/runtimeContext/result/tryHandle(
//     sourceStateKey:presentationContext:)/complete(result:)/
//     waitForCompletion(timeout:)/init(url:title:html:webJs:config:)）/
//     JSBrowserNavigationRequest（init(request:)/init(url:method:headers:)/
//     makeURLRequest/localDocument()）/ SourceBrowserURLRouting
//     .shouldOpenInHostApp(URL)（×3 ICF 副本）/ SourceBrowserRequestResolver
//     .resolve(ruleURL:source:runtimeContext:)/localHTML(fromDataURL:)/
//     canResolveBrowserURL(String) / SourceBrowserImportRouting
//     .importSourceURL(from:)/action(for:) / InteractiveBrowserWebView
//     （makeCoordinator/makeUIView/updateUIView/dismantleUIView/
//     browserCompatibilityScript/collectCookies/applyBackground/
//     debugSnippet/debugHeaderSummary/debugCookieSummary；Coordinator：
//     currentRuntimeContext/edgeSwipe 族/手势/导航代理族/captureHTML/
//     executeBridgeJavaScript/saveCookies/captureAndReturn）/ LoginWebView
//     （collectExistingCookies/persistObservedCookies/cookiesDidChange/
//     captureAndSaveCookies）/ SourceLoginView（body/webViewLoginContent/
//     formLoginContent/initLogin/flushEditedLoginInfo/
//     applyLoginUiDataUpdate/reloadLoginUi/saveEffectiveLoginHeader/
//     handleBrowserHostAppNavigation/importCurrentBrowserSelection/
//     enqueueToast/showNextToast/applyResolvedLoginUiItems/setupLoginMode/
//     refreshResolvedViewNames/persistBridgeUpdatedLoginInfo/
//     scheduleRemoteLoginInfoSave/resolveLoginUrl/buildHeaderMap/
//     performFormLogin/binding(for:)/handleButtonAction/
//     localVisibleLoginUiItems/localLoginUiItemView/normalizedFlexBasis/
//     normalizedFlexGrow/mergedPersistedCookieString/
//     resolvedLoginHeaderText/formatLoginHeaderDisplay/resolvedViewName/
//     currentValue/对齐三件/updateSelectValue/cycleToggleValue/
//     toggleValueBadge/LocalLoginGlassCardModifier/
//     LocalLoginInteractiveGlassCardModifier/persistEditedLoginInfo/
//     scheduleFieldAction/executeLoginUiAction/mergedLoginActionValues/
//     hasEditableLoginFields/editableLoginData/loginInfoJSONString/
//     showLoginHeaderInfo/legacyFormLoginBody/localFormLoginBody/
//     卡片度量族/javaScriptStringLiteral/formValuesAfterButtonActionSuccess/
//     isSourceRemoteMode）/ LoginFormFlexLayout（sizeThatFits/arrangedRows/
//     placeSubviews/preferredWidth + flushCurrentRow 闭包）/
//     SourceLoginScreenModifier + View.sourceLoginScreenStyle /
//     RemoteBrowserSheet（body/parseHeader/handleBrowserHostAppNavigation/
//     captureAndSaveCookies/browserImportSelectionPresented/
//     importCurrentBrowserSelection）/ RemoteBrowserWebView（makeUIView/
//     updateUIView/makeCoordinator + Coordinator 导航域）
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceLoginView.c
//     （27044 行）
//   - 字符串确证（位模式/IPA 指针）：桥域 '[InteractiveBrowserBridge] #'
//     @ptr / ' worker start baseURL=' / ' executeJsRule begin' /
//     ' executeJsRule end resultChars=' @ptr / ' elapsed' / 's baseURL=' /
//     ' result=' / ' timeout' / 's script' / 'ser] handoff-to-host-app
//     url=' @ptr / 'ser] htmlCapture chars=' @ptr / 'ser] didStart url='
//     @ptr / 'ser] persistCookies total=' @ptr / ' prompt script=' /
//     ' referer=' / ' origin=' / ' cookieLen=' / ' webJsChars=' /
//     ' headers' / ' cookies' / ' method=' / ' mainFra' / ' domains='；
//     路由域 'qireader'（L31，宿主 scheme 确证）/'about:blank'（L448）/
//     'data:text/html'（L577）/'https://'；表单域 'password'（type 域）/
//     'loginInfo_'（L14063）/'loginHeader_'（L17581）/'Headers:'/'无登录头
//     信息' @ptr/'登录信息'/'登录成功'/'无可配置项'/'无效的登录 URL' @ptr/
//     '登录 - '/'远程后端'/'sourceVariable_'/'flex_start'/'flex_end'/
//     '页面加载完成: ' @ptr/'无法打开浏览器' @ptr
//   - 事实：JSBrowserRequest 经 tryHandle(sourceStateKey:presentationContext:)
//     桥接（T-401-03 SourceLoginModifier body 复用确证）；
//     handleBrowserHostAppNavigation 双实现（SourceLoginView/
//     RemoteBrowserSheet）+ shouldOpenInHostApp ×3 ICF 副本；
//     qireader:// 宿主 scheme + about:blank/data:text/html 本地文档域；
//     saveEffectiveLoginHeader(additionalHosts:) + loginHeader_ 前缀 +
//     'Headers:' 展示；mergedPersistedCookieString 合并持久 cookie；
//     LoginFormFlexLayout 自定义 Layout（arrangedRows + flushCurrentRow
//     闭包确证）；flex_start/flex_end 对齐域确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 桥接/路由/解析器: high（签名族 + 桥串确证）
//   - WebView 协调器: medium-high（代理族 + 捕获域确证）
//   - 登录表单/Flex 布局: medium-high（域串 + Layout 签名确证）
//   - 远端登录态持久化细节: medium（loginInfo_/loginHeader_ 前缀确证，
//     远端写回随 T-501-01 交叉）
// 还原: 2026-11-20

import SwiftUI
import WebKit
import UIKit

// MARK: - SourceLoginView

/// 书源登录视图（WebView 登录 + 表单登录双模）。
@MainActor
struct SourceLoginView: View {
    let source: BookSource
    var book: Book?
    var chapter: Chapter?

    // 登录表单态（loginInfo_ 前缀域确证）。
    @State var loginValues: [String: String] = [:]
    @State var loginItems: [LoginUiItem] = []
    @State var loginModeReady = false
    @State var loginURL: URL?
    @State var loginHeader: String = ""
    @State var toasts: [(String, Double)] = []
    @State var toastTask: Task<Void, Never>?
    @State var showRemoteBrowser = false
    @State var actionURL: URL?
    @State var isExecuting = false
    @State var actionStatus: String?
    @State var resolvedViewNames: [String: String] = [:]
    @State var viewNameResolutionTask: Task<Void, Never>?
    @State var loginInitializationStarted = false
    @State var fieldActionScheduler = LoginFieldActionScheduler()
    @Environment(\.dismiss) var dismiss

    init(source: BookSource, book: Book?, chapter: Chapter?) {
        self.source = source
        self.book = book
        self.chapter = chapter
    }

    /// isSourceRemoteMode getter（签名确证；'远程后端' 域确证）。
    var isSourceRemoteMode: Bool {
        !source.bookSourceUrl.isEmpty
            && source.bookSourceUrl.contains("远程后端") == false
            && loginURL?.scheme == "https"
    }

    var body: some View {
        // body（签名域）：导航壳 + 双模内容。
        NavigationStack {
            Group {
                if !loginModeReady {
                    ProgressView("正在加载登录配置")
                } else if source.loginUrl == nil && loginItems.isEmpty && actionStatus == nil {
                    Text("无可配置项")
                        .appThemeText(.caption, opacity: 0.6)
                } else if loginURL != nil {
                    webViewLoginContent
                } else {
                    formLoginContent
                }
            }
            .navigationTitle("登录 - \(source.bookSourceName)")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(SourceLoginScreenModifier())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { flushEditedLoginInfo(); dismiss() }
                        .disabled(isExecuting)
                        .accessibilityIdentifier("source-login-close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登录信息") { showLoginHeaderInfo() }
                }
            }
            .onAppear {
                initLogin()
            }
            .onDisappear { flushEditedLoginInfo(); viewNameResolutionTask?.cancel(); fieldActionScheduler.cancelAll() }
            .onChange(of: loginValues) { _, _ in refreshResolvedViewNames(items: loginItems, force: false) }
            .onReceive(NotificationCenter.default.publisher(for: LoginService.dataUpdatedNotification)) { notification in
                guard notification.userInfo?["sourceStateKey"] as? String == source.stateKey else { return }
                if let data = notification.userInfo?["data"] as? [String: Any] {
                    applyLoginUiDataUpdate(data.mapValues { $0 is NSNull ? nil : String(describing: $0) })
                } else {
                    loginValues = LoginService.resolvedLoginInfo(source: source, items: loginItems)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: LoginService.reloadRequestedNotification)) { notification in
                guard notification.userInfo?["sourceStateKey"] as? String == source.stateKey else { return }
                setupLoginMode()
            }
            .interactiveDismissDisabled(isExecuting)
            .sheet(isPresented: $showRemoteBrowser) {
                if let url = actionURL {
                    RemoteBrowserSheet(
                        source: source,
                        request: RemoteBrowserRequest(
                            url: url,
                            sourceStateKey: source.bookSourceUrl)) { header in
                        loginHeader = header
                        saveEffectiveLoginHeader(additionalHosts: [])
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toasts.first {
                    Text(toast.0)
                        .appThemeText(.caption)
                        .padding(.horizontal, 14.0)
                        .padding(.vertical, 8.0)
                        .background(
                            Capsule().fill(Color.black.opacity(0.75)))
                        .padding(.bottom, 24.0)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: 登录模式

    /// initLogin（签名确证）：按 loginUrl/loginUi 建立模式。
    func initLogin() {
        guard !loginInitializationStarted else { return }
        loginInitializationStarted = true
        setupLoginMode()
    }

    /// setupLoginMode（签名确证）：解析登录 URL 与表单项。
    func setupLoginMode() {
        let raw = source.loginUrl ?? ""
        loginURL = resolveLoginUrl(raw)
        Task {
            let parsed = await LoginService.parseLoginUi(source: source, book: book, chapter: chapter)
            loginItems = parsed.items
            actionStatus = parsed.error
            loginValues = LoginService.resolvedLoginInfo(source: source, items: loginItems)
            loginModeReady = true
            refreshResolvedViewNames(items: loginItems, force: true)
        }
    }

    /// resolveLoginUrl（签名确证；'无效的登录 URL' 域确证）。
    func resolveLoginUrl(_ raw: String) -> URL? {
        LoginService.browserURL(raw)
    }

    // MARK: WebView 登录

    /// webViewLoginContent getter（签名确证）。
    var webViewLoginContent: some View {
        VStack(spacing: 0) {
            if let url = loginURL {
                LoginWebView(
                    source: source, loginHost: url.host, loginURL: url,
                    onCookieObserved: { header in
                        loginHeader = header
                        saveEffectiveLoginHeader(additionalHosts: [])
                    })
            }
            if !loginHeader.isEmpty {
                Text("Headers:")
                    .appThemeText(.caption, opacity: 0.6)
                Text(Self.formatLoginHeaderDisplay(
                    rawHeader: loginHeader, headers: buildHeaderMap()))
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(4)
                    .padding(.horizontal, 12.0)
            }
        }
    }

    /// handleBrowserHostAppNavigation（签名确证）。
    func handleBrowserHostAppNavigation(_ url: URL) {
        // 'ser] handoff-to-host-app url=' 域确证。
        enqueueToast(url.absoluteString, duration: 2.0)
    }

    // MARK: 表单登录

    /// formLoginContent getter（签名确证）。
    var formLoginContent: some View {
        ScrollView {
            VStack(spacing: 10.0) {
                if loginItems.isEmpty {
                    Text("无可配置项")
                        .appThemeText(.caption, opacity: 0.6)
                } else {
                    LoginFormFlexLayout(
                        availableWidth: UIScreen.main.bounds.width - 32.0) {
                        ForEach(localVisibleLoginUiItems) { item in
                            localLoginUiItemView(for: item)
                                .layoutValue(key: LoginFlexBasisKey.self, value: normalizedFlexBasis(for: item))
                                .layoutValue(key: LoginFlexGrowKey.self, value: normalizedFlexGrow(for: item))
                                .layoutValue(key: LoginWrapBeforeKey.self, value: item.style?.layoutWrapBefore ?? false)
                        }
                    }
                }
                Button {
                    performFormLogin()
                } label: {
                    Text("登录")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting || (source.loginUrl?.isEmpty ?? true))
                .accessibilityIdentifier("source-login-submit")
                if isExecuting { ProgressView("正在执行登录动作") }
                if let actionStatus {
                    Text(actionStatus)
                        .accessibilityIdentifier("source-login-status")
                }
                if !loginHeader.isEmpty {
                    Text("Headers:")
                        .appThemeText(.caption, opacity: 0.6)
                    Text(Self.formatLoginHeaderDisplay(
                        rawHeader: loginHeader, headers: buildHeaderMap()))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(.all, 16.0)
        }
        .modifier(LocalLoginGlassCardModifier())
    }

    /// localVisibleLoginUiItems getter（签名确证）。
    var localVisibleLoginUiItems: [LoginUiItem] {
        loginItems.filter { item in
            (item.type ?? "").lowercased() != "hidden"
        }
    }

    /// localLoginUiItemView(for:)（签名确证；type 域确证）。
    @ViewBuilder
    func localLoginUiItemView(for item: LoginUiItem) -> some View {
        let type = item.normalizedType
        switch type {
        case "button":
            Button {
                handleButtonAction(item)
            } label: {
                Text(resolvedViewName(for: item))
            }
            .buttonStyle(.bordered)
            .disabled(isExecuting)
            .accessibilityIdentifier("source-login-action-\(item.name)")
        case "password":
            SecureField(
                item.placeholder ?? resolvedViewName(for: item),
                text: binding(for: item))
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .disabled(isExecuting)
                .accessibilityIdentifier("source-login-field-\(item.name)")
        case "select":
            Picker(resolvedViewName(for: item), selection: binding(for: item)) {
                ForEach(Array((item.chars ?? []).enumerated()), id: \.offset) { _, option in
                    if let option { Text(option).tag(option) }
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .disabled(isExecuting)
            .accessibilityIdentifier("source-login-field-\(item.name)")
        case "checkbox", "toggle":
            Button {
                cycleToggleValue(for: item)
            } label: {
                HStack {
                    toggleValueBadge(currentValue(for: item))
                    Text(resolvedViewName(for: item))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .disabled(isExecuting)
            .accessibilityIdentifier("source-login-field-\(item.name)")
        default:
            TextField(
                item.placeholder ?? resolvedViewName(for: item), text: binding(for: item))
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isExecuting)
                .accessibilityIdentifier("source-login-field-\(item.name)")
        }
    }

    /// binding(for: String)（签名确证）。
    func binding(for name: String) -> Binding<String> {
        Binding(
            get: { loginValues[name] ?? "" },
            set: { loginValues[name] = $0; flushEditedLoginInfo() })
    }

    /// binding(for: LoginUiItem)（签名确证）。
    func binding(for item: LoginUiItem) -> Binding<String> {
        Binding(get: { currentValue(for: item) }, set: { value in
            loginValues[item.name] = value
            flushEditedLoginInfo()
            scheduleFieldAction(for: item, values: loginValues,
                debounced: item.normalizedType == "text" || item.normalizedType == "password")
        })
    }

    /// currentValue(for:)（签名确证）。
    func currentValue(for item: LoginUiItem) -> String {
        loginValues[item.name] ?? item.resolvedDefaultValue
    }

    /// cycleToggleValue(for:)（签名确证）：checkbox 值轮转。
    func cycleToggleValue(for item: LoginUiItem) {
        let options = item.values ?? ["false", "true"]
        guard !options.isEmpty else { return }
        let current = currentValue(for: item)
        guard let index = options.firstIndex(of: current) else {
            loginValues[item.name] = options.first ?? "true"
            flushEditedLoginInfo()
            return
        }
        loginValues[item.name] = options[(index + 1) % options.count]
        flushEditedLoginInfo()
        if item.action?.isEmpty == false { scheduleFieldAction(for: item, values: loginValues) }
    }

    /// toggleValueBadge（签名确证）。
    @ViewBuilder
    func toggleValueBadge(_ value: String) -> some View {
        Image(
            systemName: value == "true" || value == "1"
                ? "checkmark.square.fill" : "square")
            .foregroundColor(.accentColor)
    }

    /// updateSelectValue(_:for:)（签名确证）。
    func updateSelectValue(_ value: String, for item: LoginUiItem) {
        loginValues[item.name] = value
    }

    /// handleButtonAction（签名确证）。
    func handleButtonAction(_ item: LoginUiItem) {
        executeLoginUiAction(for: item, values: loginValues)
    }

    /// performFormLogin（签名确证；"登录成功" 域确证）。
    func performFormLogin() {
        runLoginAction(nil)
    }

}

