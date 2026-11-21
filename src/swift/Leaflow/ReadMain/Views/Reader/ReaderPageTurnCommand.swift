import Foundation
// 原路径: ReadMain/Views/Reader/ReaderPageTurnCommand.swift
// 证据:
//   - PGO: 6 个主函数（index/task_functions.csv T-301-07 / ReaderPageTurnCommand.swift），
//     地址：ReaderPageCommit.init(index:pages:isDoublePage:) 0x1007bf7a8 L15-29
//     （+closure 0x1007bfa88 L28）/ shouldApply(currentIndex:pageCount:) 闭包
//     0x1007c15bc L32 / ReaderPageTurnCommandBuffer.submit 0x10070a624 L45-52
//     （+closure 0x10076921c L48）/ ReaderPageTurnTarget.index 0x1007bf9d0 L71-79 /
//     ReaderPageTurnCommandIssuer.command 0x100729780 L89-100
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderPageTurnCommand.c（332 行）
//   - 事实：ReaderPageCommit.init —— 双页时跨页对求和（index|1 配对，
//     0x7FFFFFFFFFFFFFFE 掩码 + 496 字节步长确证），characterCount 聚合；
//     shouldApply(currentIndex:pageCount:)；CommandBuffer.submit 暂存命令；
//     ReaderPageTurnTarget.index 静态定位；CommandIssuer.command 发起命令
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - ReaderPageCommit 聚合: high（跨页求和确证）
//   - CommandBuffer/Issuer: medium-high（暂存/发起语义确证；字段名还原）
// 还原: 2026-11-19

/// 页提交结果（跨页聚合）。
struct ReaderPageCommit {
    let index: Int
    let characterCount: Int
    let isDoublePage: Bool

    /// 伪代码 0x1007bf7a8（L15-29）+ closure #1（0x1007bfa88）。
    /// 双页时配对求和：index 与 index|1（越界收敛到 pageCount-1），
    /// characterCount = 可见页 charCount 聚合。
    init(index: Int, pages: [PageData], isDoublePage: Bool) {
        self.index = index
        self.isDoublePage = isDoublePage
        guard pages.indices.contains(index) else {
            self.characterCount = 0
            return
        }
        var count = pages[index].charCount
        if isDoublePage {
            let paired = min(index | 1, pages.count - 1)
            if paired != index {
                count += pages[paired].charCount
            }
        }
        self.characterCount = count
    }

    /// 伪代码 0x1007c15bc（L32）：提交是否仍适用（索引未越界且未漂移）。
    func shouldApply(currentIndex: Int, pageCount: Int) -> Bool {
        currentIndex >= 0 && currentIndex < pageCount && currentIndex == index
    }
}

/// 翻页命令（direction + 可选目标）。
struct ReaderPageTurnCommand {
    let id: UUID
    let direction: ReaderPageTurnDirection
    let targetIndex: Int?

    init(direction: ReaderPageTurnDirection, targetIndex: Int? = nil) {
        self.id = UUID()
        self.direction = direction
        self.targetIndex = targetIndex
    }
}

/// 翻页目标定位（枚举命名空间）。
enum ReaderPageTurnTarget {
    /// 伪代码 0x1007bf9d0（L71-79）：静态目标定位。
    static func index(
        currentIndex: Int, pageCount: Int, direction: ReaderPageTurnDirection
    ) -> Int? {
        let delta = direction == .next ? 1 : -1
        let target = currentIndex + delta
        guard target >= 0, target < pageCount else { return nil }
        return target
    }
}

/// 翻页命令缓冲（暂存单条待处理命令；submit 语义确证）。
final class ReaderPageTurnCommandBuffer {
    private(set) var pending: ReaderPageTurnCommand?

    /// 伪代码 0x10070a624（L45-52）+ closure（0x10076921c）：
    /// nil 提交清空；否则覆盖暂存。
    func submit(_ command: ReaderPageTurnCommand?) {
        pending = command
    }

    /// 取出暂存命令。
    func take() -> ReaderPageTurnCommand? {
        defer { pending = nil }
        return pending
    }
}

/// 翻页命令发起器（伪代码 0x100729780，L89-100）。
final class ReaderPageTurnCommandIssuer {
    private let buffer: ReaderPageTurnCommandBuffer

    init(buffer: ReaderPageTurnCommandBuffer) {
        self.buffer = buffer
    }

    /// 发起方向翻页命令。
    func command(
        direction: ReaderPageTurnDirection,
        currentIndex: Int,
        pageCount: Int
    ) {
        let target = ReaderPageTurnTarget.index(
            currentIndex: currentIndex, pageCount: pageCount, direction: direction)
        buffer.submit(ReaderPageTurnCommand(direction: direction, targetIndex: target))
    }
}
