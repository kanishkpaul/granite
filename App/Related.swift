import Foundation
import KBCore
import KBIndex

/// Per-session memory for inline related items.
struct RelatedSession {
    var task: Task<Void, Never>?
    /// Targets you dismissed, per note: never shown there again this session.
    var dismissed: [String: Set<String>] = [:]
    /// "path|target" pairs already logged as shown.
    var logged: Set<String> = []
}

/// Inline related items (master plan §7, idea 2): up to three ghost links at the end of the
/// paragraph you are writing. Logged as feature "related"; pauses below 10% acceptance.
extension VaultStore {
    static let relatedFeature = "related"
    static let relatedEnabledKey = "granite.related"

    var relatedEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.relatedEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.relatedEnabledKey) }
    }

    func relatedItems(id: Int, paragraph: String) {
        related.task?.cancel()
        guard relatedEnabled, let path = openPath, let database,
              (try? state?.isPaused(feature: Self.relatedFeature)) != true else { return }
        let searcher = semantic.hasVectors ? semantic.searcher : nil
        let finder = RelatedFinder(database: database, vectors: searcher?.vectors, embedder: searcher?.embedder)
        let dismissed = related.dismissed[path] ?? []
        related.task = Task {
            guard let found = try? await finder.forText(paragraph, in: path, limit: 6), !Task.isCancelled,
                  openPath == path else { return }
            let items = found
                .filter { !dismissed.contains($0.title) && $0.aiLabel != AILabel.none.rawValue }
                .prefix(3)
                .map { candidate in
                    RelatedItem(target: candidate.title, title: candidate.title,
                                reason: candidate.reason == .mention ? .mention : .similar,
                                mention: candidate.reason == .mention ? candidate.snippet : nil,
                                detail: candidate.reason == .mention
                                    ? "Mentioned here: link “\(candidate.snippet)”"
                                    : (candidate.headingPath.isEmpty ? "" : "\(candidate.headingPath): ")
                                        + "“\(candidate.snippet.prefix(120))…”")
                }
            for item in items where related.logged.insert("\(path)|\(item.target)").inserted {
                try? state?.record(feature: Self.relatedFeature, action: .shown, target: path)
            }
            editor.send(.related(id: id, items: Array(items)))
        }
    }

    func relatedDecided(target: String, accepted: Bool) {
        guard let path = openPath else { return }
        try? state?.record(feature: Self.relatedFeature, action: accepted ? .accepted : .rejected, target: path)
        if !accepted { related.dismissed[path, default: []].insert(target) }
    }
}
