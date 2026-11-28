// 原路径: ReadMain/Services/LoginService.swift
// 0x10034f814 / 0x100355940 / 0x100357dc8：配置规则上下文、表单注入、脚本加动作。
import Foundation
import JavaScriptCore

extension LoginService {
    struct ActionResult {
        let success: Bool
        let message: String?
        let values: [String: String]
    }

    static func configuredAnalyzeRule(
        source: BookSource, content: String = "", baseUrl: String? = nil,
        book: Book? = nil, chapter: Chapter? = nil, loadJsLib: Bool = true,
        defaults: UserDefaults = .standard
    ) -> AnalyzeRule {
        let analyzer = AnalyzeRule(source: source, parent: nil, isolatedJavaScript: true)
        analyzer.book = book
        if let chapter {
            analyzer.currentChapter = BookChapter(title: chapter.name, url: chapter.url,
                index: chapter.index, isRead: chapter.isRead)
        }
        analyzer.setContent(content, baseUrl: baseUrl ?? source.bookSourceUrl)
        analyzer.installSourceBridgeBindings()
        analyzer.setupChapterVariableBridge()
        installLoginSourceBridge(into: analyzer, source: source, defaults: defaults)
        let context = analyzer.jsContextHandle()
        if let book, let data = try? JSONEncoder().encode(book),
           let object = try? JSONSerialization.jsonObject(with: data) {
            context.setObject(object, forKeyedSubscript: "book" as NSString)
        }
        if let chapter, let data = try? JSONEncoder().encode(chapter),
           let object = try? JSONSerialization.jsonObject(with: data) {
            context.setObject(object, forKeyedSubscript: "chapter" as NSString)
        }
        context.setObject(analyzer.baseUrl, forKeyedSubscript: "baseUrl" as NSString)
        if loadJsLib, let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
        }
        return analyzer
    }

    static func runLocalAction(
        source: BookSource, action: String?, formData: [String: String],
        book: Book? = nil, chapter: Chapter? = nil
    ) async -> ActionResult {
        await Task.detached(priority: .userInitiated) {
            evaluateLocalAction(source: source, action: action, formData: formData,
                book: book, chapter: chapter)
        }.value
    }

    /// 原版成功条件是脚本没有异常；返回 false 的脚本值本身不等于执行失败。
    static func evaluateLocalAction(
        source: BookSource, action: String?, formData: [String: String],
        book: Book? = nil, chapter: Chapter? = nil, defaults: UserDefaults = .standard
    ) -> ActionResult {
        func failure(_ message: String) -> ActionResult {
            ActionResult(success: false, message: message,
                values: loginInfoMap(source: source, persistDefaults: false, defaults: defaults))
        }
        let script = getLoginJs(source: source) ?? ""
        guard action != nil || !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return failure("未配置登录脚本")
        }
        if let action, action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return failure("未配置按钮动作")
        }
        // HTTP 登录交由页面浏览器，不能当作 JavaScript 或直接返回成功。
        let candidate = action ?? source.loginUrl ?? ""
        if browserURL(candidate) != nil { return failure("此登录动作需要浏览器") }
        guard persistLoginInfo(formData, source: source, defaults: defaults) else {
            return failure("登录信息保存失败")
        }
        let analyzer = configuredAnalyzeRule(source: source, book: book, chapter: chapter, defaults: defaults)
        defer { analyzer.releaseOwnedJSContext() }
        let context = analyzer.jsContextHandle()
        if context.exception != nil { return failure("登录脚本库执行失败") }
        injectLoginResultObject(formData, into: analyzer)
        context.setObject(false, forKeyedSubscript: "isLongClick" as NSString)
        let prefix = browserURL(source.loginUrl ?? "") == nil ? script : ""
        let suffix: String
        if let action {
            suffix = action.hasPrefix("@js:") ? String(action.dropFirst(4)) : action
        } else {
            suffix = AnalyzeRule.loginShimScript
        }
        context.exception = nil
        context.evaluateScript(prefix + "\n" + suffix)
        guard context.exception == nil else { return failure("登录动作执行失败，请检查书源脚本") }
        return ActionResult(success: true, message: nil,
            values: loginInfoMap(source: source, persistDefaults: false, defaults: defaults))
    }

    static func browserURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else { return nil }
        return url
    }

    /// AnalyzeRule 原版源桥0x1000265b0/0x10002660c，与 loginInfo_ 状态共用读写。
    static func installLoginSourceBridge(into analyzer: AnalyzeRule, source: BookSource, defaults: UserDefaults) {
        let context = analyzer.jsContextHandle()
        let getInfo: @convention(block) () -> String = {
            defaults.string(forKey: loginInfoStateKey(source: source)) ?? ""
        }
        let putInfo: @convention(block) (String) -> Bool = { json in
            guard let values = parseLoginInfoMap(from: json) else { return false }
            return persistLoginInfo(values, source: source, defaults: defaults)
        }
        let removeInfo: @convention(block) () -> Void = {
            defaults.removeObject(forKey: loginInfoStateKey(source: source))
        }
        context.setObject(getInfo, forKeyedSubscript: "_sourceGetLoginInfo" as NSString)
        context.setObject(putInfo, forKeyedSubscript: "_sourcePutLoginInfo" as NSString)
        context.setObject(removeInfo, forKeyedSubscript: "_sourceRemoveLoginInfo" as NSString)
        context.setObject(["bookSourceUrl": source.bookSourceUrl, "bookSourceName": source.bookSourceName],
            forKeyedSubscript: "source" as NSString)
        context.evaluateScript("""
        source.getLoginInfo = function() { return _sourceGetLoginInfo(); };
        source.getLoginInfoMap = function() {
            var raw = _sourceGetLoginInfo(); return raw ? JSON.parse(raw) : {};
        };
        source.putLoginInfo = function(value) {
            var raw = typeof value === 'string' ? value : JSON.stringify(value);
            if (!_sourcePutLoginInfo(raw)) { throw new Error('登录信息保存失败'); }
        };
        source.removeLoginInfo = function() { _sourceRemoveLoginInfo(); };
        """)
    }

    /// 0x1003515b4 / 0x101265500：原版 result Map 方法，不可枚举，保持 JSON 只含数据。
    static func injectLoginResultObject(_ values: [String: String], into analyzer: AnalyzeRule) {
        let context = analyzer.jsContextHandle()
        context.setObject(values, forKeyedSubscript: "result" as NSString)
        context.evaluateScript("""
        (function(target) {
            function key(k) { return k == null ? '' : String(k); }
            function value(v) { return v == null ? '' : String(v); }
            function has(k) { return Object.prototype.hasOwnProperty.call(target, k); }
            function keys() { return Object.keys(target).filter(function(k) { return typeof target[k] !== 'function'; }); }
            function define(k, fn) {
                Object.defineProperty(target, k, {value:fn, enumerable:false, configurable:true, writable:true});
            }
            define('get', function(k) { k = key(k); return has(k) ? target[k] : null; });
            define('put', function(k, v) { k = key(k); var old = has(k) ? target[k] : null; target[k] = value(v); return old; });
            define('putAll', function(map) {
                if (map && typeof map === 'object') {
                    Object.keys(map).forEach(function(k) { if (typeof map[k] !== 'function') { target[key(k)] = value(map[k]); } });
                }
                return null;
            });
            define('containsKey', function(k) { return has(key(k)); });
            define('containsValue', function(v) { v = value(v); return keys().some(function(k) { return target[k] === v; }); });
            define('remove', function(k) { k = key(k); var old = has(k) ? target[k] : null; delete target[k]; return old; });
            define('isEmpty', function() { return keys().length === 0; });
            define('size', function() { return keys().length; });
        })(result);
        """)
    }
}
