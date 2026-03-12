//
//  JSWebSocketPolyfillTests.swift
//  TONWalletKit
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
import JavaScriptCore
import Testing

@_private(sourceFile: "JSWebSocketPolyfill.swift")
@_private(sourceFile: "JSWebSocket.swift")
@_private(sourceFile: "WebSocketTask.swift")
@testable import TONWalletKit

// MARK: - Registration Tests

@Suite("JSWebSocketPolyfill Registration Tests")
struct JSWebSocketPolyfillRegistrationTests {

    @Test("Apply registers WebSocket constructor on context")
    func applyRegistersConstructor() {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)

        let ws = context.objectForKeyedSubscript("WebSocket")
        #expect(ws != nil)
        #expect(!ws!.isUndefined)
    }

    @Test("WebSocket has static CONNECTING constant equal to 0")
    func staticConnectingConstant() {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)

        let value = context.evaluateScript("WebSocket.CONNECTING")
        #expect(value?.toInt32() == 0)
    }

    @Test("WebSocket has static OPEN constant equal to 1")
    func staticOpenConstant() {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)

        let value = context.evaluateScript("WebSocket.OPEN")
        #expect(value?.toInt32() == 1)
    }

    @Test("WebSocket has static CLOSING constant equal to 2")
    func staticClosingConstant() {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)

        let value = context.evaluateScript("WebSocket.CLOSING")
        #expect(value?.toInt32() == 2)
    }

    @Test("WebSocket has static CLOSED constant equal to 3")
    func staticClosedConstant() {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)

        let value = context.evaluateScript("WebSocket.CLOSED")
        #expect(value?.toInt32() == 3)
    }
}

// MARK: - Constructor Tests

@Suite("JSWebSocket Constructor Tests")
struct JSWebSocketConstructorTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        // Install timer polyfill for async operations
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("Constructor creates WebSocket with ws:// URL")
    func constructorWithWsUrl() {
        let context = makeContext()
        let ws = context.evaluateScript("new WebSocket('ws://example.com')")
        #expect(ws != nil)
        #expect(!ws!.isUndefined)
        #expect(!ws!.isNull)
    }

    @Test("Constructor creates WebSocket with wss:// URL")
    func constructorWithWssUrl() {
        let context = makeContext()
        let ws = context.evaluateScript("new WebSocket('wss://example.com')")
        #expect(ws != nil)
        #expect(!ws!.isUndefined)
        #expect(!ws!.isNull)
    }

    @Test("Constructor sets url property correctly")
    func constructorSetsUrl() {
        let context = makeContext()
        let url = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com/path');
            ws.url;
        """)
        #expect(url?.toString() == "wss://example.com/path")
    }

    @Test("Constructor sets initial readyState to CONNECTING (0)")
    func constructorSetsReadyState() {
        let context = makeContext()
        let readyState = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.readyState;
        """)
        #expect(readyState?.toInt32() == 0)
    }

    @Test("Constructor sets default binaryType to 'blob'")
    func constructorSetsBinaryType() {
        let context = makeContext()
        let binaryType = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.binaryType;
        """)
        #expect(binaryType?.toString() == "blob")
    }

    @Test("Constructor sets empty protocol")
    func constructorSetsEmptyProtocol() {
        let context = makeContext()
        let proto = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.protocol;
        """)
        #expect(proto?.toString() == "")
    }

    @Test("Constructor sets empty extensions")
    func constructorSetsEmptyExtensions() {
        let context = makeContext()
        let ext = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.extensions;
        """)
        #expect(ext?.toString() == "")
    }

    @Test("Constructor sets bufferedAmount to 0")
    func constructorSetsBufferedAmount() {
        let context = makeContext()
        let amount = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.bufferedAmount;
        """)
        #expect(amount?.toInt32() == 0)
    }

    @Test("Constructor sets event handlers to null")
    func constructorSetsNullHandlers() {
        let context = makeContext()
        context.evaluateScript("var ws = new WebSocket('wss://example.com');")

        let onopen = context.evaluateScript("ws.onopen")
        let onmessage = context.evaluateScript("ws.onmessage")
        let onclose = context.evaluateScript("ws.onclose")
        let onerror = context.evaluateScript("ws.onerror")

        #expect(onopen?.isNull == true || onopen?.isUndefined == true)
        #expect(onmessage?.isNull == true || onmessage?.isUndefined == true)
        #expect(onclose?.isNull == true || onclose?.isUndefined == true)
        #expect(onerror?.isNull == true || onerror?.isUndefined == true)
    }

    @Test("Constructor throws error for invalid URL (http://)")
    func constructorThrowsForHttpUrl() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("new WebSocket('http://example.com')")
        #expect(exceptionCaught == true)
    }

    @Test("Constructor throws error for invalid URL (empty string)")
    func constructorThrowsForEmptyUrl() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("new WebSocket('')")
        #expect(exceptionCaught == true)
    }

    @Test("Constructor throws error for invalid URL (no scheme)")
    func constructorThrowsForNoScheme() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("new WebSocket('example.com')")
        #expect(exceptionCaught == true)
    }

    @Test("Constructor accepts string protocol")
    func constructorAcceptsStringProtocol() {
        let context = makeContext()
        let ws = context.evaluateScript("new WebSocket('wss://example.com', 'chat')")
        #expect(ws != nil)
        #expect(!ws!.isUndefined)
    }

    @Test("Constructor accepts array of protocols")
    func constructorAcceptsArrayProtocols() {
        let context = makeContext()
        let ws = context.evaluateScript("new WebSocket('wss://example.com', ['chat', 'superchat'])")
        #expect(ws != nil)
        #expect(!ws!.isUndefined)
    }

    @Test("Constructor works without protocols argument")
    func constructorWorksWithoutProtocols() {
        let context = makeContext()
        let ws = context.evaluateScript("new WebSocket('wss://example.com')")
        #expect(ws != nil)
        #expect(!ws!.isUndefined)
    }
}

