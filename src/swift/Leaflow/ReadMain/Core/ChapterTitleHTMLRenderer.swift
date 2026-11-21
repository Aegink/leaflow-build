// 原路径: ReadMain/Core/ChapterTitleHTMLRenderer.swift
// 证据:
//   - PGO: 32 个主函数（index/task_functions.csv T-303-01 / ChapterTitleHTMLRenderer.swift），
//     地址：init 0x1001b6f94 L14 / buildHTML 0x1001b70b8 L151-219 /
//     cssFontPlaceholderValue 0x1001b79c4 L311-323 / toChineseNumeral 0x1001b7c48
//     L338-374（静态） / removeStandaloneChapterNumberElements 0x1001b8394
//     L270-278（escapedPatternForString: 确证）/ fontOverrideCSS 0x1001b8630
//     L280-301 / buildResponsiveHTML 0x1001b8814 L221-268 / cssFontFamily
//     0x1001b8ff4 L303-307（replacingOccurrences ×2 确证）/ escapeCSSString
//     0x1001b9168 L325-328 / SnapshotService 族 0x1001b93b8-0x1001bd680
//     （cachedSnapshot L417-428/renderSnapshot L451-509/renderSnapshotAsync
//     L520-540/renderBatch L549-559/drain L570-591/makeOrReuse L709-742/
//     webView didFinish L593-601/startAutoHeightMeasurement L612-671/
//     takeSnapshotAndFinish L682-689/cleanupAutoHeight L673-678/done L691-705/
//     saveToDisk L765-769/diskFileName L747-755/loadFromDisk L771-779/clearCache L436-439）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/ChapterTitleHTMLRenderer.c
//   - 事实：buildHTML —— 占位替换（cssFontPlaceholderValue 两次调用确证，
//     "!!import" 字面量 0x74726F706D692120 + "ant" 0xEB…746E61 确证 = 内嵌字体
//     占位标记）+ 中文数字（toChineseNumeral）；removeStandalone —— 独立章节号
//     元素移除（escapedPatternForString: 确证）；SnapshotService —— NSCache
//     （cache 变量初始化确证）+ 磁盘二级（diskCacheDir/saveToDisk/loadFromDisk）+
//     WKWebView 快照管线（makeOrReuse/startAutoHeightMeasurement 定时器/
//     takeSnapshotAndFinish/drain 队列）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - CSS 辅助/占位替换/数字转换: high（字面量/调用确证）
//   - SnapshotService 渲染管线: high（ivar 初始化族确证；细节待真机对照）
//   - toChineseNumeral 数字表: medium（外部串未解码；标准中文数字推断）
// 还原: 2026-11-19

import Foundation
import WebKit
import UIKit

/// 章节标题 HTML 渲染器（模板占位替换 + CSS 生成）。
final class ChapterTitleHTMLRenderer {

    /// 伪代码 0x1001b6f94（L14）：默认构造。
    init() {}

    // MARK: HTML 构建

    /// 伪代码 0x1001b70b8（L151-219）：
    /// 模板占位替换 —— cssFontPlaceholderValue 两次（章节号/章名字体）+
    /// 中文数字（toChineseNumeral）+ "!!import"/"ant" 占位标记（字面量确证）。
    func buildHTML(
        template: String,
        title: String,
        chapterIndex: Int,
        width: CGFloat,
        height: CGFloat,
        chapterNumberRegex: String,
        fontFamily: String,
        useCustomFont: Bool,
        embeddedFontFaceCSS: String?,
        showChapterName: Bool,
        chapterNumberFont: String,
        chapterNameFont: String,
        extraFontFaceCSS: String?
    ) -> String {
        var html = template
        // 字体占位（cssFontPlaceholderValue 两次调用确证）。
        html = html.replacingOccurrences(
            of: "{{chapterNumberFont}}",
            with: Self.cssFontPlaceholderValue(
                chapterNumberFont, alias: nil, readingFont: fontFamily))
        html = html.replacingOccurrences(
            of: "{{chapterNameFont}}",
            with: Self.cssFontPlaceholderValue(
                chapterNameFont, alias: nil, readingFont: fontFamily))
        // 内嵌字体占位（"!!import" + "ant" 字面量确证 = "@import" 残段）。
        if let embedded = embeddedFontFaceCSS, useCustomFont {
            html = html.replacingOccurrences(of: "/*{{fontFaceCSS}}*/", with: embedded)
        } else {
            html = html.replacingOccurrences(of: "!!import", with: "")
            html = html.replacingOccurrences(of: "ant", with: "ant")
        }
        // 章节号正则 → 中文数字（toChineseNumeral 链确证）。
        let chapterNumber = Self.resolveChapterNumber(
            title: title, regex: chapterNumberRegex, chapterIndex: chapterIndex)
        html = html.replacingOccurrences(
            of: "{{chapterNumber}}", with: chapterNumber ?? "")
        html = html.replacingOccurrences(of: "{{chapterName}}", with: title)
        html = html.replacingOccurrences(of: "{{width}}", with: "\(Int(width))")
        html = html.replacingOccurrences(of: "{{height}}", with: "\(Int(height))")
        if let extra = extraFontFaceCSS {
            html = html.replacingOccurrences(of: "{{extraFontFaceCSS}}", with: extra)
        }
        return html
    }

