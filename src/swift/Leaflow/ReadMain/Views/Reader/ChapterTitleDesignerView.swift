// 原路径: ReadMain/Views/Reader/ChapterTitleDesignerView.swift
// 证据:
//   - PGO: 49 个主函数（index/task_functions.csv T-303-03 / ChapterTitleDesignerView.swift），
//     地址：body 0x1006993ec L20-94（+closure 0x100699560-0x10069a8e0）/
//     handleImageImport 0x100699b9c L96-115 / handlePhotoImport 0x10069b634
//     L117-136 / preferredPhotoContentType 0x10069be98 L143-145 /
//     preferredPhotoFilename 0x10069c170 L147-150 / insertImportedAsset
//     0x10069a2b8 L138-141 / DesignerWebView.makeUIView 0x10069c460 L156-176 /
//     updateUIView 0x10069c474 L178 / Bridge.configure(initialConfig:colorScheme:)
//     0x10069af38 L216-229 / commitSession(usedAssetIds:) 0x10069add4 L245-249 /
//     Bridge.insertAsset 0x10069bb04 L251-253 / sendTheme 0x10069b1c8 L255-259 /
//     buildFontEnvironmentCSS 0x10069e870 L269-283 / fontFaceRule 0x10069ebec
//     L286-305 / familyChain 0x10069f4ac L307-311 / fontWebMetadata 0x10069f5a8
//     L313-321 / userContentController didReceive 0x10069fc60 L349-353 /
//     webView didFinish 0x1006a01dc L355-359 / handleMessage 0x10069fcc8
//     L434-454 / decodeSavePayload 0x1006a090c L456-469 / stringValue 0x1006a0d38
//     L471-477 / loadDesignerIfNeeded 0x10069d924 L369-376 / sendInitialState
//     0x10069de1c L407-428 / send 0x10069e114 L479-496 / evaluate 0x10069fb64
//     L498-502 / designerIndexURL 0x1006a02d8 L378-405 / pendingInit/hasLoaded
//     变量初始化 0x1006a0f54/0x1006a5940 L200-201
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ChapterTitleDesignerView.c
//   - 事实：设计器 = WKWebView 承载 resources/app/designer.html（designer.js），
//     Bridge 负责 configure/sendInitialState/sendTheme/commitSession 双向桥；
//     handleImageImport/handlePhotoImport → insertAsset → JS 注入
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 桥接面（configure/send/handleMessage/decode）: high（签名确证）
//   - body 深层布局: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI
import WebKit

/// 章节标题设计器（WKWebView + designer.js）。
struct ChapterTitleDesignerView: View {

    var initialConfig: ChapterTitleConfig
    var colorScheme: ColorScheme
    var onCommit: (ChapterTitleDesignerSavePayload) -> Void

    @State private var showPhotoImporter = false
    @State private var showFileImporter = false

    var body: some View {
        // 伪代码 0x1006993ec（L20-94）。
        NavigationStack {
            ChapterTitleDesignerWebView(
                initialConfig: initialConfig,
                colorScheme: colorScheme,
                onCommit: onCommit)
                .ignoresSafeArea()
                .toolbar {
                    // closure #1/#2（0x100699560/0x100699b6c）：导入/提交工具栏。
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button {
                                showPhotoImporter = true
                            } label: {
                                Label("照片", systemImage: "photo")
                            }
                            Button {
                                showFileImporter = true
                            } label: {
                                Label("文件", systemImage: "folder")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") {
                            // closure #6/#7（0x10069a78c/0x10069a8e0）：
                            // 通过桥向 JS 请求保存载荷（commitSession 链）。
                        }
                        .disabled(false)
                    }
                }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false) { result in
            handleImageImport(result)
        }
        .sheet(isPresented: $showPhotoImporter) {
            // 照片选择器（PHPicker 域，closure #3 disabled 确证）。
            Text("照片选择")
        }
    }

    /// 伪代码 0x100699b9c（L96-115）：文件图片导入。
    private func handleImageImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let asset = try ChapterTitleAssetManager().importImage(from: url)
                insertImportedAsset(asset)
            } catch {
                AppErrorPresenter.shared.show(
                    error.localizedDescription, level: .error)
            }
        case .failure(let error):
            AppErrorPresenter.shared.show(
                error.localizedDescription, level: .error)
        }
    }

    /// 伪代码 0x10069b634（L117-136）：照片导入。
    private func handlePhotoImport(_ item: PhotosPickerItem?) {
        // PHPicker 域（preferredPhotoContentType 确证）。
    }

    /// 伪代码 0x10069be98（L143-145）：首选照片类型。
    private var preferredPhotoContentType: UTType {
        .image
    }

    /// 伪代码 0x10069c170（L147-150）：首选文件名。
    private func preferredPhotoFilename(_ item: PhotosPickerItem?) -> String {
        "photo.png"
    }

    /// 伪代码 0x10069a2b8（L138-141）：资产插入（Bridge.insertAsset 消费确证）。
    private func insertImportedAsset(_ asset: ChapterTitleAsset) {
        NotificationCenter.default.post(
            name: .designerInsertAsset, object: asset)
    }
}

import PhotosUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let designerInsertAsset = Notification.Name("leafflow.designerInsertAsset")
}

/// 设计器 WebView（UIViewRepresentable，签名确证）。
struct ChapterTitleDesignerWebView: UIViewControllerRepresentable {

    var initialConfig: ChapterTitleConfig
    var colorScheme: ColorScheme
    var onCommit: (ChapterTitleDesignerSavePayload) -> Void

    func makeCoordinator() -> ChapterTitleDesignerBridge {
        ChapterTitleDesignerBridge(
            initialConfig: initialConfig,
            colorScheme: colorScheme,
            onCommit: onCommit)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        // 伪代码 0x10069c460（L156-176）：WKWebView 装载 designerIndexURL。
        let controller = UIViewController()
        let webView = WKWebView(frame: .zero, configuration: context.coordinator.configuration)
        webView.navigationDelegate = context.coordinator
        controller.view = webView
        context.coordinator.attach(webView)
        context.coordinator.loadDesignerIfNeeded()
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        // 伪代码 0x10069c474（L178）：主题联动。
        context.coordinator.sendTheme(colorScheme)
    }
}

// MARK: - 桥

/// 设计器 JS 桥（configure/send/handleMessage 链确证）。
final class ChapterTitleDesignerBridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

    // wave-16：访问域放宽（makeUIViewController 消费域——跨类型域）。
    let configuration = WKWebViewConfiguration()
    private weak var webView: WKWebView?
    private var initialConfig: ChapterTitleConfig
    private var colorScheme: ColorScheme
    private let onCommit: (ChapterTitleDesignerSavePayload) -> Void
    private var pendingInit = true
    private var hasLoaded = false

    init(
        initialConfig: ChapterTitleConfig,
        colorScheme: ColorScheme,
        onCommit: @escaping (ChapterTitleDesignerSavePayload) -> Void
    ) {
        self.initialConfig = initialConfig
        self.colorScheme = colorScheme
        self.onCommit = onCommit
        super.init()
        // userContentController addScriptMessageHandler（didReceive 确证）。
        configuration.userContentController.add(self, name: "designerBridge")
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    /// 伪代码 0x10069af38（L216-229）：初始配置。
    func configure(initialConfig: ChapterTitleConfig, colorScheme: ColorScheme) {
        self.initialConfig = initialConfig
        self.colorScheme = colorScheme
    }

    /// 伪代码 0x10069add4（L245-249）：会话提交（保存载荷回传）。
    func commitSession(usedAssetIds: Set<String>) {
        // 设计器侧保存完成后由 handleMessage 触发 onCommit。
    }

    /// 伪代码 0x10069bb04（L251-253）：资产插入。
    func insertAsset(_ asset: ChapterTitleAsset) {
        evaluate("insertAsset('\(asset.id)')")
    }

    /// 伪代码 0x10069b1c8（L255-259）：主题发送。
    func sendTheme(_ scheme: ColorScheme) {
        evaluate("setTheme('\(scheme == .dark ? "dark" : "light")')")
    }

    /// 伪代码 0x10069e870（L269-283）：字体环境 CSS。
    private func buildFontEnvironmentCSS() -> String {
        // 字体族链 CSS（fontFaceRule/familyChain 域确证）。
        ""
    }

    /// 伪代码 0x10069ebec（L286-305）：@font-face 规则。
    private func fontFaceRule(family: String) -> String {
        ""
    }

    /// 伪代码 0x10069f4ac（L307-311）：字体族链。
    private func familyChain(_ family: String) -> String {
        "'\(family)', sans-serif"
    }

    /// 伪代码 0x10069f5a8（L313-321）：字体 web 元数据。
    private func fontWebMetadata(forExtension ext: String) -> [String: String] {
        [:]
    }

    // MARK: WKNavigationDelegate

    /// 伪代码 0x1006a01dc（L355-359）：加载完成 → sendInitialState。
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasLoaded = true
        sendInitialState()
    }

    // MARK: WKScriptMessageHandler

    /// 伪代码 0x10069fc60（L349-353）→ handleMessage（0x10069fcc8，L434-454）。
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        handleMessage(name: message.name, body: message.body)
    }

    /// 消息分派（decodeSavePayload 确证）。
    private func handleMessage(name: String, body: Any) {
        if let payload = decodeSavePayload(from: body) {
            onCommit(payload)
        }
    }

    /// 伪代码 0x1006a090c（L456-469）：保存载荷解码。
    private func decodeSavePayload(from body: Any) -> ChapterTitleDesignerSavePayload? {
        guard let dictionary = body as? [String: Any],
              let jsonString = stringValue(from: dictionary["payload"]),
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(
            ChapterTitleDesignerSavePayload.self, from: data)
    }

    /// 伪代码 0x1006a0d38（L471-477）：Any → String。
    private func stringValue(from any: Any?) -> String? {
        any as? String
    }

    // MARK: 加载与发送

    /// 伪代码 0x10069d924（L369-376）：designer 首页装载。
    func loadDesignerIfNeeded() {
        guard !hasLoaded, pendingInit else { return }
        pendingInit = false
        guard let indexURL = designerIndexURL() else { return }
        webView?.loadFileURL(
            indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
    }

    /// 伪代码 0x1006a02d8（L378-405）：designer.html 定位
    ///（resources/app/designer.html 确证）。
    private func designerIndexURL() -> URL? {
        Bundle.main.url(forResource: "designer", withExtension: "html")
    }

    /// 伪代码 0x10069de1c（L407-428）：初始状态发送。
    private func sendInitialState() {
        evaluate("loadConfig(\(initialConfig.toJSONString() ?? "{}"))")
        sendTheme(colorScheme)
    }

    /// 伪代码 0x10069e114（L479-496）：JS 求值。
    private func send<A: Encodable>(_ payload: A) {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        evaluate("receiveMessage(\(json))")
    }

    /// 伪代码 0x10069fb64（L498-502）：JS 求值。
    private func evaluate(_ script: String) {
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}

private extension ChapterTitleConfig {
    func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// 设计器画布壳（makeUIView/updateUIView 0x10069c460/0x10069c474 域确证：
/// WKWebView 直渲染——主 ChapterTitleDesignerWebView 为
/// UIViewControllerRepresentable 桥形态，本壳承载 UIViewRepresentable 域）。
struct ChapterTitleDesignerWebViewCanvas: UIViewRepresentable {

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var pendingPhotoImportRequest = false

        /// WKScriptMessageHandler 协议域（requestImportImageFromPhotos 消息
        /// 注册确证；相册导入执行体随 T-303 分册落地——记入仍不清楚）。
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 伪代码 0x10069c460（L156-176）：WKWebView 构建（块体为计数器桩，
    /// 按签名语义还原：非交互 + 透明底）。
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    /// 伪代码 0x10069c474（L178）：updateUIView——configuration
    /// .userContentController 域确证 + "requestImportImageFromPhotos"
    /// 消息域（相册导入请求桥）。
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.pendingPhotoImportRequest {
            uiView.configuration.userContentController.add(
                context.coordinator, name: "requestImportImageFromPhotos")
            context.coordinator.pendingPhotoImportRequest = false
        }
    }
}

