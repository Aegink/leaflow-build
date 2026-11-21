// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JsStubs.swift
// 证据:
//   - PGO: jsBookVariableValue(LL) / bookVariableForJavaScript(LL) / putBookVariableFromJavaScript(LL) /
//     ensureWrapRespFunctionInstalled / currentBookBridgeState(LL) / currentChapterBridgeState(LL) /
//     installDynamicBookAndChapterBridgeBlocks(LL) 及 8 闭包 / installBookObjectShell(LL) /
//     installChapterObjectShell(LL) / hasBookBridgeMethods(LL) / syncBookObject(LL) /
//     syncChapterObject(LL) / installCookieBridgeBindings 及 2 闭包 / refreshSelfBridgeBlocks 及闭包 /
//     refreshSourceAndSelfMethods
//   - CovMap: jsBookVariableValue L22-32 @0x10005b38c；bookVariableForJavaScript L34-38 @0x10005b634；
//     putBookVariableFromJavaScript L40-44 @0x10005c534；ensureWrapRespFunctionInstalled L60-65
//     @0x10005b330；currentBookBridgeState L67-82 @0x10005cc44；installDynamicBookAndChapterBridgeBlocks
//     L111-152 @0x10005d678（闭包 #1-#8）；installBookObjectShell L154-256 @0x10005db60；
//     installChapterObjectShell L258-307 @0x10005e7cc；hasBookBridgeMethods L336-349 @0x10005ecd4；
//     syncBookObject L369-486 @0x10005eee0；syncChapterObject L488-536 @0x10005ff48；
//     installCookieBridgeBindings 闭包 L564-569；refreshSelfBridgeBlocks L594-652 @0x10005afe0；
//     refreshSourceAndSelfMethods L656-663 @0x10005abe8
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - 守护键：__bookObjectSignature/__bookState/__chapterObjectSignature/__chapterState
//   - 桥键：getVariable/putVariable/isVip/chapter/java/_rawGetString/_rawGetStringWithContent/
//     getElements/setContent/put/_varGet
//   - 归组噪声：0x1000b99ac…0x100885f7c 的 17 个 closure#5 地址副本、
//     [PARA-CMT-*]/[QDReaderTrace]/[远程后端] 等他文件字符串（读后记事实 22/23）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - syncBookObject: high（签名守护链逐条对应；book 字段集合见推断 4）
//   - installBookObjectShell / installChapterObjectShell / syncChapterObject: medium-high
//     （shell 属性集合按惯例推断，见推断 5）
//   - installDynamicBookAndChapterBridgeBlocks / refreshSelfBridgeBlocks: medium-high（闭包清单可见）
//   - Cookie 桥: high（键名逐一可见）
// 依赖: JSContextPool（T-204）、Book/BookChapter（T-601）、CookieBridge（T-208）。
// 还原: 2026-11-18

import Foundation
import JavaScriptCore

extension AnalyzeRule {

    // MARK: - book / chapter 变量

    /// 伪代码 0x10005b38c（L22-32）：JSValue → book 变量字符串。
    func jsBookVariableValue(_ value: JSValue) -> String? {
        value.toString().flatMap { $0.isEmpty ? nil : $0 }
    }

    /// 伪代码 0x10005b634（L34-38）：`book.getVariable(name)` → getVariable。
    func bookVariableForJavaScript(_ name: String) -> String? {
        getVariable(name)
    }

    /// 伪代码 0x10005c534（L40-44）：`book.putVariable(name, value)` → 存变量。
    func putBookVariableFromJavaScript(_ name: String, _ value: JSValue) {
        guard let string = value.toString() else { return }
        putVariable(name, value: string)
    }

    // MARK: - book / chapter 对象 shell 与同步