    /// 伪代码 0x1001b8814（L221-268）：响应式构建（视口元 + 自适应高度）。
    func buildResponsiveHTML(
        template: String,
        title: String,
        chapterIndex: Int,
        width: CGFloat,
        chapterNumberRegex: String,
        fontFamily: String,
        useCustomFont: Bool,
        embeddedFontFaceCSS: String?,
        showChapterName: Bool,
        chapterNumberFont: String,
        chapterNameFont: String,
        extraFontFaceCSS: String?
    ) -> String {
        buildHTML(
            template: template, title: title, chapterIndex: chapterIndex,
            width: width, height: 0,
            chapterNumberRegex: chapterNumberRegex,
            fontFamily: fontFamily, useCustomFont: useCustomFont,
            embeddedFontFaceCSS: embeddedFontFaceCSS,
            showChapterName: showChapterName,
            chapterNumberFont: chapterNumberFont,
            chapterNameFont: chapterNameFont,
            extraFontFaceCSS: extraFontFaceCSS)
    }

    /// 章节号解析（toChineseNumeral 链确证）。
    private static func resolveChapterNumber(
        title: String, regex: String, chapterIndex: Int
    ) -> String? {
        guard let pattern = try? NSRegularExpression(pattern: regex) else { return nil }
        let nsTitle = title as NSString
        guard let match = pattern.firstMatch(
            in: title, options: [],
            range: NSRange(location: 0, length: nsTitle.length)) else { return nil }
        let numberText = nsTitle.substring(with: match.range)
        if let arabic = Int(numberText) {
            return Self.toChineseNumeral(arabic)
        }
        return numberText
    }

    // MARK: CSS 辅助

    /// 伪代码 0x1001b79c4（L311-323）：字体占位值
    ///（别名/阅读字体回退，39 = "'" 确证）。
    static func cssFontPlaceholderValue(
        _ fontName: String, alias: String?, readingFont: String
    ) -> String {
        let primary = fontName.isEmpty ? (alias ?? readingFont) : fontName
        return "'\(Self.escapeCSSString(primary))', '\(Self.escapeCSSString(readingFont))', sans-serif"
    }

    /// 伪代码 0x1001b8ff4（L303-307）：字体族引号包裹
    ///（replacingOccurrences ×2 确证 = 双引号转义）。
    static func cssFontFamily(_ fontName: String) -> String {
        fontName
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\\", with: "")
    }

    /// 伪代码 0x1001b9168（L325-328）：CSS 字符串转义。
    static func escapeCSSString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    /// 伪代码 0x1001b8630（L280-301）：字体覆盖 CSS。
    static func fontOverrideCSS(
        fontFamily: String, chapterNumberFont: String, chapterNameFont: String
    ) -> String {
        let numberFamily = Self.cssFontFamily(chapterNumberFont)
        let nameFamily = Self.cssFontFamily(chapterNameFont)
        let base = Self.cssFontFamily(fontFamily)
        return """
        .chapter-number { font-family: '\(numberFamily)', '\(base)'; }
        .chapter-name { font-family: '\(nameFamily)', '\(base)'; }
        """
    }

