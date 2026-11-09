import AppKit
import KBCapture
import SwiftUI

/// The floating capture panel: type, ⌘↩ saves, then an optional "why" line (↩ saves, Esc skips).
@MainActor
@Observable
final class CaptureController {
    enum Phase: Equatable {
        case writing
        case why(path: String)
        case error(String)
    }

    enum Trigger: String {
        case hotkey, menu, url
    }

    var text = ""
    var why = ""
    var phase = Phase.writing
    private(set) var isSaving = false
    /// Changes every time the panel is shown, so the view can move focus.
    private(set) var showCount = 0
    /// Milliseconds from trigger to the panel becoming key, for the < 300 ms gate.
    private(set) var lastShowMs: Double?

    private let store: VaultStore
    private var panel: CapturePanel?
    private var shownAt: ContinuousClock.Instant?
    private var trigger = Trigger.hotkey

    init(store: VaultStore) {
        self.store = store
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(trigger: Trigger) {
        if isVisible { hide() } else { show(trigger: trigger) }
    }

    func show(trigger: Trigger) {
        shownAt = ContinuousClock.now
        self.trigger = trigger
        if case .writing = phase {} else { reset() }
        present()
    }

    func askWhy(for path: String) {
        shownAt = ContinuousClock.now
        trigger = .url
        text = ""
        why = ""
        phase = .why(path: path)
        present()
    }

    func showError(_ message: String) {
        shownAt = ContinuousClock.now
        phase = .error(message)
        present()
    }

    private func present() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        showCount += 1
        panel.center()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func makePanel() -> CapturePanel {
        let panel = CapturePanel(content: CaptureView(controller: self))
        panel.onBecomeKey = { [weak self] in self?.didBecomeKey() }
        return panel
    }

    private func didBecomeKey() {
        guard let shownAt else { return }
        let elapsed = ContinuousClock.now - shownAt
        let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        lastShowMs = ms
        self.shownAt = nil
        NSLog("granite: capture panel key in %.1f ms (%@)", ms, trigger.rawValue)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func reset() {
        text = ""
        why = ""
        phase = .writing
    }

    /// ⌘↩ in the writing phase.
    func save() {
        let request = CaptureRequest(text: text)
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let path = try await store.capture(request)
                text = ""
                phase = .why(path: path)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    /// ↩ in the why phase.
    func saveWhy() {
        guard case .why(let path) = phase else { return }
        let line = why
        hide()
        reset()
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            do { try await store.setWhy(line, for: path) } catch { showError(error.localizedDescription) }
        }
    }

    /// Esc: discard an unsaved capture, skip the why line, or dismiss an error.
    func cancel() {
        hide()
        reset()
    }
}

/// A Spotlight-style panel: floats over every Space and full-screen app and takes keyboard focus
/// without activating granite, so the app you were in stays frontmost.
final class CapturePanel: NSPanel {
    var onBecomeKey: (() -> Void)?

    init(content: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 230),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        contentView = NSHostingView(rootView: content)
    }

    override var canBecomeKey: Bool { true }

    override func becomeKey() {
        super.becomeKey()
        onBecomeKey?()
    }
}
