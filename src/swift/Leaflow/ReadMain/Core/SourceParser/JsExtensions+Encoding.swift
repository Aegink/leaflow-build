// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsExtensions+Encoding.swift
// 证据:
//   - PGO: encodeURIWithCharset/decodeURI/strToBytesWithCharset/bytesToStr/getEncoding
//   - CovMap: encodeURIWithCharset L15-28 @0x1001065f8（closure @0x10010602c）；decodeURI L30-32 @0x1001068b0；strToBytesWithCharset L40-46 @0x100106aa8；bytesToStr L48-50 @0x100105f48；getEncoding L61-80 @0x100105b3c
//   - IDA: 上述地址
//   - 编码族（getEncoding 的 BOM 探测见读后记仍不清楚 2）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

extension JsExtensions {

    /// 伪代码 0x1001065f8（L15-28）：按 charset 的 encodeURI。
    func encodeURIWithCharset(_ text: String, _ charset: String) -> String {
        let encoding = getEncoding(charset)
        guard let data = text.data(using: encoding) else { return text }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~!$&'()*+,;=:@/?#[]%")
        return String(data: data, encoding: encoding)?
            .addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    /// 伪代码 0x1001068b0（L30-32）。
    func decodeURI(_ text: String) -> String {
        text.removingPercentEncoding ?? text
    }

    /// 伪代码 0x100106aa8（L40-46）。
    func strToBytesWithCharset(_ text: String, _ charset: String) -> [UInt8] {
        let encoding = getEncoding(charset)
        return Array(text.data(using: encoding) ?? Data())
    }

    /// 伪代码 0x100105f48（L48-50）。
    func bytesToStr(_ bytes: [UInt8]) -> String {
        String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// 伪代码 0x100105b3c（L61-80）：charset 名 → String.Encoding。
    func getEncoding(_ charset: String) -> String.Encoding {
        let lowered = charset.lowercased()
        if lowered.contains("gbk") || lowered.contains("gb2312") || lowered.contains("gb18030") {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            ))
        }
        if lowered.contains("big5") {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.big5.rawValue)
            ))
        }
        if lowered.contains("windows-1252") || lowered.contains("iso-8859") {
            return .isoLatin1
        }
        return .utf8
    }
}
