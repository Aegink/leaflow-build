// 原路径: ReadMain/Core/SourceParser/RuleEvaluation/RuleEvaluator.swift
// 证据:
//   - PGO: RuleEvaluationStructuredValue.init(foundationValue:) (0x10007f250 L47-80) / foundationValue.getter (0x10007ed88 L82-97) 及 closure #1/#2
//   - CovMap: L47-80 @0x10007f250；L82-97 @0x10007ed88
//   - IDA: 上述地址
//   - doubleValue 选择子；与 T-204-01 ruleEvaluation 家族同族
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// 结构化求值值（RuleEvaluator）。
struct RuleEvaluationStructuredValue {

    private let storage: Any?

    /// 伪代码 0x10007f250（L47-80）。
    init(foundationValue: Any) {
        switch foundationValue {
        case let string as String:
            storage = string
        case let number as NSNumber:
            storage = number
        case let bool as Bool:
            storage = bool
        case let array as [Any]:
            storage = array
        case let dictionary as [String: Any]:
            storage = dictionary
        case is NSNull:
            storage = nil
        default:
            storage = String(describing: foundationValue)
        }
    }

    /// 伪代码 0x10007ed88（L82-97）。
    var foundationValue: Any {
        storage ?? NSNull()
    }

    var doubleValue: Double? {
        (storage as? NSNumber)?.doubleValue
    }

    var textValue: String? {
        storage as? String
    }
}
