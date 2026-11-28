// 原路径: ReadMain/Services/ReadAloud/HttpTtsSynthesizer.swift。
// 0x10027fe60/类型表5163：多帧动作、状态、发送追加、音频上限和完成条件。
import Foundation

extension HttpTtsSynthesizer {
    func requestWebSocketAudio(request: URLRequest, configuration: HttpTtsWebSocketConfiguration,
                               source: HttpTts, text: String, speed: Int) async throws -> Data {
        let connection = try await webSocketTransport.connect(request: request, configuration: configuration)
        defer { connection.close() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            for message in configuration.messages { try await connection.send(message) }
            var audio = Data()
            var stateJSON: String?
            while true {
                try Task.checkCancellation()
                let frame = try await receive(from: connection, timeoutMilliseconds: configuration.receiveTimeoutMilliseconds)
                let action = try HttpTtsWebSocketAction.evaluate(frame: frame, script: configuration.onMessageScript,
                    stateJSON: stateJSON, source: source, text: text, speed: speed)
                if let error = action.errorMessage, !error.isEmpty { throw HttpTtsWebSocketError.sourceReported(error) }
                if let chunk = action.audio {
                    guard chunk.count <= configuration.maximumAudioBytes - audio.count else {
                        throw HttpTtsWebSocketError.audioTooLarge(configuration.maximumAudioBytes)
                    }
                    audio.append(chunk)
                }
                stateJSON = action.stateJSON ?? stateJSON
                for message in action.messages { try await connection.send(message) }
                if action.done {
                    guard !audio.isEmpty else { throw HttpTtsWebSocketError.noAudioReceived }
                    return audio
                }
            }
        } onCancel: { connection.close() }
    }

    private func receive(from connection: HttpTtsWebSocketConnection,
                          timeoutMilliseconds: Int) async throws -> HttpTtsWebSocketFrame {
        try await withThrowingTaskGroup(of: HttpTtsWebSocketFrame.self) { group in
            group.addTask { try await connection.receive() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(1, timeoutMilliseconds)) * 1_000_000)
                connection.close()
                throw HttpTtsWebSocketError.receiveTimeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw HttpTtsWebSocketError.connectionClosedBeforeCompletion }
            return first
        }
    }
}