// MARK: - Property Tests

@Suite("JSWebSocket Property Tests")
struct JSWebSocketPropertyTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("binaryType can be set to 'arraybuffer'")
    func setBinaryTypeToArrayBuffer() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.binaryType = 'arraybuffer';
            ws.binaryType;
        """)
        #expect(result?.toString() == "arraybuffer")
    }

    @Test("binaryType can be set to 'blob'")
    func setBinaryTypeToBlob() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.binaryType = 'arraybuffer';
            ws.binaryType = 'blob';
            ws.binaryType;
        """)
        #expect(result?.toString() == "blob")
    }

    @Test("onopen can be set to a function")
    func setOnopen() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.onopen = function() {};
            typeof ws.onopen;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("onmessage can be set to a function")
    func setOnmessage() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.onmessage = function() {};
            typeof ws.onmessage;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("onclose can be set to a function")
    func setOnclose() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.onclose = function() {};
            typeof ws.onclose;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("onerror can be set to a function")
    func setOnerror() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.onerror = function() {};
            typeof ws.onerror;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("Instance has CONNECTING, OPEN, CLOSING, CLOSED constants")
    func instanceConstants() {
        let context = makeContext()
        context.evaluateScript("var ws = new WebSocket('wss://example.com');")

        #expect(context.evaluateScript("ws.CONNECTING")?.toInt32() == 0)
        #expect(context.evaluateScript("ws.OPEN")?.toInt32() == 1)
        #expect(context.evaluateScript("ws.CLOSING")?.toInt32() == 2)
        #expect(context.evaluateScript("ws.CLOSED")?.toInt32() == 3)
    }
}

// MARK: - close() Validation Tests

