// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl+CryptoBridge.swift
// 证据:
//   - PGO: analyzeUrlBase64InputBytes(LL) / analyzeUrlCollectionBridgeArray(LL) /
//     registerUtilAndCryptoBridge / registerPackagesBridges 及 8 闭包 / loadJsLib /
//     downloadScript(LL)
//   - CovMap: base64InputBytes L17-36 @0x100097f28（closure#1 L27-35 @0x100098310）；
//     collectionBridgeArray L38-53 @0x1000980e4；registerUtilAndCryptoBridge L63-116
//     @0x100098b68（closure#1 L70-72 @0x100098c70、#2 L76-78 @0x100098cac、#3 L82-84
//     @0x100098ce8、#8 L105-114 @0x100098ec0）；registerPackagesBridges L119-209
//     @0x100099160（closure#1 L121-128 @0x10009952c、#2 L131-138 @0x1000996ec、#3 L141-147
//     @0x100099b50、#4 L150-162 @0x100099fe0、#5 L165-180 @0x10009a520 内嵌 (Int)->UInt8
//     @0x10009ac94、#6 L183-187 @0x10009b0a0、#7 L190-194 @0x10009b4a8）；
//     loadJsLib L211-227 @0x10009b668（closure#2 L220-222 @0x100098b24）；
//     downloadScript L229-258 @0x10009b6a0
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 选择子常量
//   - 原生键：_nativeBase64Encode/_nativeBase64DecodeToBytes/_nativeCipherProcess/
//     _nativeStrToBytes/_nativeBytesToStr/_nativeGunzip/_nativeGzip/_nativeSleepMillis
//   - 选择子：isArray/toArray/integerValue/toBool/toObject/isObject/isUndefined/isNull/
//     valueForProperty:/invokeMethod:withArguments:/setObject:forKeyedSubscript:/
//     sleepForTimeInterval:/defaultManager/URLsForDirectory:inDomains:
//   - 常量：iso-8859(0x393538382D6F7369)、"-1"
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - base64/collection 桥: high（键名与选择子逐一可见）
//   - registerPackagesBridges 闭包: medium-high（签名确证，算法内部待 T-208 交叉）
//   - loadJsLib/downloadScript: medium-high（缓存目录 + 远程拉取链可见）
// 还原: 2026-11-19

import Foundation
import JavaScriptCore

extension AnalyzeUrl {

    // MARK: - JSValue 字节转换

    /// 伪代码 0x100097f28（L17-36）：JSValue → [UInt8]（事实 6）。
    static func analyzeUrlBase64InputBytes(from value: JSValue) -> [UInt8]? {
        guard value.isArray else { return nil }
        guard let array = value.toArray() else { return nil }
        var bytes: [UInt8] = []
        for item in array {
            if let number = item as? Int, number >= 0, number <= 255 {
                bytes.append(UInt8(number))
            } else if let number = item as? Double, number >= 0, number <= 255 {
                bytes.append(UInt8(number))
            } else {
                return nil
            }
        }
        return bytes
    }

    /// 伪代码 0x1000980e4（L38-53）：JSValue → [Any] 收集桥。
    static func analyzeUrlCollectionBridgeArray(from value: JSValue) -> [Any]? {
        guard value.isArray else { return nil }
        return value.toArray()
    }

    // MARK: - 原生工具/加密桥

