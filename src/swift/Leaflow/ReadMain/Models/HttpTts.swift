// 原路径: ReadMain/Models/HttpTts.swift
// 证据:
//   - PGO: 14 条记录（index/task_functions.csv T-801-02 / HttpTts.swift；
//     7 函数，伪代码域 90 行）
//   - CovMap: 上述 L 区段（init(from:) L31-54 / Int64 闭包 L39 /
//     hasJsScript L80 / stableNumericId L83-90）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/HttpTts.c（246 行）
//   - 块体确证（地址+行号域）：
//     init(from:) 0x10023fe9c L31-54（CodingKeys 容器链：name/url
//     decode + contentType/concurrentRate/enabledCookieJar/loginUrl/
//     loginUi/header/jsLib/loginCheckJs decodeIfPresent + enabled
//     decodeIfPresent + lastUpdateTime 域）/ implicit closure #1
//     0x1002411c4 L39（URLsForDirectory:9 域 + 'Books'
//     0x736B6F6F42 追加域）/ hasJsScript closure 三域 0x10024132c/
//     0x100241840 L80（String.hash + Hasher finalize 域）/
//     stableNumericId(for:) 实际块0x1002406f8，乘数0x1001be0f8
//   - init(numericId:name:url:...) 十三参签名域确证
//   - 事实：HttpTts = 朗读源模型（id: Int64 稳定哈希；jsLib/
//     loginCheckJs 双脚本域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（init 十三参签名 + CodingKeys 域确证）
// 还原: 2026-11-20

import Foundation

/// HTTP 朗读源模型（init 十三参签名域确证）。
struct HttpTts: Codable, Identifiable, Equatable {

    var numericId: Int64
    var name: String
    var url: String
    var contentType: String?
    var concurrentRate: String?
    var enabledCookieJar: Bool?
    var loginUrl: String?
    var loginUi: String?
    var header: String?
    var jsLib: String?
    var loginCheckJs: String?
    var lastUpdateTime: Double?
    var enabled: Bool?

    /// id getter（签名域确证：Int64 稳定 ID）。
    var id: Int64 {
        numericId
    }

    /// init 十三参（签名域确证）。
    init(
        numericId: Int64,
        name: String,
        url: String,
        contentType: String? = nil,
        concurrentRate: String? = nil,
        enabledCookieJar: Bool? = nil,
        loginUrl: String? = nil,
        loginUi: String? = nil,
        header: String? = nil,
        jsLib: String? = nil,
        loginCheckJs: String? = nil,
        lastUpdateTime: Double? = nil,
        enabled: Bool? = nil
    ) {
        self.numericId = numericId
        self.name = name
        self.url = url
        self.contentType = contentType
        self.concurrentRate = concurrentRate
        self.enabledCookieJar = enabledCookieJar
        self.loginUrl = loginUrl
        self.loginUi = loginUi
        self.header = header
        self.jsLib = jsLib
        self.loginCheckJs = loginCheckJs
        self.lastUpdateTime = lastUpdateTime
        self.enabled = enabled
    }

    /// 0x100240898实际块：检查请求URL中的两种脚本标记。
    var hasJsScript: Bool {
        url.contains("@js:") || url.contains("<js>")
    }

    /// init(from:)（0x10023fe9c L31-54 块体确证：CodingKeys 容器链，
    /// name/url 必填 decode，其余 decodeIfPresent）。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        // 0x100240090/0d0/108/378：整数、数字串、非空串哈希、名称哈希。
        if let value = try? c.decode(Int64.self, forKey: .id) {
            numericId = value
        } else if let value = try? c.decode(String.self, forKey: .id), !value.isEmpty {
            numericId = Int64(value) ?? Self.stableNumericId(for: value)
        } else {
            numericId = Self.stableNumericId(for: name)
        }
        url = try c.decode(String.self, forKey: .url)
        contentType = try c.decodeIfPresent(
            String.self, forKey: .contentType)
        concurrentRate = try c.decodeIfPresent(
            String.self, forKey: .concurrentRate)
        enabledCookieJar = try c.decodeIfPresent(
            Bool.self, forKey: .enabledCookieJar)
        loginUrl = try c.decodeIfPresent(String.self,
                                         forKey: .loginUrl)
        loginUi = try c.decodeIfPresent(String.self,
                                        forKey: .loginUi)
        header = try c.decodeIfPresent(String.self, forKey: .header)
        jsLib = try c.decodeIfPresent(String.self, forKey: .jsLib)
        loginCheckJs = try c.decodeIfPresent(
            String.self, forKey: .loginCheckJs)
        lastUpdateTime = try c.decodeIfPresent(
            Double.self, forKey: .lastUpdateTime)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(numericId, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(url, forKey: .url)
        try c.encodeIfPresent(contentType, forKey: .contentType)
        try c.encodeIfPresent(concurrentRate, forKey: .concurrentRate)
        try c.encodeIfPresent(enabledCookieJar,
                              forKey: .enabledCookieJar)
        try c.encodeIfPresent(loginUrl, forKey: .loginUrl)
        try c.encodeIfPresent(loginUi, forKey: .loginUi)
        try c.encodeIfPresent(header, forKey: .header)
        try c.encodeIfPresent(jsLib, forKey: .jsLib)
        try c.encodeIfPresent(loginCheckJs, forKey: .loginCheckJs)
        try c.encodeIfPresent(lastUpdateTime, forKey: .lastUpdateTime)
        try c.encodeIfPresent(enabled, forKey: .enabled)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case contentType
        case concurrentRate
        case enabledCookieJar
        case loginUrl
        case loginUi
        case header
        case jsLib
        case loginCheckJs
        case lastUpdateTime
        case enabled
    }

    /// 0x1002406f8：UTF-8 FNV-1a，溢出乘法后保留低63位。
    static func stableNumericId(for value: String) -> Int64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return Int64(hash & 0x7fffffffffffffff)
    }
}
