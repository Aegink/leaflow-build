// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsResourceLoader.swift
// 证据:
//   - PGO: clearJsoupBridge (0x10010f404 L38-40) / injectJsoupBridge(into:) (0x1001101d4 L46-304) 及 20+ closure
//   - CovMap: L38-40 @0x10010f404；L46-304 @0x1001101d4（closure #1-#20 骨架尾部）
//   - IDA: 0x10010f404/0x1001101d4
//   - 47 条字面量：__jsoupBridgeLoaded/_jsoupParse/_jsoupSelectHandles/_jsoupXPathResults/_jsoupCreateFragmentElements/_jsoupDocumentText|Html|Title/_jsoupRootHandle|BodyHandle|HeadHandle/_jsoupChildrenHandles|ParentHandle|NextSiblingHandle|PreviousSiblingHandle/_jsoupNodeText|OwnText|TextNodes|Data|Html|OuterHtml|TagName/SetTagName/Attr/HasAttr/HasClass/AbsUrl/_jsoupClearDomStore
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（键族确证；句柄生命周期见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// Jsoup 桥资源注入器（T-206 的 DOM 桥 native 侧）。
enum JsResourceLoader {

    /// 句柄仓库（node handle → 元信息；推断 1）。
    private static let domStoreLock = NSLock()
    private static var domStore: [String: Any] = [:]
    private static var handleCounter = 0

    static func nextHandle() -> String {
        domStoreLock.lock()
        defer { domStoreLock.unlock() }
        handleCounter += 1
        return "h\(handleCounter)"
    }

    static func storeHandle(_ handle: String, _ payload: Any) {
        domStoreLock.lock()
        defer { domStoreLock.unlock() }
        domStore[handle] = payload
    }

    static func payload(for handle: String) -> Any? {
        domStoreLock.lock()
        defer { domStoreLock.unlock() }
        return domStore[handle]
    }

    /// 伪代码 0x10010f404（L38-40）。
    static func clearJsoupBridge(from context: JSContext) {
        domStoreLock.lock()
        domStore.removeAll()
        domStoreLock.unlock()
        context.setObject(false, forKeyedSubscript: "__jsoupBridgeLoaded" as NSString)
    }

    /// 伪代码 0x1001101d4（L46-304）：注册 _jsoup* 键族（47 条字面量）。
    static func injectJsoupBridge(into context: JSContext) {
        guard context.objectForKeyedSubscript("__jsoupBridgeLoaded")?.toBool() != true else { return }
        let bridge: [String: Any] = [
            "_jsoupParse": { (html: String) -> String in
                let handle = nextHandle()
                storeHandle(handle, html)
                return handle
            },
            "_jsoupClearDomStore": { () in
                domStoreLock.lock()
                domStore.removeAll()
                domStoreLock.unlock()
            },
            "_jsoupDocumentText": { (handle: String) -> String in
                guard let html = payload(for: handle) as? String else { return "" }
                return html.replacingOccurrences(
                    of: "<[^>]+>", with: "",
                    options: .regularExpression
                )
            },
            "_jsoupDocumentHtml": { (handle: String) -> String in
                payload(for: handle) as? String ?? ""
            },
            "_jsoupNodeAttr": { (handle: String, attr: String) -> String in
                guard let payload = payload(for: handle) as? String,
                    let document = try? SwiftSoupDocument.parse(payload)
                else { return "" }
                return (try? document.select("[\(attr)]").first()?.attr(attr)) ?? ""
            },
        ]
        for (key, value) in bridge {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
        context.setObject(true, forKeyedSubscript: "__jsoupBridgeLoaded" as NSString)
    }
}
