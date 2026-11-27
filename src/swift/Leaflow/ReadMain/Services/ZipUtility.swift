// 原路径: ReadMain/Services/ZipUtility.swift
// 证据:
//   - PGO: 26 条记录（index/task_functions.csv T-901-04 /
//     ZipUtility.swift；18 函数，伪代码域 300 行）
//   - CovMap: 上述 L 区段（createZip/extractZip/findEOCD/
//     parseCentralDirectoryEntry/parseLocalFileHeader/inflateRawDeflate/
//     inflateWithBuffer/adler32Checksum/readUInt32/readUInt16 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ZipUtility.c
//     （1001 行）
//   - 块体确证（签名域）：
//     ZipError.errorDescription getter / createZip(from:to:) throws /
//     extractZip(from:to:) throws / findEOCD(in: Data) -> EOCDRecord? /
//     parseCentralDirectoryEntry(data:offset:) -> CentralDirectoryEntry? /
//     parseLocalFileHeader(data:offset:) -> LocalFileHeader? /
//     inflateRawDeflate(_:expectedSize:) / inflateWithBuffer(
//     _:expectedSize:) / adler32Checksum(Data) / readUInt32(_:at:) /
//     readUInt16(_:at:)
//   - 事实：ZIP 三记录域（EOCD 0x06054b50 / central 0x02014b50 /
//     local 0x04034b50）+ raw deflate 域 + adler32 校验域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十一签名域确证）
// 还原: 2026-11-20

import Foundation
import zlib

/// ZIP 工具（createZip/extractZip 签名域确证）。
enum ZipUtility {

    /// 错误（errorDescription 签名域确证）。
    enum ZipError: LocalizedError {
        case invalidArchive
        case unsupportedCompression
        case checksumMismatch

        var errorDescription: String? {
            switch self {
            case .invalidArchive:
                return "ZIP 归档无效"
            case .unsupportedCompression:
                return "不支持的压缩方式"
            case .checksumMismatch:
                return "解压校验失败"
            }
        }
    }

    /// EOCD 记录（EOCDRecord 域还原桥）。
    struct EOCDRecord {
        let entryCount: Int
        let centralDirectoryOffset: Int
        let centralDirectorySize: Int
    }

    /// 中央目录条目（CentralDirectoryEntry 域还原桥）。
    /// extraCount：extra+comment 长度和（游标推进域确证，wave-16 补字段）。
    struct CentralDirectoryEntry {
        let fileName: String
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
        let compressionMethod: UInt16
        let extraCount: Int
        let fileNameLength: Int
        let checksum: UInt32
    }

    /// 本地文件头（LocalFileHeader 域还原桥）。
    struct LocalFileHeader {
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let fileNameLength: Int
        let extraFieldLength: Int
    }

    private static let eocdSignature: UInt32 = 0x0605_4b50
    private static let centralSignature: UInt32 = 0x0201_4b50
    private static let localSignature: UInt32 = 0x0403_4b50

    // MARK: 打包域（createZip 签名域确证）

