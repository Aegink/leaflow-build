// 原路径: ReadMain/Core/SourceParser/CryptoBridge.swift
// 证据:
//   - 调用域确证（wave-19 补桥）：
//     digest(_ mode:)——JavaBridge.md5Encode / JsBridgeShared+Util
//     md5Encode/md5Encode16 / JsExtensions+Crypto.md5Encode（"md5" 档）；
//     cipherProcess(input:key:iv:mode:)——JsBridgeShared+SymmetricCrypto
//     decryptBytes（JSImportSymmetricCryptoStore 域）。
//   - transformer 串形如 "AES/CBC/PKCS5Padding"（legado 域惯例）。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（摘要域调用确证；对称域算法/填充档为还原推断——
//   记入仍不清楚：原始 cipherProcess 的完整算法/填充矩阵待真机核清）
// 还原: 2026-11-21

import Foundation
import CommonCrypto

/// JS 桥加密域（CryptoBridge）。
enum CryptoBridge {

    // MARK: 摘要域

    /// digest(input:mode:)（hex 输出；md5 档调用域确证，sha 档随
    /// CommonCrypto 全集——还原推断）。
    static func digest(_ input: String, mode: String) -> String {
        let data = Array(input.utf8)
        let digestBytes: [UInt8]
        switch mode.lowercased() {
        case "md5":
            digestBytes = commonDigest(data) { CC_MD5($0, CC_LONG($1), $2) }
        case "sha1":
            digestBytes = commonDigest(data) { CC_SHA1($0, CC_LONG($1), $2) }
        case "sha256":
            digestBytes = commonDigest(data) { CC_SHA256($0, CC_LONG($1), $2) }
        case "sha512":
            digestBytes = commonDigest(data) { CC_SHA512($0, CC_LONG($1), $2) }
        default:
            // 未识别档回退 md5（还原推断）。
            digestBytes = commonDigest(data) { CC_MD5($0, CC_LONG($1), $2) }
        }
        return digestBytes.map { String(format: "%02x", $0) }.joined()
    }

    /// CommonCrypto 一次性摘要桥。
    private static func commonDigest(
        _ data: [UInt8],
        _ transform: (UnsafeRawPointer, Int, UnsafeMutablePointer<UInt8>)
            -> UnsafeMutablePointer<UInt8>
    ) -> [UInt8] {
        // 各算法缓冲上限统一取 SHA512 摘要长度（64）。
        var output = [UInt8](repeating: 0, count: 64)
        _ = data.withUnsafeBufferPointer { buffer in
            transform(
                buffer.baseAddress ?? UnsafeRawPointer([UInt8]()),
                data.count, &output)
        }
        return output
    }

    // MARK: 对称域

    /// cipherProcess(input:key:iv:mode:)（SymmetricCrypto decryptBytes
    /// 域确证——解密路径）。transformer 解析：算法/分组/填充；
    /// key/iv 按 UTF-8 字节（legado 域惯例），不满足算法长度需求时
    /// 补零/截断（还原推断）。
    static func cipherProcess(
        input: String, key: String, iv: String, mode: String
    ) -> String {
        let parts = mode.split(separator: "/").map { $0.uppercased() }
        let algorithm = parts.first ?? "AES"
        let blockMode = parts.count > 1 ? parts[1] : "CBC"
        let padding = parts.count > 2 ? parts[2] : "PKCS5PADDING"

        let inputData = Array(input.utf8)
        let keyBytes = normalizedKey(Array(key.utf8), algorithm: algorithm)
        let ivBytes = Array(iv.utf8)

        let processed: [UInt8]
        switch algorithm {
        case "RC4":
            processed = rc4(inputData, key: keyBytes)
        case "DES", "DESEDE", "DESede", "TRIPLEDES", "3DES":
            let ccAlgorithm: CCAlgorithm = algorithm == "DES"
                ? CCAlgorithm(kCCAlgorithmDES) : CCAlgorithm(kCCAlgorithm3DES)
            processed = blockCipher(
                inputData, key: keyBytes, iv: ivBytes,
                algorithm: ccAlgorithm, blockSize: 8,
                ecb: blockMode == "ECB" || blockMode == "ECBNOPADDING"
                    || blockMode == "ECBZEROTBYTEPADDING"
                    || blockMode == "ECBZEROTBYTE",
                padded: isPadded(padding))
        default:
            processed = blockCipher(
                inputData, key: keyBytes, iv: ivBytes,
                algorithm: CCAlgorithm(kCCAlgorithmAES), blockSize: 16,
                ecb: blockMode == "ECB" || blockMode == "ECBNOPADDING"
                    || blockMode == "ECBZEROTBYTEPADDING"
                    || blockMode == "ECBZEROTBYTE",
                padded: isPadded(padding))
        }
        return String(decoding: processed, as: UTF8.self)
    }

