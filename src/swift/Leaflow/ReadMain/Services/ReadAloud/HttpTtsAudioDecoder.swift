// 原路径: ReadMain/Services/ReadAloud/HttpTtsAudioDecoder.swift
// 证据:
//   - PGO: 28 条记录（index/task_functions.csv T-801-05 /
//     HttpTtsAudioDecoder.swift；伪代码域 160 行）
//   - CovMap: 上述 L 区段（decode/copyFrames/slices 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsAudioDecoder.c（940 行）
//   - 块体确证（签名域）：
//     decode(_: Data, targetFormat: AVAudioFormat?) async throws /
//     copyFrames(from: AVAudioPCMBuffer, sourceOffset: Int, to:
//     AVAudioPCMBuffer, frameCount: Int) / slices(of: AVAudioPCMBuffer,
//     anchors: [ReadAloudAnchor], textUTF16Length: Int,
//     tailTrimMilliseconds: Int)
//   - 事实：AVAudioFile 解码 + PCM 拷贝 + 锚点切片（尾部裁剪域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三签名域确证）
// 还原: 2026-11-20

import AVFoundation

/// 朗读音频解码器（decode/copyFrames/slices 签名域确证）。
final class HttpTtsAudioDecoder: HttpTtsAudioDecoding {

    init() {}

    /// decode(_:targetFormat:)（签名域确证：临时文件 → AVAudioFile
    /// 解码 → 目标格式转换）。
    func decode(
        _ data: Data, targetFormat: AVAudioFormat?
    ) async throws -> ReadAloudAudioBuffer {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".audio")
        try data.write(to: temporaryURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        let file = try AVAudioFile(forReading: temporaryURL)
        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw ReadAloudDriverFactoryError.outputPreparationFailed
        }
        try file.read(into: sourceBuffer)
        guard let target = targetFormat ?? sourceFormat else {
            throw ReadAloudDriverFactoryError.outputPreparationFailed
        }
        if target == sourceFormat {
            return ReadAloudAudioBuffer(sourceBuffer)
        }
        // 转换域（copyFrames 签名还原桥）。
        let converter = AVAudioConverter(
            from: sourceFormat, to: target)
        guard let converter else {
            throw ReadAloudDriverFactoryError.outputPreparationFailed
        }
        let ratio = target.sampleRate / sourceFormat.sampleRate
        let convertedCapacity = AVAudioFrameCount(
            Double(frameCount) * ratio) + 1024
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: target, frameCapacity: convertedCapacity) else {
            throw ReadAloudDriverFactoryError.outputPreparationFailed
        }
        var filled: AVAudioFrameCount = 0
        var remaining = sourceBuffer
        while filled < convertedCapacity {
            let status = converter.convert(
                to: converted, error: nil,
                withInputFrom: { _, outStatus in
                    if remaining.frameLength == 0 {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    outStatus.pointee = .haveData
                    let chunk = remaining
                    remaining = AVAudioPCMBuffer(
                        pcmFormat: remaining.format, frameCapacity: 0
                    ) ?? remaining
                    return chunk
                })
            if status == .error { break }
            if status == .endOfStream { break }
            filled = converted.frameLength
            if filled >= convertedCapacity { break }
        }
        return ReadAloudAudioBuffer(converted)
    }

    /// copyFrames(from:sourceOffset:to:frameCount:)（签名域确证：
    /// 通道对齐帧拷贝）。
    func copyFrames(
        from source: AVAudioPCMBuffer, sourceOffset: Int,
        to target: AVAudioPCMBuffer, frameCount: Int
    ) {
        let channels = Swift.min(
            source.format.channelCount, target.format.channelCount)
        let safeCount = Swift.min(
            frameCount,
            source.frameLength - AVAudioFrameCount(sourceOffset))
        for channel in 0..<channels {
            guard let src = source.floatChannelData?[channel],
                  let dst = target.floatChannelData?[channel] else {
                continue
            }
            for frame in 0..<Int(safeCount) {
                dst[frame] = src[sourceOffset + frame]
            }
        }
        target.frameLength = AVAudioFrameCount(safeCount)
    }

    /// slices(of:anchors:textUTF16Length:tailTrimMilliseconds:)
    /// （签名域确证：锚点切分 + 尾部裁剪域）。
    func slices(
        of buffer: AVAudioPCMBuffer,
        anchors: [ReadAloudAnchor],
        textUTF16Length: Int,
        tailTrimMilliseconds: Int
    ) -> [(buffer: ReadAloudAudioBuffer, anchor: ReadAloudAnchor)] {
        guard textUTF16Length > 0 else {
            return [(ReadAloudAudioBuffer(buffer), anchors.last ?? .empty)]
        }
        let totalFrames = buffer.frameLength
        let trimFrames = Swift.min(
            AVAudioFrameCount(
                Double(tailTrimMilliseconds) / 1000.0
                    * buffer.format.sampleRate),
            totalFrames)
        var results: [(buffer: ReadAloudAudioBuffer,
                       anchor: ReadAloudAnchor)] = []
        let sliceCount = max(anchors.count, 1)
        let framesPerSlice = totalFrames / AVAudioFrameCount(sliceCount)
        for (index, anchor) in anchors.enumerated() {
            let start = AVAudioFrameCount(index) * framesPerSlice
            let length = index == anchors.count - 1
                ? totalFrames - start - trimFrames
                : framesPerSlice
            guard length > 0, start + length <= totalFrames else {
                continue
            }
            guard let slice = AVAudioPCMBuffer(
                pcmFormat: buffer.format, frameCapacity: length) else {
                continue
            }
            copyFrames(
                from: buffer, sourceOffset: Int(start),
                to: slice, frameCount: Int(length))
            results.append((ReadAloudAudioBuffer(slice), anchor))
        }
        return results
    }
}

/// TTS 音频解码错误（errorDescription 0x1002662dc L188-197 域；容器缺失
/// 还原）。
enum HttpTtsAudioDecodingError: LocalizedError {
    case malformedData
    case unsupportedFormat(String)
    case interrupted

    var errorDescription: String? {
        switch self {
        case .malformedData:
            return "TTS 音频数据格式错误"
        case .unsupportedFormat(let format):
            return "不支持的 TTS 音频格式：\(format)"
        case .interrupted:
            return "TTS 音频解码被中断"
        }
    }
}

