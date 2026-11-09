import KBAI
import KBIndex
import KeyboardShortcuts
import KBAIMLX
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
            AISettingsSection()
            CodeSettingsSection()
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

/// Settings → AI: the Claude key (Keychain), which routes work, spend, and what left the Mac.
struct AISettingsSection: View {
    @Environment(VaultStore.self) private var store
    @State private var key = ""
    @State private var hasKey = APIKeyStore.isStored
    @State private var routes: Set<ModelRoute> = []
    @State private var spend = 0.0
    @State private var egress: [EgressSummary] = []
    @State private var message: String?
    @AppStorage(VaultStore.relatedEnabledKey) private var relatedOn = true
    @AppStorage(VaultStore.spotlightKey) private var spotlightOn = true

    var body: some View {
        Section("AI") {
            Toggle("Semantic search (local; downloads ~0.4 GB once)", isOn: Binding(
                get: { store.semantic.isEnabled }, set: { store.semantic.isEnabled = $0 }))
            Toggle("Show related notes while writing", isOn: $relatedOn)
            Toggle("Spotlight and Siri can find notes (cloud and PCC labels only)", isOn: $spotlightOn)
                .onChange(of: spotlightOn) { _, on in
                    Task { if on { await store.reindexSpotlight(force: true) } else { await store.clearSpotlight() } }
                }
            LocalModelSettings(local: store.localModel) { provider in Task { await store.models?.add(provider) } }
            if hasKey {
                LabeledContent("Claude API key") {
                    HStack {
                        Text("Stored in the Keychain").foregroundStyle(.secondary)
                        Button("Remove") {
                            APIKeyStore.delete()
                            hasKey = APIKeyStore.isStored
                            Task { await refresh() }
                        }
                    }
                }
            } else {
                HStack {
                    SecureField("Claude API key (optional)", text: $key)
                    Button("Save") {
                        do {
                            try APIKeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines))
                            key = ""
                            hasKey = true
                            Task { await refresh() }
                        } catch {
                            message = "\(error)"
                        }
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Without a key, granite uses Apple's on-device model. Notes labelled local or pcc never go to Claude.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Routes available") {
                Text(ModelRoute.allCases.filter { routes.contains($0) }.map(\.rawValue).joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Spent this month") {
                Text(String(format: "$%.2f of $%.0f (alert $%.0f, background jobs stop at $%.0f)", spend, store.budget.monthlyUSD, store.budget.alertUSD, store.budget.hardStopUSD))
                    .foregroundStyle(.secondary)
            }
            if !egress.isEmpty {
                LabeledContent("Sent this week") {
                    VStack(alignment: .trailing) {
                        ForEach(egress, id: \.route) { row in
                            Text("\(row.route): \(row.calls) calls, \(row.notes) notes")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let message { Text(message).font(.caption).foregroundStyle(.red) }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let models = store.models else { return }
        routes = await models.availability(refresh: true)
        spend = await models.spendThisMonth()
        egress = (try? store.state?.egress(since: Date().addingTimeInterval(-7 * 86_400))) ?? []
    }
}


/// Settings → AI → local language model (the MLX route): off by default, multi-GB download.
struct LocalModelSettings: View {
    @Bindable var local: LocalModel
    let providerChanged: (MLXLanguageProvider) -> Void
    @State private var enabled = UserDefaults.standard.bool(forKey: LocalModel.enabledKey)

    var body: some View {
        Toggle("Local language model (MLX) for private notes and overnight jobs", isOn: $enabled)
            .onChange(of: enabled) { _, on in local.isEnabled = on }
        if enabled {
            Picker("Model", selection: Binding(get: { local.modelID }, set: {
                local.modelID = $0
                providerChanged(local.provider)
            })) {
                ForEach(MLXLanguageProvider.choices, id: \.id) { choice in Text(choice.label).tag(choice.id) }
            }
            LabeledContent("Weights") {
                if let status = local.status {
                    Text(status).foregroundStyle(.secondary)
                } else if local.isDownloaded {
                    Text("Downloaded").foregroundStyle(.secondary)
                } else {
                    Button("Download") { local.downloadAndLoad() }
                }
            }
        }
    }
}