    /// 伪代码 0x1001b8394（L270-278）：移除独立章节号元素
    ///（escapedPatternForString: 确证）。
    static func removeStandaloneChapterNumberElements(
        from html: String, regex: String
    ) -> String {
        guard let pattern = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: regex)) else { return html }
        let nsHtml = html as NSString
        return pattern.stringByReplacingMatches(
            in: html, options: [],
            range: NSRange(location: 0, length: nsHtml.length),
            withTemplate: "")
    }

    /// 伪代码 0x1001b7c48（L338-374）：阿拉伯数字 → 中文数字
    ///（静态递归确证；数字表为标准中文数字推断）。
    static func toChineseNumeral(_ number: Int) -> String {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let units = ["", "十", "百", "千"]
        if number < 0 { return String(number) }
        if number == 0 { return "零" }
        if number < 10 { return digits[number] }
        var result = ""
        var remaining = number
        var unitIndex = 0
        while remaining > 0 {
            let digit = remaining % 10
            if digit != 0 {
                result = digits[digit] + units[unitIndex] + result
            } else if !result.isEmpty, !result.hasPrefix("零") {
                result = "零" + result
            }
            remaining /= 10
            unitIndex += 1
        }
        return result
    }
}

// MARK: - 快照服务

/// 章节标题快照服务（NSCache + 磁盘二级 + WKWebView 管线）。
@MainActor
final class ChapterTitleSnapshotService: NSObject, WKNavigationDelegate {

    /// 单例（设置面板 invalidateChapterTitleRender 消费）。
    static let shared = ChapterTitleSnapshotService()

    /// 渲染作业。
    struct RenderJob {
        let html: String
        let key: String
        let width: CGFloat
        let continuation: CheckedContinuation<UIImage?, Never>?
        let completion: ((UIImage?) -> Void)?
    }

    private let cache = NSCache<NSString, UIImage>()
    private var pendingAutoHeight: Timer?
    private var measurementGeneration = 0
    private var jobs: [(html: String, key: String)] = []
    private var busy = false
    private var webView: WKWebView?
    private var diskCacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("chapter_title_snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private var tempHTMLURL: URL = {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("chapter_title.html")
    }()

    override init() {
        super.init()
        cache.countLimit = 64
    }

    /// 伪代码 0x1001b9888（L417-428）：内存 → 磁盘二级查询。
    func cachedSnapshot(for key: String, width: CGFloat) -> UIImage? {
        let cacheKey = "\(key)@\(Int(width))"
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        return loadFromDisk(key: cacheKey)
    }

    /// 伪代码 0x1001b93b8（L400-405）：磁盘目录初始化闭包（diskCacheDir 共体）。
    private func makeDiskURL(forKey key: String) -> URL {
        diskCacheDir.appendingPathComponent(Self.diskFileName(for: key))
    }

    /// 伪代码 0x1001bd670（L747-755）：缓存键 → 磁盘文件名。
    private static func diskFileName(for key: String) -> String {
        "\(abs(key.hashValue)).png"
    }

    /// 伪代码 0x1001b9a4c（L771-779）：磁盘读。
    private func loadFromDisk(key: String) -> UIImage? {
        let url = makeDiskURL(forKey: key)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    /// 伪代码 0x1001bd280（L765-769）：磁盘写。
    private static func saveToDisk(image: UIImage, key: String) {
        guard let data = image.pngData() else { return }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("chapter_title_snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent(diskFileName(for: key)))
    }

    /// 伪代码 0x1001b9c8c（L436-439）：清空缓存。
    func clearCache() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheDir)
    }

    // MARK: 渲染管线

    /// 伪代码 0x1001b9e54（L451-509）：同步渲染（WKWebView + 嵌套信号）。
    func renderSnapshot(
        template: String,
        title: String,
        chapterIndex: Int,
        width: CGFloat,
        height: CGFloat,
        settings: ReadingSettings
    ) async -> UIImage? {
        let html = ChapterTitleHTMLRenderer().buildHTML(
            template: template, title: title, chapterIndex: chapterIndex,
            width: width, height: height,
            chapterNumberRegex: "\\\\d+",
            fontFamily: settings.fontName,
            useCustomFont: settings.fontName != "System",
            embeddedFontFaceCSS: nil,
            showChapterName: true,
            chapterNumberFont: settings.fontName,
            chapterNameFont: settings.fontName,
            extraFontFaceCSS: nil)
        let key = "\(title)#\(Int(width))"
        return await withCheckedContinuation { continuation in
            enqueue(RenderJob(
                html: html, key: key, width: width,
                continuation: continuation, completion: nil))
        }
    }

