import KeyboardShortcuts
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Capture…") { AppModel.shared.capture.show(trigger: .menu) }
        Button("Open granite") {
            openWindow(id: "main")
            NSApplication.shared.activate()
        }
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit granite") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct SettingsView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture hotkey:", name: .capture)
            LabeledContent("Vault:") {
                Text(store.vault?.root.path(percentEncoded: false) ?? "None. Open one from the main window.")
                    .textSelection(.enabled)
            }
            LabeledContent("Captures go to:") { Text("Inbox/ (local-only AI label)") }
        }
        .padding(20)
        .frame(width: 480)
    }
}
