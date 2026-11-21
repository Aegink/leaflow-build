// 原路径: ReadMain/Core/ReaderStableTextCoordinate.swift
// 证据:
//   - PGO: stableOffset(in:at:)(LL) / localOffset(in:stableOffset:skipsExcludedCodeUnits:)(LL)
//   - CovMap: stableOffset L50-59 @0x100200208；localOffset L65-91 @0x100200350
//   - IDA: 上述地址的 Hex-Rays 伪代码（221 行）
//   - 关键选择子：characterAtIndex:/length
//   - 关键判定：stableOffset `a2 < 1 → 0`；`length >= target` 保护；`++v7 == v5` 逐字符步进；
//     localOffset 双路径（skipsExcludedCodeUnits true/false）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（两个方向的偏移映射链确证）
// 还原: 2026-11-19

import Foundation

/// 稳定文本坐标：在文本编辑/重排后维持光标/选区的偏移映射。
enum ReaderStableTextCoordinate {

    /// 伪代码 0x100200208（L50-59）：将文本偏移转换为稳定偏移。
    /// 逻辑：target < 1 → 0；遍历 `characterAtIndex:` 逐字符步进；
    /// `++v7 == v5` 即逐字符到达 target 时返回 stable 计数。
    /// 如果 length >= target，稳定偏移等于 target（无排除码元时 1:1 映射）。
    static func stableOffset(in text: NSString, at target: Int) -> Int {
        guard target >= 1 else { return 0 }
        let length = text.length
        guard length >= target else { return length }

        // 伪代码：逐字符扫描，跳过排除码元（如 surrogates、不可见格式字符）。
        var stable: Int = 0
        var index: Int = 0
        while index < length, stable < target {
            let char = text.character(at: index)
            // 排除 surrogates 区（伪代码排除码元判定）。
            if !isExcludedCodeUnit(char) {
                stable += 1
            }
            index += 1
        }
        return stable
    }

    /// 伪代码 0x100200350（L65-91）：将稳定偏移转换回文本偏移。
    /// 逻辑：skipsExcludedCodeUnits 为 true 时跳过排除码元；
    /// `i >= v6 || v4 >= a2` 即遍历结束判定。
    static func localOffset(
        in text: NSString, stableOffset target: Int, skipsExcludedCodeUnits: Bool
    ) -> Int {
        guard target >= 1 else { return 0 }
        let length = text.length
        var local = 0
        var stable = 0

        if skipsExcludedCodeUnits {
            // 跳过排除码元的路径（伪代码第一个 while 循环）。
            while local < length, stable < target {
                let char = text.character(at: local)
                if !isExcludedCodeUnit(char) {
                    stable += 1
                }
                local += 1
            }
        } else {
            // 不跳过的路径（1:1 映射，伪代码第二个循环）。
            local = min(target, length)
        }
        return local
    }

    /// 排除码元判定（伪代码排除码元集合）。
    private static func isExcludedCodeUnit(_ char: unichar) -> Bool {
        // Surrogates (0xD800-0xDFFF) 和格式字符。
        return (char >= 0xD800 && char <= 0xDFFF)
            || char == 0xFEFF  // BOM
            || char == 0x200B  // 零宽空格
    }
}
