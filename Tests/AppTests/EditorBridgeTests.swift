import Foundation
import Testing
@testable import granite

/// Round-trip against the fixtures Vitest also uses (Editor/test/fixtures/bridge-messages.json):
/// every message decodes, and re-encodes to the same JSON object.
@Suite struct EditorBridgeTests {
    struct Fixtures {
        let host: [Any]
        let editor: [Any]
        let invalidHost: [Any]
    }

    func fixtures() throws -> Fixtures {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: "bridge-messages", withExtension: "json"))
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url), options: [.fragmentsAllowed]) as? [String: Any])
        return Fixtures(host: object["host"] as? [Any] ?? [], editor: object["editor"] as? [Any] ?? [],
                        invalidHost: object["invalidHost"] as? [Any] ?? [])
    }

    func roundTrip<T: Codable>(_ type: T.Type, _ value: Any) throws -> (NSDictionary, NSDictionary) {
        let data = try JSONSerialization.data(withJSONObject: value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        let encoded = try JSONEncoder().encode(decoded)
        let again = try #require(try JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        return (try #require(value as? NSDictionary), again)
    }

    @Test func hostMessagesRoundTrip() throws {
        let fixtures = try fixtures()
        #expect(fixtures.host.count == 16)
        for message in fixtures.host {
            let (original, again) = try roundTrip(HostMessage.self, message)
            #expect(original == again)
        }
    }

    @Test func editorMessagesRoundTrip() throws {
        let fixtures = try fixtures()
        #expect(fixtures.editor.count == 13)
        for message in fixtures.editor {
            let (original, again) = try roundTrip(EditorMessage.self, message)
            #expect(original == again)
            // The WKScriptMessage path: a Foundation dictionary body.
            _ = try EditorMessage.decode(body: message)
        }
    }

    @Test func invalidHostMessagesAreRejected() throws {
        for message in try fixtures().invalidHost {
            guard JSONSerialization.isValidJSONObject(message) else { continue }
            let data = try JSONSerialization.data(withJSONObject: message)
            #expect(throws: (any Error).self) { try JSONDecoder().decode(HostMessage.self, from: data) }
        }
    }

    @Test func loadEncodesForReceive() throws {
        let json = try HostMessage.load(path: "a.md", text: "x\n\"y\"", version: 2, cursor: nil).json()
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["type"] as? String == "load")
        #expect(object["text"] as? String == "x\n\"y\"")
        #expect(object["cursor"] == nil)
    }
}

private final class BundleToken {}
