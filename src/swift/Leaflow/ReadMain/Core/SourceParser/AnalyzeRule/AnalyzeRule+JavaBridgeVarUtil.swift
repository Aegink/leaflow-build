// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JavaBridgeVarUtil.swift
// 证据:
//   - PGO: registerVarUtilBridge (0x100040dc0 L15-651) 及 closure #1/#3/#4
//   - CovMap: L15-651 @0x100040dc0；closures @0x100040e8c/0x100041040/0x100041a38
//   - IDA: 上述地址
//   - 会话配置选择子族（与 T-203-02 ephemeral 会话同构）；sleepForTimeInterval:；线程亲和 currentThread/threadDictionary
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（注册链确证；30+ closure 键映射见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

extension AnalyzeRule {

    /// 伪代码 0x100040dc0（L15-651）：变量/工具桥主注册。
    func registerVarUtilBridge() {
        let context = jsContextHandle()
        let varUtil: [String: Any] = [
            "putVariable": { (key: String, value: String) in
                self.putVariable(key, value: value)
            },
            "getVariable": { (key: String) -> String in
                self.getVariable(key) ?? ""
            },
            "getSource": { () -> String in
                self.sourceKey ?? ""
            },
            "sleepMillis": { (millis: Double) in
                Thread.sleep(forTimeInterval: millis / 1000.0)
            },
            "encodeURI": { (text: String) -> String in
                JsBridgeTemplates.makeEncodeURIBlock()(text)
            },
            "decodeURI": { (text: String) -> String in
                text.removingPercentEncoding ?? text
            },
            "strToBytes": { (text: String) -> [Int] in
                Array(text.utf8).map { Int($0) }
            },
            "bytesToStr": { (bytes: [Int]) -> String in
                String(bytes: bytes.compactMap { UInt8(exactly: $0) }, encoding: .utf8) ?? ""
            },
        ]
        for (key, value) in varUtil {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
    }
}