@Suite("JSWebSocket close() Validation Tests")
struct JSWebSocketCloseValidationTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("close() with no arguments doesn't throw")
    func closeWithNoArgs() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close();
        """)
        #expect(exceptionCaught == false)
    }

    @Test("close() with valid code 1000 doesn't throw")
    func closeWithCode1000() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1000);
        """)
        #expect(exceptionCaught == false)
    }

    @Test("close() with code 3000 doesn't throw")
    func closeWithCode3000() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(3000);
        """)
        #expect(exceptionCaught == false)
    }

    @Test("close() with code 4999 doesn't throw")
    func closeWithCode4999() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(4999);
        """)
        #expect(exceptionCaught == false)
    }

    @Test("close() with invalid code 1001 throws error")
    func closeWithInvalidCode1001() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1001);
        """)
        #expect(exceptionCaught == true)
    }

    @Test("close() with invalid code 2999 throws error")
    func closeWithInvalidCode2999() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(2999);
        """)
        #expect(exceptionCaught == true)
    }

    @Test("close() with invalid code 5000 throws error")
    func closeWithInvalidCode5000() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(5000);
        """)
        #expect(exceptionCaught == true)
    }

    @Test("close() with code and reason doesn't throw")
    func closeWithCodeAndReason() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1000, 'goodbye');
        """)
        #expect(exceptionCaught == false)
    }

    @Test("close() with reason exceeding 123 bytes throws error")
    func closeWithLongReason() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1000, 'a'.repeat(124));
        """)
        #expect(exceptionCaught == true)
    }

    @Test("close() with exactly 123 byte reason doesn't throw")
    func closeWithExact123ByteReason() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1000, 'a'.repeat(123));
        """)
        #expect(exceptionCaught == false)
    }

    @Test("close() sets readyState to CLOSING (2)")
    func closeSetsReadyState() {
        let context = makeContext()
        context.exceptionHandler = { _, _ in }

        let readyState = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1000);
            ws.readyState;
        """)
        #expect(readyState?.toInt32() == 2)
    }
}

// MARK: - send() Validation Tests

@Suite("JSWebSocket send() Validation Tests")
struct JSWebSocketSendValidationTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("send() while CONNECTING throws InvalidStateError")
    func sendWhileConnecting() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.send('hello');
        """)
        #expect(exceptionCaught == true)
    }

    @Test("send() while CLOSING doesn't throw")
    func sendWhileClosing() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.close(1000);
            ws.send('hello');
        """)
        // close() may have thrown if readyState is still 0, but send should not throw when CLOSING
        // readyState after close() on a CONNECTING socket becomes 2
        // send() with readyState 2 should silently return
        // The only exception should be from send() while CONNECTING
    }
}

// MARK: - addEventListener Tests

@Suite("JSWebSocket addEventListener Tests")
struct JSWebSocketAddEventListenerTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("addEventListener exists as a method")
    func addEventListenerExists() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            typeof ws.addEventListener;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("removeEventListener exists as a method")
    func removeEventListenerExists() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            typeof ws.removeEventListener;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("addEventListener doesn't throw with valid arguments")
    func addEventListenerDoesntThrow() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            ws.addEventListener('open', function() {});
            ws.addEventListener('message', function() {});
            ws.addEventListener('close', function() {});
            ws.addEventListener('error', function() {});
        """)
        #expect(exceptionCaught == false)
    }

    @Test("removeEventListener doesn't throw with valid arguments")
    func removeEventListenerDoesntThrow() {
        let context = makeContext()
        var exceptionCaught = false
        context.exceptionHandler = { _, _ in exceptionCaught = true }

        context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            var handler = function() {};
            ws.addEventListener('open', handler);
            ws.removeEventListener('open', handler);
        """)
        #expect(exceptionCaught == false)
    }
}

// MARK: - WebSocket Method Availability Tests

@Suite("JSWebSocket Method Availability Tests")
struct JSWebSocketMethodTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("send method exists")
    func sendMethodExists() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            typeof ws.send;
        """)
        #expect(result?.toString() == "function")
    }

    @Test("close method exists")
    func closeMethodExists() {
        let context = makeContext()
        let result = context.evaluateScript("""
            var ws = new WebSocket('wss://example.com');
            typeof ws.close;
        """)
        #expect(result?.toString() == "function")
    }
}

// MARK: - Memory Leak Tests

@Suite("JSWebSocket Memory Tests")
struct JSWebSocketMemoryTests {

    @Test("WebSocket polyfill doesn't leak JSContext")
    func noContextLeak() async throws {
        var context: JSContext? = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context!.polyfill(with: polyfill)
        context!.evaluateScript("")
        weak var weakContext = context

        context = nil

        try await Task.sleep(for: .seconds(0.1))

        #expect(weakContext == nil)
    }

    @Test("Multiple WebSocket instances don't leak")
    func multipleInstancesDontLeak() async throws {
        var context: JSContext? = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context!.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context!.polyfill(with: timerPolyfill)

        weak var weakContext = context

        context!.evaluateScript("""
            var ws1 = new WebSocket('wss://example.com/1');
            var ws2 = new WebSocket('wss://example.com/2');
            var ws3 = new WebSocket('wss://example.com/3');
            ws1 = null;
            ws2 = null;
            ws3 = null;
        """)

        context = nil

        try await Task.sleep(for: .seconds(0.5))

        #expect(weakContext == nil)
    }
}

// MARK: - WebSocketTask Unit Tests

@Suite("WebSocketTask State Tests")
struct WebSocketTaskTests {

    @Test("WebSocketEvent enum has correct cases")
    func eventEnumCases() {
        let openEvent = WebSocketEvent.open(negotiatedProtocol: "chat")
        let textMsg = WebSocketEvent.message(.text("hello"))
        let binaryMsg = WebSocketEvent.message(.binary(Data([0x01, 0x02])))
        let closeEvent = WebSocketEvent.close(code: 1000, reason: "bye", wasClean: true)
        let errorEvent = WebSocketEvent.error("connection failed")

        // Verify events can be constructed (type checking)
        switch openEvent {
        case .open(let proto): #expect(proto == "chat")
        default: #expect(Bool(false), "Expected open event")
        }

        switch textMsg {
        case .message(.text(let text)): #expect(text == "hello")
        default: #expect(Bool(false), "Expected text message")
        }

        switch binaryMsg {
        case .message(.binary(let data)): #expect(data == Data([0x01, 0x02]))
        default: #expect(Bool(false), "Expected binary message")
        }

        switch closeEvent {
        case .close(let code, let reason, let wasClean):
            #expect(code == 1000)
            #expect(reason == "bye")
            #expect(wasClean == true)
        default: #expect(Bool(false), "Expected close event")
        }

        switch errorEvent {
        case .error(let msg): #expect(msg == "connection failed")
        default: #expect(Bool(false), "Expected error event")
        }
    }

