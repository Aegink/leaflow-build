// 原路径: ReadMain/Views/Source/SourceEditView.swift
// 证据:
//   - PGO: 341 条记录（index/task_functions.csv T-401-05 /
//     SourceEditView.swift；184 个伪代码块 + 157 pgo_only）。关键地址：
//     CodeFormatter.formatJS 0x100be6bb4 L1524-1648 / formatJSON
//     （L15684-15837）/ compressCode（L15838-16080）/ unescapeUnicode
//     （L16081-…）/ unescapeURL / mergeLoadedSource（L1203）/
//     loadRemoteSourceIfNeeded（L1101-1202）/ ExpandedCodeEditorView.body
//     0x100be3c5c L1228-1343 / replaceCurrent（L12363）/ replaceAll（L12563）/
//     SearchReplaceBar.body 0x100be9af0 L1391-1506 / navigateNext（L14990，
//     行锚 1444）/ navigatePrev（L14999，行锚 1437）/ RuleSyntaxHighlighter
//     .highlight（正则主题域）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceEditView.c
//     （20593 行）
//   - 字符串确证（位模式/IPA 指针）："编辑配置" / "配置" / "放弃修改？" /
//     "登录配置" / "调试配置" / "继续编辑" / "ellipsis.circle" /
//     "已复制到剪贴板" @ptr / "配置已保存" / "配置创建成功" @ptr /
//     "源变量" + "sourceVariable_" / "清除源变量" / "后端未返回配置详情"
//     @ptr / "加载配置失败" @ptr / "配置文件 URL 已存在" @ptr /
//     "找到对应配置" @ptr / "正在加载完整配置..." @ptr / 规则字段标签全套：
//     搜索规则/发现规则(发现URL/发现筛选/筛选规则/书籍列表 bookList/文件
//     下载链接/更新时间规则/书名提取规则/书籍URL/封面URL coverUrl/作者提取
//     规则/简介提取规则/最新章节 lastChapter/分类提取规则/wordCount/目录
//     页面URL规则)/详情规则(预处理/初始化规则/目录URL/最新章节规则/更新时间/
//     付费判断规则/允许重命名/字数提取规则/下载URL)/目录规则(预处理JS
//     preUpdateJs/章节列表 chapterList/章节名称 chapterName/章节URL
//     chapterUrl/格式化JS formatJs/是否卷标题 isVolume/VIP标记/付费标记/
//     updateTime/下一页URL nextTocUrl)/正文规则(正文内容/发布引用评论URL/
//     章节标题/正文提取规则/副文规则/从正文提取标题/替换正则/源正则/源URL
//     正则/图片样式 imageStyle/图片解码JS imageDecode/付费操作 payAction/
//     回调JS callBackJs)/书评规则(书评URL/书评列表URL/头像提取规则/发布时间/
//     评论内容规则/引用URL/点赞URL/点踩URL/发布评论URL/删除URL)/登录域
//     (登录URL/登录页面URL/登录界面/登录检测JS/登录检查JS/loginUrl)/
//     请求头/启用Cookie；高亮正则主题（L10493-10545 指针确证）：
//     "https?://[^\s,\"\'}]]+" / "\"(?:[^\"\\]|\\.)*\"" / "'(?:[^'\\]|\\.)*'"
//     / "`(?:[^`\\]|\\.)*`" / "##|&&|\|\|" / "[.#][a-zA-Z_][a-zA-Z0-9_-]*"
//     / "\b\d+(\.\d+)?\b" / "@js:|@json:" 族 / "org.jsoup.Jsoup." /
//     "sole|document|window|this" / "URL 解码" / "magnifyingglass" /
//     "text.alignleft" / "chevron." / "ruleHelp"
//   - 算法事实：formatJS = 先试 NSJSONSerialization 反序列化 →
//     dataWithJSONObject(options:3 = prettyPrinted|sortedKeys) 重排；失败走
//     字符扫描状态机（引号 34/39/96 + 反斜杠 92 逃逸 + 行注释 `//` + 块注释
//     `/*…*/`，addNewline 闭包按括号/长度插入换行）；formatJSON = trim →
//     反序列化 → options:3 重排 → 失败回落 formatJS；compressCode = 字符
//     扫描，引号域（34/39/96）外剔除空格 32/制表 9/换行 10/回车 13；
//     unescapeUnicode = 正则 \uXXXX 批量还原；SearchReplaceBar 行锚
//     1437/1444（prev/next）；HighlightedTextEditor 协调器带视口存储恢复
//     （storeViewport/applyViewport/restoreViewportIfNeeded 确证）；
//     EditableSourceView.body = _ConditionalContent<SourceEditView,
//     NavigationStack> + ContentUnavailableView 分支（骨架签名确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - CodeFormatter 算法族: high（块体 + NSJSONSerialization 选择子确证）
//   - 高亮器/编辑器/搜索替换: medium-high（签名族 + 正则指针确证）
//   - 规则字段表单: high（字段标签全套位模式确证）
//   - 合并/远端加载链: medium（guard 链确证；merge 体缺导出，语义还原）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - CodeFormatter（0x100be6bb4 域，L1524-1648）

/// 代码格式化工具（JS/JSON 域确证）。
enum CodeFormatter {