    /// 伪代码 0x10005db60（L154-256）：`book` 对象 shell 安装（force 重装）。
    /// shell 属性集合按 Legado book 对象惯例（推断 5）。
    func installBookObjectShell(force: Bool) -> String {
        let context = Self.jsContextHandle()
        JSContextPool.warmup(count: context)
        let installed = context.objectForKeyedSubscript("__bookObjectSignature")?.toString()
        if !force, installed != nil {
            return installed!
        }
        let bookObject: [String: Any] = [
            "name": book?.name ?? "",
            "author": book?.author ?? "",
            "kind": book?.kind ?? "",
            "lastChapter": book?.lastChapter ?? "",
            "origin": book?.origin ?? "",
            "bookUrl": book?.bookUrl ?? "",
            "tocUrl": book?.tocUrl ?? "",
            "getVariable": { [weak self] (name: String) -> String? in
                self?.bookVariableForJavaScript(name)
            },
            "putVariable": { [weak self] (name: String, value: JSValue) in
                self?.putBookVariableFromJavaScript(name, value)
            },
            "isVip": false,
        ]
        context.setObject(bookObject, forKeyedSubscript: "book" as NSString)
        let signature = "book|\(book?.name ?? "")|\(book?.bookUrl ?? "")"
        context.setObject(signature, forKeyedSubscript: "__bookObjectSignature" as NSString)
        return signature
    }

    /// 伪代码 0x10005e7cc（L258-307）：`chapter` 对象 shell 安装。
    func installChapterObjectShell(force: Bool) -> String {
        let context = Self.jsContextHandle()
        JSContextPool.warmup(count: context)
        let installed = context.objectForKeyedSubscript("__chapterObjectSignature")?.toString()
        if !force, installed != nil {
            return installed!
        }
        let chapterObject: [String: Any] = [
            "title": currentChapter?.title ?? "",
            "url": currentChapter?.url ?? "",
            "index": currentChapter?.index ?? 0,
            "getVariable": { [weak self] (name: String) -> String? in
                self?.getVariable(name)
            },
            "putVariable": { [weak self] (name: String, value: String) in
                self?.putVariable(name, value: value)
            },
        ]
        context.setObject(chapterObject, forKeyedSubscript: "chapter" as NSString)
        let signature = "chapter|\(currentChapter?.url ?? "")|\(currentChapter?.index ?? -1)"
        context.setObject(signature, forKeyedSubscript: "__chapterObjectSignature" as NSString)
        return signature
    }

    /// 伪代码 0x10005eee0（L369-486）：book 状态同步。
    /// 非 force 且 `__bookObjectSignature` 未变且 javaBridge 刷新签名未变 → 早退；
    /// 否则重建 shell 并写入 `__bookState`。
    func syncBookObject(force: Bool) {
        let signature = installBookObjectShell(force: force)
        let context = Self.jsContextHandle()
        JSContextPool.warmup(count: context)
        if !force {
            if let existing = context.objectForKeyedSubscript("__bookObjectSignature")?
                .toString(), existing == signature,
                Self.currentJavaBridgeRefreshSignatureUnchanged() {
                return
            }
        }
        let state = currentBookBridgeState()
        context.setObject(state, forKeyedSubscript: "__bookState" as NSString)
        context.setObject(signature, forKeyedSubscript: "__bookObjectSignature" as NSString)
    }

    /// 伪代码 0x10005ff48（L488-536）：chapter 状态同步（同构）。
    func syncChapterObject(force: Bool) {
        let signature = installChapterObjectShell(force: force)
        let context = Self.jsContextHandle()
        JSContextPool.warmup(count: context)
        if !force {
            if let existing = context.objectForKeyedSubscript("__chapterObjectSignature")?
                .toString(), existing == signature,
                Self.currentJavaBridgeRefreshSignatureUnchanged() {
                return
            }
        }
        let state = currentChapterBridgeState()
        context.setObject(state, forKeyedSubscript: "__chapterState" as NSString)
        context.setObject(signature, forKeyedSubscript: "__chapterObjectSignature" as NSString)
    }

