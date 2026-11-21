// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsBridgeShared+SymmetricCrypto.swift
// 证据:
//   - PGO: JSImportSymmetricCryptoStore(createState/decryptBytes×2/encryptBase64/encryptHex/data(from:)/decodeCipherInput)/JSImportSymmetricCryptoStoreRegistry.store(for:)
//   - CovMap: createState L17-27 @0x1000f33b0；decryptBytes L38-48 @0x1000f34e4 / L50-59 @0x1000f3c5c；encryptBase64 L61-73 @0x1000f40c0；encryptHex L75-87 @0x1000f4340；data(from:) L96-98 @0x1000f3430；decodeCipherInput L100-111 @0x1000f39d4；registry L126-136 @0x1000f32d4
//   - IDA: 上述地址
//   - 键：__qireaderCryptoUtf8Bytes/__qireaderCryptoBase64EncodeBytes/__qireaderCryptoBytesToUtf8String/__qireaderCreateSymmetricCryptoState/__qireaderSetSymmetricCryptoIv/__qireaderSymmetricDecryptBytesFromString/__qireaderSymmetricDecryptBytes/__qireaderSymmetricEncryptBase64/__qireaderSymmetricEncryptHex
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（state 注册表确证；密文输入格式见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// 对称加密状态（__qireaderCreateSymmetricCryptoState 创建）。
struct JSImportSymmetricCryptoState {
    var transformer: String
    var key: [UInt8]
    var iv: [UInt8]?
}

/// state 注册表（NSMapTable by JSContext，推断 1）。
final class JSImportSymmetricCryptoStore {

    private var states: [String: JSImportSymmetricCryptoState] = [:]
    private let lock = NSLock()

    /// 伪代码 0x1000f33b0（L17-27）。
    func createState(transformer: String, key: [UInt8], iv: [UInt8]?) -> String {
        let stateId = UUID().uuidString
        lock.lock()
        defer { lock.unlock() }
        states[stateId] = JSImportSymmetricCryptoState(
            transformer: transformer, key: key, iv: iv
        )
        return stateId
    }

    /// 伪代码 0x1000f34e4（L38-48）/0x1000f3c5c（L50-59）。
    func decryptBytes(stateId: String, input: [UInt8], fromString: Bool) -> [UInt8] {
        lock.lock()
        defer { lock.unlock() }
        guard let state = states[stateId] else { return [] }
        let data = Data(input)
        let output = CryptoBridge.cipherProcess(
            input: String(decoding: data, as: UTF8.self),
            key: String(decoding: Data(state.key), as: UTF8.self),
            iv: state.iv.map { String(decoding: Data($0), as: UTF8.self) } ?? "",
            mode: state.transformer
        )
        return Array(output.utf8)
    }

    /// 伪代码 0x1000f40c0（L61-73）。
    func encryptBase64(stateId: String, input: [UInt8]) -> String {
        let bytes = decryptBytes(stateId: stateId, input: input, fromString: false)
        return Data(bytes).base64EncodedString()
    }

    /// 伪代码 0x1000f4340（L75-87）。
    func encryptHex(stateId: String, input: [UInt8]) -> String {
        let bytes = decryptBytes(stateId: stateId, input: input, fromString: false)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// 伪代码 0x1000f3430（L96-98）。
    static func data(from bytes: [UInt8]) -> Data {
        Data(bytes)
    }

    /// 伪代码 0x1000f39d4（L100-111）。
    static func decodeCipherInput(_ input: String) -> [UInt8] {
        if let data = Data(base64Encoded: input) {
            return Array(data)
        }
        if input.count % 2 == 0, input.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil {
            var bytes: [UInt8] = []
            let characters = Array(input)
            var index = 0
            while index + 1 < characters.count {
                if let high = characters[index].hexDigitValue,
                    let low = characters[index + 1].hexDigitValue {
                    bytes.append(UInt8(high * 16 + low))
                }
                index += 2
            }
            return bytes
        }
        return Array(input.utf8)
    }
}

/// registry（NSMapTable<JSContext, Store>，伪代码 0x1000f32d4 L126-136）。
final class JSImportSymmetricCryptoStoreRegistry {
    private var stores: [ObjectIdentifier: JSImportSymmetricCryptoStore] = [:]
    private let lock = NSLock()

    func store(for context: JSContext) -> JSImportSymmetricCryptoStore {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(context)
        if let existing = stores[key] {
            return existing
        }
        let created = JSImportSymmetricCryptoStore()
        stores[key] = created
        return created
    }
}

extension JsBridgeTemplates {

    /// 伪代码 0x1000f3100（L196-237）：对称加密桥注册——store 域
    ///（createState/decryptBytes/encryptBase64/encryptHex 四键域确证）。
    static func registerSymmetricCryptoBridge(in context: JSContext) {
        let store = JSImportSymmetricCryptoStore()
        let crypto = JSValue(newObjectIn: context)!
        crypto.setObject(
            { (transformer: String, key: String, iv: String?) -> String in
                store.createState(
                    transformer: transformer,
                    key: Array(key.utf8),
                    iv: iv.map { Array($0.utf8) })
            } as @convention(block) (String, String, String?) -> String,
            forKeyedSubscript: "createState" as NSString)
        crypto.setObject(
            { (stateId: String, input: String, fromString: Bool) -> String in
                let bytes = store.decryptBytes(
                    stateId: stateId,
                    input: Array(input.utf8),
                    fromString: fromString)
                return String(bytes: bytes, encoding: .utf8) ?? ""
            } as @convention(block) (String, String, Bool) -> String,
            forKeyedSubscript: "decrypt" as NSString)
        crypto.setObject(
            { (stateId: String, input: String) -> String in
                store.encryptBase64(
                    stateId: stateId, input: Array(input.utf8))
            } as @convention(block) (String, String) -> String,
            forKeyedSubscript: "encryptBase64" as NSString)
        context.setObject(
            crypto, forKeyedSubscript: "crypto" as NSString)
    }
}

