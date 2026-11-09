/// The fixed set of object types (master plan §4.4). Hard-coded on purpose: no schema builder.
public enum ObjectType: String, Sendable, Codable, CaseIterable {
    case note, claim, decision, source, clipping, person, project, daily
    case synthesis, digest, proposal

    /// Machine types live in `AI/` and are never evidence by default.
    public var isMachineType: Bool {
        switch self {
        case .synthesis, .digest, .proposal: true
        default: false
        }
    }
}

/// Where a file's text came from (principle 2).
public enum Origin: String, Sendable, Codable, CaseIterable {
    case human
    case source
    case ai
    case aiAccepted = "ai-accepted"
}

/// Folder privacy label (principle 7). Ordered from least to most strict.
public enum AILabel: String, Sendable, Codable, CaseIterable, Comparable {
    case cloud, pcc, local, none

    private var strictness: Int {
        switch self {
        case .cloud: 0
        case .pcc: 1
        case .local: 2
        case .none: 3
        }
    }

    public static func < (lhs: AILabel, rhs: AILabel) -> Bool {
        lhs.strictness < rhs.strictness
    }

    /// The strictest label wins whenever labels combine (a request, a derived note).
    public static func strictest<S: Sequence>(_ labels: S) -> AILabel? where S.Element == AILabel {
        labels.max()
    }
}

/// What agents may do in a folder.
public enum AgentRights: String, Sendable, Codable {
    case none, propose, write
}

/// Typed relations stored as flat frontmatter lists of links (master plan §4.4).
/// Only the forward direction is stored; the index computes inverses.
public enum Relation: String, Sendable, Codable, CaseIterable {
    case supports
    case contradicts
    case supersedes
    case derivedFrom = "derived_from"
    case implementedIn = "implemented_in"
    case about
    case source

    /// Untyped inline links share the table with typed relations under this name.
    public static let untyped = "links"
    /// Inline `![[embeds]]`.
    public static let embed = "embed"
}
