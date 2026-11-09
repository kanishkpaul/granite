import Foundation
import GraniteMCPKit
import MCP

// granite-mcp --vault <folder> [--db <index.sqlite>] [--read-only]
// stdio MCP server. stdout carries the protocol: everything else goes to stderr.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("granite-mcp: \(message)\n".utf8))
    exit(1)
}

func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let arguments = CommandLine.arguments
if arguments.contains("--help") || arguments.contains("-h") {
    FileHandle.standardError.write(Data("usage: granite-mcp --vault <folder> [--db <index.sqlite>] [--read-only]\n".utf8))
    exit(0)
}
guard let vaultPath = value(after: "--vault", in: arguments) else { fail("missing --vault <folder>") }

do {
    let tools = try GraniteServer.tools(vaultPath: vaultPath, databasePath: value(after: "--db", in: arguments),
                                        readOnly: arguments.contains("--read-only"))
    let server = await GraniteServer.make(tools: tools)
    try await server.start(transport: StdioTransport())
    await server.waitUntilCompleted()
} catch {
    fail("\(error)")
}
