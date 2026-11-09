import AppKit
import KBCapture
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    /// Global capture hotkey; default ⌃⌥Space, changeable in Settings.
    static let capture = Self("capture", initial: .init(.space, modifiers: [.control, .option]))
}

/// App-wide state shared by the window, the menu bar, URL handling and App Intents.
@MainActor
final class AppModel {
    static let shared = AppModel()

    let store = VaultStore()
    let capture: CaptureController
    let git = AutoCommitter()

    private init() {
        capture = CaptureController(store: store)
        store.onVaultOpened = { [git] root in Task { await git.configure(root: root) } }
        store.onVaultChanged = { [git] in git.vaultChanged() }
    }

    /// Called once at launch (not in benchmark mode).
    func start() {
        KeyboardShortcuts.onKeyDown(for: .capture) { [capture] in
            capture.toggle(trigger: .hotkey)
        }
        Task { await store.reopenLastVault() }
    }

    func handle(_ url: URL) {
        do {
            switch try GraniteURL.parse(url) {
            case .showCapturePanel:
                capture.show(trigger: .url)
            case .capture(let request):
                Task {
                    do {
                        let path = try await store.capture(request)
                        // One cheap nudge toward processing (principle 8): ask why, unless already given.
                        if request.why?.isEmpty ?? true { capture.askWhy(for: path) }
                    } catch {
                        capture.showError(error.localizedDescription)
                    }
                }
            case .open(let path, let id):
                showMainWindow()
                if let path { store.openNote(path) } else if let id { store.openNote(id: id) }
            }
        } catch {
            NSLog("granite: ignored URL \(url.absoluteString.prefix(200)): \(error)")
        }
    }

    func showMainWindow() {
        NSApplication.shared.activate()
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") ?? false }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
