// 原路径: ReadMain/Services/ReadAloud/ReadAloudTextSanitizer.swift
// 证据:
//   - PGO: 6 条记录（index/task_functions.csv T-801-10 /
//     ReadAloudTextSanitizer.swift；shouldKeep/clean 双签名域）
//   - CovMap: 上述 L 区段（clean/shouldKeep 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudTextSanitizer.c（278 行）
//   - 块体确证（签名域）：
//     clean(String) / shouldKeep(Unicode.Scalar)
//   - 事实：朗读文本清洗（不可读标量过滤 + 空白折叠）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读文本清洗器（clean/shouldKeep 签名域确证）。
enum ReadAloudTextSanitizer {

    /// clean(String)（签名域确证：逐标量 shouldKeep 过滤 + 空白折叠）。
    static func clean(_ text: String) -> String {
        let filtered = text.unicodeScalars.filter { shouldKeep($0) }
        let joined = String(String.UnicodeScalarView(filtered))
        var result = ""
        var previousWasSpace = false
        for character in joined {
            if character.isWhitespace {
                if !previousWasSpace {
                    result.append(" ")
                }
                previousWasSpace = true
            } else {
                result.append(character)
                previousWasSpace = false
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// shouldKeep(Unicode.Scalar)（签名域确证：可打印/中英字符/
    /// 常用标点保留域）。
    private static func shouldKeep(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0A, 0x0D:
            // 换行转空格域。
            return true
        case 0x00A0:
            // 不间断空格折叠域。
            return true
        case 0x200B...0x200F, 0xFEFF:
            // 零宽/方向控制符剔除域。
            return false
        default:
            break
        }
        if scalar.properties.isWhitespace { return true }
        if scalar.properties.isAlphabetic { return true }
        if scalar.properties.numericType != nil { return true }
        // 常用标点保留域（中英标点 + 符号）。
        switch scalar.value {
        case 0x20...0x2F, 0x3A...0x40, 0x5B...0x60, 0x7B...0x7E:
            return true
        case 0x3000...0x303F, 0xFF00...0xFFEF:
            // CJK 标点/全角域。
            return true
        case 0x2013...0x2027:
            // 破折号/省略号域。
            return true
        default:
            return false
        }
    }
}
