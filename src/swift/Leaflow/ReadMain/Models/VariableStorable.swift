// 原路径: ReadMain/Models/VariableStorable.swift
// 证据:
//   - PGO: 4 个主函数（index/task_functions.csv T-1001-02 / VariableStorable.swift），
//     地址：variableMap.getter 0x100015354/0x1001195fc/0x100136d34/0x10023bbd4
//     L13-19（4 个 ICF 共体块 = 4 种载荷域）；pgo_only：getVariable(String) ->
//     String?、variableMap.setter
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/VariableStorable.c（488 行，4 块）
//   - 关键调用：String.data(using:.utf8) / NSJSONSerialization JSONObjectWithData /
//     dataWithJSONObject / Data._bridgeToObjectiveC / _bridgeAnyObjectToAny /
//     Dictionary.init(dictionaryLiteral:)
//   - 事实：variableMap.getter —— 4 个共体块对应四种载荷形态：
//     ① 空实现（0x100015354 计数空转 = 默认空表）；② 字符串 JSON 反序列化
//     （data(using:.utf8) + JSONObjectWithData + Any 桥接，失败 → willThrow 回退
//     空字典）；③ 同上 + String._fromSubstring；④ 双向（dataWithJSONObject 序列化
//     参与确证）；setter/getVariable 为 pgo_only 共体
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 协议面/JSON 编解码链: high（选择子确证）
//   - 4 个共体块的精确域划分: medium（按块体特征推断）
// 还原: 2026-11-19

import Foundation

/// 变量存储协议（规则变量/源变量的 JSON 快照面）。
protocol VariableStorable: AnyObject {
    /// 变量表（键 → 值）。
    var variableMap: [String: String] { get set }
}

extension VariableStorable {

    /// 伪代码 0x1001195fc/0x100136d34/0x10023bbd4（L13-19，3 个共体块）：
    /// 表 → JSON 字符串（dataWithJSONObject + utf8）。
    var variableMapJSON: String? {
        guard !variableMap.isEmpty else { return nil }
        guard JSONSerialization.isValidJSONObject(variableMap) else { return nil }
        guard let data = try? JSONSerialization.data(
            withJSONObject: variableMap, options: [.fragmentsAllowed]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 伪代码 0x1001195fc 块（L13-19）：
    /// JSON 字符串 → 表（data(using:.utf8) + JSONObjectWithData；
    /// 解析失败 → willThrow + 回退空字典，L85-L110 确证）。
    func loadVariableMap(fromJSON json: String?) {
        guard let json, let data = json.data(using: .utf8, allowLossyConversion: false) else {
            variableMap = [:]
            return
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            if let dictionary = object as? [String: String] {
                variableMap = dictionary
            } else if let anyDict = object as? [String: Any] {
                // 非字符串值降级为字符串（_bridgeAnyObjectToAny 域确证）。
                variableMap = anyDict.mapValues { "\($0)" }
            } else {
                variableMap = [:]
            }
        } catch {
            // swift_willThrow + 回退空字典（伪代码 L110 确证）。
            variableMap = [:]
        }
    }

    /// pgo_only getVariable(String) -> String?（签名确证）。
    func getVariable(_ key: String) -> String? {
        variableMap[key]
    }

    /// pgo_only variableMap.setter 辅助（签名确证）。
    func setVariable(_ key: String, value: String?) {
        if let value {
            variableMap[key] = value
        } else {
            variableMap.removeValue(forKey: key)
        }
    }
}
