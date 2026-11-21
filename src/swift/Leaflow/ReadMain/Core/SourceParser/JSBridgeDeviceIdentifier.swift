// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSBridgeDeviceIdentifier.swift
// 证据:
//   - PGO: prepare / value.getter / androidID(from:) / MainActor closure
//   - CovMap: 主条目见骨架（本文件 3 函数，伪代码内联于 Prepare 区段）
//   - IDA: 骨架地址
//   - 设备标识桥（androidId 的 native 侧）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（androidId 语义按 Legado 惯例；prepare 时机未逐行）
// 还原: 2026-11-19


import Foundation

/// 设备标识桥（T-204-02 读后记推断 2 的 native 侧）。
enum JSBridgeDeviceIdentifier {

    private static var cachedValue: String?
    private static let lock = NSLock()

    /// 预取（App 启动/首个 JS 调用前）。
    static func prepare() {
        _ = value
    }

    /// `java.androidId` 的取值（MainActor closure 对应 UI 侧取值）。
    static var value: String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cachedValue {
            return cached
        }
        let identifier = androidID(from: UUID())
        cachedValue = identifier
        return identifier
    }

    /// UUID → 稳定 androidId 形态（32 位小写十六进制）。
    static func androidID(from uuid: UUID?) -> String? {
        guard let uuid else { return nil }
        let hex = uuid.uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
        return hex.isEmpty ? nil : hex
    }
}
