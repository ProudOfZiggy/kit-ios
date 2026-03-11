//
//  Copyright (c) 2025 TON Connect
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

// MARK: - WebSocketActor

@globalActor actor WebSocketActor: GlobalActor {
    static let shared = WebSocketActor()
}

// MARK: - WebSocketEvent

enum WebSocketEvent: Sendable {
    case open(negotiatedProtocol: String?)
    case message(WebSocketMessage)
    case close(code: Int, reason: String, wasClean: Bool)
    case error(String)
}

enum WebSocketMessage: Sendable {
    case text(String)
    case binary(Data)
}

// MARK: - WebSocketTask

@WebSocketActor
final class WebSocketTask {
    enum State {
        case connecting
        case open
        case closing
        case closed
    }

    private var state: State = .connecting
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    private let protocols: [String]
    private var continuation: AsyncStream<WebSocketEvent>.Continuation?
    private var delegate: SessionDelegate?

    init(url: URL, protocols: [String]) {
        self.url = url
        self.protocols = protocols
    }

    func start() -> AsyncStream<WebSocketEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else { return }
            self.continuation = continuation

            let delegate = SessionDelegate()
            self.delegate = delegate

            delegate.onOpen = { [weak self] negotiatedProtocol in
                Task { @WebSocketActor [weak self] in
                    guard let self, self.state == .connecting else { return }
                    self.state = .open
                    self.continuation?.yield(.open(negotiatedProtocol: negotiatedProtocol))
                    await self.receiveLoop()
                }
            }

            delegate.onClose = { [weak self] closeCode, reason in
                Task { @WebSocketActor [weak self] in
                    guard let self else { return }
                    let wasClean = self.state == .closing || self.state == .open
                    self.state = .closed
                    let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    self.continuation?.yield(.close(
                        code: closeCode.rawValue,
                        reason: reasonString,
                        wasClean: wasClean
                    ))
                    self.continuation?.finish()
                }
            }

            delegate.onComplete = { [weak self] error in
                Task { @WebSocketActor [weak self] in
                    guard let self, self.state != .closed else { return }
                    if let error {
                        self.continuation?.yield(.error(error.localizedDescription))
                    }
                    self.state = .closed
                    self.continuation?.yield(.close(
                        code: 1006,
                        reason: "",
                        wasClean: false
                    ))
                    self.continuation?.finish()
                }
            }

            let session = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )
            self.urlSession = session

            var request = URLRequest(url: self.url)
            if !self.protocols.isEmpty {
                request.setValue(
                    self.protocols.joined(separator: ", "),
                    forHTTPHeaderField: "Sec-WebSocket-Protocol"
                )
            }

            let task = session.webSocketTask(with: request)
            self.webSocketTask = task
            task.resume()

            continuation.onTermination = { [weak self] _ in
                Task { @WebSocketActor [weak self] in
                    self?.cancel()
                }
            }
        }
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard state == .open, let webSocketTask else { return }
        try await webSocketTask.send(message)
    }

    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard state == .open || state == .connecting else { return }
        state = .closing
        webSocketTask?.cancel(with: code, reason: reason)
    }

    func cancel() {
        guard state != .closed else { return }
        state = .closed
        webSocketTask?.cancel()
        urlSession?.invalidateAndCancel()
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }
        while state == .open {
            do {
                let message = try await webSocketTask.receive()
                switch message {
                case .string(let text):
                    continuation?.yield(.message(.text(text)))
                case .data(let data):
                    continuation?.yield(.message(.binary(data)))
                @unknown default:
                    break
                }
            } catch {
                break
            }
        }
    }
}

// MARK: - SessionDelegate

extension WebSocketTask {
    final class SessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
        var onOpen: ((String?) -> Void)?
        var onClose: ((URLSessionWebSocketTask.CloseCode, Data?) -> Void)?
        var onComplete: ((Error?) -> Void)?

        func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didOpenWithProtocol protocol: String?
        ) {
            onOpen?(`protocol`)
        }

        func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason: Data?
        ) {
            onClose?(closeCode, reason)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            onComplete?(error)
        }
    }
}
