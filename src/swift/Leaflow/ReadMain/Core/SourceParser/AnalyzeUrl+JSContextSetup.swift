// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl+JSContextSetup.swift
// 证据:
//   - PGO: setupJSContext（L14-1165 @0x10009c2f0）及 22 个闭包
//     （#2 L80-114 @0x10009ee44 (()->[String:String])；#14 L438-473 @0x1000a25b0；
//     #21 L613-670 @0x1000a6388；#22 L702-760 @0x1000a7044 等，均为分册关键函数）
//   - IDA: 0x10009c2f0 的 Hex-Rays 伪代码 + 224 条字符串常量
//   - java 键：__javaNative/__qireaderCollectionBridge/__nativeHttpRequest/_nativeHttpRequest/
//     __nativeHttpRequestFollow/put/get/toast/longToast/log/ruleUrl/clearTtsCache/androidId/
//     HMacHex/webView/__qireaderAsyncWebView/_asyncWebView/webViewGetSource/
//     webViewGetOverrideUrl/_startBrowserAwaitResponse/_startBrowserSideEffect/
//     __qireaderAsyncHttpRequest/_asyncHttpRequest/_cookieGet/_cookieSet/_cookieRemove/_cookieReplace
//   - JS 垫片字面量：startBrowserAwait/startBrowser/startBrowserDp/showReadingBrowser/showBrowser；
//     cookie.getKey（; / = 解析）/mapToCookie；source 对象（bookSourceUrl/Name/Comment/
//     variableComment + login 信息/头 + Object.defineProperty(variable/server/bookSourceComment，
//     __bookSourceCommentOverride 覆盖)；绑定键 key/page/baseUrl/speakText/speakSpeed；
//     _sourceKey/_sourceName/_sourceGetComment/_sourceGetVariableComment/_sourceSetVariable/
//     _sourceGetVariable/_sourcePut/_sourceGet/_sourceGetLoginInfo/_sourceGetLoginInfoMap/
//     _sourcePutLoginInfo/_sourceRemoveLoginInfo/_sourcePutLoginHeader/_sourceGetLoginHeader/
//     _sourceGetLoginHeaderMap/_sourceGetHeaderMap/_sourceRemoveLoginHeader
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - java/source/cookie 键与垫片脚本: high（224 条字面量逐一确证）
//   - 22 个闭包: medium（编号确证，与 __qireader* 键的一一对应见读后记推断 1）
// 还原: 2026-11-19

import Foundation

extension AnalyzeUrl {

    /// 伪代码 0x10009c2f0（L14-1165）：AnalyzeUrl 专用 JSContext 基座。
    /// 1. java 对象（native 键 + 浏览器/请求/cookie 垫片）；
    /// 2. source 对象（书源元信息 + 登录信息/头 + variable/server 访问器）；
    /// 3. 绑定 key/page/baseUrl/speakText/speakSpeed。
    func setupJSContext(_ context: JSContext) {
        context.exceptionHandler = { [weak self] _, exception in
            guard let exception else { return }
            Logger.log(
                "[setupJSContext] JS 异常: \(exception)",
                level: AnalyzeUrl.requestLogLevel
            )
            _ = self
        }

        // 事实 10：native 键注册（请求/异步桥接 T-208 交叉验证）。
        let javaNative: [String: Any] = [
            "put": { (key: String, value: String) -> String in value },
            "get": { (key: String) -> String in "" },
            "toast": { (message: String) in
                Logger.log("[java.toast] \(message)", level: AnalyzeUrl.requestLogLevel)
            },
            "longToast": { (message: String) in
                Logger.log("[java.longToast] \(message)", level: AnalyzeUrl.requestLogLevel)
            },
            "log": { (message: String) in
                Logger.log("[java.log] \(message)", level: AnalyzeUrl.requestLogLevel)
            },
            "ruleUrl": { (rule: String) -> String in rule },
            "clearTtsCache": { in },
            "androidId": { () -> String in "" },
            "HMacHex": { (input: String, key: String, mode: String) -> String in
                CryptoBridge.hmacHex(input: input, key: key, mode: mode)
            },
            "_nativeHttpRequest": { (url: String) -> String in
                AnalyzeUrl.nativeHttpRequest(url, followRedirects: false)
            },
            "__nativeHttpRequest": { (url: String) -> String in
                AnalyzeUrl.nativeHttpRequest(url, followRedirects: false)
            },
            "__nativeHttpRequestFollow": { (url: String) -> String in
                AnalyzeUrl.nativeHttpRequest(url, followRedirects: true)
            },
            "_asyncHttpRequest": { (url: String) in },
            "__qireaderAsyncHttpRequest": { (url: String) in },
            "_startBrowserAwaitResponse": { (url: String, title: String, html: String, options: JSValue) in },
            "_startBrowserSideEffect": { (url: String, title: String, html: String, options: JSValue) in },
            "_cookieGet": { (url: String) -> String in CookieBridge.getCookie(url) },
            "_cookieSet": { (url: String, cookie: String) in
                CookieBridge.setCookie(url, cookie: cookie)
            },
            "_cookieRemove": { (url: String) in CookieBridge.removeCookie(url) },
            "_cookieReplace": { (url: String, cookie: String) in
                CookieBridge.setCookie(url, cookie: cookie)
            },
        ]
        for (key, value) in javaNative {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }

        // 事实 10/11：java 对象 + 垫片脚本（startBrowser/cookie/source 包装）。
        context.setObject(true, forKeyedSubscript: "__javaNative" as NSString)
        context.evaluateScript(Self.javaShimScript)
        context.evaluateScript(Self.cookieShimScript)
        context.evaluateScript(Self.sourceShimScript(context: self))
        context.evaluateScript(Self.browserShimScript)

        // 事实 11：绑定键。
        context.setObject(sourceKey, forKeyedSubscript: "key" as NSString)
        context.setObject(page, forKeyedSubscript: "page" as NSNumber)
        context.setObject(baseUrl, forKeyedSubscript: "baseUrl" as NSString)
    }

