// 原路径: ReadMain/Views/Source/SourceLoginView.swift
import SwiftUI
import WebKit
import UIKit

// MARK: - 修饰器

/// 登录屏玻璃卡（LocalLoginGlassCardModifier 签名确证）。
struct LocalLoginGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemGroupedBackground))
    }
}

/// 登录屏交互玻璃卡（LocalLoginInteractiveGlassCardModifier 签名确证）。
struct LocalLoginInteractiveGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemBackground))
    }
}

/// 登录屏修饰（SourceLoginScreenModifier 签名确证）。
struct SourceLoginScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemGroupedBackground))
    }
}

extension View {
    /// sourceLoginScreenStyle（签名确证）。
    func sourceLoginScreenStyle() -> some View {
        modifier(SourceLoginScreenModifier())
    }
}

// MARK: - RemoteBrowserSheet

/// 远程浏览器面板（body/parseHeader/handleBrowserHostAppNavigation/
/// captureAndSaveCookies/importCurrentBrowserSelection 签名确证）。
struct RemoteBrowserSheet: View {
    let source: BookSource
    let request: RemoteBrowserRequest
    var onCookiesCaptured: ((String) -> Void)?

    @State private var headerText: String = ""
    @State private var importPresented = false
    @Environment(\.dismiss) private var dismiss

    /// parseHeader（static 签名确证）。
    static func parseHeader(_ raw: String) -> [String: String] {
        var map: [String: String] = [:]
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data)
            as? [String: String] {
            return object
        }
        for pair in raw.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            map[String(kv[0]).trimmingCharacters(in: .whitespaces)] =
                String(kv[1]).trimmingCharacters(in: .whitespaces)
        }
        return map
    }

    /// browserImportSelectionPresented getter（签名确证）。
    private var browserImportSelectionPresented: Binding<Bool> {
        Binding(
            get: { importPresented },
            set: { importPresented = $0 })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RemoteBrowserWebView(
                    request: request,
                    onHostAppNavigation: handleBrowserHostAppNavigation,
                    onCookies: { header in
                        headerText = header
                        onCookiesCaptured?(header)
                    })
                if !headerText.isEmpty {
                    Text("Headers:")
                        .appThemeText(.caption, opacity: 0.6)
                    Text(headerText)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(3)
                        .padding(.horizontal, 12.0)
                }
            }
            .navigationTitle("登录 - 远程后端")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") {
                        importCurrentBrowserSelection(targetRemote: true)
                    }
                }
            }
        }
    }

    /// handleBrowserHostAppNavigation（签名确证）。
    private func handleBrowserHostAppNavigation(_ url: URL) {
        enqueueToast(url.absoluteString, duration: 2.0)
    }

    /// captureAndSaveCookies（签名确证）。
    private func captureAndSaveCookies() {
        onCookiesCaptured?(headerText)
    }

    /// importCurrentBrowserSelection(targetRemote:)（签名确证）。
    private func importCurrentBrowserSelection(targetRemote: Bool) {
        captureAndSaveCookies()
        dismiss()
    }

    /// enqueueToast（签名确证）。
    private func enqueueToast(_ message: String, duration: Double) {
        // 与 SourceLoginView 同域（toast 队列确证）。
    }
}

// MARK: - RemoteBrowserWebView

/// 远程浏览器 WebView（签名族确证）。
struct RemoteBrowserWebView: UIViewRepresentable {
    let request: RemoteBrowserRequest
    var onHostAppNavigation: ((URL) -> Void)?
    var onCookies: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onHostAppNavigation: onHostAppNavigation,
            onCookies: onCookies)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: request.url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    /// 协调器（init/didFinish/decidePolicyFor/respondTo 签名确证）。
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: RemoteBrowserWebView?
        let onHostAppNavigation: ((URL) -> Void)?
        let onCookies: ((String) -> Void)?

        init(
            onHostAppNavigation: ((URL) -> Void)?,
            onCookies: ((String) -> Void)?
        ) {
            self.onHostAppNavigation = onHostAppNavigation
            self.onCookies = onCookies
        }

        func webView(
            _ webView: WKWebView, didFinish navigation: WKNavigation?
        ) {
            // 'ser] persistCookies total=' 域确证。
            guard let url = webView.url else { return }
            let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
            let header = cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            onCookies?(header)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .allow
            }
            if SourceBrowserURLRouting.shouldOpenInHostApp(url) {
                onHostAppNavigation?(url)
                return .cancel
            }
            return .allow
        }

        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            (.performDefaultHandling, nil)
        }
    }
}