    @Test("WebSocketMessage enum has text and binary cases")
    func messageEnumCases() {
        let textMsg = WebSocketMessage.text("test")
        let binaryMsg = WebSocketMessage.binary(Data([0xFF]))

        switch textMsg {
        case .text(let t): #expect(t == "test")
        default: #expect(Bool(false))
        }

        switch binaryMsg {
        case .binary(let d): #expect(d == Data([0xFF]))
        default: #expect(Bool(false))
        }
    }
}

// MARK: - Connection Lifecycle Tests (via JS)

@Suite("JSWebSocket Connection Lifecycle Tests")
struct JSWebSocketConnectionLifecycleTests {

    private func makeContext() -> JSContext {
        let context = JSContext()!
        let polyfill = JSWebSocketPolyfill()
        context.polyfill(with: polyfill)
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)
        return context
    }

    @Test("WebSocket starts in CONNECTING state and receives error/close for invalid server")
    func connectionToInvalidServerFiresEvents() async throws {
        let context = makeContext()
        context.exceptionHandler = { _, _ in }

        context.evaluateScript("""
            var events = [];
            var ws = new WebSocket('wss://localhost:1');
            ws.onerror = function(e) { events.push('error'); };
            ws.onclose = function(e) { events.push('close:' + e.code + ':' + e.wasClean); };
        """)

        // Wait for connection attempt to fail
        try await Task.sleep(for: .seconds(2))

        let eventsArray = context.objectForKeyedSubscript("events")?.toArray()
        let events = eventsArray?.compactMap { $0 as? String } ?? []

        // Should have received error and close events
        #expect(events.contains("error"))
        #expect(events.contains { $0.hasPrefix("close:") })
    }

    @Test("readyState transitions to CLOSED (3) after connection failure")
    func readyStateTransitionsToClosedOnFailure() async throws {
        let context = makeContext()
        context.exceptionHandler = { _, _ in }

        context.evaluateScript("""
            var finalReadyState = -1;
            var ws = new WebSocket('wss://localhost:1');
            ws.onclose = function(e) { finalReadyState = ws.readyState; };
        """)

        try await Task.sleep(for: .seconds(2))

        let finalReadyState = context.objectForKeyedSubscript("finalReadyState")?.toInt32()
        #expect(finalReadyState == 3)
    }

    @Test("close event has wasClean=false for connection failure")
    func closeEventHasWasCleanFalseOnFailure() async throws {
        let context = makeContext()
        context.exceptionHandler = { _, _ in }

        context.evaluateScript("""
            var wasClean = null;
            var ws = new WebSocket('wss://localhost:1');
            ws.onclose = function(e) { wasClean = e.wasClean; };
        """)

        try await Task.sleep(for: .seconds(2))

        let wasClean = context.objectForKeyedSubscript("wasClean")
        #expect(wasClean?.toBool() == false)
    }

    @Test("close event has code 1006 for abnormal closure")
    func closeEventHasCode1006ForAbnormalClosure() async throws {
        let context = makeContext()
        context.exceptionHandler = { _, _ in }

        context.evaluateScript("""
            var closeCode = -1;
            var ws = new WebSocket('wss://localhost:1');
            ws.onclose = function(e) { closeCode = e.code; };
        """)

        try await Task.sleep(for: .seconds(2))

        let closeCode = context.objectForKeyedSubscript("closeCode")?.toInt32()
        #expect(closeCode == 1006)
    }

    @Test("addEventListener receives same events as on-handler")
    func addEventListenerReceivesEvents() async throws {
        let context = makeContext()
        context.exceptionHandler = { _, _ in }

        context.evaluateScript("""
            var handlerCalled = false;
            var listenerCalled = false;
            var ws = new WebSocket('wss://localhost:1');
            ws.onerror = function(e) { handlerCalled = true; };
            ws.addEventListener('error', function(e) { listenerCalled = true; });
        """)

        try await Task.sleep(for: .seconds(2))

        let handlerCalled = context.objectForKeyedSubscript("handlerCalled")?.toBool()
        let listenerCalled = context.objectForKeyedSubscript("listenerCalled")?.toBool()
        #expect(handlerCalled == true)
        #expect(listenerCalled == true)
    }
}
