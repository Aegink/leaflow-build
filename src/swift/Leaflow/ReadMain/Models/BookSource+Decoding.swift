// 原始归属: ReadMain/Models/BookSource.swift
// 证据:
//   - PGO: 16 个主函数（index/task_functions.csv T-1001-01 / BookSource.swift），
//     地址：RawJSONValue.init(from:) 0x1002310b0 L12-35 / RawJSONValue.encode(to:)
//     0x1002315d0 L37-56 / RawJSONValue.stringValue 0x100231954 L58-74 /
//     LenientJSONString.init(from:) 0x1002328cc（pgo 共体）/
//     JSONStringBacked.init(from:) 0x100231c48 L88-95 / decodeLenientStringIfPresent
//     0x100231f7c L99-102 / decodeObjectOrJSONStringIfPresent 0x10023205c+5 共体块
//     L104-113 / BookSource.id 0x1002332a4 L153 / BookSource.init(from:)
//     0x1002339b0 L229-279 / readState 0x100230ba8 L380-399 / writeState 0x100230e00
//     L406-416 / removeState 0x100231094 L419-424
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/BookSource.c（1266 行，16 块）
//   - 关键调用：dispatch thunk of Decoder.singleValueContainer / SingleValueDecodingContainer
//     .decodeNil|decode / String.data(using:.utf8, allowLossyConversion:false) /
//     JSONDecoder.decode(_:from:) / DecodingError.dataCorruptedError(in:debugDescription:)
//     （25 字符字面量 0x101261910）/ KeyedDecodingContainer.decodeIfPresent /
//     UserDefaults standardUserDefaults setObject:forKey:|removeObjectForKey:
//   - 事实：RawJSONValue —— 枚举包装 Any（decodeNil → nil，其余 decode(Any.Type)，
//     encode 走 singleValueContainer）；JSONStringBacked —— 字符串值再经
//     JSONDecoder 解码为 A（utf8 data，失败 → dataCorruptedError）；
//     decodeObjectOrJSONStringIfPresent —— 先按对象解码失败回退 JSON 字符串
//     （6 个 ICF 共体块 = 6 个规则字段）；init(from:) 35 字段解码链
//     （decodeIfPresent 占多数 + 6 规则对象 + StorageKind 回退闭包，
//     init 默认字节位 +160/+176/+192 = true 确证）；
//     id（L153 单行，返回 bookSourceUrl）；state 系（UserDefaults，键含
//     bookSourceUrl 拼接确证）；StorageKind.label/shortLabel/icon/color（pgo 内联）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - RawJSONValue/JSONStringBacked/lenient 解码扩展: high（调用链确证）
//   - init(from:) 字段链: high（decodeIfPresent 链 + 默认字节位确证；字段名为还原命名）
//   - state 系/id/StorageKind 展示属性: high（UserDefaults 选择子确证）
// 还原: 2026-11-19

import Foundation

// MARK: - JSON 宽松解码辅助（mangle 内私有族）

/// Any 包装（伪代码 0x1002310b0，L12-35：singleValueContainer + decodeNil 判定）。
enum RawJSONValue: Codable {
    case null
    case value(Any)

    init() { self = .null }

    /// Any 归一（容器递归包装；不支持的类型 → nil）。
    private static func normalize(_ any: Any) -> Any? {
        switch any {
        case let v as String: return v
        case let v as Bool: return v
        case let v as Int: return v
        case let v as Double: return v
        case let v as [Any]:
            let mapped = v.compactMap { normalize($0) }
            return mapped.isEmpty && !v.isEmpty ? nil : mapped
        case let v as [String: Any]:
            var out: [String: Any] = [:]
            for (key, item) in v {
                guard let normalized = normalize(item) else { return nil }
                out[key] = normalized
            }
            return out
        case is NSNull: return nil
        default: return nil
        }
    }

    /// Any 包装构造（JSONSerialization 域值 → RawJSONValue）。
    init?(any raw: Any) {
        guard let normalized = Self.normalize(raw) else { return nil }
        self = .value(normalized)
    }

