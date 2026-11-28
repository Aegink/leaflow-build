// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl.swift
import Foundation

extension AnalyzeUrl {
    // MARK: - 快照与清理

    /// 伪代码 0x1000876d8（L1024-1062）：请求参数快照（重试用，推断 4）。
    struct Snapshot {
        var url: String
        var method: String
        var headers: [String: String]
        var body: String?

        init(_ source: AnalyzeUrl) {
            url = source.url
            method = source.method
            headers = source.headers
            body = source.body
        }
    }

}

// MARK: - 静态清理族

extension AnalyzeUrl {

    static let analyzeUrlLogLevel: Logger.Level = .warning

    /// 伪代码 0x100081ffc（L365-418）：搜索缓存全清。
    static func clearSearchCaches() {
        Logger.log(
            "[AnalyzeUrl] 清缓存前 AnalyzeUrlPool checkedOut", level: analyzeUrlLogLevel
        )
        batchSearchSession?.invalidateAndCancel()
        batchSearchSession = nil
        Logger.log(
            "[AnalyzeUrl] 清缓存后 AnalyzeUrlPool checkedOut 索缓存已全部清理 "
                + "drainJSContexts=0 clearSharedJsScope=0",
            level: analyzeUrlLogLevel
        )
    }

    /// 伪代码 0x100082658（L420-456）。
    static func clearIdleRuntimeCaches() {
        JSContextPool.drain()
    }

    /// 伪代码 closure @0x10008288c（L461-467）：批量请求取消。
    static func cancelAllBatchRequests() {
        batchSearchSession?.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    /// 伪代码 0x10008214c（L471-476）。
    static func drainJSContextPool() {
        JSContextPool.drain()
    }

    /// 伪代码 0x100082c5c（L484-513）。
    static func clearBatchRefreshCaches() {
        cancelAllBatchRequests()
        drainJSContextPool()
    }
}
