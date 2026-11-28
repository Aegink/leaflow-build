// 原路径: ReadMain/Services/ReadAloud/HttpTtsWebSocket.swift。
// 类型表5137，0x100288710：URLSessionWebSocketTask真实文本/二进制收发。
import Foundation

struct URLSessionHttpTtsWebSocketTransport: HttpTtsWebSocketTransporting {
    var session: URLSession = .shared

    func connect(request: URLRequest, configuration: HttpTtsWebSocketConfiguration) async throws -> HttpTtsWebSocketConnection {
        try Task.checkCancellation()
        var request = request
        request.timeoutInterval = Double(configuration.connectTimeoutMilliseconds) / 1000
        let task = session.webSocketTask(with: request)
        task.resume()
        return URLSessionHttpTtsWebSocketConnection(task: task)
    }
}

final class URLSessionHttpTtsWebSocketConnection: HttpTtsWebSocketConnection {
    private let task: URLSessionWebSocketTask
    init(task: URLSessionWebSocketTask) { self.task = task }

    func send(_ message: HttpTtsWebSocketOutgoingMessage) async throws {
        switch message {
        case .text(let text): try await task.send(.string(text))
        case .binary(let data): try await task.send(.data(data))
        }
    }

    func receive() async throws -> HttpTtsWebSocketFrame {
        switch try await task.receive() {
        case .string(let text): return .init(data: Data(text.utf8), isText: true)
        case .data(let data): return .init(data: data, isText: false)
        @unknown default: throw HttpTtsWebSocketError.invalidMessage
        }
    }

    func close() { task.cancel(with: .normalClosure, reason: nil) }
}
