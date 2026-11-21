// 原路径: ReadMain/Core/Logger.swift
// 证据:
//   - PGO: 34 个主函数（index/task_functions.csv T-101-03 / Logger.swift），
//     地址：CaptureState closure #1 0x1001546a8 L94-100 / Configuration closure #2
//     0x100154894 L206-214 / timestampFormatter closure #3 0x1001549cc L231 /
//     CaptureState closure 0x100154a20 L114-120 / 0x100157104 L105-110 /
//     CaptureSnapshot.extraParts(prefix:) 0x1001e3188 L58-64 / Level.< 0x1001e31dc
//     L16-18 / Level.emoji 0x1001e3218 L20-28 / Configuration 变量初始化
//     0x1001e3680 L68 / log 0x1001e3734 L188-243 / isSourceParserMemoryDebugMessage
//     0x1001e3520 L245-247 / CaptureState 初始化 0x1001e3e18 L78 /
//     consumeCapturedLogs 0x100c217b0 L104-111 / error(Error,context:...) 0x1002e1974
//     L180-184 / enableQuietMode 0x100d3b8f8 L282-289
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/Logger.c（1597 行）
//   - 事实：log 主链（0x1001e3734，L188-243）—— String.append 8 段拼装
//     （L1294-1337）+ print(_:separator:" ",terminator:"\n")（L1349 确证）；
//     Level.<（0x1001e31dc，L16-18：raw 比较确证）；Configuration 变量初始化
//     （0x1001e3680，L68）；CaptureState/captureSnapshot/consumeCapturedLogs
//     （0x100c217b0，L104-111 确证）；enableQuietMode（0x100d3b8f8，L282-289）；
//     已知噪声：Level.emoji 块体（0x1001e3218）实为 UIPasteboard/JsConsoleSheet
//     逻辑（ICF 误标，emoji 表不冒充解码）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - log 主链/捕获/模式开关: high（print/append/closure 链确证）
//   - Level emoji 表: low（块体误标；emoji 未解码）
// 还原: 2026-11-19

import Foundation

/// 全局日志（枚举命名空间 + 静态状态）。
enum Logger {

    /// 日志级别（raw 比较 < 确证）。
    /// wave-16：补 verbose/ultraVerbose 档——调用域 40 处 `level: 7`（性能/
    /// 滚动跟踪域）+ 1 处 `level: 9`（段评命中域），raw 值由调用域确证，
    /// 命名为还原推断。
    enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case silent = 4
        case verbose = 7
        case ultraVerbose = 9

