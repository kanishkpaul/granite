import Foundation

/// A small schema language for structured output, translated to JSON Schema for Claude and to
/// FoundationModels' dynamic schemas on device. Objects are closed (no extra properties).
public indirect enum OutputSchema: Sendable, Hashable {
    case string(String? = nil)
    case number(String? = nil)
    case integer(String? = nil)
    case boolean(String? = nil)
    case choice([String], String? = nil)
    case array(OutputSchema, String? = nil)
    case object(name: String, fields: [Field], String? = nil)

    public struct Field: Sendable, Hashable {
        public let name: String
        public let schema: OutputSchema
        public let optional: Bool

        public init(_ name: String, _ schema: OutputSchema, optional: Bool = false) {
            self.name = name
            self.schema = schema
            self.optional = optional
        }
    }

    public var description: String? {
        switch self {
        case .string(let d), .number(let d), .integer(let d), .boolean(let d), .choice(_, let d), .array(_, let d),
             .object(_, _, let d): d
        }
    }

    /// JSON Schema (draft 2020-12 subset the Claude API accepts).
    public var jsonSchema: [String: Any] {
        var schema: [String: Any]
        switch self {
        case .string: schema = ["type": "string"]
        case .number: schema = ["type": "number"]
        case .integer: schema = ["type": "integer"]
        case .boolean: schema = ["type": "boolean"]
        case .choice(let values, _): schema = ["type": "string", "enum": values]
        case .array(let item, _): schema = ["type": "array", "items": item.jsonSchema]
        case .object(_, let fields, _):
            var properties: [String: Any] = [:]
            for field in fields {
                properties[field.name] = field.optional
                    ? ["anyOf": [field.schema.jsonSchema, ["type": "null"]]]
                    : field.schema.jsonSchema
            }
            // Strict structured outputs want every property listed as required; optional ones are nullable.
            schema = ["type": "object", "properties": properties, "required": fields.map(\.name),
                      "additionalProperties": false]
        }
        if let description { schema["description"] = description }
        return schema
    }

    /// Text describing the expected JSON, for routes without native structured output.
    public var promptHint: String {
        let data = (try? JSONSerialization.data(withJSONObject: jsonSchema, options: [.sortedKeys])) ?? Data()
        return "Respond with only a JSON value matching this JSON Schema, no prose:\n" + String(decoding: data, as: UTF8.self)
    }

    /// The first complete JSON object or array in `text` (skips prose and ``` fences).
    public static func extractJSON(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        guard let start = scalars.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return text }
        var depth = 0
        var inString = false
        var escaped = false
        for index in start..<scalars.count {
            let c = scalars[index]
            if inString {
                if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
                continue
            }
            switch c {
            case "\"": inString = true
            case "{", "[": depth += 1
            case "}", "]":
                depth -= 1
                if depth == 0 { return String(String.UnicodeScalarView(scalars[start...index])) }
            default: break
            }
        }
        return String(String.UnicodeScalarView(scalars[start...]))
    }
}
