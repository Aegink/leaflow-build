// 原路径: ReadMain/Views/Reader/ReaderPageDebug.swift
// 证据:
//   - PGO: 2 个主函数（index/task_functions.csv T-301-07 / ReaderPageDebug.swift），
//     地址：visibleTextLength(in:) 0x1007bf570 L7-17 / isSuspiciousBlank 0x100bf2c0 L23-25；
//     骨架补充：logPageSet(event:pages:targetIndex:extra:)
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderPageDebug.c（125 行）
//   - 事实：isSuspiciousBlank = 正文去除 whitespacesAndNewlines 后为空（确证）；
//     0x1007bf570 块体（标 String 重载）实为 PageData 重载：isSuspiciousBlank ||
//     comments 非空（offset 216）|| isLoadingPlaceholder（offset 160）→ 0，
//     否则 isErrorPlaceholder(offset 161) ^ 1 —— 语义为"可显示正文判定"；
//     String 重载按签名还原（可见字符计数）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（布尔链/字节位确证；String 重载为签名级还原）
// 还原: 2026-11-19

/// 页面调试诊断（枚举命名空间）。
enum ReaderPageDebug {

    /// 伪代码 0x100bf2c0（L23-25）：正文去空白后为空 → 可疑空页。
    static func isSuspiciousBlank(_ page: PageData) -> Bool {
        page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 伪代码 0x100bf570 块体（L7-17；块标 String 重载实为 PageData 重载）：
    /// 可显示正文判定 —— 可疑空页 / 评论非空 / 加载占位 → 0；
    /// 否则错误占位取反。
    static func visibleTextLength(in page: PageData) -> Int {
        if isSuspiciousBlank(page)
            || !page.comments.isEmpty
            || page.isLoadingPlaceholder {
            return 0
        }
        return page.isErrorPlaceholder ? 0 : 1
    }

    /// String 重载（签名确证）：可见字符计数（去空白）。
    static func visibleTextLength(in text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    /// 页集诊断日志（骨架签名；autoclosure extra 确证）。
    static func logPageSet(
        event: String,
        pages: [PageData],
        targetIndex: Int?,
        extra: @autoclosure () -> String
    ) {
        Logger.log(
            "pageSet \(event) count=\(pages.count) target=\(String(describing: targetIndex)) \(extra())",
            level: 7)
    }
}