        /// 伪代码 0x1001e31dc（L16-18）：raw 比较。
        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        /// 伪代码 0x1001e3218（L20-28；块体为 ICF 误标——UIPasteboard/JsConsoleSheet
        /// 逻辑；emoji 表未解码，按级别语义还原）。
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .silent: return ""
            case .verbose: return "🧪"
            case .ultraVerbose: return "🔬"
            }
        }
    }

    /// 日志域（调用方确证：module 参数贯穿全部入口）。
    enum Module: String {
        case app
        case source
        case parser
        case reader
        case tts
        case sync
        case js
        case general
    }

    /// 运行模式（enable*Mode 系确证）。
    struct Configuration {
        var minimumLevel: Level = .info
        var quietMode = false
        var sourceParsingMode = false
        var captureEnabled = false
    }

    /// 捕获条目（consumeCapturedLogs 返回域确证）。
    struct CapturedLogEntry {
        let message: String
        let level: Level
        let timestamp: Date
    }

    /// 捕获快照（骨架签名 captureSnapshot）。
    struct CaptureSnapshot {
        var entries: [CapturedLogEntry]

        /// 伪代码 0x1001e3188（L58-64）：前缀附加段。
        func extraParts(prefix: String) -> [String] {
            entries.map { "\(prefix)\($0.level.emoji) \($0.message)" }
        }
    }

    /// 时间戳格式器（timestampFormatter closure #3 确证）。
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    // 静态状态（Configuration/CaptureState 初始化确证）。
    private static let stateLock = NSLock()
    private static var configuration = Configuration()
    private static var captureState: [CapturedLogEntry] = []
    private static var captureOn = false

    // MARK: 模式开关

    /// 伪代码 0x100d3b8f8（L282-289）：静默模式（仅 error）。
    static func enableQuietMode() {
        stateLock.lock()
        defer { stateLock.unlock() }
        configuration.quietMode = true
        configuration.minimumLevel = .error
    }

    static func enableDevMode() {
        stateLock.lock()
        defer { stateLock.unlock() }
        configuration.quietMode = false
        configuration.minimumLevel = .debug
    }

    static func enableProdMode() {
        stateLock.lock()
        defer { stateLock.unlock() }
        configuration.quietMode = false
        configuration.minimumLevel = .warning
    }

    static func enableSourceParsingMode() {
        stateLock.lock()
        defer { stateLock.unlock() }
        configuration.sourceParsingMode = true
    }

    /// 捕获开关（骨架签名 setCaptureEnabled(_)）。
    static func setCaptureEnabled(_ enabled: Bool) {
        stateLock.lock()
        defer { stateLock.unlock() }
        captureOn = enabled
        if !enabled {
            captureState.removeAll()
        }
    }

    // MARK: 核心输出

    /// 伪代码 0x1001e3734（L188-243）：主输出链。
    /// 8 段 String.append 拼装（emoji/时间戳/级别/域/文件行/消息，L1294-1337 确证）
    /// + print(separator:" ", terminator:"\n")（L1349 确证）；低于阈值早退；
    /// 捕获开启时同步入 CaptureState。
    static func log(
        _ message: String,
        level: Level,
        module: Module = .general,
        file: String = "",
        line: Int = 0
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard level.rawValue >= configuration.minimumLevel.rawValue else { return }
        let fileName = (file as NSString).lastPathComponent
        let lineText = "\(timestampFormatter.string(from: Date())) " +
            "\(level.emoji) [\(module.rawValue)] \(fileName):\(line) \(message)"
        print(lineText, separator: " ", terminator: "\n")
        if captureOn {
            captureState.append(
                CapturedLogEntry(message: message, level: level, timestamp: Date()))
            if captureState.count > 500 {
                captureState.removeFirst(captureState.count - 500)
            }
        }
    }

    // MARK: 级别便捷入口（签名确证）

    static func debug(
        _ message: String, module: Module = .general, file: String = #file, line: Int = #line
    ) {
        log(message, level: .debug, module: module, file: file, line: line)
    }

    static func info(
        _ message: String, module: Module = .general, file: String = #file, line: Int = #line
    ) {
        log(message, level: .info, module: module, file: file, line: line)
    }

    static func warning(
        _ message: String, module: Module = .general, file: String = #file, line: Int = #line
    ) {
        log(message, level: .warning, module: module, file: file, line: line)
    }

    static func error(
        _ message: String, module: Module = .general, file: String = #file, line: Int = #line
    ) {
        log(message, level: .error, module: module, file: file, line: line)
    }

    /// 伪代码 0x1002e1974（L180-184 + closure）：错误 + 上下文串。
    static func error(
        _ error: Swift.Error,
        context: String,
        module: Module = .general,
        file: String = #file,
        line: Int = #line
    ) {
        log("\(context): \(error.localizedDescription)", level: .error, module: module, file: file, line: line)
    }

    // MARK: 捕获快照

    /// 伪代码 0x100157104（L105-110）：快照导出。
    static func captureSnapshot() -> CaptureSnapshot {
        stateLock.lock()
        defer { stateLock.unlock() }
        return CaptureSnapshot(entries: captureState)
    }

    /// 伪代码 0x100c217b0（L104-111）：取出并清空。
    static func consumeCapturedLogs() -> [CapturedLogEntry] {
        stateLock.lock()
        defer { stateLock.unlock() }
        let entries = captureState
        captureState.removeAll()
        return entries
    }

    /// 伪代码 0x1001e3520（L245-247）：解析器内存调试消息过滤（签名确证）。
    static func isSourceParserMemoryDebugMessage(_ message: String) -> Bool {
        message.contains("SourceParserMemory")
    }
}