    /// 0x1003f2588/0x1003f332c：协调完整目录上传归档，再复制到目标文件。
    static func createZip(from directory: URL, to output: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        var copied = false
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading,
            error: &coordinationError) { archiveURL in
                do {
                    if FileManager.default.fileExists(atPath: output.path) {
                        try FileManager.default.removeItem(at: output)
                    }
                    try FileManager.default.copyItem(at: archiveURL, to: output)
                    copied = true
                } catch { copyError = error }
            }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        guard copied else { throw ZipError.invalidArchive }
    }

    /// extractZip(from:to:)（签名域确证：findEOCD → central 遍历 →
    /// inflate 域）。
    static func extractZip(from archive: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destination, withIntermediateDirectories: true)
        let data = try Data(contentsOf: archive)
        guard let eocd = findEOCD(in: data),
              eocd.centralDirectoryOffset <= data.count,
              eocd.centralDirectorySize <= data.count - eocd.centralDirectoryOffset else {
            throw ZipError.invalidArchive
        }
        var cursor = eocd.centralDirectoryOffset
        for _ in 0..<eocd.entryCount {
            guard let entry = parseCentralDirectoryEntry(
                data: data, offset: cursor) else {
                throw ZipError.invalidArchive
            }
            cursor += 46 + entry.fileNameLength + entry.extraCount
            guard let header = parseLocalFileHeader(
                data: data, offset: entry.localHeaderOffset) else {
                throw ZipError.invalidArchive
            }
            let dataStart = entry.localHeaderOffset + 30
                + header.fileNameLength + header.extraFieldLength
            guard dataStart <= data.count, entry.compressedSize <= data.count - dataStart,
                  header.compressionMethod == entry.compressionMethod else {
                throw ZipError.invalidArchive
            }
            let payload = data.subdata(
                in: dataStart..<(dataStart + entry.compressedSize))
            let inflated: Data?
            switch header.compressionMethod {
            case 0:
                inflated = payload
            case 8:
                inflated = inflateRawDeflate(
                    payload, expectedSize: entry.uncompressedSize)
            default:
                throw ZipError.unsupportedCompression
            }
            guard let inflated, inflated.count == entry.uncompressedSize, crc32(inflated) == entry.checksum else {
                throw ZipError.checksumMismatch
            }
            let name = entry.fileName
            let root = destination.resolvingSymlinksInPath().standardizedFileURL.path
            let target = destination.appendingPathComponent(name.replacingOccurrences(of: "\\", with: "/"))
                .resolvingSymlinksInPath().standardizedFileURL
            guard !name.isEmpty, !name.hasPrefix("/"), target.path.hasPrefix(root + "/") else {
                throw ZipError.invalidArchive
            }
            if name.hasSuffix("/") {
                try fileManager.createDirectory(
                    at: target,
                    withIntermediateDirectories: true)
                continue
            }
            try fileManager.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try inflated.write(to: target, options: .atomic)
        }
    }

    // MARK: 解析域（findEOCD/parseCentralDirectoryEntry/
    // parseLocalFileHeader 签名域确证）

    /// findEOCD(in:)（签名域确证：尾部倒扫域）。
    static func findEOCD(in data: Data) -> EOCDRecord? {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { return nil }
        var index = bytes.count - 22
        while index >= 0 {
            if readUInt32(data, at: index) == eocdSignature {
                let commentLength = Int(readUInt16(data, at: index + 20))
                guard index + 22 + commentLength == bytes.count else { index -= 1; continue }
                let entryCount = Int(readUInt16(data, at: index + 10))
                let size = Int(readUInt32(data, at: index + 12))
                let offset = Int(readUInt32(data, at: index + 16))
                return EOCDRecord(
                    entryCount: entryCount,
                    centralDirectoryOffset: offset,
                    centralDirectorySize: size)
            }
            index -= 1
        }
        return nil
    }

    /// parseCentralDirectoryEntry(data:offset:)（签名域确证）。
    static func parseCentralDirectoryEntry(
        data: Data, offset: Int
    ) -> CentralDirectoryEntry? {
        guard offset >= 0, offset <= data.count, data.count - offset >= 46,
              readUInt32(data, at: offset) == centralSignature else {
            return nil
        }
        let nameLength = Int(readUInt16(data, at: offset + 28))
        let extraCount = Int(readUInt16(data, at: offset + 30))
        let commentCount = Int(readUInt16(data, at: offset + 32))
        guard nameLength + extraCount + commentCount <= data.count - offset - 46 else { return nil }
        guard let name = String(
            data: data.subdata(in: (offset + 46)..<(offset + 46 + nameLength)),
            encoding: .utf8) else { return nil }
        return CentralDirectoryEntry(
            fileName: name,
            compressedSize: Int(readUInt32(data, at: offset + 20)),
            uncompressedSize: Int(readUInt32(data, at: offset + 24)),
            localHeaderOffset: Int(readUInt32(data, at: offset + 42)),
            compressionMethod: readUInt16(data, at: offset + 10),
            extraCount: extraCount + commentCount, fileNameLength: nameLength,
            checksum: readUInt32(data, at: offset + 16))
    }

    /// parseLocalFileHeader(data:offset:)（签名域确证）。
    static func parseLocalFileHeader(
        data: Data, offset: Int
    ) -> LocalFileHeader? {
        guard offset >= 0, offset <= data.count, data.count - offset >= 30,
              readUInt32(data, at: offset) == localSignature else {
            return nil
        }
        return LocalFileHeader(
            compressionMethod: readUInt16(data, at: offset + 8),
            compressedSize: Int(readUInt32(data, at: offset + 18)),
            uncompressedSize: Int(readUInt32(data, at: offset + 22)),
            fileNameLength: Int(readUInt16(data, at: offset + 26)),
            extraFieldLength: Int(readUInt16(data, at: offset + 28)))
    }

    // MARK: 解压域（inflateRawDeflate/inflateWithBuffer 签名域确证）

    /// inflateRawDeflate(_:expectedSize:)（签名域确证：raw deflate 域）。
    static func inflateRawDeflate(
        _ data: Data, expectedSize: Int
    ) -> Data? {
        var stream = z_stream()
        guard inflateInit2_(
            &stream, -MAX_WBITS, ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }
        return inflateWith(stream: &stream, input: data,
                           expectedSize: expectedSize)
    }

    /// inflateWithBuffer(_:expectedSize:)（签名域确证：zlib 域）。
    static func inflateWithBuffer(
        _ data: Data, expectedSize: Int
    ) -> Data? {
        var stream = z_stream()
        guard inflateInit_(
            &stream, ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }
        return inflateWith(stream: &stream, input: data,
                           expectedSize: expectedSize)
    }

    private static func inflateWith(
        stream: inout z_stream, input: Data, expectedSize: Int
    ) -> Data? {
        guard expectedSize >= 0 else { return nil }
        var inflated = Data()
        var chunk = [UInt8](repeating: 0, count: 16_384)
        var status: Int32 = Z_OK
        input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            stream.next_in = UnsafeMutablePointer<UInt8>(
                mutating: raw.bindMemory(to: UInt8.self).baseAddress)
            stream.avail_in = uInt(input.count)
            repeat {
                var produced = 0
                chunk.withUnsafeMutableBufferPointer { buffer in
                    stream.next_out = buffer.baseAddress
                    stream.avail_out = uInt(buffer.count)
                    status = inflate(&stream, Z_NO_FLUSH)
                    produced = buffer.count - Int(stream.avail_out)
                }
                guard status == Z_OK || status == Z_STREAM_END,
                      produced <= expectedSize - inflated.count else {
                    status = Z_DATA_ERROR
                    return
                }
                inflated.append(chunk, count: produced)
            } while status == Z_OK && stream.avail_out == 0
        }
        return status == Z_STREAM_END && inflated.count == expectedSize ? inflated : nil
    }

    // MARK: 校验/读取域（adler32Checksum/readUInt32/readUInt16 域确证）

    /// adler32Checksum(Data)（签名域确证）。
    static func adler32Checksum(_ data: Data) -> UInt32 {
        let modulus: UInt32 = 65_521
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in [UInt8](data) {
            a = (a + UInt32(byte)) % modulus
            b = (b + a) % modulus
        }
        return (b << 16) | a
    }

    /// readUInt32(_:at:)（签名域确证：小端域）。
    static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let bytes = [UInt8](data)
        guard offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    /// readUInt16(_:at:)（签名域确证：小端域）。
    static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        let bytes = [UInt8](data)
        guard offset + 2 <= bytes.count else { return 0 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    // MARK: 帮助域（字节序写入域）

    private static func fromUInt32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func fromUInt16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in [UInt8](data) {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1)
                    ^ ((crc & 1 == 1) ? 0xEDB8_8320 : 0)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
