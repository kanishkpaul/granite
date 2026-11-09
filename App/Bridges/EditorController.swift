import AppKit
import SwiftUI
import WebKit

/// Hosts the CodeMirror bundle in a `WKWebView`. Swift owns file I/O; the editor only sees text.
/// Messages sent before the editor reports `ready` are queued.
@MainActor
@Observable
final class EditorController {
    let webView: WKWebView
    private(set) var isReady = false
    private var queue: [HostMessage] = []
    private var listeners: [UUID: (EditorMessage) -> Void] = [:]
    private let handler = ScriptHandler()

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(handler, contentWorld: .page, name: EditorBridge.handlerName)
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        handler.controller = self
        loadBundle()
    }

    private func loadBundle() {
        guard let page = Bundle.main.url(forResource: "editor", withExtension: "html", subdirectory: "editor") else {
            assertionFailure("editor bundle missing: run `pnpm build` in Editor/")
            return
        }
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
    }

    /// Registers a listener for editor messages; returns a token for `removeListener`.
    @discardableResult
    func addListener(_ listener: @escaping (EditorMessage) -> Void) -> UUID {
        let token = UUID()
        listeners[token] = listener
        return token
    }

    func removeListener(_ token: UUID) { listeners[token] = nil }

    func send(_ message: HostMessage) {
        guard isReady else {
            queue.append(message)
            return
        }
        deliver(message)
    }

    private func deliver(_ message: HostMessage) {
        do {
            let json = try message.json()
            webView.callAsyncJavaScript("window.granite.receive(message)", arguments: ["message": json], in: nil,
                                        in: .page) { result in
                if case .failure(let error) = result { NSLog("granite editor: send failed: \(error)") }
            }
        } catch {
            NSLog("granite editor: encode failed: \(error)")
        }
    }

    fileprivate func received(_ body: Any) {
        let message: EditorMessage
        do {
            message = try EditorMessage.decode(body: body)
        } catch {
            NSLog("granite editor: bad message from editor: \(error)")
            return
        }
        if case .ready(let version) = message {
            guard version == EditorBridge.protocolVersion else {
                NSLog("granite editor: protocol \(version), host expects \(EditorBridge.protocolVersion)")
                return
            }
            isReady = true
            let pending = queue
            queue = []
            pending.forEach(deliver)
        }
        if case .log(let level, let text) = message { NSLog("granite editor [\(level)]: \(text)") }
        for listener in listeners.values { listener(message) }
    }

    /// Waits for the next message matching `predicate`.
    func next(where predicate: @escaping (EditorMessage) -> Bool) async -> EditorMessage {
        await withCheckedContinuation { continuation in
            var token: UUID?
            token = addListener { [weak self] message in
                guard predicate(message), let token else { return }
                self?.removeListener(token)
                continuation.resume(returning: message)
            }
        }
    }
}

/// Weak trampoline: `WKUserContentController` retains its handlers strongly.
private final class ScriptHandler: NSObject, WKScriptMessageHandler {
    weak var controller: EditorController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            controller?.received(message.body)
        }
    }
}

struct EditorView: NSViewRepresentable {
    let controller: EditorController

    func makeNSView(context: Context) -> WKWebView { controller.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
