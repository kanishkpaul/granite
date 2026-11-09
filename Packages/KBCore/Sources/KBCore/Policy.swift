import Foundation
import Yams

/// Rules for one vault folder, from `.granite/policy.yaml` (master plan §4.3).
public struct FolderPolicy: Sendable, Hashable {
    public var ai: AILabel
    public var origin: Origin
    public var agents: AgentRights
    /// Set for folders whose files granite partly regenerates, e.g. "zotero".
    public var managed: String?
    /// "untrusted" for clippings: text that may carry prompt injection.
    public var trust: String?
    /// Hidden from `granite-mcp` entirely.
    public var mcpHidden: Bool
    /// Whether retrieval may cite this folder as evidence (false for `AI/`).
    public var evidence: Bool

    public init(ai: AILabel, origin: Origin, agents: AgentRights, managed: String? = nil, trust: String? = nil,
                mcpHidden: Bool = false, evidence: Bool = true) {
        self.ai = ai
        self.origin = origin
        self.agents = agents
        self.managed = managed
        self.trust = trust
        self.mcpHidden = mcpHidden
        self.evidence = evidence
    }
}

public struct Budget: Sendable, Hashable {
    public var monthlyUSD: Double
    public var alertUSD: Double
    public var hardStopUSD: Double
}

public struct PolicyError: Error, CustomStringConvertible, Sendable {
    public let description: String
}

/// Folder policy for a vault. Lookup uses the longest matching folder prefix.
public struct VaultPolicy: Sendable {
    /// Folder prefix ("Notes/") → policy, longest prefix first.
    public let folders: [(prefix: String, policy: FolderPolicy)]
    /// Applies to paths no folder entry matches. Fails closed: `local`, agents may only propose.
    public let fallback: FolderPolicy
    public let budget: Budget?
    public let repos: [String]

    public init(folders: [String: FolderPolicy], fallback: FolderPolicy = VaultPolicy.closedFallback,
                budget: Budget? = nil, repos: [String] = []) {
        self.folders = folders
            .map { (VaultPolicy.normalizePrefix($0.key), $0.value) }
            .sorted { $0.0.count > $1.0.count }
        self.fallback = fallback
        self.budget = budget
        self.repos = repos
    }

    public static let closedFallback = FolderPolicy(ai: .local, origin: .human, agents: .propose)

    /// The plan's default policy, used when a vault has no `.granite/policy.yaml`.
    public static let builtIn = VaultPolicy(
        folders: [
            "Notes/": FolderPolicy(ai: .cloud, origin: .human, agents: .propose),
            "Daily/": FolderPolicy(ai: .pcc, origin: .human, agents: .propose),
            "Inbox/": FolderPolicy(ai: .local, origin: .human, agents: .propose),
            "Papers/": FolderPolicy(ai: .cloud, origin: .source, agents: .propose, managed: "zotero"),
            "References/": FolderPolicy(ai: .cloud, origin: .human, agents: .propose),
            "Clippings/": FolderPolicy(ai: .cloud, origin: .source, agents: .none, trust: "untrusted"),
            "Code/": FolderPolicy(ai: .cloud, origin: .human, agents: .propose),
            "Projects/": FolderPolicy(ai: .cloud, origin: .human, agents: .propose),
            "Private/": FolderPolicy(ai: .local, origin: .human, agents: .none, mcpHidden: true),
            "AI/": FolderPolicy(ai: .cloud, origin: .ai, agents: .write, evidence: false),
        ],
        budget: Budget(monthlyUSD: 20, alertUSD: 15, hardStopUSD: 25)
    )

    public func policy(for path: String) -> FolderPolicy {
        let lowered = path.lowercased()
        for entry in folders where lowered.hasPrefix(entry.prefix.lowercased()) {
            return entry.policy
        }
        return fallback
    }

    static func normalizePrefix(_ prefix: String) -> String {
        var value = prefix.trimmingCharacters(in: .whitespaces)
        while value.hasPrefix("./") { value.removeFirst(2) }
        while value.hasPrefix("/") { value.removeFirst() }
        if !value.hasSuffix("/") { value += "/" }
        return value
    }

    /// Loads `.granite/policy.yaml` from a vault, or the built-in policy if the file is absent.
    public static func load(vaultRoot: URL) throws -> VaultPolicy {
        let url = vaultRoot.appending(path: ".granite/policy.yaml")
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return .builtIn }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(yaml: text)
    }

    public static func parse(yaml text: String) throws -> VaultPolicy {
        let root: Any?
        do { root = try Yams.load(yaml: text) } catch { throw PolicyError(description: "policy.yaml: \(error)") }
        guard let map = root as? [String: Any] else { throw PolicyError(description: "policy.yaml: expected a mapping") }

        var folders: [String: FolderPolicy] = [:]
        if let entries = map["folders"] as? [String: Any] {
            for (prefix, raw) in entries {
                guard let fields = raw as? [String: Any] else {
                    throw PolicyError(description: "policy.yaml: folder \(prefix) must be a mapping")
                }
                folders[prefix] = try folderPolicy(fields, context: prefix, base: nil)
            }
        }
        var fallback = closedFallback
        if let fields = map["default"] as? [String: Any] {
            fallback = try folderPolicy(fields, context: "default", base: closedFallback)
        }
        var budget: Budget?
        if let fields = map["budget"] as? [String: Any] {
            budget = Budget(monthlyUSD: number(fields["monthly_usd"]) ?? 20,
                            alertUSD: number(fields["alert_usd"]) ?? 15,
                            hardStopUSD: number(fields["hard_stop_usd"]) ?? 25)
        }
        let repos = (map["repos"] as? [Any])?.compactMap { $0 as? String } ?? []
        return VaultPolicy(folders: folders, fallback: fallback, budget: budget, repos: repos)
    }

    static func folderPolicy(_ fields: [String: Any], context: String, base: FolderPolicy?) throws -> FolderPolicy {
        func enumValue<T: RawRepresentable>(_ key: String, _ type: T.Type) throws -> T? where T.RawValue == String {
            guard let raw = fields[key] else { return nil }
            let text = raw as? String ?? (raw as? Bool).map { $0 ? "true" : "false" } ?? "\(raw)"
            guard let value = T(rawValue: text) else {
                throw PolicyError(description: "policy.yaml: \(context) has invalid \(key) '\(text)'")
            }
            return value
        }
        let ai = try enumValue("ai", AILabel.self) ?? base?.ai
        let origin = try enumValue("origin", Origin.self) ?? base?.origin
        let agents = try enumValue("agents", AgentRights.self) ?? base?.agents
        guard let ai, let origin, let agents else {
            throw PolicyError(description: "policy.yaml: \(context) needs ai, origin and agents")
        }
        return FolderPolicy(
            ai: ai, origin: origin, agents: agents,
            managed: fields["managed"] as? String,
            trust: fields["trust"] as? String,
            mcpHidden: (fields["mcp"] as? String) == "hidden",
            evidence: (fields["evidence"] as? Bool) ?? (origin != .ai)
        )
    }

    static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }
}
