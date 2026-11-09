import KeyboardShortcuts
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Capture…") { AppModel.shared.capture.show(trigger: .menu) }
        GitMenuSection(git: AppModel.shared.git)
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
            GitSettingsSection(git: AppModel.shared.git)
        }
        .padding(20)
        .frame(width: 480)
    }
}

struct GitMenuSection: View {
    @Bindable var git: AutoCommitter

    var body: some View {
        Divider()
        Text(git.statusText)
        if case .paused = git.state {
            Button("Commit Anyway…") { git.confirmCommitAnyway() }
        } else if git.isRepository && git.isEnabled {
            Button("Commit Now") { Task { await git.commit() } }
        }
        Divider()
    }
}

struct GitSettingsSection: View {
    @Bindable var git: AutoCommitter

    var body: some View {
        Section("History") {
            Toggle("Commit the vault to git automatically", isOn: $git.isEnabled)
                .disabled(!git.isRepository)
            Text(git.statusText).font(.caption).foregroundStyle(.secondary)
            if !git.isRepository, AppModel.shared.store.vault != nil {
                Button("Initialize git in this vault") { Task { await git.initialize() } }
            }
        }
    }
}
