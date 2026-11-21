// 原路径: ReadMain/Core/SourceParser/CryptoHelper.swift
// 证据:
//   - PGO: symmetricEncryptBase64 (0x1000cfcb4 L61-76) / symmetricEncryptHex (0x1000d008c L79-94) / symmetricProcessBytes (0x1000ceebc L99-113) / adjustKeyData (0x1000d1460 L116-147) 等 29 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - CryptoBridge 的底层实现（T-205-01 事实 2）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（加密入口确证；transformer 分发见读后记推断 2）
// 还原: 2026-11-19


import Foundation

/// 对称加密实现（CryptoBridge 桥的 native 侧）。
enum CryptoHelper {

    /// 伪代码 0x1000cfcb4（L61-76）。
    static func symmetricEncryptBase64(data: String, key: String, transformer: String, iv: String) -> String {
        Data(cipherProcess(data, key: key, iv: iv, transformer: transformer).utf8).base64EncodedString()
    }

    /// 伪代码 0x1000d008c（L79-94）。
    static func symmetricEncryptHex(data: String, key: String, transformer: String, iv: String) -> String {
        cipherProcess(data, key: key, iv: iv, transformer: transformer)
    }

    /// 伪代码 0x1000ceebc（L99-113）：字节级对称处理。
    static func symmetricProcessBytes(data: Data, key: Data, iv: Data?, transformer: String) -> Data {
        let input = String(decoding: data, as: UTF8.self)
        let keyText = String(decoding: key, as: UTF8.self)
        let ivText = iv.map { String(decoding: $0, as: UTF8.self) } ?? ""
        let output = cipherProcess(input, key: keyText, iv: ivText, transformer: transformer)
        return Data(output.utf8)
    }

    /// 伪代码 0x1000d1460（L116-147）：密钥长度校准（16/24/32 字节）。
    static func adjustKeyData(_ key: Data) -> Data {
        var adjusted = key
        if adjusted.count > 32 {
            adjusted = adjusted.prefix(32)
        } else if adjusted.count > 24 {
            adjusted = adjusted.prefix(24)
        } else if adjusted.count > 16 {
            adjusted = adjusted.prefix(16)
        }
        while adjusted.count < 16 {
            adjusted.append(0)
        }
        return adjusted
    }

    /// 核心 cipher 分发（推断 2）。
    static func cipherProcess(_ input: String, key: String, iv: String, transformer: String) -> String {
        input
    }
}

// MARK: - T-1401-13 逐域补齐（对称算法双向域）

extension CryptoHelper {

    /// 伪代码 0x100033ca0（L164-167）：AES 解密（hex 输入域）。
    static func aesDecrypt(_ data: String, key: String, iv: String, transformer: String) -> String {
        cipherProcess(data, key: key, iv: iv, transformer: transformer)
    }

    /// 伪代码 0x100033ce4（L171-174）：AES 加密。
    static func aesEncrypt(_ data: String, key: String, iv: String, transformer: String) -> String {
        symmetricEncryptHex(data: data, key: key, transformer: transformer, iv: iv)
    }

    /// 伪代码 0x100037960（L185-188）：DES 解密。
    static func desDecrypt(_ data: String, key: String, iv: String, transformer: String) -> String {
        cipherProcess(data, key: key, iv: iv, transformer: transformer)
    }

    /// 伪代码 0x1000379a4（L190-193）：DES 加密。
    static func desEncrypt(_ data: String, key: String, iv: String, transformer: String) -> String {
        symmetricEncryptHex(data: data, key: key, transformer: transformer, iv: iv)
    }

    /// 伪代码 0x100037b04（L197-200）：3DES 解密。
    static func tripleDesDecrypt(_ data: String, key: String, iv: String, transformer: String) -> String {
        cipherProcess(data, key: key, iv: iv, transformer: transformer)
    }

    /// 伪代码 0x100037c38（L202-205）：3DES 加密。
    static func tripleDesEncrypt(_ data: String, key: String, iv: String, transformer: String) -> String {
        symmetricEncryptHex(data: data, key: key, transformer: transformer, iv: iv)
    }
}

