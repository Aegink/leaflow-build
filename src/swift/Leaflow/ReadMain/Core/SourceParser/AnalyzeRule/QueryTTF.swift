// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/QueryTTF.swift
// 证据:
//   - PGO: GlyphData.hash(into:) (0x10007ac00 L95-102) / implicit closure #6/#7 (0x10007b688/0x10007b884 L109-110)
//   - CovMap: L95-102/L109-110
//   - IDA: 上述地址
//   - 字体查询（书源自定义字体 glyph 子集，主体推断见读后记推断 1）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（哈希键确证，查询入口待反汇编）
// 还原: 2026-11-19


import Foundation

/// 字体查询（QueryTTF）。
enum QueryTTF {

    /// 伪代码 GlyphData（L95-102，Hashable 合成 closure #6/#7）。
    struct GlyphData: Hashable {
        let character: Character
        let fontSize: Int
        let fontWeight: Int

        func hash(into hasher: inout Hasher) {
            hasher.combine(character)
            hasher.combine(fontSize)
            hasher.combine(fontWeight)
        }
    }

    /// 查询入口（主体内联，推断 1）：返回字形在字体子集内的映射或原字符。
    static func glyph(for data: GlyphData, in fontName: String) -> String {
        String(data.character)
    }
}
