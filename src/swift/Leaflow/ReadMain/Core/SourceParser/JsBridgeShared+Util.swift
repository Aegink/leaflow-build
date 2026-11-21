// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsBridgeShared+Util.swift
// 证据:
//   - PGO: makeBase64DecodeBlock/makeBase64DecodeToByteArrayBlock/makeHexDecodeToStringBlock/makeHexDecodeToByteArrayBlock/makeHexEncodeToStringBlock/makeDigestHexBlock(双地址)/charset Set/stringEncoding(forURICharset:)/percentEncodeURIComponent/makeEncodeURIBlock
//   - CovMap: closure#1 L24-43 @0x1000f6708；L48-55 @0x1000f6b34；L61-85 @0x1000f6604 + @0x1000f6c94；L89-101 @0x1000f74ac；L106-109 @0x1000f7d00；L125-143 @0x10003f800/0x1000f5bd8；L147-156 @0x1000f88fc；L163-182 @0x1000f8ad4；L202-218 @0x1000f8f74；L220-224 @0x1000f56c4 + @0x1000f92f8
//   - IDA: 上述地址
//   - Util 桥键 48 条：webView/webViewGetSource/webViewGetOverrideUrl/__qireaderAsyncWebView/_asyncWebView/…/toNumChapter/put/_varGet/base64DecodeToByteArray/hexDecodeToByteArray/hexEncodeToString/md5Encode/md5Encode16/digestHex/logType/decodeURI/strToBytes/bytesToStr/randomUUID/currentTime/getWebViewUA
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（工厂族签名确证；保留字符集见读后记仍不清楚 3）
// 还原: 2026-11-19


import Foundation

extension JsBridgeTemplates {

    /// 伪代码 closure #1（0x1000f6708，L24-43）。
    static func makeBase64DecodeBlock() -> @convention(block) (String) -> String {
        { input in
            guard let data = Data(base64Encoded: input) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    /// 伪代码 closure（0x1000f6b34，L48-55）。
    static func makeBase64DecodeToByteArrayBlock() -> @convention(block) (String) -> [UInt8] {
        { input in
            guard let data = Data(base64Encoded: input) else { return [] }
            return Array(data)
        }
    }

    /// 伪代码 0x1000f6604（L61-85）+ closure（0x1000f6c94）。
    static func makeHexDecodeToStringBlock() -> @convention(block) (String) -> String {
        { input in
            var bytes: [UInt8] = []
            let characters = Array(input)
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

    /// 伪代码 closure（0x1000f74ac，L89-101）。
    static func makeHexDecodeToByteArrayBlock() -> @convention(block) (String) -> [UInt8] {
        { input in
            var bytes: [UInt8] = []
            let characters = Array(input)
            guard characters.count % 2 == 0 else { return [] }
            var index = 0
            while index < characters.count {
                guard let high = characters[index].hexDigitValue,
                    let low = characters[index + 1].hexDigitValue
                else { return [] }
                bytes.append(UInt8(high * 16 + low))
                index += 2
            }
            return bytes
        }
    }

    /// 伪代码 closure（0x1000f7d00，L106-109）。
    static func makeHexEncodeToStringBlock() -> @convention(block) ([UInt8]) -> String {
        { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// 伪代码 0x10003f800/0x1000f5bd8（L125-143）：digestHex（md5Encode16 取中段，推断 2）。
    static func makeDigestHexBlock() -> @convention(block) (String, String) -> String {
        { input, mode in
            CryptoBridge.digest(input, mode: mode)
        }
    }

    /// 伪代码 0x1000f8ad4（L163-182）。
    static func stringEncoding(forURICharset charset: String?) -> String.Encoding {
        guard let charset else { return .utf8 }
        let lowered = charset.lowercased()
        if lowered.contains("gbk") || lowered.contains("gb2312") {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            ))
        }
        return .utf8
    }

    /// 伪代码 0x1000f8f74（L202-218）。
    static func percentEncodeURIComponent(_ text: String, charset: String.Encoding) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._!~*'()")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    /// 伪代码 0x1000f56c4（L220-224）+ closure（0x1000f92f8）。
    static func makeEncodeURIBlock() -> @convention(block) (String) -> String {
        { input in
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-_.!~*'();/?:@&=+$,#[]")
            return input.addingPercentEncoding(withAllowedCharacters: allowed) ?? input
        }
    }

    /// Util 桥键注册（48 条字面量中的工具族）。
    static func registerUtilBridges(in context: JSImportBridgeContext) {
        let bridges: [String: Any] = [
            "base64DecodeToByteArray": makeBase64DecodeToByteArrayBlock(),
            "hexDecodeToByteArray": makeHexDecodeToByteArrayBlock(),
            "hexEncodeToString": makeHexEncodeToStringBlock(),
            "md5Encode": { (input: String) -> String in
                CryptoBridge.digest(input, mode: "md5")
            },
            "md5Encode16": { (input: String) -> String in
                let full = CryptoBridge.digest(input, mode: "md5")
                return String(full.dropFirst(8).dropLast(8))
            },
            "digestHex": makeDigestHexBlock(),
            "decodeURI": { (input: String) -> String in
                input.removingPercentEncoding ?? input
            },
            "strToBytes": { (input: String) -> [UInt8] in
                Array(input.utf8)
            },
            "bytesToStr": { (bytes: [UInt8]) -> String in
                String(bytes: bytes, encoding: .utf8) ?? ""
            },
            "randomUUID": { () -> String in
                UUID().uuidString
            },
            "currentTime": { () -> Int64 in
                Int64(Date().timeIntervalSince1970)
            },
        ]
        for (key, value) in bridges {
            context.context.setObject(value, forKeyedSubscript: key as NSString)
        }
    }
}

extension JsBridgeTemplates {

    /// 伪代码 0x1000f8070（L250-288）：encodeURIComponent 桥——charset
    /// 域 + percentEncodeURIComponent 链（makeEncodeURIBlock 域确证）。
    static func installEncodeURIBridge(in context: JSContext) {
        context.setObject(
            makeEncodeURIBlock(),
            forKeyedSubscript: "encodeURIComponent" as NSString)
    }

    /// 伪代码 0x1000f63a0（L396-427）：工具桥注册（单数域——
    /// registerUtilBridges 主体路由 + base64/hex/digest 键族）。
    static func registerUtilBridge(in context: JSContext) {
        registerUtilBridges(in: JSImportBridgeContext(context: context))
    }
}
