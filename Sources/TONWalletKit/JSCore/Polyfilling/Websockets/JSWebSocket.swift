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

@preconcurrency import JavaScriptCore

// MARK: - JSWebSocketExport

@objc private protocol JSWebSocketExport: JSExport {
    init?(url: String, protocols: JSValue)

    var url: String { get }
    var readyState: Int { get }
    var `protocol`: String { get }
    var extensions: String { get }
    var bufferedAmount: Int { get }
    var binaryType: String { get set }

    var onopen: JSValue? { get set }
    var onmessage: JSValue? { get set }
    var onclose: JSValue? { get set }
    var onerror: JSValue? { get set }

    func send(_ data: JSValue)
    @objc(close::) func close(_ code: JSValue, _ reason: JSValue)

    @objc(addEventListener::) func addEventListener(_ type: String, _ listener: JSValue)
    @objc(removeEventListener::) func removeEventListener(_ type: String, _ listener: JSValue)
}

// MARK: - JSWebSocket

@objc(WebSocket) class JSWebSocket: NSObject, JSWebSocketExport {

    // MARK: - Properties

    private(set) var url: String
    private(set) var readyState: Int = 0
    private(set) var `protocol`: String = ""
    private(set) var extensions: String = ""
    private(set) var bufferedAmount: Int = 0
    var binaryType: String = "blob"

    var onopen: JSValue?
    var onmessage: JSValue?
    var onclose: JSValue?
    var onerror: JSValue?

    // MARK: - Private

    private var eventListeners: [String: [JSManagedValue]] = [:]
    private var task: WebSocketTask?
    private weak var context: JSContext?

    // MARK: - Init

    required init?(url urlString: String, protocols: JSValue) {
        guard let context = JSContext.current() else { return nil }
        self.context = context
        self.url = urlString

        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "ws" || scheme == "wss" else {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to construct 'WebSocket': The URL '\(urlString)' is invalid.",
                in: context
            )
            return nil
        }

        let protocolList: [String]
        if protocols.isUndefined || protocols.isNull {
            protocolList = []
        } else if protocols.isString {
            protocolList = [protocols.toString()]
        } else if protocols.isArray {
            protocolList = protocols.toArray().compactMap { $0 as? String }
        } else {
            protocolList = [protocols.toString()]
        }

        super.init()

        Task { @WebSocketActor in
            let wsTask = WebSocketTask(url: url, protocols: protocolList)
            await MainActor.run { self.task = wsTask }
            let stream = wsTask.start()

            for await event in stream {
                await MainActor.run {
                    self.handleEvent(event)
                }
            }
        }
    }

    // MARK: - send

    func send(_ data: JSValue) {
        guard let context = self.context else { return }

        guard readyState != 0 else {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to execute 'send' on 'WebSocket': Still in CONNECTING state.",
                in: context
            )
            return
        }
        guard readyState == 1 else { return }

        Task { @WebSocketActor in
            guard let task = await MainActor.run(body: { self.task }) else { return }
            do {
                if data.isString {
                    try await task.send(.string(data.toString()))
                } else {
                    let bytes = await MainActor.run { self.extractBytes(from: data, in: context) }
                    if let bytes {
                        try await task.send(.data(bytes))
                    } else {
                        try await task.send(.string(data.toString()))
                    }
                }
            } catch {
                // Send failures will surface through the delegate error path
            }
        }
    }

    // MARK: - close

    @objc(close::)
    func close(_ codeValue: JSValue, _ reasonValue: JSValue) {
        guard readyState == 0 || readyState == 1 else { return }
        guard let context = self.context else { return }

        let code: Int
        if codeValue.isUndefined || codeValue.isNull {
            code = 1000
        } else {
            code = Int(codeValue.toInt32())
            if code != 1000 && !(3000...4999).contains(code) {
                context.exception = JSValue(
                    newErrorFromMessage: "Failed to execute 'close' on 'WebSocket': The code must be either 1000, or between 3000 and 4999. \(code) is neither.",
                    in: context
                )
                return
            }
        }

        let reason: String
        if reasonValue.isUndefined || reasonValue.isNull {
            reason = ""
        } else {
            reason = reasonValue.toString() ?? ""
            if reason.utf8.count > 123 {
                context.exception = JSValue(
                    newErrorFromMessage: "Failed to execute 'close' on 'WebSocket': The message must not be greater than 123 bytes.",
                    in: context
                )
                return
            }
        }

        self.readyState = 2

        Task { @WebSocketActor in
            guard let task = await MainActor.run(body: { self.task }) else { return }
            let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure
            task.close(code: closeCode, reason: reason.data(using: .utf8))
        }
    }

    // MARK: - addEventListener / removeEventListener

    @objc(addEventListener::)
    func addEventListener(_ type: String, _ listener: JSValue) {
        guard listener.isObject else { return }
        let managed = JSManagedValue(value: listener, andOwner: self)
        if eventListeners[type] == nil {
            eventListeners[type] = []
        }
        if let managed {
            eventListeners[type]?.append(managed)
        }
    }

    @objc(removeEventListener::)
    func removeEventListener(_ type: String, _ listener: JSValue) {
        eventListeners[type]?.removeAll { managed in
            managed.value?.isEqual(to: listener) ?? false
        }
    }
}

