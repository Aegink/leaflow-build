// 原路径: ReadMain/Views/Source/SourceLoginView.swift
import SwiftUI
import WebKit
import UIKit

// MARK: - LoginWebView

/// 登录 WebView（cookie 捕获域确证）。
struct LoginWebView: UIViewRepresentable {
    let source: BookSource
    var loginHost: String?
    var loginURL: URL?
    var onCookieObserved: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            source: source, loginHost: loginHost,
            onCookieObserved: onCookieObserved)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.navigationDelegate = context.coordinator
        view.configuration.websiteDataStore.httpCookieStore.add(
            context.coordinator)
        if let url = loginURL ?? LoginService.browserURL(source.loginUrl ?? "") {
            view.load(URLRequest(url: url))
        }
        return view
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
        view.stopLoading()
        view.navigationDelegate = nil
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    /// collectExistingCookies(for:source:)（签名确证）。
    static func collectExistingCookies(
        for url: URL, source: BookSource
    ) -> [HTTPCookie] {
        HTTPCookieStorage.shared.cookies(for: url) ?? []
    }

    /// 协调器（init/persistObservedCookies/cookiesDidChange/didFinish/
    /// respondTo/captureAndSaveCookies 签名确证）。
    final class Coordinator: NSObject, WKNavigationDelegate,
        WKHTTPCookieStoreObserver {
        var parent: LoginWebView?
        let source: BookSource
        let loginHost: String?
        let onCookieObserved: ((String) -> Void)?

        init(
            source: BookSource, loginHost: String?,
            onCookieObserved: ((String) -> Void)?
        ) {
            self.source = source
            self.loginHost = loginHost
            self.onCookieObserved = onCookieObserved
        }

        /// persistObservedCookies（签名确证）。
        func persistObservedCookies(
            _ cookies: [HTTPCookie], currentURL: URL
        ) {
            let merged = LoginWebView.collectExistingCookies(
                for: currentURL, source: source)
            let header = cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            onCookieObserved?(header)
            _ = merged
        }

        /// cookiesDidChange（签名确证）。
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            cookieStore.getAllCookies { cookies in
                self.persistObservedCookies(
                    cookies, currentURL: URL(string: "https://\(self.loginHost ?? "")")
                        ?? URL(fileURLWithPath: "/"))
            }
        }

        func webView(
            _ webView: WKWebView, didFinish navigation: WKNavigation?
        ) {
            captureAndSaveCookies(from: webView, completion: nil)
        }

        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            (.performDefaultHandling, nil)
        }

        /// captureAndSaveCookies(from:completion:)（签名确证）。
        func captureAndSaveCookies(
            from webView: WKWebView, completion: (() -> Void)?
        ) {
            webView.configuration.websiteDataStore.httpCookieStore
                .getAllCookies { cookies in
                    let header = cookies
                        .map { "\($0.name)=\($0.value)" }
                        .joined(separator: "; ")
                    self.onCookieObserved?(header)
                    completion?()
                }
        }
    }
}

// MARK: - LoginFormFlexLayout

/// 登录表单 Flex 布局（sizeThatFits/arrangedRows/placeSubviews/
/// preferredWidth + flushCurrentRow 签名确证；flex_start/flex_end 域）。
struct LoginFormFlexLayout: Layout {
    var availableWidth: CGFloat = 0

    /// preferredWidth(for:availableWidth:)（签名确证）。
    private func preferredWidth(
        for subview: LayoutSubview, availableWidth: CGFloat
    ) -> CGFloat {
        let size = subview.sizeThatFits(.unspecified)
        if availableWidth > 0 && size.width > availableWidth {
            return availableWidth
        }
        return size.width
    }

    /// arrangedRows(for:availableWidth:)（签名确证）。
    private func arrangedRows(
        for subviews: LayoutSubviews, availableWidth: CGFloat
    ) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = []
        var current: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        func flushCurrentRow() {
            if !current.isEmpty {
                rows.append(current)
                current = []
                currentWidth = 0
            }
        }
        for subview in subviews {
            let width = preferredWidth(for: subview, availableWidth: availableWidth)
            if currentWidth + width > availableWidth, !current.isEmpty {
                flushCurrentRow()
            }
            current.append(subview)
            currentWidth += width
        }
        flushCurrentRow()
        return rows
    }

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? availableWidth
        let rows = arrangedRows(for: subviews, availableWidth: width)
        var totalHeight: CGFloat = 0
        for row in rows {
            let rowHeight = row
                .map { $0.sizeThatFits(.unspecified).height }
                .max() ?? 0
            totalHeight += rowHeight
        }
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews,
        cache: inout ()
    ) {
        let rows = arrangedRows(
            for: subviews, availableWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size))
                x += size.width
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight
        }
    }
}
