// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JavaBridge.swift
// 证据:
//   - PGO: currentJavaBridgeRefreshSignature 闭包族 + login 垫片 + java 方法键注册（51 函数）
//   - CovMap: L15-15 闭包族（8+ ICF 地址副本 0x1000234b4…0x100036ea4 —— 归组噪声）
//   - IDA: 上述地址
//   - 160 条字面量：login 垫片 if(typeof login=='function'){…}throw('Function login not implements!!!')；java 键 open/searchBook/_rawGetString/_rawGetStringWithContent/getElements/getElement/setContent/timeFormat/hexDecodeToString/toURL/base64Encode/base64Decode/log/toast
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（键族与垫片确证；50+ 方法闭包映射见读后记仍不清楚）
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

extension AnalyzeRule {

    /// login 垫片（事实 3 字面量）。
    static let loginShimScript = """
        if(typeof login=='function'){
            login.apply(this);
        } else {
            throw('Function login not implements!!!');
        }
        """

    /// java 方法键注册（事实 3 键族）。
    func registerJavaBridgeMethods() {
        let context = jsContextHandle()
        let methods: [String: Any] = [
            "open": { (url: String) in
                JSOpenBridge.post(name: "url", url: url, title: nil, options: nil)
            },
            "searchBook": { (keyword: String) -> String in
                ""
            },
            "_rawGetString": { (rule: String) -> String in
                self.getString(rule: rule, isUrl: false) ?? ""
            },
            "_rawGetStringWithContent": { (rule: String, content: String) -> String in
                self.getString(rule: rule, isUrl: false) ?? content
            },
            "getElements": { (rule: String) -> [String] in
                self.getElementsSingle(rule: rule).map { $0.contentString }
            },
            "getElement": { (rule: String) -> String in
                self.getElement(rule: rule) as? String ?? ""
            },
            "setContent": { (content: String) -> String in
                self.setContent(content, baseUrl: self.baseUrl)
                return content
            },
            "timeFormat": { (timestamp: Int64) -> String in
                let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter.string(from: date)
            },
            "hexDecodeToString": { (input: String) -> String in
                JsExtensions().hexDecode(input)
            },
            "toURL": { (path: String) -> String in
                self.formatUrl(path)
            },
            "base64Encode": { (input: String) -> String in
                Data(input.utf8).base64EncodedString()
            },
            "base64Decode": { (input: String) -> String in
                Data(base64Encoded: input).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            },
            "log": { (message: String) in
                Logger.log("[java.log] \(message)", level: .warning)
            },
            "toast": { (message: String) in
                JSToastBridge.post(message, isLong: false)
            },
        ]
        for (key, value) in methods {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
    }

    /// login 上下文（垫片在登录型规则执行前 evaluate）。
    func evaluateLoginIfNeeded() {
        let context = jsContextHandle()
        context.exception = nil
        context.evaluateScript(Self.loginShimScript)
    }

    /// 刷新签名（currentJavaBridgeRefreshSignature 的字符串载体）。
    var javaBridgeRefreshSignature: String {
        "\(ObjectIdentifier(self).hashValue)|\(baseUrl)|\(sourceKey ?? "")"
    }
}

// MARK: - T-1401-10 逐域补齐（源桥装配域）

extension AnalyzeRule {

    /// 伪代码 0x100023b64（L80-496）：源桥装配总入口——网络/加密/Cookie/
    /// 工具/Java 对象五桥注册编排（块体为逐函数 setObject:forKeyedSubscript
    /// 长链，模块桥路由还原）。
    func installSourceBridgeBindings() {
        let context = jsContextHandle()
        registerNetworkBridge()
        registerCryptoBridge()
        registerCoreBridge()
        JsBridgeTemplates.registerSymmetricCryptoBridge(in: context)
        JsBridgeTemplates.installEncodeURIBridge(in: context)
        JsBridgeTemplates.registerUtilBridge(in: context)
        setupJavaObject()
        registerJavaBridgeMethods()
    }

    /// 伪代码 0x1000272d8（L498-613）：java 对象装配——java 键域方法表
    ///（JavaBridge/CookieBridge 静态域路由）。
    func setupJavaObject() {
        let context = jsContextHandle()
        let java: [String: Any] = [
            // T-1601-B3：ajax 单请求（legado 源常用入口）。
            "ajax": { (url: String) -> String in
                JavaBridge.ajax(url)
            },
            // java.get/put 为**变量域**（JavaBridge 签名 + inout 字典闭包确证）。
            "get": { (key: String) -> String in
                JavaBridge.get(key)
            },
            "put": { (key: String, value: String) -> String in
                JavaBridge.put(key, value)
            },
            "ajaxAll": { (urls: [String]) -> [String] in
                JavaBridge.ajaxAll(urls)
            },
            "post": { (url: String, body: String, headers: [String: String]) -> String in
                JavaBridge.post(url, body: body, headers: headers)
            },
            "connect": { (url: String, body: String, headers: [String: String]) -> String in
                JavaBridge.connect(url, body: body, headers: headers)
            },
            // 注意：java.put 为变量域（上方已注册）；HTTP PUT 无独立键，
            // 字典字面量不可重复键（run11 Fatal error 根因）。
            "md5Encode": { (input: String) -> String in
                JavaBridge.md5Encode(input)
            },
            "log": { (message: String) in
                JavaBridge.log(message)
            },
            "timeFormat": { (timestamp: Int64) -> String in
                JavaBridge.timeFormat(timestamp)
            },
            "timeFormatUTC": { (timestamp: Int64, format: String, offset: Int) -> String in
                JavaBridge.timeFormatUTC(timestamp, format, offset)
            },
            "base64Encode": { (input: String) -> String in
                JavaBridge.base64Encode(input)
            },
            "base64Decode": { (input: String) -> String in
                Data(base64Encoded: input)
                    .flatMap { String(data: $0, encoding: .utf8) } ?? ""
            },
            // T-1601-B3：cookie.*（CookieBridge get/set/remove 域）。
            "getCookie": { (url: String, name: String) -> String in
                CookieBridge.getCookie(url, name: name)
            },
            "setCookie": { (url: String, name: String, value: String) in
                CookieBridge.setCookie(url, name: name, value: value)
            },
            "removeCookie": { (url: String, name: String) in
                CookieBridge.removeCookie(url, name: name)
            },
            "hexDecodeToString": { (input: String) -> String in
                JavaBridge.hexDecodeToString(input)
            },
            "aesBase64DecodeToString": { (data: String, key: String, iv: String, mode: String) -> String in
                JavaBridge.aesBase64DecodeToString(data, key: key, iv: iv, transformer: mode)
            },
            "aesEncodeToString": { (data: String, key: String, iv: String, mode: String) -> String in
                JavaBridge.aesEncodeToString(data, key: key, iv: iv, transformer: mode)
            },
        ]
        let bridgeObject = JSValue(newObjectIn: context)!
        for (key, value) in java {
            bridgeObject.setObject(value, forKeyedSubscript: key as NSString)
        }
        context.setObject(bridgeObject, forKeyedSubscript: "java" as NSString)
    }
}

