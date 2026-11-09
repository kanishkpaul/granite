import Foundation
import FoundationModels

/// Apple's on-device model or Private Cloud Compute, through FoundationModels.
/// Structured output uses guided generation with a dynamic schema, so the JSON always parses.
public struct AppleProvider: LanguageProvider {
    public let route: ModelRoute

    public init(route: ModelRoute) {
        precondition(route == .onDevice || route == .pcc, "AppleProvider serves on-device and PCC only")
        self.route = route
    }

    public func isAvailable() async -> Bool {
        route == .pcc ? PrivateCloudComputeLanguageModel().isAvailable : SystemLanguageModel.default.isAvailable
    }

    public func generate(_ request: GenerationRequest) async throws -> Generation {
        let prompt = request.promptWithDocuments
        do {
            let text: String
            if route == .pcc {
                text = try await respond(LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: request.system),
                                         prompt: prompt, schema: request.schema)
            } else {
                text = try await respond(LanguageModelSession(model: SystemLanguageModel.default, instructions: request.system),
                                         prompt: prompt, schema: request.schema)
            }
            // FoundationModels reports no token counts; estimate (≈ 4 characters per token) for the audit log.
            return Generation(text: text, inputTokens: (request.system.count + prompt.count) / 4, outputTokens: text.count / 4,
                              model: route == .pcc ? "apple-pcc" : "apple-on-device")
        } catch let error as LanguageModelError {
            throw ModelError.unavailable("\(route.rawValue): \(error)")
        } catch let error as ModelError {
            throw error
        } catch {
            throw ModelError.unavailable("\(route.rawValue): \(error)")
        }
    }

    private func respond(_ session: LanguageModelSession, prompt: String, schema: OutputSchema?) async throws -> String {
        guard let schema else { return try await session.respond(to: prompt).content }
        var counter = 0
        let generationSchema = try GenerationSchema(root: schema.dynamic(name: "Output", counter: &counter), dependencies: [])
        return try await session.respond(to: prompt, schema: generationSchema).content.jsonString
    }
}

extension OutputSchema {
    /// FoundationModels equivalent. Named types get unique names within one schema.
    func dynamic(name: String, counter: inout Int) -> DynamicGenerationSchema {
        counter += 1
        let unique = "\(name)\(counter)"
        switch self {
        case .string: return DynamicGenerationSchema(type: String.self)
        case .number: return DynamicGenerationSchema(type: Double.self)
        case .integer: return DynamicGenerationSchema(type: Int.self)
        case .boolean: return DynamicGenerationSchema(type: Bool.self)
        case .choice(let values, let description):
            return DynamicGenerationSchema(name: unique, description: description, anyOf: values)
        case .array(let item, _):
            return DynamicGenerationSchema(arrayOf: item.dynamic(name: name + "Item", counter: &counter))
        case .object(let objectName, let fields, let description):
            var properties: [DynamicGenerationSchema.Property] = []
            for field in fields {
                properties.append(DynamicGenerationSchema.Property(
                    name: field.name, description: field.schema.description,
                    schema: field.schema.dynamic(name: objectName + "_" + field.name, counter: &counter), isOptional: field.optional))
            }
            return DynamicGenerationSchema(name: "\(objectName)\(counter)", description: description, properties: properties)
        }
    }
}
