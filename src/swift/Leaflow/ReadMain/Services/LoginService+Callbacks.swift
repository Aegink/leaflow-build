// 原路径: ReadMain/Services/LoginService.swift
// 0x10034fe7c/0x100350db4/0x10034eee0/0x10034ef14：三个java回调、源状态合并及原版通知。
import Foundation
import JavaScriptCore

extension LoginService {
    static let dataUpdatedNotification = Notification.Name("LoginUIBridgeDataUpdated")
    static let reloadRequestedNotification = Notification.Name("LoginUIBridgeReloadRequested")

    static func installLoginUiCallbacks(
        into analyzer: AnalyzeRule, source: BookSource, defaults: UserDefaults = .standard,
        notifications: NotificationCenter = .default
    ) {
        let context = analyzer.jsContextHandle()
        let update: @convention(block) (JSValue) -> Void = { value in
            var updates: [String: String?]?
            if !value.isNull, !value.isUndefined, !value.isArray, let object = value.toDictionary() {
                updates = [:]
                for rawKey in object.keys {
                    guard let key = rawKey as? String, let member = value.objectForKeyedSubscript(key) else { continue }
                    if member.isNull || member.isUndefined { updates?[key] = .some(nil) }
                    else { updates?[key] = .some(member.toString() ?? "") }
                }
            }
            if let updates {
                var persisted = loginInfoMap(source: source, persistDefaults: false, defaults: defaults)
                for (key, value) in updates { persisted[key] = value }
                persistLoginInfo(persisted, source: source, defaults: defaults)
            }
            var info: [String: Any] = ["sourceStateKey": source.stateKey]
            if let updates { info["data"] = updates.mapValues { $0.map { $0 as Any } ?? NSNull() } }
            let payload = info
            DispatchQueue.main.async {
                notifications.post(name: dataUpdatedNotification, object: nil, userInfo: payload)
            }
        }
        let reload: @convention(block) (Bool) -> Void = { delta in
            DispatchQueue.main.async {
                notifications.post(name: reloadRequestedNotification, object: nil,
                    userInfo: ["sourceStateKey": source.stateKey, "deltaUp": delta])
            }
        }
        context.setObject(update, forKeyedSubscript: "__loginUpdateData" as NSString)
        context.setObject(reload, forKeyedSubscript: "__loginReloadView" as NSString)
        context.evaluateScript("""
        java.upLoginData = function(data) { __loginUpdateData(data); };
        java.reLoginView = function(deltaUp) { __loginReloadView(!!deltaUp); };
        java.refreshExplore = function() { __loginReloadView(false); };
        """)
    }
}
