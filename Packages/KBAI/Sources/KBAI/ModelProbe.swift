import Foundation
import FoundationModels

/// One row of the spike D route matrix (master plan §6.1).
public struct RouteStatus: Sendable {
    public enum Route: String, Sendable, CaseIterable {
        case onDevice = "on-device"
        case pcc
        case mlx
        case claude
    }

    public let route: Route
    public let available: Bool
    /// Why a route is unavailable, quota state, or what is not wired yet.
    public let detail: String
    public let contextSize: Int?
    /// Round trip for a one-line prompt, when one was sent.
    public let latencyMs: Double?
    public let reply: String?
}

/// Checks which model routes work on this Mac. Sends only a fixed, content-free prompt.
public enum ModelProbe {
    public static let prompt = "Reply with exactly one word: ready"

    public static func run(sendPrompt: Bool) async -> [RouteStatus] {
        [
            await onDevice(sendPrompt: sendPrompt),
            await privateCloud(sendPrompt: sendPrompt),
            RouteStatus(route: .mlx, available: false, detail: "not wired yet (spike B part 2: mlx-swift-lm)",
                        contextSize: nil, latencyMs: nil, reply: nil),
            RouteStatus(route: .claude, available: false, detail: "not wired yet (needs the Messages client and a Keychain API key)",
                        contextSize: nil, latencyMs: nil, reply: nil),
        ]
    }

    static func onDevice(sendPrompt: Bool) async -> RouteStatus {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            let reason: String = switch model.availability {
            case .unavailable(.deviceNotEligible): "device not eligible"
            case .unavailable(.appleIntelligenceNotEnabled): "Apple Intelligence is turned off in System Settings"
            case .unavailable(.modelNotReady): "model not ready (still downloading?)"
            default: "unavailable"
            }
            return RouteStatus(route: .onDevice, available: false, detail: reason, contextSize: nil, latencyMs: nil, reply: nil)
        }
        let context = model.contextSize
        guard sendPrompt else {
            return RouteStatus(route: .onDevice, available: true, detail: "available", contextSize: context,
                               latencyMs: nil, reply: nil)
        }
        let session = LanguageModelSession(model: model)
        return await respond(route: .onDevice, contextSize: context) { try await session.respond(to: prompt).content }
    }

    static func privateCloud(sendPrompt: Bool) async -> RouteStatus {
        let model = PrivateCloudComputeLanguageModel()
        guard case .available = model.availability else {
            let reason: String = switch model.availability {
            case .unavailable(.deviceNotEligible): "device not eligible"
            case .unavailable(.systemNotReady): "system not ready"
            default: "unavailable"
            }
            return RouteStatus(route: .pcc, available: false, detail: reason, contextSize: nil, latencyMs: nil, reply: nil)
        }
        let quota: String = switch model.quotaUsage.status {
        case .belowLimit: "quota below limit"
        case .limitReached: "quota limit reached"
        @unknown default: "quota unknown"
        }
        let context = try? await model.contextSize
        guard sendPrompt else {
            return RouteStatus(route: .pcc, available: true, detail: quota, contextSize: context, latencyMs: nil, reply: nil)
        }
        let session = LanguageModelSession(model: model)
        let status = await respond(route: .pcc, contextSize: context) { try await session.respond(to: prompt).content }
        return RouteStatus(route: .pcc, available: status.available, detail: "\(quota); \(status.detail)",
                           contextSize: context, latencyMs: status.latencyMs, reply: status.reply)
    }

    static func respond(route: RouteStatus.Route, contextSize: Int?,
                        _ body: () async throws -> String) async -> RouteStatus {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let reply = try await body()
            let elapsed = clock.now - start
            let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
            return RouteStatus(route: route, available: true, detail: "responded", contextSize: contextSize,
                               latencyMs: ms, reply: reply.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return RouteStatus(route: route, available: false, detail: "respond failed: \(error)", contextSize: contextSize,
                               latencyMs: nil, reply: nil)
        }
    }
}
