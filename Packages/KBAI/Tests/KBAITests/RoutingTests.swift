import Foundation
import KBCore
import KBIndex
import Testing
@testable import KBAI

@Suite struct RoutingTests {
    let everything = Set(ModelRoute.allCases)

    func router(_ available: Set<ModelRoute>? = nil, spend: Double = 0) -> Router {
        Router(available: available ?? everything, budget: .standard, spendThisMonth: spend)
    }

    @Test func strictestLabelWinsAndLimitsRoutes() {
        let cloud = router().decide(.qa, labels: [.cloud, .cloud], interactive: true)
        #expect(cloud.routes.first == .haiku && cloud.label == .cloud)
        let mixed = router().decide(.qa, labels: [.cloud, .pcc], interactive: true)
        #expect(mixed.label == .pcc && mixed.routes == [.pcc, .mlx, .onDevice])
        let local = router().decide(.qa, labels: [.cloud, .local], interactive: true)
        #expect(local.routes == [.mlx, .onDevice])
        #expect(!local.routes.contains { $0.isThirdPartyCloud })
        let none = router().decide(.tagging, labels: [.cloud, .none], interactive: true)
        #expect(none.routes.isEmpty && none.refusal?.contains("none") == true)
    }

    @Test func availabilityAndNotices() {
        let noKey = router([.onDevice, .pcc]).decide(.qa, labels: [.cloud], interactive: true)
        #expect(noKey.routes == [.pcc, .onDevice])
        #expect(noKey.notice?.contains("haiku") == true)
        let nothing = router([]).decide(.qa, labels: [.cloud], interactive: true)
        #expect(nothing.routes.isEmpty && nothing.refusal != nil)
    }

    @Test func synthesisIsCloudOnly() {
        #expect(router().decide(.synthesis, labels: [.cloud], interactive: true).routes == [.opus, .sonnet])
        let local = router().decide(.synthesis, labels: [.local], interactive: true)
        #expect(local.routes.isEmpty && local.refusal?.contains("cloud") == true)
    }

    @Test func budgetHardStopsBackgroundCloudWork() {
        let alert = router(spend: 16).decide(.digest, labels: [.cloud], interactive: false)
        #expect(alert.routes.first == .sonnet && alert.notice?.contains("Budget alert") == true)
        let stopped = router(spend: 25).decide(.digest, labels: [.cloud], interactive: false)
        #expect(stopped.routes == [.mlx, .onDevice] && stopped.notice?.contains("hard stop") == true)
        let interactive = router(spend: 25).decide(.qa, labels: [.cloud], interactive: true)
        #expect(interactive.routes.first == .haiku, "you can still ask questions; only background jobs stop")
    }

    @Test func smallTasksStayOnDevice() {
        for task in [ModelTask.tagging, .linkReason, .contextPrefix, .triage] {
            #expect(router().decide(task, labels: [.cloud], interactive: false).routes == [.onDevice, .mlx])
        }
    }

    @Test func pricing() {
        #expect(Pricing.usd(route: .haiku, inputTokens: 8_000, outputTokens: 600) == 0.0011)
        #expect(Pricing.usd(route: .sonnet, inputTokens: 60_000, outputTokens: 2_000, batch: true) == 0.07)
        #expect(Pricing.usd(route: .onDevice, inputTokens: 1_000_000, outputTokens: 1_000_000) == 0)
    }
}

@Suite struct OutputSchemaTests {
    static let answer = OutputSchema.object(name: "Answer", fields: [
        .init("sentences", .array(.object(name: "Sentence", fields: [
            .init("text", .string()), .init("chunk", .string("chunk id")), .init("quote", .string(), optional: true),
        ]))),
        .init("confidence", .choice(["low", "high"])),
    ])

    @Test func jsonSchemaIsClosedAndComplete() throws {
        let schema = Self.answer.jsonSchema
        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(schema["required"] as? [String] == ["sentences", "confidence"])
        let sentence = ((schema["properties"] as? [String: Any])?["sentences"] as? [String: Any])?["items"] as? [String: Any]
        #expect(sentence?["required"] as? [String] == ["text", "chunk", "quote"])
        let quote = (sentence?["properties"] as? [String: Any])?["quote"] as? [String: Any]
        #expect((quote?["anyOf"] as? [Any])?.count == 2)
        #expect(Self.answer.promptHint.contains("\"enum\":[\"low\",\"high\"]"))
    }