    /// 伪代码 0x10005cc44（L67-82）：book 桥状态字典。
    func currentBookBridgeState() -> [String: Any] {
        [
            "name": book?.name ?? "",
            "author": book?.author ?? "",
            "bookUrl": book?.bookUrl ?? "",
            "tocUrl": book?.tocUrl ?? "",
        ]
    }

    /// 伪代码（currentChapterBridgeState 同区段）：chapter 桥状态字典。
    func currentChapterBridgeState() -> [String: Any] {
        [
            "title": currentChapter?.title ?? "",
            "url": currentChapter?.url ?? "",
            "index": currentChapter?.index ?? -1,
        ]
    }

    /// 伪代码 0x10005ecd4（L336-349）：book 桥方法是否已挂。
    func hasBookBridgeMethods() -> Bool {
        let context = Self.jsContextHandle()
        return context.objectForKeyedSubscript("book") != nil
    }

    // MARK: - 动态桥

    /// 伪代码 0x10005d678（L111-152）：动态注册 book/chapter 桥闭包（事实 21）。
    /// 闭包 #1-#8 与伪代码一一对应；键集来自字符串常量表。
    func installDynamicBookAndChapterBridgeBlocks() {
        let context = Self.jsContextHandle()
        JSContextPool.warmup(count: context)

        // 闭包 #1（L118-120）：AnalyzeRule 提供者。
        context.setObject({ [weak self] () -> AnalyzeRule? in self },
                          forKeyedSubscript: "__currentAnalyzer" as NSString)
        // 闭包 #2（L122-124）：NSDictionary 状态。
        context.setObject({ [weak self] () -> NSDictionary in
            (self?.currentBookBridgeState() ?? [:]) as NSDictionary
        }, forKeyedSubscript: "__bookState" as NSString)
        // 闭包 #3（L125-127）：getString 变换。
        context.setObject({ [weak self] (rule: String) -> String in
            self?.getString(rule: rule, isUrl: false) ?? ""
        }, forKeyedSubscript: "_rawGetString" as NSString)
        // 闭包 #4（L128-130）：(String, JSValue) -> () put。
        context.setObject({ [weak self] (name: String, value: JSValue) in
            self?.putBookVariableFromJavaScript(name, value)
        }, forKeyedSubscript: "_varPut" as NSString)
        // 闭包 #5（L131-133）：状态串。
        context.setObject({ [weak self] () -> String in
            self?.currentChapter?.title ?? ""
        }, forKeyedSubscript: "__chapterTitle" as NSString)
        // 闭包 #6（L134-136）：NSDictionary chapter 状态。
        context.setObject({ [weak self] () -> NSDictionary in
            (self?.currentChapterBridgeState() ?? [:]) as NSDictionary
        }, forKeyedSubscript: "__chapterState" as NSString)
        // 闭包 #7（L137-139）：(String, String) -> () putPair。
        context.setObject({ [weak self] (name: String, value: String) in
            self?.putVariable(name, value: value)
        }, forKeyedSubscript: "putVariable" as NSString)
        // 闭包 #8（L140-142）：(String) -> String。
        context.setObject({ [weak self] (name: String) -> String in
            self?.getVariable(name) ?? ""
        }, forKeyedSubscript: "getVariable" as NSString)

        syncBookObject(force: false)
        syncChapterObject(force: false)
    }

    /// 伪代码 0x10005b330（L60-65）：wrapResp 函数确保安装。
    func ensureWrapRespFunctionInstalled() {
        let context = Self.jsContextHandle()
        if context.objectForKeyedSubscript("__wrapResp") != nil {
            return
        }
        context.evaluateScript(
            "function __wrapResp(value) { return value; }"
        )
    }

    // MARK: - Cookie 桥

