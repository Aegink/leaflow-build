// T-1602：原HTML资源和生产WKWebView协调器的加载/搜索/清除，非真机证据。
import SwiftUI
import WebKit

enum HelpResourceSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        guard let url = SourceHelpRepository.htmlURL(for: .ttsHelp) else {
            emit("help_original_resources_packaged", ["true", "true"], ["false", "false"])
            return
        }
        emit("help_original_resources_packaged", ["true", "true"],
            [String(SourceHelpRepository.hasHTML(for: .ttsHelp)), String(SourceHelpRepository.hasHTML(for: .ruleHelp))])
        let coordinator = HTMLHelpWebView.Coordinator(matchCount: .constant(0), logPrefix: "help-selftest")
        let config = WKWebViewConfiguration()
        config.userContentController.add(coordinator, name: "helpSearch")
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), configuration: config)
        coordinator.attach(view)
        view.navigationDelegate = coordinator
        defer { coordinator.teardown() }
        coordinator.update(htmlURL: url, searchText: "")
        for _ in 0..<300 {
            if coordinator.isLoaded { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        do {
            emit("help_real_webview_loads_original_document", ["true", "TTS 源编写指南"],
                [String(coordinator.isLoaded), try await view.evaluateJavaScript("document.title") as? String ?? ""])
            coordinator.update(htmlURL: url, searchText: "setResponseBase64")
            try? await Task.sleep(nanoseconds: 200_000_000)
            let marks = try await view.evaluateJavaScript("document.querySelectorAll('mark.search-hit').length") as? Int ?? 0
            emit("help_production_search_marks_text", ["true"], [String(marks > 0)])
            coordinator.update(htmlURL: url, searchText: "")
            try? await Task.sleep(nanoseconds: 200_000_000)
            emit("help_clearing_search_removes_marks", ["0"],
                [String(try await view.evaluateJavaScript("document.querySelectorAll('mark.search-hit').length") as? Int ?? -1)])
            coordinator.update(htmlURL: url, searchText: "');window.helpInjected=true;//\n\r\u{2028}")
            try? await Task.sleep(nanoseconds: 200_000_000)
            emit("help_search_literal_cannot_execute", ["undefined"],
                [try await view.evaluateJavaScript("typeof window.helpInjected") as? String ?? ""])
            coordinator.teardown()
            emit("help_teardown_detaches_navigation", ["true", "false"],
                [String(view.navigationDelegate == nil), String(coordinator.isLoaded)])
        } catch { emit("help_real_webview_loads_original_document", ["成功"], [error.localizedDescription]) }
    }
}