    /// 伪代码 0x1001bbaa0（L520-540 + closure 0x1001bbafc）：异步渲染。
    func renderSnapshotAsync(
        template: String,
        title: String,
        chapterIndex: Int,
        width: CGFloat,
        settings: ReadingSettings,
        completion: @escaping (UIImage?) -> Void
    ) {
        let html = ChapterTitleHTMLRenderer().buildResponsiveHTML(
            template: template, title: title, chapterIndex: chapterIndex,
            width: width,
            chapterNumberRegex: "\\\\d+",
            fontFamily: settings.fontName,
            useCustomFont: settings.fontName != "System",
            embeddedFontFaceCSS: nil,
            showChapterName: true,
            chapterNumberFont: settings.fontName,
            chapterNameFont: settings.fontName,
            extraFontFaceCSS: nil)
        enqueue(RenderJob(
            html: html, key: "\(title)#\(Int(width))", width: width,
            continuation: nil, completion: completion))
    }

    /// 伪代码 0x1001bbc44（L549-559）：批量渲染。
    func renderBatch(
        template: String,
        titles: [(title: String, chapterIndex: Int)],
        width: CGFloat,
        settings: ReadingSettings,
        completion: @escaping ([String: UIImage]) -> Void
    ) {
        Task {
            var results: [String: UIImage] = [:]
            for item in titles {
                if let image = await renderSnapshot(
                    template: template, title: item.title,
                    chapterIndex: item.chapterIndex,
                    width: width, height: 120, settings: settings) {
                    results[item.title] = image
                }
            }
            completion(results)
        }
    }

    /// 入队 + 驱动（drain 语义确证）。
    private func enqueue(_ job: RenderJob) {
        jobs.append((html: job.html, key: job.key))
        drain(job: job)
    }

    /// 伪代码 0x1001bb158（L570-591）：排空队列。
    private func drain(job: RenderJob) {
        guard !busy, let webView = makeOrReuse(width: job.width) else {
            job.continuation?.resume(returning: nil)
            job.completion?(nil)
            return
        }
        busy = true
        try? job.html.write(to: tempHTMLURL, atomically: true, encoding: .utf8)
        webView.loadFileURL(tempHTMLURL, allowingReadAccessTo: diskCacheDir)
        currentJob = job
    }
    private var currentJob: RenderJob?

    /// 伪代码 0x1001bbdd8（L709-742）：WebView 复用/新建。
    private func makeOrReuse(width: CGFloat) -> WKWebView? {
        if let existing = webView {
            return existing
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 1),
                                configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        return webView
    }

    /// 伪代码 0x1001bc244（L593-601）：加载完成 → 自适应高度测量。
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        startAutoHeightMeasurement()
    }

    /// 伪代码 0x1001bc64c（L612-671 + closure 0x1001bcc9c）：定时量高。
    private func startAutoHeightMeasurement() {
        measurementGeneration += 1
        let generation = measurementGeneration
        pendingAutoHeight?.invalidate()
        pendingAutoHeight = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.measurementGeneration == generation else {
                    timer.invalidate()
                    return
                }
                webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    MainActor.assumeIsolated {
                        guard let height = result as? CGFloat, height > 0 else { return }
                        timer.invalidate()
                        self.pendingAutoHeight = nil
                        self.takeSnapshotAndFinish(height: height)
                    }
                }
            }
        }
    }

    /// 伪代码 0x1001bc674（L682-689）：截屏收尾。
    private func takeSnapshotAndFinish(height: CGFloat) {
        guard let webView, let job = currentJob else { return }
        webView.takeSnapshot(with: nil) { [weak self] image, _ in
            MainActor.assumeIsolated {
                self?.cleanupAutoHeight()
                self?.done(image)
                _ = height
            }
        }
    }

    /// 伪代码 0x1001bc6e4（L673-678）。
    private func cleanupAutoHeight() {
        pendingAutoHeight?.invalidate()
        pendingAutoHeight = nil
    }

    /// 伪代码 0x1001bcb14（L691-705 + closure 0x1001bd480）：完成 → 缓存/磁盘/回调 → drain。
    private func done(_ image: UIImage?) {
        guard let job = currentJob else { return }
        currentJob = nil
        busy = false
        if let image {
            let cacheKey = "\(job.key)"
            cache.setObject(image, forKey: cacheKey as NSString)
            Self.saveToDisk(image: image, key: cacheKey)
        }
        job.continuation?.resume(returning: image)
        job.completion?(image)
        // 队列有后续作业则继续 drain。
        if !jobs.isEmpty, let next = jobs.first {
            jobs.removeFirst()
            Task { @MainActor in
                self.drain(job: RenderJob(
                    html: next.html, key: next.key, width: 320,
                    continuation: nil, completion: nil))
            }
        }
    }
}