    /// 伪代码（installCookieBridgeBindings 闭包 #1/#2，L564-569）：
    /// `cookie.get(key)` / `cookie.set(key, value)`（事实 8 的键族）。
    /// CookieBridge 为 (url:name:) 域 API——JS 契约是整域读取/整串写入
    /// （legado java.cookie 域，wave-16）。
    func installCookieBridgeBindings() {
        let context = Self.jsContextHandle()
        let cookieObject: [String: Any] = [
            "getCookie": { (url: String) -> String in
                guard let target = URL(string: url) else { return "" }
                let cookies = HTTPCookieStorage.shared.cookies(for: target) ?? []
                return cookies.map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")
            },
            "setCookie": { (url: String, value: String) in
                for pair in value.split(separator: ";") {
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    guard kv.count == 2 else { continue }
                    CookieBridge.setCookie(
                        url,
                        name: kv[0].trimmingCharacters(in: .whitespaces),
                        value: String(kv[1]))
                }
            },
            "removeCookie": { (url: String) in
                guard let target = URL(string: url) else { return }
                for cookie in HTTPCookieStorage.shared.cookies(for: target) ?? [] {
                    CookieBridge.removeCookie(url, name: cookie.name)
                }
            },
            "replaceCookie": { (url: String, value: String) in
                for pair in value.split(separator: ";") {
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    guard kv.count == 2 else { continue }
                    CookieBridge.setCookie(
                        url,
                        name: kv[0].trimmingCharacters(in: .whitespaces),
                        value: String(kv[1]))
                }
            },
            "putCookie": { (url: String, value: String) in
                for pair in value.split(separator: ";") {
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    guard kv.count == 2 else { continue }
                    CookieBridge.setCookie(
                        url,
                        name: kv[0].trimmingCharacters(in: .whitespaces),
                        value: String(kv[1]))
                }
            },
        ]
        context.setObject(cookieObject, forKeyedSubscript: "cookie" as NSString)
    }

    // MARK: - 自桥刷新

    /// 伪代码 0x10005afe0（L594-652）：自桥闭包刷新（事实 22）。
    func refreshSelfBridgeBlocks() {
        let context = Self.jsContextHandle()
        JSContextPool.warmup(count: context)

        // 闭包 #1（L597-604）：getString。
        context.setObject({ [weak self] (rule: String) -> String in
            self?.getString(rule: rule, isUrl: false) ?? ""
        }, forKeyedSubscript: "getString" as NSString)
        // 闭包 #2（L607-614）：get + 环境展开。
        context.setObject({ [weak self] (rule: String, content: String) -> String in
            self?.getString(rule: rule, isUrl: false) ?? content
        }, forKeyedSubscript: "_rawGetStringWithContent" as NSString)
        // 闭包 #3（L617-627）：getElements。
        context.setObject({ [weak self] (rule: String) -> [Any] in
            guard let self else { return [] }
            return self.getElementsSingle(rule: rule).map { $0.contentString }
        }, forKeyedSubscript: "getElements" as NSString)
        // 闭包 #5（L642-645）：setContent。
        context.setObject({ [weak self] (content: String, baseUrl: String) -> String in
            self?.setContent(content, baseUrl: baseUrl)
            return content
        }, forKeyedSubscript: "setContent" as NSString)
        // `put`（事实 21 键集）。
        context.setObject({ [weak self] (name: String, value: String) in
            self?.putVariable(name, value: value)
        }, forKeyedSubscript: "put" as NSString)

        ensureWrapRespFunctionInstalled()
        refreshSourceAndSelfMethods()
    }

    /// 伪代码 0x10005abe8（L656-663）：源级与自级方法刷新。
    func refreshSourceAndSelfMethods() {
        let context = Self.jsContextHandle()
        context.setObject({ [weak self] () -> NSDictionary in
            (self?.currentBookBridgeState() ?? [:]) as NSDictionary
        }, forKeyedSubscript: "java" as NSString)
    }
}

// MARK: - 自桥刷新去重（wave-16 补桥）

extension AnalyzeRule {

    /// currentJavaBridgeRefreshSignatureUnchanged()（syncBookObject/
    /// syncChapterObject 去重域确证）。刷新签名缓存域未还原——恒 false
    /// （每次全量重建桥对象），记入仍不清楚。
    static func currentJavaBridgeRefreshSignatureUnchanged() -> Bool {
        false
    }
}
