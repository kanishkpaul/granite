import Foundation

// The typed message channel between this host and the CodeMirror editor.
// Mirror: Editor/src/bridge.ts. Change both together; Editor/test/fixtures/bridge-messages.json
// is decoded and re-encoded by both sides (Vitest and EditorBridgeTests).

enum EditorBridge {
    static let protocolVersion = 1
    /// Name of the `WKScriptMessageHandler` the editor posts to.
    static let handlerName = "granite"
}

enum EditorCommand: String, Codable, Sendable {
    case undo, redo, focus, selectAll
}

/// Host → editor.
enum HostMessage: Codable, Sendable, Equatable {
    case load(path: String, text: String, version: Int, cursor: Int?)
    case setResolved(targets: [String])
    case command(EditorCommand)
    case bench(lines: [Int], keystrokes: Int, scrollMs: Int)

    private enum CodingKeys: String, CodingKey {
        case type, path, text, version, cursor, targets, name, lines, keystrokes, scrollMs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "load":
            self = .load(path: try container.decode(String.self, forKey: .path),
                         text: try container.decode(String.self, forKey: .text),
                         version: try container.decode(Int.self, forKey: .version),
                         cursor: try container.decodeIfPresent(Int.self, forKey: .cursor))
        case "setResolved":
            self = .setResolved(targets: try container.decode([String].self, forKey: .targets))
        case "command":
            self = .command(try container.decode(EditorCommand.self, forKey: .name))
        case "bench":
            self = .bench(lines: try container.decode([Int].self, forKey: .lines),
                          keystrokes: try container.decode(Int.self, forKey: .keystrokes),
                          scrollMs: try container.decode(Int.self, forKey: .scrollMs))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "unknown host message \(type)")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .load(let path, let text, let version, let cursor):
            try container.encode("load", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(text, forKey: .text)
            try container.encode(version, forKey: .version)
            try container.encodeIfPresent(cursor, forKey: .cursor)
        case .setResolved(let targets):
            try container.encode("setResolved", forKey: .type)
            try container.encode(targets, forKey: .targets)
        case .command(let name):
            try container.encode("command", forKey: .type)
            try container.encode(name, forKey: .name)
        case .bench(let lines, let keystrokes, let scrollMs):
            try container.encode("bench", forKey: .type)
            try container.encode(lines, forKey: .lines)
            try container.encode(keystrokes, forKey: .keystrokes)
            try container.encode(scrollMs, forKey: .scrollMs)
        }
    }

    /// JSON text handed to `window.granite.receive(_:)`.
    func json() throws -> String {
        String(decoding: try JSONEncoder().encode(self), as: UTF8.self)
    }
}

struct BenchResult: Codable, Sendable, Equatable {
    var typing: [Double]
    var parsedTyping: [Double]
    var parseMs: [Double]
    var domTyping: [Double]
    var scrollFrames: [Double]
    var undoRestored: Bool
    var redoReapplied: Bool
    var docLines: Int
}

/// Editor → host.
enum EditorMessage: Codable, Sendable, Equatable {
    case ready(protocol: Int)
    case loaded(version: Int, ms: Double)
    case changed(version: Int, text: String)
    case selection(anchor: Int, head: Int, line: Int)
    case openLink(target: String, heading: String?, blockID: String?, newPane: Bool)
    case benchResult(BenchResult)
    case log(level: String, message: String)

    private enum CodingKeys: String, CodingKey {
        case type, `protocol`, version, ms, text, anchor, head, line, target, heading, blockID, newPane, result, level,
             message
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "ready":
            self = .ready(protocol: try container.decode(Int.self, forKey: .protocol))
        case "loaded":
            self = .loaded(version: try container.decode(Int.self, forKey: .version),
                           ms: try container.decode(Double.self, forKey: .ms))
        case "changed":
            self = .changed(version: try container.decode(Int.self, forKey: .version),
                            text: try container.decode(String.self, forKey: .text))
        case "selection":
            self = .selection(anchor: try container.decode(Int.self, forKey: .anchor),
                              head: try container.decode(Int.self, forKey: .head),
                              line: try container.decode(Int.self, forKey: .line))
        case "openLink":
            self = .openLink(target: try container.decode(String.self, forKey: .target),
                             heading: try container.decodeIfPresent(String.self, forKey: .heading),
                             blockID: try container.decodeIfPresent(String.self, forKey: .blockID),
                             newPane: try container.decode(Bool.self, forKey: .newPane))
        case "benchResult":
            self = .benchResult(try container.decode(BenchResult.self, forKey: .result))
        case "log":
            self = .log(level: try container.decode(String.self, forKey: .level),
                        message: try container.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "unknown editor message \(type)")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ready(let version):
            try container.encode("ready", forKey: .type)
            try container.encode(version, forKey: .protocol)
        case .loaded(let version, let ms):
            try container.encode("loaded", forKey: .type)
            try container.encode(version, forKey: .version)
            try container.encode(ms, forKey: .ms)
        case .changed(let version, let text):
            try container.encode("changed", forKey: .type)
            try container.encode(version, forKey: .version)
            try container.encode(text, forKey: .text)
        case .selection(let anchor, let head, let line):
            try container.encode("selection", forKey: .type)
            try container.encode(anchor, forKey: .anchor)
            try container.encode(head, forKey: .head)
            try container.encode(line, forKey: .line)
        case .openLink(let target, let heading, let blockID, let newPane):
            try container.encode("openLink", forKey: .type)
            try container.encode(target, forKey: .target)
            try container.encodeIfPresent(heading, forKey: .heading)
            try container.encodeIfPresent(blockID, forKey: .blockID)
            try container.encode(newPane, forKey: .newPane)
        case .benchResult(let result):
            try container.encode("benchResult", forKey: .type)
            try container.encode(result, forKey: .result)
        case .log(let level, let message):
            try container.encode("log", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(message, forKey: .message)
        }
    }

    /// Decodes a `WKScriptMessage.body` (a Foundation dictionary) or raw JSON data.
    static func decode(body: Any) throws -> EditorMessage {
        let data: Data
        if let raw = body as? Data {
            data = raw
        } else if let text = body as? String {
            data = Data(text.utf8)
        } else {
            data = try JSONSerialization.data(withJSONObject: body)
        }
        return try JSONDecoder().decode(EditorMessage.self, from: data)
    }
}
