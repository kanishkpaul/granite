import AppIntents
import KBCapture

/// "Capture to granite" for Shortcuts, Spotlight and Siri. Runs without bringing granite forward.
struct CaptureToGraniteIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture to granite"
    static let description = IntentDescription("Saves text to the Inbox of your granite vault.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Text") var text: String
    @Parameter(title: "Link") var link: URL?
    @Parameter(title: "Why I saved this") var why: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = AppModel.shared.store
        await store.reopenLastVault()
        let path = try await store.capture(CaptureRequest(text: text, url: link, why: why))
        return .result(value: path, dialog: "Saved to \(path)")
    }
}

struct GraniteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CaptureToGraniteIntent(), phrases: ["Capture to \(.applicationName)"],
                    shortTitle: "Capture", systemImageName: "tray.and.arrow.down")
        AppShortcut(intent: AskNotesIntent(), phrases: ["Ask \(.applicationName)", "Ask my notes in \(.applicationName)"],
                    shortTitle: "Ask", systemImageName: "questionmark.bubble")
        AppShortcut(intent: SearchNotesIntent(), phrases: ["Search \(.applicationName)"],
                    shortTitle: "Search", systemImageName: "magnifyingglass")
        AppShortcut(intent: OpenNoteIntent(), phrases: ["Open \(\.$target) in \(.applicationName)"],
                    shortTitle: "Open Note", systemImageName: "doc.text")
    }
}