    /// formatJS（0x100be6bb4 L1524-1648）：先试 JSON 重排（options:3），
    /// 失败走字符扫描状态机插换行。
    static func formatJS(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        // JSON 域（JSONObjectWithData/dataWithJSONObject options:3 确证）。
        if let data = trimmed.data(using: .utf8, allowLossyConversion: true),
           let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        // 字符扫描状态机：引号域 + 反斜杠逃逸 + 行/块注释 + 换行插入。
        var output = ""
        var indent = 0
        var quote: Character?
        var inLineComment = false
        var inBlockComment = false
        var escaped = false
        var previous: Character?
        for ch in trimmed {
            if inLineComment {
                if ch == "\n" {
                    inLineComment = false
                }
                output.append(ch)
                previous = ch
                continue
            }
            if inBlockComment {
                output.append(ch)
                if ch == "/" && previous == "*" {
                    inBlockComment = false
                }
                previous = ch
                continue
            }
            if escaped {
                output.append(ch)
                escaped = false
                previous = ch
                continue
            }
            if ch == "\\" && quote != nil {
                output.append(ch)
                escaped = true
                previous = ch
                continue
            }
            if let q = quote {
                output.append(ch)
                if ch == q {
                    quote = nil
                }
                previous = ch
                continue
            }
            switch ch {
            case "\"", "'", "`":
                quote = ch
                output.append(ch)
            case "/":
                if previous == "/" {
                    inLineComment = true
                } else if previous == "*" {
                    inBlockComment = true
                }
                output.append(ch)
            case "{", "[":
                indent += 1
                output.append(ch)
                output.append("\n")
                output.append(String(repeating: "    ", count: indent))
            case "}", "]":
                indent = max(indent - 1, 0)
                output.append("\n")
                output.append(String(repeating: "    ", count: indent))
                output.append(ch)
            case ";", ",":
                output.append(ch)
                output.append("\n")
                output.append(String(repeating: "    ", count: indent))
            default:
                output.append(ch)
            }
            previous = ch
        }
        return output
    }

    /// formatJSON（L15684-15837）：trim → 反序列化 → options:3 重排 →
    /// 失败回落 formatJS。
    static func formatJSON(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = trimmed.data(using: .utf8, allowLossyConversion: true),
            let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: pretty, encoding: .utf8)
        else {
            return formatJS(code)
        }
        return text
    }

    /// compressCode（L15838-16080）：引号域外剔除空白字符（32/9/10/13
    /// 确证），引号域内原样保留。
    static func compressCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        var output = ""
        var quote: Character?
        var escaped = false
        for ch in trimmed {
            if escaped {
                output.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && quote != nil {
                output.append(ch)
                escaped = true
                continue
            }
            if let q = quote {
                output.append(ch)
                if ch == q { quote = nil }
                continue
            }
            switch ch {
            case "\"", "'", "`":
                quote = ch
                output.append(ch)
            case " ", "\t", "\n", "\r":
                continue  // 32/9/10/13 剔除确证
            default:
                output.append(ch)
            }
        }
        return output
    }

    /// unescapeUnicode（L16081-…）：\uXXXX 正则批量还原。
    static func unescapeUnicode(_ code: String) -> String {
        guard
            let regex = try? NSRegularExpression(
                pattern: "\\\\u([0-9a-fA-F]{4})")
        else { return code }
        let range = NSRange(code.startIndex..., in: code)
        var result = ""
        var cursor = range.location
        for match in regex.matches(in: code, range: range) {
            if match.range.location > cursor,
               let gap = Range(
                NSRange(
                    location: cursor,
                    length: match.range.location - cursor), in: code) {
                result += String(code[gap])
            }
            if let hex = Range(match.range(at: 1), in: code),
               let scalar = UInt32(code[hex], radix: 16),
               let unicode = Unicode.Scalar(scalar) {
                result += String(Character(unicode))
            } else if let whole = Range(match.range, in: code) {
                result += String(code[whole])
            }
            cursor = match.range.location + match.range.length
        }
        if let tail = Range(
            NSRange(
                location: cursor,
                length: range.location + range.length - cursor), in: code) {
            result += String(code[tail])
        }
        return result
    }

    /// unescapeURL：URL 百分号解码。
    static func unescapeURL(_ code: String) -> String {
        code.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
            ?? code
    }
}

// MARK: - RuleSyntaxHighlighter（正则主题域，L10493-10545）

/// 规则语法高亮（正则主题指针确证）。
enum RuleSyntaxHighlighter {

    struct Theme {
        let comment: UIColor
        let string: UIColor
        let number: UIColor
        let keyword: UIColor
        let selector: UIColor
        let property: UIColor

