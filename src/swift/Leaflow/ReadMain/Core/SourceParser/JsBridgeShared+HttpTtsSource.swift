// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsBridgeShared+HttpTtsSource.swift
// 证据:
//   - PGO: registerHttpTtsSourceBridge(in:source:) 及 closure #2/#3/#5/#6/#7/#10/#11/#12/#14/#15
//   - CovMap: L16-169 @0x1000f14ec；closures @0x1000f20cc/0x1000f212c/0x1000f2910/0x1000f294c/0x1000f297c/0x1000f2280/0x1000f2678/0x1000f2a48/0x1000f2874/0x1000f1f50
//   - IDA: 上述地址
//   - TTS 源桥 16 键：_sourceGetLoginInfo/_sourceGetLoginInfoMap/_sourcePutLoginInfo/_sourceRemoveLoginInfo/_sourceSetVariable/_sourceGetVariable/_sourcePut/_sourceGet/_sourceGetLoginHeader/_sourcePutLoginHeader/_sourceGetLoginHeaderMap/_sourceRemoveLoginHeader/_ttsLoginUrl/_ttsCacheGet/_ttsCachePut/_ttsCacheDelete（与 T-203-02 source 垫片一一对应）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（16 键确证；_ttsLoginUrl 结构见读后记仍不清楚 2）
// 还原: 2026-11-19


import Foundation

extension JsBridgeTemplates {

    /// 伪代码 0x1000f14ec（L16-169）：TTS 源桥注册。
    static func registerHttpTtsSourceBridge(
        in context: JSContext,
        source: BookSource?
    ) {
        let analyzer = AnalyzeRule.sharedInstance()
        let bridge: [String: Any] = [
            // closure（L23-25 区域族）：source 变量读写。
            "_sourceGetVariable": { () -> String in
                analyzer.getVariable("ttsVariable") ?? ""
            },
            "_sourceSetVariable": { (value: String) in
                analyzer.putVariable("ttsVariable", value: value)
            },
            "_sourcePut": { (key: String, value: String) -> String in
                analyzer.putVariable(key, value: value)
                return value
            },
            "_sourceGet": { (key: String) -> String in
                analyzer.getVariable(key) ?? ""
            },
            // 登录信息/头族。
            "_sourceGetLoginInfo": { (key: String) -> String in
                analyzer.getVariable("loginInfo_\(key)") ?? ""
            },
            "_sourceGetLoginInfoMap": { () -> [String: String] in
                [:]
            },
            "_sourcePutLoginInfo": { (key: String, value: String) in
                analyzer.putVariable("loginInfo_\(key)", value: value)
            },
            "_sourceRemoveLoginInfo": { (key: String) in
                analyzer.putVariable("loginInfo_\(key)", value: "")
            },
            "_sourceGetLoginHeader": { (key: String) -> String in
                analyzer.getVariable("loginHeader_\(key)") ?? ""
            },
            "_sourceGetLoginHeaderMap": { () -> [String: String] in
                [:]
            },
            "_sourcePutLoginHeader": { (key: String, value: String) in
                analyzer.putVariable("loginHeader_\(key)", value: value)
            },
            "_sourceRemoveLoginHeader": { (key: String) in
                analyzer.putVariable("loginHeader_\(key)", value: "")
            },
            // closure #6（L43-45）/_ttsLoginUrl（推断 2：返回源登录 URL）。
            "_ttsLoginUrl": { () -> String in
                source?.loginUrl ?? ""
            },
            // TTS 缓存族。
            "_ttsCacheGet": { (key: String) -> String in
                JsCacheManager.shared.get("tts_\(key)") ?? ""
            },
            "_ttsCachePut": { (key: String, value: String) in
                JsCacheManager.shared.put("tts_\(key)", value)
            },
            "_ttsCacheDelete": { (key: String) in
                JsCacheManager.shared.delete("tts_\(key)")
            },
        ]
        for (key, value) in bridge {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
    }
}
