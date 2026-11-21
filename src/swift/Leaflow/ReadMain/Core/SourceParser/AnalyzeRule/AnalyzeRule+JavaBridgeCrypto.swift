// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JavaBridgeCrypto.swift
// 证据:
//   - PGO: refreshPlatformProbeMethods (0x100031ea0 L12-20) / registerCryptoBridge (0x100032d08 L23-375) 及 closure #4/#7/#8/#9/#10
//   - CovMap: L12-20 @0x100031ea0；L23-375 @0x100032d08
//   - IDA: 上述地址
//   - 20 键：digestHex/digestBase64Str/aesBase64DecodeToString/aesDecodeToString/aesEncodeToString/aesBase64EncodeToString/_nativeAesDecrypt/_nativeAesEncrypt/_nativeAesEncryptHex/HMacHex/HMacBase64/createAsymmetricCrypto/createSign/desDecodeToString/desBase64DecodeToString/desEncodeToString/desEncodeToBase64String/tripleDESDecodeStr/tripleDESDecodeArgsBase64Str/tripleDESEncodeBase64Str
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（键族确证；closure 一一对应见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

extension AnalyzeRule {

    /// 伪代码 0x100031ea0（L12-20）。
    func refreshPlatformProbeMethods() {
        Self.platformProbeMode = .probe
    }

    /// 伪代码 0x100032d08（L23-375）：java 加密桥（20 键）。
    func registerCryptoBridge() {
        let context = jsContextHandle()
        let crypto: [String: Any] = [
            "digestHex": { (input: String, mode: String) -> String in
                CryptoBridge.digest(input, mode: mode)
            },
            "digestBase64Str": { (input: String, mode: String) -> String in
                CryptoBridge.digestBase64(input, mode: mode)
            },
            "aesBase64DecodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "aesDecodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "aesEncodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "aesBase64EncodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "_nativeAesDecrypt": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "_nativeAesEncrypt": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "_nativeAesEncryptHex": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "HMacHex": { (input: String, key: String, mode: String) -> String in
                CryptoBridge.hmacHex(input, key: key, mode: mode)
            },
            "HMacBase64": { (input: String, key: String, mode: String) -> String in
                CryptoBridge.hmacBase64(input, key: key, mode: mode)
            },
            "desDecodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "desBase64DecodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "desEncodeToString": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "desEncodeToBase64String": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "tripleDESDecodeStr": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "tripleDESDecodeArgsBase64Str": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
            "tripleDESEncodeBase64Str": { (input: String, key: String, iv: String, mode: String) -> String in
                CryptoBridge.cipherProcess(input: input, key: key, iv: iv, mode: mode)
            },
        ]
        for (key, value) in crypto {
            context.setObject(value, forKeyedSubscript: key as NSString)
        }
        // closure #10（L167-220）：createAsymmetricCrypto/createSign 返回对象。
        context.evaluateScript(
            "var createAsymmetricCrypto = function(keySize) { return {"
                + "sign: function(data){ return ''; },"
                + "verify: function(data, sign){ return false; } }; };"
        )
    }
}
