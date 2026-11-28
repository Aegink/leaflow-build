// 原路径: ReadMain/Core/SourceParser/JsBridgeShared+HttpTtsSource.swift
// 0x1000f14ec与0x101259030...630：原16个绑定、源身份、Map.get、变量属性及缓存别名。
// 0x1000f2280/251c/2678：登录头规范化、按源读取及可选Cookie同步。
import Foundation
import JavaScriptCore

extension JsBridgeTemplates {
    static func registerHttpTtsSourceBridge(
        in context: JSContext, source: HttpTts, runtimeStore store: HttpTtsRuntimeStore,
        mergePersistedLoginHeader: Bool = true, synchronizeCookieHost: String? = nil,
        includeRemovalHooks: Bool = true
    ) {
        let id = source.id
        let loginInfo: @convention(block) () -> String = { store.loginInfo(sourceID: id) ?? "" }
        let loginMap: @convention(block) () -> [String: String] = { store.loginInfoMap(sourceID: id) }
        let putLogin: @convention(block) (JSValue) -> Bool = { value in
            store.setLoginInfo(ttsNullableString(value), sourceID: id)
            return true
        }
        let removeLogin: @convention(block) () -> Void = { store.setLoginInfo(nil, sourceID: id) }
        let variable: @convention(block) () -> String = { store.sourceVariable(sourceID: id) ?? "" }
        let setVariable: @convention(block) (JSValue) -> Void = { store.setSourceVariable(ttsNullableString($0), sourceID: id) }
        let get: @convention(block) (String) -> String = { store.value(for: $0, sourceID: id) ?? "" }
        let put: @convention(block) (String, String) -> String = { key, value in
            store.setValue(value, for: key, sourceID: id)
            return value
        }
        let header: @convention(block) () -> String = { store.loginHeader(sourceID: id) ?? "" }
        let headerMap: @convention(block) () -> [String: String] = {
            if mergePersistedLoginHeader { return LoginService.parseLoginHeaderMap(from: store.loginHeader(sourceID: id)) ?? [:] }
            return store.loginHeaderMap(sourceID: id)
        }
        let putHeader: @convention(block) (String) -> Void = { raw in
            if mergePersistedLoginHeader {
                let parsed = LoginService.persistedLoginHeader(incomingRawValue: raw)
                store.setLoginHeader(parsed?.storedValue, sourceID: id)
                synchronizeTtsCookie(host: synchronizeCookieHost, map: parsed?.headerMap, clear: parsed == nil)
            } else { store.setLoginHeader(raw, sourceID: id) }
        }
        let removeHeader: @convention(block) () -> Void = {
            store.setLoginHeader(nil, sourceID: id)
            synchronizeTtsCookie(host: synchronizeCookieHost, map: nil, clear: true)
        }
        let cacheGet: @convention(block) (String) -> String = { store.cacheValue(for: $0, sourceID: id) ?? "" }
        let cachePut: @convention(block) (String, String) -> String = { key, value in
            store.setCacheValue(value, for: key, sourceID: id)
            return value
        }
        let cacheDelete: @convention(block) (String) -> Void = { store.setCacheValue(nil, for: $0, sourceID: id) }
        let bindings: [String: Any] = [
            "_sourceGetLoginInfo": loginInfo, "_sourceGetLoginInfoMap": loginMap,
            "_sourcePutLoginInfo": putLogin, "_sourceRemoveLoginInfo": removeLogin,
            "_sourceGetVariable": variable, "_sourceSetVariable": setVariable,
            "_sourceGet": get, "_sourcePut": put, "_sourceGetLoginHeader": header,
            "_sourceGetLoginHeaderMap": headerMap, "_sourcePutLoginHeader": putHeader,
            "_sourceRemoveLoginHeader": removeHeader,
            "_ttsCacheGet": cacheGet, "_ttsCachePut": cachePut, "_ttsCacheDelete": cacheDelete,
            "_ttsLoginUrl": JSScriptCompatibility.sanitizeJavaScriptForCompatibility(
                source.loginUrl ?? "", convertLegadoTemplates: false)]
        for (key, value) in bindings { context.setObject(value, forKeyedSubscript: key as NSString) }
        // 身份用原版字符串前缀，额外保留已有请求样本消费的id/name/url别名。
        context.setObject(["key": "httpTts_\(id)", "bookSourceUrl": "httpTts_\(id)",
            "bookSourceName": source.name, "bookSourceComment": "", "variableComment": "",
            "id": id, "name": source.name, "url": source.url] as [String: Any], forKeyedSubscript: "source" as NSString)
        context.evaluateScript("""
        var cache = {get: _ttsCacheGet, put: _ttsCachePut, getFile: _ttsCacheGet,
            putFile: _ttsCachePut, delete: _ttsCacheDelete};
        source.loginUrl = _ttsLoginUrl;
        source.getKey = function() { return this.key; };
        source.getVariable = _sourceGetVariable;
        source.setVariable = source.putVariable = _sourceSetVariable;
        source.getLoginInfo = _sourceGetLoginInfo;
        source.putLoginInfo = _sourcePutLoginInfo;
        source.getLoginInfoMap = function() {
            var obj = _sourceGetLoginInfoMap();
            obj.get = function(k) { return Object.prototype.hasOwnProperty.call(this, String(k)) ? this[String(k)] : null; };
            return obj;
        };
        source.getLoginHeader = _sourceGetLoginHeader;
        source.putLoginHeader = _sourcePutLoginHeader;
        source.getLoginHeaderMap = function() {
            var obj = _sourceGetLoginHeaderMap();
            obj.get = function(k) { return Object.prototype.hasOwnProperty.call(this, String(k)) ? this[String(k)] : null; };
            return obj;
        };
        source.put = _sourcePut;
        source.get = _sourceGet;
        Object.defineProperty(source, 'variable', {
            get: _sourceGetVariable, set: _sourceSetVariable, enumerable: true, configurable: true
        });
        """)
        if includeRemovalHooks {
            context.evaluateScript("source.removeLoginInfo = _sourceRemoveLoginInfo; source.removeLoginHeader = _sourceRemoveLoginHeader;")
        }
    }

    private static func ttsNullableString(_ value: JSValue) -> String? {
        value.isNull || value.isUndefined ? nil : value.toString()
    }

    private static func synchronizeTtsCookie(host: String?, map: [String: String]?, clear: Bool) {
        guard let host, !host.isEmpty else { return }
        if clear { CookiePersistenceService.shared.removeCookies(for: host); return }
        guard let cookie = LoginService.headerValue(in: map ?? [:], named: "Cookie"), !cookie.isEmpty else { return }
        let values = cookie.split(separator: ";").compactMap { field -> HTTPCookie? in
            let pair = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return nil }
            return HTTPCookie(properties: [.domain: host, .path: "/",
                .name: pair[0].trimmingCharacters(in: .whitespaces), .value: String(pair[1])])
        }
        CookiePersistenceService.shared.saveResponseCookies(values, for: host)
    }
}
