// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsBridgeShared.swift
// 证据:
//   - PGO: JSPromiseBridge.SettlementLane(init/register/resolve×2/reject/settle/invalidate)/httpPayloadJSON
//   - CovMap: SettlementLane.init L544-548 @0x1000f120c；register L550-566 @0x1000efe44；resolve(payloadJSON) L568-570 @0x100040aa4；resolve(value) L572-574 @0x100042cb8/0x1000a39d4；reject L576-578 @0x1000f0c00；settle L584-594 @0x1000f0cc4；invalidate closure L597 @0x1000f1220；httpPayloadJSON L619-640 @0x1000f00c4
//   - IDA: 上述地址
//   - 选择子：valueWithNewObjectInContext:/setValue:forProperty:/valueForProperty:/deleteProperty:/callWithArguments:/globalObject/statusCode/URL/localizedStringForStatusCode:/dataWithJSONObject:options:error:/allHeaderFields
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（Promise 结算通道确证）
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

/// JS Promise 桥（java.ajax 等异步返回的结算通道）。
final class JSPromiseBridge {

    /// 伪代码 SettlementLane（L544-597）：按 id 结算。
    final class SettlementLane {
        private let context: JSContext
        private var lanes: [String: (resolve: JSValue, reject: JSValue)] = [:]
        private let lock = NSLock()

        init(context: JSContext) {
            self.context = context
        }

        /// 伪代码 0x1000efe44（L550-566）。
        func register(resolve: JSValue, reject: JSValue) -> String {
            let id = UUID().uuidString
            lock.lock()
            lanes[id] = (resolve, reject)
            lock.unlock()
            return id
        }

        /// 伪代码 0x100040aa4（L568-570）。
        func resolve(_ id: String, payloadJSON: String) {
            let value = context.evaluateScript("(\(payloadJSON))")
            resolve(id, value: value)
        }

        /// 伪代码 0x100042cb8（L572-574）。
        func resolve(_ id: String, value: JSValue?) {
            settle(id) { lane in
                lane.resolve.call(withArguments: [value ?? NSNull()])
            }
        }

        /// 伪代码 0x1000f0c00（L576-578）。
        func reject(_ id: String, error: Error) {
            settle(id) { lane in
                lane.reject.call(withArguments: [String(describing: error)])
            }
        }

        /// 伪代码 0x1000f0cc4（L584-594，closure @0x1000f0f0c @Sendable）。
        private func settle(_ id: String, body: @escaping ((resolve: JSValue, reject: JSValue)) -> Void) {
            lock.lock()
            let lane = lanes.removeValue(forKey: id)
            lock.unlock()
            guard let lane else { return }
            DispatchQueue.global().async { body(lane) }
        }

        /// 伪代码 0x1000f1220（L597）：失效判定。
        var isEmpty: Bool {
            lock.lock()
            defer { lock.unlock() }
            return lanes.isEmpty
        }
    }

    /// 伪代码 0x1000f00c4（L619-640）：HTTP payload JSON 化。
    static func httpPayloadJSON(data: Data, response: URLResponse?) -> String {
        let http = response as? HTTPURLResponse
        let payload: [String: Any] = [
            "body": String(decoding: data, as: UTF8.self),
            "code": http?.statusCode ?? 0,
            "message": http.map { HTTPURLResponse.localizedString(forStatusCode: $0.statusCode) } ?? "",
            "headers": (http?.allHeaderFields as? [String: String]) ?? [:],
        ]
        guard JSONSerialization.isValidJSONObject(payload),
            let encoded = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let text = String(data: encoded, encoding: .utf8)
        else { return "{}" }
        return text
    }
}
