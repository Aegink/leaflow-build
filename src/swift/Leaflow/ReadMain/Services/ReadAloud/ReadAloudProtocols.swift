// 原路径: ReadMain/Services/ReadAloud/ReadAloudProtocols.swift
// 证据:
//   - PGO: 1 条记录（index/task_functions.csv T-801-09 /
//     ReadAloudProtocols.swift；1 函数，伪代码 54 行）
//   - CovMap: 上述 L 区段（errorDescription 0x100299d2c L56-61 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudProtocols.c（54 行）
//   - 块体确证（地址+行号域）：
//     ReadAloudDriverFactoryError.errorDescription getter
//     0x100299d2c L56-61（Task.userInitiated 域 + withTaskCancellation
//     Handler 域）
//   - 事实：工厂错误域（其余协议随 T-801-08 ReadAloudModels 落地，
//     本分册为错误枚举域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（单签名域确证；枚举随 T-801-08 桥域落地）
// 还原: 2026-11-20

import Foundation

/// 驱动工厂错误（0x100299d2c L56-61 块体确证；枚举本体随
/// ReadAloudModels.swift T-801-08 域落地，此处为引用登记）。
// ReadAloudDriverFactoryError（T-801-08 ReadAloudModels.swift 域）

/// 驱动工厂错误（errorDescription 0x100299d2c L56-61 域；容器缺失还原）。
enum ReadAloudDriverFactoryError: LocalizedError {
        case outputPreparationFailed
    case engineUnavailable
    case voiceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .outputPreparationFailed:
            return "朗读输出准备失败"
        case .engineUnavailable:
            return "朗读引擎不可用"
        case .voiceNotFound(let identifier):
            return "未找到语音：\(identifier)"
        }
    }
}

