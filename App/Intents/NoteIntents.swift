import AppIntents
import CoreSpotlight
import Foundation
import KBAI
import KBCore
import KBIndex

/// A note, for Siri, Shortcuts and Spotlight (master plan §8 phase 4: App Intents entities).
struct NoteEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static let defaultQuery = NoteQuery()

    /// The vault-relative path.
    let id: String
    let title: String
    let folder: String
    let text: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: folder.isEmpty ? nil : "\(folder)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.title = title
        set.contentDescription = String(text.prefix(300))
        set.textContent = String(text.prefix(4_000))
        set.kind = "granite note"
        return set
    }

    @MainActor
    static func load(_ path: String, store: VaultStore) -> NoteEntity? {
        guard let vault = store.vault, let data = try? Data(contentsOf: vault.url(for: path)) else { return nil }
        let body = MarkdownDocument(text: String(decoding: data, as: UTF8.self)).bodyLines.map(\.text).joined(separator: "\n")
        return NoteEntity(id: path, title: NoteParser.title(for: path), folder: path.split(separator: "/").dropLast().joined(separator: "/"),
                          text: body)
    }
}

struct NoteQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [NoteEntity] {
        let store = AppModel.shared.store
        await store.reopenLastVault()
        return identifiers.compactMap { NoteEntity.load($0, store: store) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [NoteEntity] {
        let store = AppModel.shared.store
        await store.reopenLastVault()
        return store.titles(matching: string, limit: 20).compactMap { NoteEntity.load($0.path, store: store) }
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteEntity] {
        let store = AppModel.shared.store
        await store.reopenLastVault()
        return store.recentNotes(limit: 10).compactMap { NoteEntity.load($0.path, store: store) }
    }
}

struct OpenNoteIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Note in granite"
    static let description = IntentDescription("Opens a note from your granite vault.")
    @Parameter(title: "Note") var target: NoteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.showMainWindow()
        AppModel.shared.store.openNote(target.id)
        return .result()
    }
}

struct SearchNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search granite"
    static let description = IntentDescription("Finds notes in your granite vault by keywords.")
    static let supportedModes: IntentModes = .background
    @Parameter(title: "Words") var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteEntity]> {
        let store = AppModel.shared.store
        await store.reopenLastVault()
        let hits = (try? store.database?.search(query, options: SearchOptions(limit: 10))) ?? []
        return .result(value: hits.compactMap { NoteEntity.load($0.path, store: store) })
    }
}

/// "Ask granite": grounded Q&A, answered only from your notes, every sentence verified.
struct AskNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask granite"
    static let description = IntentDescription("Answers from your own notes only, or says there is no note on it.")
    static let supportedModes: IntentModes = .background
    @Parameter(title: "Question") var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = AppModel.shared.store
        await store.reopenLastVault()
        let answer = try await store.ask(question, mode: .tellMe, view: nil)
        let verified = answer.sentences.filter(\.verified)
        let text = answer.abstained || verified.isEmpty
            ? "I have no note on that."
            : verified.map { sentence in
                let source = sentence.sourceID.flatMap { id in answer.sources.first { $0.id == id } }
                return sentence.text + (source.map { " (\($0.hit.title))" } ?? "")
            }.joined(separator: " ")
        return .result(value: text, dialog: "\(text)")
    }
}

/// Keeps Spotlight's copy of the vault in step. Only notes a cloud or PCC route may read go in
/// (Spotlight feeds Siri and Apple Intelligence), never `mcp: hidden` folders, never AI/.
extension VaultStore {
    static let spotlightKey = "granite.spotlight"

    var spotlightEnabled: Bool { UserDefaults.standard.object(forKey: Self.spotlightKey) as? Bool ?? true }

    func spotlightAllows(_ record: NoteRecord) -> Bool {
        (record.aiLabel == AILabel.cloud.rawValue || record.aiLabel == AILabel.pcc.rawValue)
            && !policy.policy(for: record.path).mcpHidden && !record.path.hasPrefix("AI/")
    }

    /// Indexes these paths (or removes them when gone or not allowed).
    func updateSpotlight(paths: [String]) async {
        guard spotlightEnabled, let database else { return }
        var entities: [NoteEntity] = []
        var removed: [String] = []
        for path in paths where path.hasSuffix(".md") {
            if let record = try? database.note(path: path), spotlightAllows(record), let entity = NoteEntity.load(path, store: self) {
                entities.append(entity)
            } else {
                removed.append(path)
            }
        }
        try? await CSSearchableIndex.default().indexAppEntities(entities)
        if !removed.isEmpty { try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: removed, ofType: NoteEntity.self) }
    }

    /// The whole vault, in batches (on open, at most once a day).
    func reindexSpotlight(force: Bool = false) async {
        guard spotlightEnabled, let database, let vault else { return }
        let key = "granite.spotlight.lastFull." + vault.root.path(percentEncoded: false)
        if !force, let last = UserDefaults.standard.object(forKey: key) as? Date, Date().timeIntervalSince(last) < 86_400 { return }
        let records = ((try? database.recent(limit: 100_000)) ?? []).filter(spotlightAllows)
        for start in stride(from: 0, to: records.count, by: 500) {
            let batch = records[start..<min(records.count, start + 500)].compactMap { NoteEntity.load($0.path, store: self) }
            try? await CSSearchableIndex.default().indexAppEntities(batch)
        }
        UserDefaults.standard.set(Date(), forKey: key)
    }

    func clearSpotlight() async {
        try? await CSSearchableIndex.default().deleteAppEntities(ofType: NoteEntity.self)
    }
}