// MARK: - Event Handling

extension JSWebSocket {
    private func handleEvent(_ event: WebSocketEvent) {
        guard let context = self.context else { return }

        switch event {
        case .open(let negotiatedProtocol):
            self.readyState = 1
            self.protocol = negotiatedProtocol ?? ""
            self.dispatchEvent(type: "open", properties: [:], in: context)

        case .message(let message):
            switch message {
            case .text(let text):
                self.dispatchEvent(type: "message", properties: [
                    "data": text as Any,
                    "origin": self.url as Any
                ], in: context)

            case .binary(let data):
                let jsData = self.convertBinaryData(data, in: context)
                self.dispatchEvent(type: "message", properties: [
                    "data": jsData as Any,
                    "origin": self.url as Any
                ], in: context)
            }

        case .close(let code, let reason, let wasClean):
            self.readyState = 3
            self.dispatchEvent(type: "close", properties: [
                "code": code,
                "reason": reason,
                "wasClean": wasClean
            ], in: context)

        case .error(let message):
            self.dispatchEvent(type: "error", properties: [
                "message": message
            ], in: context)
        }
    }

    private func dispatchEvent(
        type: String,
        properties: [String: Any],
        in context: JSContext
    ) {
        let event = JSValue(newObjectIn: context)!
        event.setValue(type, forProperty: "type")
        for (key, value) in properties {
            event.setValue(value, forProperty: key)
        }

        let handler: JSValue?
        switch type {
        case "open": handler = self.onopen
        case "message": handler = self.onmessage
        case "close": handler = self.onclose
        case "error": handler = self.onerror
        default: handler = nil
        }
        if let handler, !handler.isUndefined, !handler.isNull {
            handler.call(withArguments: [event])
        }

        if let listeners = self.eventListeners[type] {
            for managedListener in listeners {
                managedListener.value?.call(withArguments: [event])
            }
        }
    }

    private func convertBinaryData(_ data: Data, in context: JSContext) -> Any {
        let bytes = [UInt8](data)
        let uint8Array = context.objectForKeyedSubscript("Uint8Array")!
            .construct(withArguments: [bytes])!

        if self.binaryType == "arraybuffer" {
            return uint8Array.objectForKeyedSubscript("buffer")!
        }

        if let blobClass = context.objectForKeyedSubscript("Blob"),
           !blobClass.isUndefined {
            return blobClass.construct(withArguments: [[uint8Array] as [Any]])!
        }

        return uint8Array.objectForKeyedSubscript("buffer")!
    }

    private func extractBytes(from value: JSValue, in context: JSContext) -> Data? {
        guard let uint8Constructor = context.objectForKeyedSubscript("Uint8Array") else {
            return nil
        }
        guard let wrapped = uint8Constructor.construct(withArguments: [value]),
              !wrapped.isUndefined else {
            return nil
        }
        let length = wrapped.objectForKeyedSubscript("length")?.toInt32() ?? 0
        guard length > 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(Int(length))
        for i in 0..<Int(length) {
            bytes.append(UInt8(wrapped.objectAtIndexedSubscript(i)?.toInt32() ?? 0))
        }
        return Data(bytes)
    }
}
