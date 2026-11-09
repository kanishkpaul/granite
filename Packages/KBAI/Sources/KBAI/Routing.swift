import KBCore

/// Where a generation runs (master plan §6.1).
public enum ModelRoute: String, Sendable, CaseIterable, Codable {
    case onDevice = "on-device"
    case pcc
    case mlx
    case haiku
    case sonnet
    case opus

    /// Leaves Apple's and your hardware: needs a `cloud` label.
    public var isThirdPartyCloud: Bool { self == .haiku || self == .sonnet || self == .opus }

    /// The strictest note label this route may see.
    public func allows(_ label: AILabel) -> Bool {
        switch label {
        case .cloud: true
        case .pcc: self == .onDevice || self == .pcc || self == .mlx
        case .local: self == .onDevice || self == .mlx
        case .none: false
        }
    }
}

/// What the model is asked to do; each task has its own route preferences.
public enum ModelTask: String, Sendable, CaseIterable, Codable {
    case tagging, linkReason, contextPrefix, triage
    case qa, qaDeep, socratic
    case extraction, nli, digest
    case synthesis, beliefDiff

    /// Route preferences per effective label, best first (§6.1).
    public func preferences(for label: AILabel) -> [ModelRoute] {
        let candidates: [ModelRoute] = switch self {
        case .tagging, .linkReason, .contextPrefix, .triage:
            [.onDevice, .mlx]
        case .qa:
            label == .cloud ? [.haiku, .pcc, .onDevice, .mlx] : [.pcc, .mlx, .onDevice]
        case .qaDeep:
            label == .cloud ? [.sonnet, .haiku, .pcc, .mlx, .onDevice] : [.pcc, .mlx, .onDevice]
        case .socratic:
            label == .cloud ? [.sonnet, .haiku, .pcc, .onDevice] : [.pcc, .mlx, .onDevice]
        case .extraction, .nli, .digest:
            label == .cloud ? [.sonnet, .mlx, .onDevice] : [.mlx, .onDevice]
        case .synthesis:
            // Quality-critical: local models would need a warning, so not offered (§6.1).
            [.opus, .sonnet]
        case .beliefDiff:
            label == .cloud ? [.opus, .sonnet, .mlx, .onDevice] : [.mlx, .onDevice]
        }
        return candidates.filter { $0.allows(label) }
    }
}

public struct RouteDecision: Sendable, Equatable {
    /// Routes to try, in order. Empty means refused.
    public let routes: [ModelRoute]
    /// The strictest label among the inputs; derived notes inherit it (taint).
    public let label: AILabel
    /// Why nothing could run, when `routes` is empty.
    public let refusal: String?
    /// Something the user should see (budget alert, degraded route).
    public let notice: String?
}

/// Pure routing: labels, availability and budget in, ordered routes out.
public struct Router: Sendable {
    public var available: Set<ModelRoute>
    public var budget: Budget
    public var spendThisMonth: Double

    public init(available: Set<ModelRoute>, budget: Budget, spendThisMonth: Double) {
        self.available = available
        self.budget = budget
        self.spendThisMonth = spendThisMonth
    }

    /// `labels` are the AI labels of every note whose text goes into the request.
    public func decide(_ task: ModelTask, labels: [AILabel], interactive: Bool) -> RouteDecision {
        let label = AILabel.strictest(labels) ?? .cloud
        if label == .none {
            return RouteDecision(routes: [], label: label, refusal: "These notes are labelled “none”: no model may read them.",
                                 notice: nil)
        }
        var notice: String?
        var preferred = task.preferences(for: label)
        if spendThisMonth >= budget.hardStopUSD && !interactive {
            preferred.removeAll { $0.isThirdPartyCloud }
            notice = String(format: "Monthly budget hard stop reached ($%.2f of $%.0f): background jobs use local models.",
                            spendThisMonth, budget.hardStopUSD)
        } else if spendThisMonth >= budget.alertUSD {
            notice = String(format: "Budget alert: $%.2f spent of $%.0f this month.", spendThisMonth, budget.monthlyUSD)
        }
        let routes = preferred.filter { available.contains($0) }
        if routes.isEmpty {
            let wanted = task.preferences(for: label).map(\.rawValue).joined(separator: ", ")
            let reason = task == .synthesis && label != .cloud
                ? "Literature synthesis runs only on cloud models, and these notes aren't labelled cloud."
                : "No model available for \(task.rawValue) on \(label.rawValue) notes (needs one of: \(wanted))."
            return RouteDecision(routes: [], label: label, refusal: reason, notice: notice)
        }
        if let first = routes.first, first != preferred.first, notice == nil {
            notice = "Using \(first.rawValue): \(preferred.first?.rawValue ?? "the preferred route") isn't available."
        }
        return RouteDecision(routes: routes, label: label, refusal: nil, notice: notice)
    }
}

/// Dollars per million tokens (master plan §6.7; Claude API list prices).
public enum Pricing {
    public static func usd(route: ModelRoute, inputTokens: Int, outputTokens: Int, batch: Bool = false) -> Double {
        let (input, output): (Double, Double) = switch route {
        case .haiku: inputTokens > 100_000 ? (0.50, 2.50) : (0.10, 0.50)
        case .sonnet: (2.00, 10.00)
        case .opus: (4.00, 20.00)
        case .onDevice, .pcc, .mlx: (0, 0)
        }
        let cost = (Double(inputTokens) * input + Double(outputTokens) * output) / 1_000_000
        return batch ? cost / 2 : cost
    }
}