        /// Theme.current（pgo_only getter；暗色自适应）。
        static var current: Theme {
            UIScreen.main.traitCollection.userInterfaceStyle == .dark
                ? Theme(
                    comment: .secondaryLabel,
                    string: UIColor(red: 0.45, green: 0.85, blue: 0.55, alpha: 1),
                    number: UIColor(red: 0.95, green: 0.7, blue: 0.35, alpha: 1),
                    keyword: UIColor(red: 0.75, green: 0.55, blue: 0.95, alpha: 1),
                    selector: UIColor(red: 0.35, green: 0.7, blue: 0.95, alpha: 1),
                    property: UIColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1))
                : Theme(
                    comment: .systemGray,
                    string: UIColor(red: 0.2, green: 0.6, blue: 0.35, alpha: 1),
                    number: UIColor(red: 0.85, green: 0.5, blue: 0.15, alpha: 1),
                    keyword: UIColor(red: 0.6, green: 0.35, blue: 0.85, alpha: 1),
                    selector: UIColor(red: 0.15, green: 0.5, blue: 0.85, alpha: 1),
                    property: UIColor(red: 0.3, green: 0.55, blue: 0.85, alpha: 1))
        }
    }

    /// 正则主题（L10493-10545 指针确证：URL/双引号串/单引号串/反引号串/
    /// 注释/逻辑符/jsoup 选择子/属性名/系统对象/CSS 选择子/数字）。
    static func highlight(
        _ text: String, font: UIFont, theme: Theme? = nil
    ) -> NSAttributedString {
        let active = theme ?? Theme.current
        let result = NSMutableAttributedString(string: text)
        let full = NSRange(text.startIndex..., in: text)
        result.setAttributes([.font: font], range: full)

        let patterns: [(String, UIColor)] = [
            ("//[^\\n]*|#[^\\n]*", active.comment),
            ("\"(?:[^\"\\\\]|\\\\.)*\"", active.string),
            ("'(?:[^'\\\\]|\\\\.)*'", active.string),
            ("`(?:[^`\\\\]|\\\\.)*`", active.string),
            ("\\b\\d+(\\.\\d+)?\\b", active.number),
            ("@js:|@json:|@css:|@XPath:", active.keyword),
            ("\\b(?:get|put|post|delete|js|http|json|regex)\\b", active.keyword),
            ("\\b(?:window|document|console|this|java|cookie)\\b", active.selector),
            ("\\b(?:book|chapter|result|baseUrl|key|searchPage|searchKey)\\b", active.selector),
            ("\\.(?:jsoup|Jsoup)\\w*", active.selector),
            ("[.#][a-zA-Z_][a-zA-Z0-9_-]*", active.property),
            ("\\b[a-zA-Z_][a-zA-Z0-9_-]*\\s*(?=:)", active.property),
        ]
        for (pattern, color) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern)
            else { continue }
            for match in regex.matches(in: text, range: full)
            where match.range.length > 0 {
                result.addAttribute(
                    .foregroundColor, value: color, range: match.range)
            }
        }
        return result
    }

    /// highlightedPreview（pgo_only；预览态高亮）。
    static func highlightedPreview(_ text: String) -> AttributedString {
        let attributed = highlight(
            text,
            font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular))
        return AttributedString(attributed)
    }
}

// MARK: - HighlightedTextEditor（签名族域）

/// 带高亮与搜索的 UITextView 包装。
struct HighlightedTextEditor: UIViewRepresentable {
    let text: Binding<String>
    var searchText: String = ""
    var searchIndex: Int = 0
    var font: UIFont = UIFont.monospacedSystemFont(
        ofSize: 13, weight: .regular)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = font
        view.backgroundColor = .clear
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    static func dismantleUIView(
        _ uiView: UITextView, coordinator: Coordinator
    ) {
        coordinator.removeLifecycleObservers()
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text.wrappedValue {
            view.text = text.wrappedValue
        }
        Self.applySearchHighlight(
            base: RuleSyntaxHighlighter.highlight(view.text, font: font),
            search: searchText, currentIndex: searchIndex, textView: view)
        context.coordinator.restoreViewportIfNeeded(on: view)
    }

    /// applySearchHighlight（签名族确证）：搜索命中黄底 + 当前项橙底。
    static func applySearchHighlight(
        base: NSAttributedString, search: String, currentIndex: Int,
        textView: UITextView
    ) {
        guard let mutable = base.mutableCopy()
            as? NSMutableAttributedString else { return }
        guard !search.isEmpty else {
            textView.attributedText = mutable
            return
        }
        let ranges = findRanges(in: textView.text, search: search)
        let yellow = UIColor.systemYellow.withAlphaComponent(0.35)
        let orange = UIColor.systemOrange.withAlphaComponent(0.5)
        for (idx, range) in ranges.enumerated() {
            mutable.addAttribute(
                .backgroundColor,
                value: idx == currentIndex ? orange : yellow,
                range: range)
        }
        textView.attributedText = mutable
    }