    /// 填充档判定（PKCS5/PKCS7 域；NOPADDING/ZEROBYTE 不走系统填充）。
    private static func isPadded(_ padding: String) -> Bool {
        padding.contains("PKCS")
    }

    /// 密钥长度归一（AES 16/24/32、DES 8、3DES 24——补零/截断，还原推断）。
    private static func normalizedKey(
        _ bytes: [UInt8], algorithm: String
    ) -> [UInt8] {
        let target: Int
        switch algorithm {
        case "DES": target = kCCKeySizeDES
        case "DESEDE", "DESede", "TRIPLEDES", "3DES":
            target = kCCKeySize3DES
        default:
            // AES：取不超过 32 的最近合法档。
            if bytes.count > 24 { target = 32 }
            else if bytes.count > 16 { target = 24 }
            else { target = 16 }
        }
        if bytes.count == target { return bytes }
        if bytes.count > target { return Array(bytes.prefix(target)) }
        return bytes + [UInt8](repeating: 0, count: target - bytes.count)
    }

    /// 分组密码解密桥（CCCryptor：CBC 默认 / ECB 经选项域）。
    private static func blockCipher(
        _ input: [UInt8], key: [UInt8], iv: [UInt8],
        algorithm: CCAlgorithm, blockSize: Int,
        ecb: Bool, padded: Bool
    ) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: input.count + blockSize * 2)
        var moved = 0
        let options: CCOptions = padded ? CCOptions(kCCOptionPKCS7Padding)
            : CCOptions(0)
        let effectiveOptions = ecb ? options | CCOptions(kCCOptionECBMode)
            : options
        // 解密路径（decryptBytes 域确证）；零填充域补自动剥尾（还原推断）。
        let status = input.withUnsafeBufferPointer { inputBuffer in
            key.withUnsafeBufferPointer { keyBuffer in
                iv.withUnsafeBufferPointer { ivBuffer in
                    output.withUnsafeMutableBufferPointer { outputBuffer in
                        CCCrypt(
                            CCOperation(kCCDecrypt), algorithm,
                            effectiveOptions,
                            keyBuffer.baseAddress, key.count,
                            ivBuffer.baseAddress,
                            inputBuffer.baseAddress, input.count,
                            outputBuffer.baseAddress, outputBuffer.count,
                            &moved)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return [] }
        var result = Array(output.prefix(moved))
        if !padded, !result.isEmpty {
            // ZeroByte/NoPadding 域剥尾部零字节（还原推断）。
            while let last = result.last, last == 0 { result.removeLast() }
        }
        return result
    }

    /// RC4 流密码（kCCAlgorithmRC4 + CCCrypt 单发域）。
    private static func rc4(_ input: [UInt8], key: [UInt8]) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: max(input.count, 1))
        var moved = 0
        let status = input.withUnsafeBufferPointer { inputBuffer in
            key.withUnsafeBufferPointer { keyBuffer in
                output.withUnsafeMutableBufferPointer { outputBuffer in
                    CCCrypt(
                        CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmRC4),
                        CCOptions(0),
                        keyBuffer.baseAddress, key.count, nil,
                        inputBuffer.baseAddress, input.count,
                        outputBuffer.baseAddress, outputBuffer.count,
                        &moved)
                }
            }
        }
        guard status == kCCSuccess else { return [] }
        return Array(output.prefix(moved))
    }
}
