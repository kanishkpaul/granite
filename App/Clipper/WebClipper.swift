import Foundation
import KBCapture
import KBCore
import SwiftUI
import WebKit

/// Loads a page in a hidden web view (no cookies or storage kept: a non-persistent data store),
/// runs Defuddle in an isolated content world the page's scripts can't reach, and returns the
/// article as Markdown (master plan §6.6).
@MainActor
final class WebClipper: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var loaded: CheckedContinuation<Void, any Error>?
    static let world = WKContentWorld.world(name: "granite-clipper")

    struct ClipError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func clip(_ url: URL, timeout: Duration = .seconds(30)) async throws -> WebClip {
        guard let bundleURL = Bundle.main.url(forResource: "clipper", withExtension: "js", subdirectory: "editor"),
              let script = try? String(contentsOf: bundleURL, encoding: .utf8) else { throw ClipError(message: "the clipper bundle is missing") }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 900), configuration: configuration)
        view.navigationDelegate = self
        webView = view
        defer {
            webView?.stopLoading()
            webView = nil
        }
        let watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: timeout)
            self?.finish(ClipError(message: "the page took too long to load"))
        }
        defer { watchdog.cancel() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            loaded = continuation
            view.load(URLRequest(url: url, timeoutInterval: 25))
        }
        // Let client-side rendering settle.
        try? await Task.sleep(for: .seconds(1.5))
        _ = try await view.evaluateJavaScript(script, in: nil, contentWorld: Self.world)
        let result = try await view.callAsyncJavaScript("return JSON.stringify(globalThis.graniteClip(url))",
                                                        arguments: ["url": url.absoluteString], in: nil, contentWorld: Self.world)
        guard let json = result as? String, let data = json.data(using: .utf8) else { throw ClipError(message: "nothing extracted") }
        let clip = try JSONDecoder().decode(WebClip.self, from: data)
        guard !clip.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClipError(message: "no article text found on that page")
        }
        return clip
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { finish(nil) }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        MainActor.assumeIsolated { finish(error) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        MainActor.assumeIsolated { finish(error) }
    }

    private func finish(_ error: (any Error)?) {
        guard let loaded else { return }
        self.loaded = nil
        if let error { loaded.resume(throwing: error) } else { loaded.resume() }
    }
}

extension VaultStore {
    /// Clips a page into `Clippings/` and opens it.
    func clipPage(_ url: URL, why: String? = nil) async {
        guard let vault, let writer else { return }
        status = "Clipping \(url.host ?? url.absoluteString)…"
        do {
            let clip = try await WebClipper().clip(url)
            var path = "\(ClippingNote.folder)/\(ClippingNote.fileName(for: clip, url: url)).md"
            var counter = 2
            while FileManager.default.fileExists(atPath: vault.url(for: path).path(percentEncoded: false)) {
                path = "\(ClippingNote.folder)/\(ClippingNote.fileName(for: clip, url: url)) \(counter).md"
                counter += 1
            }
            try await writer.write(ClippingNote.render(clip, url: url, clipped: ClaimDay.string(Date()), why: why), to: path, as: .user)
            _ = try await indexer?.update(paths: [path])
            status = "Clipped \(clip.wordCount) words to \(path)"
            refreshLists()
            openNote(path)
        } catch {
            status = "Could not clip: \(error.localizedDescription)"
        }
    }
}

/// ⌘K "Clip a web page…": paste or confirm a URL.
struct ClipSheet: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var why = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clip a web page").font(.headline)
            Text("Saved to Clippings/ as an untrusted source: models read it as data, never instructions.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("https://…", text: $address).textFieldStyle(.roundedBorder)
            TextField("Why? (optional)", text: $why).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Clip") {
                    if let url = URL(string: address.trimmingCharacters(in: .whitespaces)) {
                        let reason = why
                        Task { await store.clipPage(url, why: reason) }
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!(URL(string: address.trimmingCharacters(in: .whitespaces))?.scheme.map { ["http", "https"].contains($0) } ?? false))
            }
        }
        .padding()
        .frame(width: 480)
        .onAppear {
            if let copied = NSPasteboard.general.string(forType: .string), copied.hasPrefix("http") { address = copied }
        }
    }
}