    /// 解包值（stringValue/JSONSerialization 域消费）。
    var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case .value(let any): return any
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        // Any 非 Decodable——标量逐档宽容解码 + 容器递归（语义同伪代码）。
        if let v = try? container.decode(Bool.self) { self = .value(v); return }
        if let v = try? container.decode(Int.self) { self = .value(v); return }
        if let v = try? container.decode(Double.self) { self = .value(v); return }
        if let v = try? container.decode(String.self) { self = .value(v); return }
        if let arr = try? container.decode([RawJSONValue].self) {
            self = .value(arr.map { $0.anyValue })
            return
        }
        if let dict = try? container.decode([String: RawJSONValue].self) {
            var out: [String: Any] = [:]
            for (key, item) in dict { out[key] = item.anyValue }
            self = .value(out)
            return
        }
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Unsupported JSON value kind"))
    }

    func encode(to encoder: Encoder) throws {
        // 伪代码 0x1002315d0（L37-56）：singleValueContainer encode。
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .value(let any):
            // Any 非 Encodable——按具体类型分派（Bool 先于 Int 防 NSNumber 重叠）。
            switch any {
            case let v as String:
                try container.encode(v)
            case let v as Bool:
                try container.encode(v)
            case let v as Int:
                try container.encode(v)
            case let v as Double:
                try container.encode(v)
            case let v as [Any]:
                try container.encode(v.compactMap(RawJSONValue.init(any:)))
            case let v as [String: Any]:
                var out: [String: RawJSONValue] = [:]
                for (key, item) in v {
                    guard let wrapped = RawJSONValue(any: item) else { continue }
                    out[key] = wrapped
                }
                try container.encode(out)
            default:
                try container.encodeNil()
            }
        }
    }

    /// 伪代码 0x100231954（L58-74）：值转 JSON 字符串（String.Encoding.utf8 确证）。
    var stringValue: String? {
        guard case .value(let any) = self else { return nil }
        if let string = any as? String {
            return string
        }
        guard let data = try? JSONSerialization.data(withJSONObject: any, options: [.fragmentsAllowed]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

/// JSON 字符串再解码（伪代码 0x100231c48，L88-95）。
/// singleValueContainer 解出 String → utf8 data → JSONDecoder.decode(A.self)；
/// data 失败（v21 >> 60 == 15 的空/坏对象判定）→ dataCorruptedError（25 字符描述）。
enum JSONStringBacked<A: Decodable> {
    static func decode(_ type: A.Type, from decoder: Decoder) throws -> A {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let data = string.data(using: .utf8, allowLossyConversion: false) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Data is not valid UTF-8 JSON string"))
        }
        return try JSONDecoder().decode(A.self, from: data)
    }
}

enum LenientJSONString {
    /// 伪代码 0x1002328cc 块（共体）：字符串字段宽容解码（对象先转 JSON 串）。
    static func decode(from decoder: Decoder) throws -> String {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            return string
        }
        // 对象/数组 → JSON 串（Any 非 Decodable——经 RawJSONValue 递归桥）。
        if let value = try? container.decode(RawJSONValue.self),
           case .value(let any) = value,
           let data = try? JSONSerialization.data(
               withJSONObject: any, options: [.fragmentsAllowed]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Value is neither String nor JSON object"))
    }
}

extension KeyedDecodingContainer {
    /// 伪代码 0x100231f7c（L99-102）：宽容字符串（nil → nil）。
    func decodeLenientStringIfPresent(forKey key: K) throws -> String? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        return try LenientJSONString.decode(from: superDecoder(forKey: key))
    }

    /// 伪代码 0x10023205c 等 6 个 ICF 共体块（L104-113）：
    /// 先按对象解码，失败回退 JSON 字符串再解码。
    func decodeObjectOrJSONStringIfPresent<A: Decodable>(
        _ type: A.Type, forKey key: K
    ) throws -> A? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        do {
            return try decode(A.self, forKey: key)
        } catch {
            let string = try LenientJSONString.decode(from: superDecoder(forKey: key))
            guard let data = string.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(A.self, from: data)
        }
    }
}