    /// 伪代码 0x100098b68（L63-116）：`java` 上的 _native* 键注册（事实 7）。
    static func registerUtilAndCryptoBridge(_ context: JSContext) {
        let native: [String: Any] = [
            "_nativeBase64Encode": { (input: JSValue) -> String in
                guard let bytes = analyzeUrlBase64InputBytes(from: input) else { return "" }
                return Data(bytes).base64EncodedString()
            },
            "_nativeBase64DecodeToBytes": { (input: String) -> [Int] in
                guard let data = Data(base64Encoded: input) else { return [] }
                return data.map { Int($0) }
            },
            "_nativeCipherProcess": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "_nativeStrToBytes": { (input: String) -> [Int] in
                Array(input.utf8).map { Int($0) }
            },
            "_nativeBytesToStr": { (bytes: [Int]) -> String in
                String(bytes: bytes.compactMap { UInt8(exactly: $0) }, encoding: .utf8) ?? ""
            },
            "_nativeGunzip": { (input: String) -> String in
                CryptoBridge.gunzip(input)
            },
            "_nativeGzip": { (input: String) -> String in
                CryptoBridge.gzip(input)
            },
            "_nativeSleepMillis": { (millis: Double) -> String in
                Thread.sleep(forTimeInterval: millis / 1000.0)
                return ""
            },
        ]
        for (key, value) in native {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
    }

    /// 伪代码 0x100099160（L119-209）：包桥注册（8 个闭包，事实 8）。
    /// 闭包签名逐一对应；算法实现走 CryptoBridge（T-208 交叉验证）。
    static func registerPackagesBridges(_ context: JSContext) {
        // closure #1（L121-128）(JSValue)->String。
        context.setObject({ (value: JSValue) -> String in
            value.toString() ?? ""
        }, forKeyedSubscript: "__packagesToString" as NSString)
        // closure #2（L131-138）(String)->[Int]。
        context.setObject({ (input: String) -> [Int] in
            Array(input.utf8).map { Int($0) }
        }, forKeyedSubscript: "__packagesStrToBytes" as NSString)
        // closure #3（L141-147）五参+Bool->[Int]。
        context.setObject({ (input: String, key: String, iv: String, mode: String, isHex: Bool) -> [Int] in
            let output = CryptoBridge.cipherProcess(
                input: input, key: key, iv: iv, mode: mode, hexOutput: isHex
            )
            return Array(output.utf8).map { Int($0) }
        }, forKeyedSubscript: "__packagesCipher" as NSString)
        // closure #4（L150-162）(String,String)->[Int]。
        context.setObject({ (input: String, mode: String) -> [Int] in
            let output = CryptoBridge.digest(input, mode: mode)
            return Array(output.utf8).map { Int($0) }
        }, forKeyedSubscript: "__packagesDigest" as NSString)
        // closure #5（L165-180）([Int],String)->String。
        context.setObject({ (bytes: [Int], charset: String) -> String in
            let data = Data(bytes.compactMap { UInt8(exactly: $0) })
            if charset.lowercased().contains("iso-8859") {
                return String(data: data, encoding: .isoLatin1) ?? ""
            }
            return String(data: data, encoding: .utf8) ?? ""
        }, forKeyedSubscript: "__packagesBytesToStr" as NSString)
        // closure #6/#7（L183-187/L190-194）([Int])->[Int]。
        context.setObject({ (bytes: [Int]) -> [Int] in
            CryptoBridge.gzipBytes(bytes.map { UInt8(exactly: $0) ?? 0 }).map { Int($0) }
        }, forKeyedSubscript: "__packagesGzip" as NSString)
        context.setObject({ (bytes: [Int]) -> [Int] in
            CryptoBridge.gunzipBytes(bytes.map { UInt8(exactly: $0) ?? 0 }).map { Int($0) }
        }, forKeyedSubscript: "__packagesGunzip" as NSString)
    }

    // MARK: - 远程脚本

    /// 伪代码 0x10009b668（L211-227）：`<jslib>` 远程库加载（iso-8859/-1 编码常量）。
    func loadJsLib(_ url: String, into context: JSContext) {
        guard let script = Self.downloadScript(url) else { return }
        context.evaluateScript(script)
    }

    /// 伪代码 0x10009b6a0（L229-258）：远程脚本拉取（缓存目录 defaultManager）。
    static func downloadScript(_ url: String) -> String? {
        let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first
        guard let cacheDirectory else { return nil }
        let fileName = url.sha256Hex()
        let cached = cacheDirectory.appendingPathComponent(fileName)
        if let cachedContent = try? String(contentsOf: cached, encoding: .utf8) {
            return cachedContent
        }
        guard let fetched = NetworkConstants.fetchSync(url) else { return nil }
        try? fetched.write(to: cached, atomically: true, encoding: .utf8)
        return fetched
    }
}

// MARK: - 辅助

extension String {
    /// downloadScript 的缓存键。
    func sha256Hex() -> String {
        let digest = CryptoBridge.digest(self, mode: "sha256")
        return digest.isEmpty ? String(abs(self.hashValue)) : digest
    }
}
