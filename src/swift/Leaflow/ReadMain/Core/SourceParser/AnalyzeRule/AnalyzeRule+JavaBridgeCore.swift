// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JavaBridgeCore.swift
// 证据:
//   - PGO: makeJavaBridgeValue(from:) (0x100029ea4 L18-40) / makeJavaElementBridgeValue(from:) (0x10002a6b4 L58-86) / makeJavaBridgeArrayValue 及闭包
//   - CovMap: L18-40 @0x100029ea4；L58-86 @0x10002a6b4；closures @0x10002aa9c/0x10002ab4c/0x10002ac8c
//   - IDA: 上述地址
//   - 选择子：valueWithNewArrayInContext:/setValue:forProperty:/setDateFormat:/stringFromDate:/setException:/firstMatchInString:options:range:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（桥构造链确证；closure 键名见读后记推断 1）
// 还原: 2026-11-19


import Foundation

extension AnalyzeRule {

    /// 伪代码 0x100029ea4（L18-40）：java 桥根对象。
    func makeJavaBridgeValue(from element: AnalyzeRule?) -> JSValue {
        let context = jsContextHandle()
        let value = context.evaluateScript("({})") ?? JSValue(undefinedIn: context)
        value?.setObject(
            element?.contentString ?? contentString,
            forKeyedSubscript: "content" as NSString
        )
        return value ?? JSValue(undefinedIn: context)
    }

    /// 伪代码 0x10002a6b4（L58-86）：元素桥（属性访问器闭包）。
    func makeJavaElementBridgeValue(from element: AnalyzeRule?) -> JSValue {
        let context = jsContextHandle()
        let target = element ?? self
        let value = context.evaluateScript("({})") ?? JSValue(undefinedIn: context)
        // closure #1/#2（L62-67）：字符串属性访问器。
        value?.setObject({ () -> String in
            target.contentString
        }, forKeyedSubscript: "text" as NSString)
        // closure #4（L71-75）：变换访问器。
        value?.setObject({ (rule: String) -> String in
            target.getString(rule: rule, isUrl: false) ?? ""
        }, forKeyedSubscript: "getString" as NSString)
        return value ?? JSValue(undefinedIn: context)
    }

    /// 数组形态桥（closure @0x10002a99c）。
    func makeJavaBridgeArrayValue(from elements: [AnalyzeRule]) -> JSValue {
        let context = jsContextHandle()
        let array = elements.map { $0.contentString }
        return JSValue(object: array, in: context) ?? JSValue(undefinedIn: context)
    }
}

// MARK: - T-1401-10 逐域补齐（核心桥域）

extension AnalyzeRule {

    /// 伪代码 0x100029d38（L90-504）：核心桥注册——java 核心键域
    ///（open/searchBook/_rawGetString/_rawGetStringWithContent/getElements/
    /// getElement/setContent/timeFormat/hexDecodeToString/toURL/base64Encode/
    /// base64Decode/log/toast 事实 3 键族确证）——路由至既有
    /// registerJavaBridgeMethods + Cookie 桥补键。
    func registerCoreBridge() {
        registerJavaBridgeMethods()
        let context = jsContextHandle()
        let cookieBridge = JSValue(newObjectIn: context)!
        cookieBridge.setObject(
            { (url: String, name: String) -> String in
                CookieBridge.getCookie(url, name: name)
            } as @convention(block) (String, String) -> String,
            forKeyedSubscript: "getCookie" as NSString)
        cookieBridge.setObject(
            { (url: String, name: String, value: String) in
                CookieBridge.setCookie(url, name: name, value: value)
            } as @convention(block) (String, String, String) -> Void,
            forKeyedSubscript: "setCookie" as NSString)
        cookieBridge.setObject(
            { (url: String, name: String) in
                CookieBridge.removeCookie(url, name: name)
            } as @convention(block) (String, String) -> Void,
            forKeyedSubscript: "removeCookie" as NSString)
        context.setObject(
            cookieBridge, forKeyedSubscript: "cookie" as NSString)
    }
}

