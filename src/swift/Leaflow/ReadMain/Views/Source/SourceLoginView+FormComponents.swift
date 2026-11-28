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
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = LoginService.mergedHeaderMap(source: source, sourceHeaders: source.headerMap)
            view.load(request)
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

    nonisolated static func matchingCookies(_ cookies: [HTTPCookie], url: URL, now: Date = Date()) -> [HTTPCookie] {
        guard let host = url.host?.lowercased() else { return [] }
        return cookies.filter { cookie in
            let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return CookiePersistenceService.domainMatches(host, domain)
                && cookie.expiresDate.map { $0 > now } != false
        }
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
            let matching = LoginWebView.matchingCookies(cookies, url: currentURL)
            for cookie in matching { HTTPCookieStorage.shared.setCookie(cookie) }
            CookiePersistenceService.shared.persistBrowserCookies(matching, currentURL: currentURL)
            let header = matching
                .map { "\($0.name)=\($0.value)" }
                .sorted()
                .joined(separator: "; ")
            onCookieObserved?(header)
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
                    if let url = webView.url { self.persistObservedCookies(cookies, currentURL: url) }
                    completion?()
                }
        }
    }
}

// MARK: - LoginFormFlexLayout

struct LoginFlexBasisKey: LayoutValueKey { static let defaultValue: CGFloat = -1 }
struct LoginFlexGrowKey: LayoutValueKey { static let defaultValue: CGFloat = 0 }
struct LoginWrapBeforeKey: LayoutValueKey { static let defaultValue = false }

/// 登录表单 Flex 布局（sizeThatFits/arrangedRows/placeSubviews/
/// preferredWidth + flushCurrentRow 签名确证；flex_start/flex_end 域）。
struct LoginFormFlexLayout: Layout {
    var availableWidth: CGFloat = 0
    var spacing: CGFloat = 8

    /// preferredWidth(for:availableWidth:)（签名确证）。
    private func preferredWidth(
        for subview: LayoutSubview, availableWidth: CGFloat
    ) -> CGFloat {
        let size = subview.sizeThatFits(.unspecified)
        let basis = subview[LoginFlexBasisKey.self]
        if basis > 0, basis <= 1 { return max(0, availableWidth) * basis }
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
            if !current.isEmpty, subview[LoginWrapBeforeKey.self] || currentWidth + spacing + width > availableWidth {
                flushCurrentRow()
            }
            if !current.isEmpty { currentWidth += spacing }
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
        for (index, row) in rows.enumerated() {
            let sizes = rowSizes(row, width: width)
            totalHeight += sizes.map(\.height).max() ?? 0
            if index > 0 { totalHeight += spacing }
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
            let sizes = rowSizes(row, width: bounds.width)
            for (index, subview) in row.enumerated() {
                let size = sizes[index]
                subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }

    private func rowSizes(_ row: [LayoutSubview], width: CGFloat) -> [CGSize] {
        let widths = row.map { preferredWidth(for: $0, availableWidth: width) }
        let growth = row.map { max(0, $0[LoginFlexGrowKey.self]) }
        let totalGrowth = growth.reduce(0, +)
        let remaining = max(0, width - widths.reduce(0, +) - CGFloat(max(0, row.count - 1)) * spacing)
        return row.enumerated().map { index, subview in
            let finalWidth = widths[index] + (totalGrowth > 0 ? remaining * growth[index] / totalGrowth : 0)
            let height = subview.sizeThatFits(ProposedViewSize(width: finalWidth, height: nil)).height
            return CGSize(width: finalWidth, height: height)
        }
    }
}
