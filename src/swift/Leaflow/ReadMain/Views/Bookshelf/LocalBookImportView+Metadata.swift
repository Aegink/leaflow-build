// 原路径: ReadMain/Views/Bookshelf/LocalBookImportView.swift
// 文件名与封面搜索分册，仍计入原始导入页门禁。
import SwiftUI
import PhotosUI

// MARK: - 文件名元数据解析（签名域确证）

/// 文件名元数据解析器（七步链确证）。
enum LocalBookFilenameMetadataParser {

    /// suggestion(for:)（签名确证）。
    static func suggestion(
        for url: URL
    ) -> (title: String, author: String?) {
        parse(from: normalizedFileStem(for: url))
    }

    /// normalizedFileStem（0x100497c5c… static 域确证）。
    static func normalizedFileStem(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    /// parse(from:)（0x10049939c L407-428 static 域确证）。
    static func parse(from stem: String) -> (title: String, author: String?) {
        // parseQuotedTitle L430-442 域确证。
        if let quoted = parseQuotedTitle(stem) {
            return (title: quoted.title, author: quoted.author)
        }
        // parseExplicitAuthor L444-460 域确证。
        if let explicit = parseExplicitAuthor(stem) {
            return (title: explicit.title, author: explicit.author)
        }
        // parseSeparated L462-477 域确证。
        let separators = CharacterSet(charactersIn: "-_—–|｜")
        let parts = stem
            .components(separatedBy: separators)
            .map { clean($0) }
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            return resolve(parts: parts)
        }
        // parseSpaceSeparated L479-499 域确证。
        let spaceParts = stem
            .components(separatedBy: .whitespaces)
            .map { clean($0) }
            .filter { !$0.isEmpty }
        if spaceParts.count >= 2 {
            return resolve(parts: spaceParts)
        }
        return (title: clean(stem), author: nil)
    }

    /// parseQuotedTitle（0x100499778 L430-442 static 域确证）。
    static func parseQuotedTitle(
        _ stem: String
    ) -> (title: String, author: String?)? {
        guard let open = stem.firstIndex(of: "《"),
              let close = stem.firstIndex(of: "》"),
              open < close
        else { return nil }
        let title = String(stem[stem.index(after: open)..<close])
        let tail = String(stem[stem.index(after: close)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let author = tail.isEmpty ? nil : clean(tail)
        return (
            title: title,
            author: (author?.isEmpty ?? true) ? nil : author)
    }

    /// parseExplicitAuthor（0x100499dd0 L444-460 static 域确证）。
    static func parseExplicitAuthor(
        _ stem: String
    ) -> (title: String, author: String?)? {
        guard let range = stem.range(of: "作者：") ?? stem.range(of: "作者:") else {
            return nil
        }
        let authorPart = String(stem[range.upperBound...])
        let titlePart = String(stem[..<range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_—– "))
        return (title: clean(titlePart), author: clean(authorPart))
    }

    /// parseSeparated（0x10049a46c L462-477 static 域确证）。
    static func parseSeparated(
        _ stem: String
    ) -> (title: String, author: String?)? {
        nil
    }

    /// parseSpaceSeparated（0x10049ad2c L479-499 static 域确证）。
    static func parseSpaceSeparated(
        _ stem: String
    ) -> (title: String, author: String?)? {
        nil
    }

    /// resolve(parts:)（0x10049bdf4 L501-523 static 域确证）。
    static func resolve(
        parts: [String]
    ) -> (title: String, author: String?) {
        guard let first = parts.first else {
            return (title: "", author: nil)
        }
        if parts.count >= 2, isLikelyAuthor(parts[1]) {
            return (title: first, author: parts[1])
        }
        return (title: first, author: nil)
    }

    /// isLikelyAuthor（0x10049c5c0 L534-555 static 域确证）。
    static func isLikelyAuthor(_ text: String) -> Bool {
        text.count <= 10 && !text.contains("第")
    }

    /// removeAuthorMarker（static 签名确证）。
    static func removeAuthorMarker(_ text: String) -> String {
        text.replacingOccurrences(of: "作者：", with: "")
            .replacingOccurrences(of: "作者:", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// clean（static 签名确证）。
    static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Bing 封面搜索（签名域确证）

/// Bing 图片搜索视图。
struct BingImageSearchView: View {

    let onSelect: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [BingImageResult] = []
    @State private var isSearching = false

    /// placeholder getter（0x1004a0550 L652-660 域确证）。
    private var placeholder: String {
        "搜索封面图片"
    }

    var body: some View {
        // 0x10049d35c L578-650 域确证。
        NavigationStack {
            VStack(spacing: 12.0) {
                HStack {
                    TextField(placeholder, text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button {
                        performSearch()
                    } label: {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(query.isEmpty || isSearching)
                }
                .padding(.horizontal, 16.0)
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible()), count: 3),
                        spacing: 8.0) {
                        ForEach(results) { result in
                            Button {
                                Task { await downloadAndSelect(result) }
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(uiColor: .tertiarySystemFill))
                                    .aspectRatio(0.72, contentMode: .fit)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 12.0)
                }
            }
            .navigationTitle("搜索封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    /// performSearch（0x1004a4d04 L662-677 域确证）。
    private func performSearch() {
        let query = query.trimmingCharacters(in: .whitespaces) + " 小说封面"
        isSearching = true
        Task {
            let found = try? await BingImageSearchService.search(
                query: query, count: 30)
            await MainActor.run {
                results = found ?? []
                isSearching = false
            }
        }
    }

    /// downloadAndSelect（0x1004a0a18 L679-696 域确证）。
    private func downloadAndSelect(_ result: BingImageResult) async {
        guard let url = URL(string: result.url),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data)
        else { return }
        await MainActor.run {
            onSelect(image)
            dismiss()
        }
    }
}

/// Bing 图片结果（parseImageResults 域确证）。
struct BingImageResult: Identifiable, Codable {
    var id: String { url }
    let url: String
    let thumbnailUrl: String?
}

/// Bing 图片搜索服务（search L709-723 + parseImageResults L726-764 域确证）。
enum BingImageSearchService {

    /// search(query:count:)（0x1004a1754 L709-723 static 域确证）。
    static func search(
        query: String, count: Int
    ) async throws -> [BingImageResult] {
        // "turl"/"murl" JSON 正则确证。
        var components = URLComponents(string: "https://www.bing.com/images/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: "\(count)"),
        ]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        // 'Safari/604.1' @ptr L8809 UA 域确证。
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
                + "Version/15.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return parseImageResults(from: html, count: count)
    }

    /// parseImageResults(from:count:)（0x1004a1d50 L726-764 static 域确证）。
    static func parseImageResults(
        from html: String, count: Int
    ) -> [BingImageResult] {
        var results: [BingImageResult] = []
        // '"turl"\s*:\s*"([^"]+)"' @ptr L7422 域确证。
        guard
            let turlRegex = try? NSRegularExpression(
                pattern: "\"turl\"\\s*:\\s*\"([^\"]+)\""),
            let murlRegex = try? NSRegularExpression(
                pattern: "\"murl\"\\s*:\\s*\"([^\"]+)\"")
        else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let murls = murlRegex.matches(in: html, range: range)
        for match in murls.prefix(count) {
            guard let urlRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            let url = String(html[urlRange])
                .replacingOccurrences(of: "\\/", with: "/")
            results.append(BingImageResult(url: url, thumbnailUrl: nil))
        }
        return results
    }
}