    @Test func extractsJSONFromProse() {
        #expect(OutputSchema.extractJSON("Sure!\n```json\n{\"a\": \"}\", \"b\": [1, {\"c\": 2}]}\n```") == #"{"a": "}", "b": [1, {"c": 2}]}"#)
        #expect(OutputSchema.extractJSON("[1,2] tail") == "[1,2]")
        #expect(OutputSchema.extractJSON("no json") == "no json")
    }
}

/// Scripted provider: each call returns the next result.
final class FakeProvider: LanguageProvider, @unchecked Sendable {
    let route: ModelRoute
    var available: Bool
    var results: [Result<Generation, ModelError>]
    private(set) var calls = 0
    let lock = NSLock()

    init(_ route: ModelRoute, available: Bool = true, results: [Result<Generation, ModelError>]) {
        self.route = route
        self.available = available
        self.results = results
    }

    func isAvailable() async -> Bool { available }

    func generate(_ request: GenerationRequest) async throws -> Generation {
        let result = lock.withLock { () -> Result<Generation, ModelError> in
            calls += 1
            return results.isEmpty ? .failure(.unavailable("script exhausted")) : results.removeFirst()
        }
        return try result.get()
    }
}

@Suite struct ModelServiceTests {
    func state() throws -> StateDatabase {
        try StateDatabase(url: FileManager.default.temporaryDirectory.appending(path: "granite-ms-\(UUID().uuidString)/state.sqlite"))
    }

    func ok(_ text: String, _ model: String, input: Int = 1_000, output: Int = 100) -> Result<Generation, ModelError> {
        .success(Generation(text: text, inputTokens: input, outputTokens: output, model: model))
    }

    @Test func fallsBackAndAuditsEveryAttempt() async throws {
        let state = try state()
        let haiku = FakeProvider(.haiku, results: [.failure(.http(status: 500, message: "boom"))])
        let pcc = FakeProvider(.pcc, results: [.failure(.unavailable("ModelManagerError 1046"))])
        let device = FakeProvider(.onDevice, results: [ok("answer", "apple-on-device")])
        let service = ModelService(providers: [haiku, pcc, device], state: state)
        let result = try await service.run(.qa, labels: [.cloud], notePaths: ["Notes/b.md", "Notes/a.md", "Notes/a.md"],
                                           request: GenerationRequest(system: "s", prompt: "p"))
        #expect(result.route == .onDevice && result.generation.text == "answer" && result.label == .cloud)
        #expect(result.notice?.contains("pcc failed") == true)
        let audit = try state.recentAudit()
        #expect(audit.map(\.route).sorted() == ["haiku", "on-device", "pcc"])
        #expect(audit.first { $0.route == "on-device" }?.notePaths == ["Notes/a.md", "Notes/b.md"])
        #expect(audit.filter { $0.outcome.hasPrefix("error") }.count == 2)

        // Failed routes cool down: the next call goes straight to the device.
        device.results = [ok("again", "apple-on-device")]
        _ = try await service.run(.qa, labels: [.cloud], notePaths: [], request: GenerationRequest(system: "s", prompt: "p"))
        #expect(haiku.calls == 1 && pcc.calls == 1)
    }

    @Test func refusalsDoNotFallBack() async throws {
        let sonnet = FakeProvider(.sonnet, results: [.failure(.refused("cyber"))])
        let device = FakeProvider(.onDevice, results: [ok("x", "apple")])
        let service = ModelService(providers: [sonnet, device], state: nil)
        await #expect(throws: ModelError.refused("cyber")) {
            try await service.run(.socratic, labels: [.cloud], notePaths: [], request: GenerationRequest(system: "", prompt: ""))
        }
        #expect(device.calls == 0)
    }

    @Test func costsAccumulateIntoTheBudget() async throws {
        let state = try state()
        let haiku = FakeProvider(.haiku, results: [ok("a", "claude-haiku-5-5", input: 8_000, output: 600)])
        let service = ModelService(providers: [haiku], state: state)
        _ = try await service.run(.qa, labels: [.cloud], notePaths: [], request: GenerationRequest(system: "", prompt: ""))
        #expect(await service.spendThisMonth() == 0.0011)
    }

    @Test func noneLabelAndMissingRoutesRefuse() async {
        let service = ModelService(providers: [FakeProvider(.onDevice, results: [])], state: nil)
        await #expect(throws: ModelError.self) {
            try await service.run(.tagging, labels: [.none], notePaths: [], request: GenerationRequest(system: "", prompt: ""))
        }
        await #expect(throws: ModelError.self) {
            try await service.run(.synthesis, labels: [.cloud], notePaths: [], request: GenerationRequest(system: "", prompt: ""))
        }
    }
}
