import Foundation
import KBCore
import KBIndex

public struct ModelResult: Sendable {
    public let generation: Generation
    public let route: ModelRoute
    /// The strictest input label. Anything written from this result inherits it (taint).
    public let label: AILabel
    public let notice: String?
}

/// Every model call goes through here: route by task and labels, enforce the budget, fall back
/// when a route fails, and record each attempt in the audit log (master plan §6.1, §6.6).
public actor ModelService {
    private var providers: [ModelRoute: any LanguageProvider]
    let state: StateDatabase?
    var budget: Budget
    private var cachedAvailability: (routes: Set<ModelRoute>, at: Date)?
    /// Routes that failed recently (PCC can report available and still fail): skipped for a while.
    private var cooling: [ModelRoute: Date] = [:]
    let coolDown: TimeInterval

    public init(providers: [any LanguageProvider], state: StateDatabase?,
                budget: Budget = Budget(monthlyUSD: 20, alertUSD: 15, hardStopUSD: 25), coolDown: TimeInterval = 3_600) {
        self.providers = Dictionary(providers.map { ($0.route, $0) }, uniquingKeysWith: { first, _ in first })
        self.state = state
        self.budget = budget
        self.coolDown = coolDown
    }

    /// Apple on-device, PCC and the three Claude routes. MLX is added by the app when configured.
    public static func standardProviders() -> [any LanguageProvider] {
        [AppleProvider(route: .onDevice), AppleProvider(route: .pcc),
         ClaudeProvider(route: .haiku), ClaudeProvider(route: .sonnet), ClaudeProvider(route: .opus)]
    }

    public func add(_ provider: any LanguageProvider) {
        providers[provider.route] = provider
        cachedAvailability = nil
    }

    public func setBudget(_ budget: Budget) { self.budget = budget }

    public func availability(refresh: Bool = false) async -> Set<ModelRoute> {
        if !refresh, let cached = cachedAvailability, Date().timeIntervalSince(cached.at) < 60 { return cached.routes }
        var routes = Set<ModelRoute>()
        for (route, provider) in providers where await provider.isAvailable() { routes.insert(route) }
        cachedAvailability = (routes, Date())
        return routes
    }

    public func spendThisMonth() -> Double {
        (try? state?.spend()) ?? 0
    }

    public func decide(_ task: ModelTask, labels: [AILabel], interactive: Bool) async -> RouteDecision {
        let now = Date()
        let available = await availability().filter { cooling[$0].map { now.timeIntervalSince($0) > coolDown } ?? true }
        return Router(available: available, budget: budget, spendThisMonth: spendThisMonth())
            .decide(task, labels: labels, interactive: interactive)
    }

    public func run(_ task: ModelTask, labels: [AILabel], notePaths: [String], request: GenerationRequest,
                    interactive: Bool = true) async throws -> ModelResult {
        let decision = await decide(task, labels: labels, interactive: interactive)
        guard !decision.routes.isEmpty else { throw ModelError.noRoute(decision.refusal ?? "no route") }
        var lastError: ModelError = .noRoute("no route")
        var notice = decision.notice
        for route in decision.routes {
            guard let provider = providers[route] else { continue }
            do {
                let generation = try await provider.generate(request)
                audit(route: route, model: generation.model, task: task, label: decision.label, generation: generation,
                      paths: notePaths, hash: request.hash, outcome: "ok")
                return ModelResult(generation: generation, route: route, label: decision.label, notice: notice)
            } catch let error as ModelError {
                audit(route: route, model: route.rawValue, task: task, label: decision.label, generation: nil,
                      paths: notePaths, hash: request.hash, outcome: "error: \(error)")
                lastError = error
                guard error.allowsFallback else { throw error }
                cooling[route] = Date()
                notice = "\(route.rawValue) failed (\(error)); trying the next route."
            }
        }
        throw lastError
    }

    private func audit(route: ModelRoute, model: String, task: ModelTask, label: AILabel, generation: Generation?,
                       paths: [String], hash: String, outcome: String) {
        let input = generation?.inputTokens ?? 0
        let output = generation?.outputTokens ?? 0
        try? state?.record(AuditEntry(route: route.rawValue, model: model, task: task.rawValue, label: label.rawValue,
                                      inputTokens: input, outputTokens: output,
                                      usd: Pricing.usd(route: route, inputTokens: input, outputTokens: output),
                                      notePaths: Array(Set(paths)).sorted(), promptHash: hash, outcome: outcome))
    }
}