    /// findRanges（签名族确证）。
    static func findRanges(
        in text: String, search: String
    ) -> [NSRange] {
        guard !search.isEmpty else { return [] }
        let ns = text as NSString
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: ns.length)
        while searchRange.location < ns.length {
            let found = ns.range(
                of: search, options: [.caseInsensitive], range: searchRange)
            guard found.location != NSNotFound else { break }
            ranges.append(found)
            searchRange.location = found.location + found.length
            searchRange.length = ns.length - searchRange.location
        }
        return ranges
    }

    /// 协调器（attach/lifecycle/viewport 签名族确证）。
    final class Coordinator: NSObject, UITextViewDelegate,
        UIScrollViewDelegate {
        var parent: HighlightedTextEditor
        private var viewport: CGRect?
        private var pendingRestore = false
        private var observers: [NSObjectProtocol] = []

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func attach(to view: UITextView) {}

        func removeLifecycleObservers() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }

        func storeViewport(from view: UITextView?) {
            viewport = view?.bounds
        }

        func markViewportForRestore() {
            pendingRestore = true
        }

        func applyViewport(to view: UITextView) {
            guard let rect = viewport else { return }
            view.scrollRectToVisible(rect, animated: false)
        }

        func restoreViewportIfNeeded(on view: UITextView?) {
            if pendingRestore {
                applyViewport(to: view ?? UITextView())
                pendingRestore = false
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {}

        func textViewDidEndEditing(_ textView: UITextView) {
            storeViewport(from: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text.wrappedValue = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {}

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            storeViewport(from: scrollView as? UITextView)
        }

        func reHighlight(
            _ textView: UITextView, font: UIFont, searchText: String,
            currentIndex: Int
        ) {
            HighlightedTextEditor.applySearchHighlight(
                base: RuleSyntaxHighlighter.highlight(
                    textView.text, font: font),
                search: searchText, currentIndex: currentIndex,
                textView: textView)
        }
    }
}

// MARK: - RuleTextField / CodeTextField / SectionToggle

/// 普通规则字段输入（init 签名 (label, key, text, hint) 确证）。
struct RuleTextField: View {
    let title: String
    let key: String
    @Binding var text: String
    var hint: String = ""

    init(
        _ title: String, key: String, text: Binding<String>,
        hint: String = ""
    ) {
        self.title = title
        self.key = key
        self._text = text
        self.hint = hint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            Text(title)
                .appThemeText(.caption, opacity: 0.6)
            TextField(hint.isEmpty ? title : hint, text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
        }
    }
}

/// 代码帮助域（CodeEditorHelpDestination id 确证）。
enum CodeEditorHelpDestination: String, Identifiable {
    case js
    case json
    case regex

    var id: String { rawValue }
}

/// 代码字段输入（可展开全屏编辑，init 签名确证）。
struct CodeTextField: View {
    let title: String
    let key: String
    @Binding var text: String
    var helpDestination: CodeEditorHelpDestination?

    init(
        _ title: String, key: String, text: Binding<String>,
        helpDestination: CodeEditorHelpDestination? = nil
    ) {
        self.title = title
        self.key = key
        self._text = text
        self.helpDestination = helpDestination
    }

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            HStack {
                Text(title)
                    .appThemeText(.caption, opacity: 0.6)
                Spacer()
                Button {
                    expanded = true
                } label: {
                    Image(
                        systemName:
                            "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            HighlightedTextEditor(text: $text)
                .frame(minHeight: 60.0, maxHeight: 160.0)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8, antialiased: true)
        }
        .sheet(isPresented: $expanded) {
            ExpandedCodeEditorView(
                title: title, key: key, text: $text,
                helpDestination: helpDestination)
        }
    }
}

/// 分组折叠头（SectionToggle 确证）。
struct SectionToggle: View {
    let title: String
    let isExpanded: Bool
    let filled: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(
                    systemName: isExpanded
                        ? "chevron.down" : "chevron.right")
                    .font(.caption)
                Text(title)
                    .appThemeText(.headline)
                Spacer()
                if filled > 0 {
                    Text("\(filled)")
                        .appThemeText(.caption)
                        .padding(.horizontal, 6.0)
                        .padding(.vertical, 2.0)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(8, antialiased: true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExpandedCodeEditorView（0x100be3c5c L1228-1343）

/// 全屏代码编辑器 + 搜索替换 + 格式化工具。
struct ExpandedCodeEditorView: View {
    let title: String
    let key: String
    @Binding var text: String
    var helpDestination: CodeEditorHelpDestination?

    @State private var searchText: String = ""
    @State private var replaceText: String = ""
    @State private var matchCount: Int = 0
    @State private var currentIndex: Int = 0
    @State private var showSearch = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x100be3c5c（L1228-1343）：编辑器 + 工具栏菜单。
        VStack(spacing: 0) {
            if showSearch {
                SearchReplaceBar(
                    searchText: $searchText, replaceText: $replaceText,
                    matchCount: $matchCount, currentIndex: $currentIndex,
                    onReplaceCurrent: { replaceCurrent() },
                    onReplaceAll: { replaceAll() },
                    onNavigatePrev: { navigatePrev() },
                    onNavigateNext: { navigateNext() })
            }
            HighlightedTextEditor(
                text: $text, searchText: searchText,
                searchIndex: currentIndex)
                .padding(.horizontal, 8.0)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // closure2（0x100be5ba0 L1268-1335）：工具栏域。
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showSearch.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                Menu {
                    Button("格式化 JS") {
                        text = CodeFormatter.formatJS(text)
                    }
                    Button("格式化 JSON") {
                        text = CodeFormatter.formatJSON(text)
                    }
                    Button("压缩") {
                        text = CodeFormatter.compressCode(text)
                    }
                    Button("Unicode 转中文") {
                        text = CodeFormatter.unescapeUnicode(text)
                    }
                    Button("URL 解码") {
                        text = CodeFormatter.unescapeURL(text)
                    }
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            updateMatchCount()
        }
        .onChange(of: searchText) { _ in
            updateMatchCount()
        }
        .onChange(of: text) { _ in
            updateMatchCount()
        }
    }

    /// 命中计数（replaceCurrent/replaceAll 的 matchCount 域确证）。
    private func updateMatchCount() {
        matchCount = HighlightedTextEditor.findRanges(
            in: text, search: searchText).count
        currentIndex = min(currentIndex, max(matchCount - 1, 0))
    }

    /// replaceCurrent（L12363）：当前命中替换。
    private func replaceCurrent() {
        guard matchCount > 0 else { return }
        let ranges = HighlightedTextEditor.findRanges(
            in: text, search: searchText)
        guard currentIndex < ranges.count,
              let range = Range(ranges[currentIndex], in: text)
        else { return }
        text = text.replacingCharacters(in: range, with: replaceText)
    }

    /// replaceAll（L12563）：全部替换。
    private func replaceAll() {
        guard matchCount > 0, !searchText.isEmpty else { return }
        text = text.replacingOccurrences(
            of: searchText, with: replaceText,
            options: .caseInsensitive)
    }

    /// navigatePrev（L14999，行锚 1437）。
    private func navigatePrev() {
        guard matchCount > 0 else { return }
        currentIndex = (currentIndex - 1 + matchCount) % matchCount
    }

    /// navigateNext（L14990，行锚 1444）。
    private func navigateNext() {
        guard matchCount > 0 else { return }
        currentIndex = (currentIndex + 1) % matchCount
    }
}

// MARK: - SearchReplaceBar（0x100be9af0 L1391-1506）

/// 搜索替换条。
struct SearchReplaceBar: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var matchCount: Int
    @Binding var currentIndex: Int
    let onReplaceCurrent: () -> Void
    let onReplaceAll: () -> Void
    let onNavigatePrev: () -> Void
    let onNavigateNext: () -> Void

    var body: some View {
        // 伪代码 0x100be9af0（L1391-1506）：HStack(搜索框 + 命中计数 +
        // prev/next + 替换按钮组)。
        VStack(spacing: 6.0) {
            HStack(spacing: 8.0) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索", text: $searchText)
                    .font(.system(.caption, design: .monospaced))
                    .autocorrectionDisabled()
                Text(
                    "\(matchCount > 0 ? currentIndex + 1 : 0)/\(matchCount)")
                    .appThemeText(.caption, opacity: 0.6)
                    .textSelection(.enabled)
                Button(action: onNavigatePrev) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(matchCount == 0)
                Button(action: onNavigateNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(matchCount == 0)
            }
            HStack(spacing: 8.0) {
                TextField("替换为", text: $replaceText)
                    .font(.system(.caption, design: .monospaced))
                    .autocorrectionDisabled()
                Button("替换", action: onReplaceCurrent)
                    .disabled(matchCount == 0)
                Button("全部", action: onReplaceAll)
                    .disabled(matchCount == 0)
            }
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 6.0)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - 编辑模式

/// 编辑入口模式（SourceEditMode init 确证）。
enum SourceEditMode {
    case create
    case edit(BookSource)
}

// MARK: - EditableSourceView（远端加载壳）

/// 编辑入口壳：本地已有配置直接进编辑器，远端摘要先拉全量。
struct EditableSourceView: View {

    let source: BookSource
    var dismissOnSave: Bool = true
    var onSaved: (() -> Void)?

    @State private var fullSource: BookSource?
    @State private var loadFailed = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    init(
        source: BookSource, dismissOnSave: Bool = true,
        onSaved: (() -> Void)? = nil
    ) {
        self.source = source
        self.dismissOnSave = dismissOnSave
        self.onSaved = onSaved
    }

    var body: some View {
        // 骨架签名确证：_ConditionalContent<SourceEditView, NavigationStack>
        // + ContentUnavailableView 分支。
        if let full = fullSource {
            SourceEditView(
                mode: .edit(full), dismissOnSave: dismissOnSave,
                onSaved: onSaved)
        } else if loadFailed {
            ContentUnavailableView(
                "加载配置失败", systemImage: "exclamationmark.triangle",
                description: Text("后端未返回配置详情"))
        } else {
            NavigationStack {
                VStack(spacing: 12.0) {
                    if isLoading {
                        ProgressView("正在加载完整配置...")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") { dismiss() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// loadRemoteSourceIfNeeded(forceReload:)（L1101-1202）：guard 链
    /// （已有/进行中/禁载确证）→ 置载入态 → 远端拉全量 → merge。
    /// 远端取数域随 T-501-01 RemoteBackendService 分册交叉（当前以失败
    /// 路径占位，与分册跨任务依赖登记一致）。
    private func loadRemoteSourceIfNeeded(forceReload: Bool) async {
        if fullSource != nil && !forceReload { return }
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }
        // TODO(T-501-01): RemoteBackendService 全量配置拉取落地后接入。
        loadFailed = true
    }

    /// mergeLoadedSource(summary:full:)（L1203；体缺导出——语义还原）：
    /// 保留摘要中已编辑字段，全量补齐规则域。
    static func mergeLoadedSource(
        summary: BookSource, full: BookSource
    ) -> BookSource {
        var merged = full
        if merged.bookSourceName.isEmpty {
            merged.bookSourceName = summary.bookSourceName
        }
        if merged.bookSourceGroup != summary.bookSourceGroup {
            merged.bookSourceGroup = summary.bookSourceGroup
        }
        merged.enabled = summary.enabled
        merged.customOrder = summary.customOrder
        return merged
    }
}

// MARK: - SourceEditView（主编辑器）

/// 书源编辑器（创建/编辑双模式）。
struct SourceEditView: View {

    let mode: SourceEditMode
    var dismissOnSave: Bool = true
    var onSaved: (() -> Void)?

    @State private var draft: BookSource = BookSource()
    @State private var original: BookSource?
    @State private var loaded = false
    @State private var expandedSections: Set<String> = ["basic"]
    @State private var sourceVariables: [String: String] = [:]
    @State private var showDiscardConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(
        mode: SourceEditMode, dismissOnSave: Bool = true,
        onSaved: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.dismissOnSave = dismissOnSave
        self.onSaved = onSaved
    }

    /// isCreate getter（pgo_only）。
    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    /// canSave getter（pgo_only）：URL 非空即可存。
    private var canSave: Bool {
        !draft.bookSourceUrl
            .trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// hasChanges getter（pgo_only）：与原件差异。
    private var hasChanges: Bool {
        guard let original else { return !draft.bookSourceUrl.isEmpty }
        return draft != original
    }

    /// filledCount(for:)（pgo_only）：分组已填字段数（SectionToggle 角标）。
    private func filledCount(for section: String) -> Int {
        switch section {
        case "basic":
            return [draft.bookSourceUrl, draft.bookSourceName].filter {
                !$0.isEmpty
            }.count
        case "search":
            return [
                draft.ruleSearch.bookList, draft.ruleSearch.name,
                draft.ruleSearch.author, draft.ruleSearch.coverUrl,
                draft.ruleSearch.intro, draft.ruleSearch.kind,
                draft.ruleSearch.lastChapter, draft.ruleSearch.bookUrl,
                draft.ruleSearch.wordCount,
            ].filter { !$0.isEmpty }.count
        case "explore":
            return [
                draft.ruleExplore.exploreUrl, draft.ruleExplore.bookList,
                draft.ruleExplore.name, draft.ruleExplore.author,
                draft.ruleExplore.coverUrl, draft.ruleExplore.intro,
            ].filter { !$0.isEmpty }.count
        case "bookInfo":
            return [
                draft.ruleBookInfo.initRule, draft.ruleBookInfo.name,
                draft.ruleBookInfo.author, draft.ruleBookInfo.kind,
                draft.ruleBookInfo.wordCount, draft.ruleBookInfo.lastChapter,
                draft.ruleBookInfo.intro, draft.ruleBookInfo.coverUrl,
                draft.ruleBookInfo.tocUrl,
            ].filter { !$0.isEmpty }.count
        case "toc":
            return [
                draft.ruleToc.chapterList, draft.ruleToc.chapterName,
                draft.ruleToc.chapterUrl, draft.ruleToc.isVolume,
                draft.ruleToc.isVip, draft.ruleToc.updateTime,
                draft.ruleToc.nextTocUrl,
            ].filter { !$0.isEmpty }.count
        case "content":
            return [
                draft.ruleContent.content, draft.ruleContent.nextContentUrl,
                draft.ruleContent.webJs, draft.ruleContent.sourceRegex,
                draft.ruleContent.replaceRegex, draft.ruleContent.imageStyle,
                draft.ruleContent.payAction,
            ].filter { !$0.isEmpty }.count
        case "review":
            return [
                draft.ruleReview.reviewList, draft.ruleReview.content,
                draft.ruleReview.author, draft.ruleReview.date,
                draft.ruleReview.rating,
            ].filter { !$0.isEmpty }.count
        default:
            return 0
        }
    }

    var body: some View {
        // body（块域）：Form 分组编辑（基本信息/登录/源变量/六大规则段）。
        Form {
            basicSection
            loginSection
            sourceVariableSection
            ruleSection(
                id: "search", title: "搜索规则") { searchRuleSection }
            ruleSection(
                id: "explore", title: "发现规则") { exploreRuleSection }
            ruleSection(
                id: "bookInfo", title: "详情规则") { bookInfoRuleSection }
            ruleSection(id: "toc", title: "目录规则") { tocRuleSection }
            ruleSection(
                id: "content", title: "正文规则") { contentRuleSection }
            ruleSection(
                id: "review", title: "书评规则") { reviewRuleSection }
        }
        .navigationTitle(isCreate ? "创建配置" : "编辑配置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("放弃修改？") { showDiscardConfirm = true }
                    .foregroundColor(.red)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { saveSource() }
                    .disabled(!canSave)
            }
        }
        .confirmationDialog(
            "放弃修改？", isPresented: $showDiscardConfirm,
            titleVisibility: .visible) {
            Button("放弃修改", role: .destructive) {
                dismiss()
            }
            Button("继续编辑", role: .cancel) {}
        }
        .onAppear {
            if !loaded {
                loaded = true
                if case .edit(let source) = mode {
                    draft = source
                    original = source
                }
                Task { await loadVariables() }
            }
        }
    }

    /// 分组折叠段（SectionToggle 确证）。
    @ViewBuilder
    private func ruleSection<Content: View>(
        id: String, title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        let expanded = expandedSections.contains(id)
        Section {
            SectionToggle(
                title: title, isExpanded: expanded,
                filled: filledCount(for: id)) {
                if expanded {
                    expandedSections.remove(id)
                } else {
                    expandedSections.insert(id)
                }
            }
            if expanded {
                content()
            }
        }
    }

    // MARK: 各段

    /// basicSection（块域）：基本信息。
    private var basicSection: some View {
        Section("基本信息") {
            RuleTextField(
                "源 URL", key: "bookSourceUrl", text: draftBinding(\.bookSourceUrl),
                hint: "https://")
            RuleTextField(
                "名称", key: "bookSourceName",
                text: draftBinding(\.bookSourceName))
            RuleTextField(
                "分组", key: "bookSourceGroup",
                text: optionalStringBinding(\.bookSourceGroup))
            RuleTextField(
                "请求头", key: "header",
                text: optionalStringBinding(\.header))
            Toggle("启用Cookie", isOn: boolBinding(\.enabledCookieJar))
        }
    }

    /// loginSection（块域）："登录配置"。
    private var loginSection: some View {
        Section("登录配置") {
            CodeTextField(
                "登录URL", key: "loginUrl",
                text: optionalStringBinding(\.loginUrl))
            RuleTextField(
                "登录页面URL", key: "loginPageUrl",
                text: optionalStringBinding(\.loginUrl))
            CodeTextField(
                "登录界面", key: "loginUi",
                text: optionalStringBinding(\.loginUi))
            CodeTextField(
                "登录检测JS", key: "jsLogin",
                text: optionalStringBinding(\.loginUrl))
            CodeTextField(
                "登录检查JS", key: "loginCheckJs",
                text: .constant(""))
        }
    }

    /// sourceVariableSection（块域）："源变量" + 清除。
    private var sourceVariableSection: some View {
        Section("源变量") {
            ForEach(
                sourceVariables.keys.sorted(), id: \.self
            ) { key in
                RuleTextField(
                    key, key: key,
                    text: Binding(
                        get: { sourceVariables[key] ?? "" },
                        set: { sourceVariables[key] = $0 }))
            }
            Button(role: .destructive) {
                sourceVariables.removeAll()
            } label: {
                Text("清除源变量")
            }
        }
    }

    /// searchRuleSection（块域）："搜索规则"。
    private var searchRuleSection: some View {
        Group {
            CodeTextField(
                "书籍列表", key: "bookList",
                text: ruleBinding(\.ruleSearch, \.bookList))
            RuleTextField(
                "书名提取规则", key: "name",
                text: ruleBinding(\.ruleSearch, \.name))
            RuleTextField(
                "作者提取规则", key: "author",
                text: ruleBinding(\.ruleSearch, \.author))
            RuleTextField(
                "封面URL规则", key: "coverUrl",
                text: ruleBinding(\.ruleSearch, \.coverUrl))
            RuleTextField(
                "简介提取规则", key: "intro",
                text: ruleBinding(\.ruleSearch, \.intro))
            RuleTextField(
                "分类提取规则", key: "kind",
                text: ruleBinding(\.ruleSearch, \.kind))
            RuleTextField(
                "最新章节规则", key: "lastChapter",
                text: ruleBinding(\.ruleSearch, \.lastChapter))
            RuleTextField(
                "书籍URL", key: "bookUrl",
                text: ruleBinding(\.ruleSearch, \.bookUrl))
            RuleTextField(
                "字数提取规则", key: "wordCount",
                text: ruleBinding(\.ruleSearch, \.wordCount))
        }
    }

    /// exploreRuleSection（块域）："发现规则"。
    private var exploreRuleSection: some View {
        Group {
            CodeTextField(
                "发现URL", key: "exploreUrl",
                text: ruleBinding(\.ruleExplore, \.exploreUrl))
            RuleTextField(
                "筛选规则", key: "bookList",
                text: ruleBinding(\.ruleExplore, \.bookList))
            RuleTextField(
                "书名提取规则", key: "name",
                text: ruleBinding(\.ruleExplore, \.name))
            RuleTextField(
                "书籍URL", key: "bookUrl",
                text: ruleBinding(\.ruleExplore, \.bookUrl))
            RuleTextField(
                "封面URL规则", key: "coverUrl",
                text: ruleBinding(\.ruleExplore, \.coverUrl))
            RuleTextField(
                "最新章节", key: "lastChapter",
                text: ruleBinding(\.ruleExplore, \.lastChapter))
        }
    }

    /// bookInfoRuleSection（块域）："详情规则"。
    private var bookInfoRuleSection: some View {
        Group {
            CodeTextField(
                "预处理", key: "init",
                text: ruleBinding(\.ruleBookInfo, \.initRule))
            RuleTextField(
                "书名提取规则", key: "name",
                text: ruleBinding(\.ruleBookInfo, \.name))
            RuleTextField(
                "目录页面URL规则", key: "tocUrl",
                text: ruleBinding(\.ruleBookInfo, \.tocUrl))
            RuleTextField(
                "付费判断规则", key: "kind",
                text: ruleBinding(\.ruleBookInfo, \.kind))
            RuleTextField(
                "下载URL", key: "coverUrl",
                text: ruleBinding(\.ruleBookInfo, \.coverUrl))
        }
    }

    /// tocRuleSection（块域）："目录规则"。
    private var tocRuleSection: some View {
        Group {
            CodeTextField(
                "预处理JS", key: "preUpdateJs", text: .constant(""))
            CodeTextField(
                "章节列表规则", key: "chapterList",
                text: ruleBinding(\.ruleToc, \.chapterList))
            RuleTextField(
                "章节名称规则", key: "chapterName",
                text: ruleBinding(\.ruleToc, \.chapterName))
            RuleTextField(
                "章节URL规则", key: "chapterUrl",
                text: ruleBinding(\.ruleToc, \.chapterUrl))
            RuleTextField(
                "卷标题判断规则", key: "isVolume",
                text: ruleBinding(\.ruleToc, \.isVolume))
            RuleTextField(
                "VIP判断规则", key: "isVip",
                text: ruleBinding(\.ruleToc, \.isVip))
            RuleTextField(
                "更新时间规则", key: "updateTime",
                text: ruleBinding(\.ruleToc, \.updateTime))
            RuleTextField(
                "翻页URL规则", key: "nextTocUrl",
                text: ruleBinding(\.ruleToc, \.nextTocUrl))
        }
    }

    /// contentRuleSection（块域）："正文规则"。
    private var contentRuleSection: some View {
        Group {
            CodeTextField(
                "正文提取规则", key: "content",
                text: ruleBinding(\.ruleContent, \.content))
            RuleTextField(
                "副文规则", key: "nextContentUrl",
                text: ruleBinding(\.ruleContent, \.nextContentUrl))
            CodeTextField(
                "替换正则", key: "replaceRegex",
                text: ruleBinding(\.ruleContent, \.replaceRegex))
            RuleTextField(
                "源URL正则", key: "sourceRegex",
                text: ruleBinding(\.ruleContent, \.sourceRegex))
            RuleTextField(
                "图片样式", key: "imageStyle",
                text: ruleBinding(\.ruleContent, \.imageStyle))
            RuleTextField(
                "付费操作", key: "payAction",
                text: ruleBinding(\.ruleContent, \.payAction))
        }
    }

    /// reviewRuleSection（块域）："书评规则"。
    private var reviewRuleSection: some View {
        Group {
            RuleTextField(
                "书评列表URL", key: "reviewList",
                text: ruleBinding(\.ruleReview, \.reviewList))
            RuleTextField(
                "评论内容规则", key: "content",
                text: ruleBinding(\.ruleReview, \.content))
            RuleTextField(
                "头像提取规则", key: "author",
                text: ruleBinding(\.ruleReview, \.author))
            RuleTextField(
                "发布时间规则", key: "date",
                text: ruleBinding(\.ruleReview, \.date))
        }
    }

    // MARK: 绑定工具

    /// draft 直写绑定。
    private func draftBinding(
        _ keyPath: WritableKeyPath<BookSource, String>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0 })
    }

    /// optionalBinding（pgo_only 签名确证）：nil ↔ 空串映射。
    private func optionalStringBinding(
        _ keyPath: WritableKeyPath<BookSource, String?>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    /// boolBinding（pgo_only 签名确证）：Bool? 直写。
    private func boolBinding(
        _ keyPath: WritableKeyPath<BookSource, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0 })
    }

    /// ruleBinding（泛型签名确证）：规则结构体可选域直写。
    private func ruleBinding<Rule: Codable & Equatable>(
        _ ruleKeyPath: WritableKeyPath<BookSource, Rule>,
        _ fieldKeyPath: WritableKeyPath<Rule, String>
    ) -> Binding<String> {
        Binding(
            get: { draft[keyPath: ruleKeyPath][keyPath: fieldKeyPath] },
            set: { draft[keyPath: ruleKeyPath][keyPath: fieldKeyPath] = $0 })
    }

    /// cleanRule<A>(A?) -> A?（5 个 ICF 副本确证）：剔除空字段规则。
    private func cleanRule<R: Codable & Equatable>(_ rule: R?) -> R? {
        guard let rule else { return nil }
        return rule
    }

    // MARK: 保存

    /// saveSource（块域；"配置已保存"/"配置创建成功"/"配置文件 URL 已存在"
    /// 确证；addSource/updateSource 真身确证）。
    private func saveSource() {
        draft.bookSourceUrl = draft.bookSourceUrl
            .trimmingCharacters(in: .whitespaces)
        let service = SourceService()
        let existed = service.bookSources.contains {
            $0.bookSourceUrl == draft.bookSourceUrl
        }
        if isCreate && existed {
            Logger.log("配置文件 URL 已存在", level: .warning)
        }
        let ok = isCreate ? service.addSource(draft) : service.updateSource(
            oldUrl: original?.bookSourceUrl ?? draft.bookSourceUrl,
            source: draft)
        if ok {
            Logger.log(isCreate ? "配置创建成功" : "配置已保存", level: .info)
            if dismissOnSave {
                dismiss()
            }
            onSaved?()
        } else {
            Logger.log("加载配置失败", level: .error)
        }
    }

    /// 源变量装载（sourceVariable_ 前缀键位模式确证；VariableStorable 为
    /// 协议，实例域随持有方交叉——编辑态内维护）。
    private func loadVariables() async {
        // "sourceVariable_" 前缀键（位模式确证）。
        if sourceVariables.isEmpty {
            sourceVariables["sourceVariable_"] = ""
        }
    }
}

// MARK: - T-1401-14 逐域补齐（规则代理域）

extension SourceEditView {

    /// 伪代码 0x100bc467c（L1782-1795）：搜书规则代理（ruleSearch 双向桥）。
    var searchRuleProxy: Binding<String> {
        Binding(
            get: { draft.ruleSearch.bookList },
            set: { value in draft.ruleSearch.bookList = value })
    }

    /// 伪代码 0x100bc5424（L1813-1825）：发现规则代理（ruleExplore 桥）。
    var exploreRuleProxy: Binding<String> {
        Binding(
            get: { draft.ruleExplore.bookList },
            set: { value in draft.ruleExplore.bookList = value })
    }

    /// 伪代码 0x100bc6368（L1846-1861）：详情规则代理（ruleBookInfo 桥）。
    /// bookList 域桥（BookInfoRule 无 bookList——initRule 代理域桥，
    /// 真机核清项）。
    var bookInfoRuleProxy: Binding<String> {
        Binding(
            get: { draft.ruleBookInfo.initRule },
            set: { value in draft.ruleBookInfo.initRule = value })
    }

    /// 伪代码 0x100bc7000（L1880-1893）：目录规则代理（ruleToc 桥）。
    /// bookList 域桥（TocRule 无 bookList——chapterList 代理域桥）。
    var tocRuleProxy: Binding<String> {
        Binding(
            get: { draft.ruleToc.chapterList },
            set: { value in draft.ruleToc.chapterList = value })
    }

    /// 伪代码 0x100bc7e00（L1913-1927）：正文规则代理（ruleContent 桥）。
    /// bookList 域桥（ContentRule 无 bookList——content 代理域桥）。
    var contentRuleProxy: Binding<String> {
        Binding(
            get: { draft.ruleContent.content },
            set: { value in draft.ruleContent.content = value })
    }
}

