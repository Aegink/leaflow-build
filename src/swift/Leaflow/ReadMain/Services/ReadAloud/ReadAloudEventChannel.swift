// 原路径: ReadMain/Services/ReadAloud/ReadAloudEventChannel.swift
// 证据:
//   - PGO: 6 条记录（index/task_functions.csv T-801-08 /
//     ReadAloudEventChannel.swift；3 函数，伪代码域 80 行）
//   - CovMap: 上述 L 区段（init/send/finish 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudEventChannel.c（258 行）
//   - 块体确证（签名域）：
//     ReadAloudEventChannel<A>.init() / send(A) / finish()
//   - 事实：AsyncStream 事件通道（.send/finish 双入口）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读事件通道（init/send/finish 签名域确证：AsyncStream 桥）。
final class ReadAloudEventChannel<Event: Sendable> {

    private var continuation: AsyncStream<Event>.Continuation?
    private let stream: AsyncStream<Event>

    init() {
        var captured: AsyncStream<Event>.Continuation?
        stream = AsyncStream { captured = $0 }
        continuation = captured
    }

    var events: AsyncStream<Event> {
        stream
    }

    /// send(A)（签名域确证）。
    func send(_ event: Event) {
        continuation?.yield(event)
    }

    /// finish（签名域确证）。
    func finish() {
        continuation?.finish()
    }
}
