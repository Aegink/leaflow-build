// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsExtensions+Crypto.swift
// 证据:
//   - PGO: base64Decode(_:charset:)/md5/hexDecode
//   - CovMap: base64Decode L15-29 @0x100104974；md5 L33-37 @0x100104f48；hexDecode L45-57 @0x100105380
//   - IDA: 上述地址
//   - md5Encode/md5Encode16 的 java 侧入口
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high
// 还原: 2026-11-19


import Foundation

extension JsExtensions {

    /// 伪代码 0x100104974（L15-29）。
    func base64Decode(_ text: String, _ charset: String) -> String {
        guard let data = Data(base64Encoded: text) else { return "" }
        let encoding = getEncoding(charset)
        return String(data: data, encoding: encoding) ?? ""
    }

    /// 伪代码 0x100104f48（L33-37）。
    func md5(_ text: String) -> String {
        CryptoBridge.digest(text, mode: "md5")
    }

    /// 伪代码 0x100105380（L45-57）。
    func hexDecode(_ text: String) -> String {
        var bytes: [UInt8] = []
        let characters = Array(text)
        guard characters.count % 2 == 0 else { return "" }
        var index = 0
        while index < characters.count {
            guard let high = characters[index].hexDigitValue,
                let low = characters[index + 1].hexDigitValue
            else { return "" }
            bytes.append(UInt8(high * 16 + low))
            index += 2
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