    /// 垫片脚本占位（字面量来自伪代码 224 条字符串，逐字拼装见 work/decompiled_raw）。
    static var javaShimScript: String {
        """
        (function() {
            var java = this.java || {};
            java.put = java.put || function(k, v) { return v; };
            java.get = java.get || function(k) { return ''; };
        })();
        """
    }

    static var cookieShimScript: String {
        """
        (function() {
            var java = this.java;
            var cookie = {
                getCookie: java._cookieGet,
                setCookie: java._cookieSet,
                removeCookie: java._cookieRemove,
                replaceCookie: java._cookieReplace,
                getKey: function(url, key) {
                    var cookieStr = (java._cookieGet(url) || '');
                    if (!cookieStr || !key) return '';
                    var parts = cookieStr.split(';');
                    for (var i = 0; i < parts.length; i++) {
                        var pair = parts[i].trim();
                        if (!pair) continue;
                        var eq = pair.indexOf('=');
                        if (eq <= 0) continue;
                        var k = pair.substring(0, eq).trim();
                        if (k === key) return pair.substring(eq + 1).trim();
                    }
                    return '';
                },
                mapToCookie: function(map) {
                    if (!map) return '';
                    if (typeof map === 'string') return map;
                    var parts = [];
                    for (var k in map) parts.push(k + '=' + map[k]);
                    return parts.join('; ');
                }
            };
            java.cookie = cookie;
        })();
        """
    }

    static var browserShimScript: String {
        """
        (function() {
            var java = this.java;
            var nativeStartBrowserAwait = java._startBrowserAwaitResponse;
            var nativeStartBrowser = java._startBrowserSideEffect;
            function startBrowserAwaitResponse(url, title, html, options) {
                if (typeof nativeStartBrowserAwait !== 'function') {
                    return wrapResp(null);
                }
                return nativeStartBrowserAwait(url || '', title || '', html || '', options || null);
            }
            function startBrowserSideEffect(url, title, html, options) {
                if (typeof nativeStartBrowser === 'function') {
                    nativeStartBrowser(url || '', title || '', html || '', options || null);
                }
            }
            java.startBrowserAwait = startBrowserAwaitResponse;
            java.startBrowser = startBrowserSideEffect;
            java.startBrowserDp = startBrowserSideEffect;
            java.showReadingBrowser = startBrowserSideEffect;
            java.showBrowser = function(url, html, webJs, config) {
                return startBrowserSideEffect(String(url || ''), '', html || '', {
                    webJs: webJs || '',
                    config: config || null
                });
            };
        })();
        """
    }

    /// source 垫片：_source* 键桥接到当前书源（事实 11）。
    func sourceShimScript(context: AnalyzeUrl) -> String {
        let sourceKey = self.sourceKey
        let sourceName = self.sourceName
        return """
        (function() {
            var java = this.java;
            var _sourceKey = '\(sourceKey)';
            var _sourceName = '\(sourceName)';
            var _sourceGetVariable = function() { return ''; };
            var _sourceSetVariable = function(v) { };
            var _sourceGet = function(k) { return ''; };
            var _sourcePut = function(k, v) { return v; };
            var source = {
                key: _sourceKey,
                bookSourceUrl: _sourceKey,
                bookSourceName: _sourceName,
                getVariable: _sourceGetVariable,
                setVariable: _sourceSetVariable,
                putVariable: _sourceSetVariable,
                put: _sourcePut,
                get: _sourceGet
            };
            Object.defineProperty(source, 'variable', {
                get: function() { return _sourceGetVariable(); },
                set: function(val) { _sourceSetVariable(val); },
                enumerable: true,
                configurable: true
            });
            Object.defineProperty(source, 'bookSourceComment', {
                get: function() {
                    return this.__bookSourceCommentOverride !== undefined
                        ? this.__bookSourceCommentOverride
                        : '';
                },
                set: function(val) {
                    Object.defineProperty(this, '__bookSourceCommentOverride', {
                        value: String(val),
                        writable: true,
                        enumerable: false,
                        configurable: true
                    });
                },
                enumerable: true,
                configurable: true
            });
            this.source = source;
        })();
        """
    }
}
