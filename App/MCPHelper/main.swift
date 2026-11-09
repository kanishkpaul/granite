import Darwin
import Foundation
import GraniteMCPKit
import KBAIMLX
import KBIndex

// granite.app/Contents/MacOS/granite-mcp --vault <folder> [--db <index.sqlite>] [--no-semantic] [--read-only]
// The bundled MCP server: like Tools/granite-mcp, plus hybrid search when the vault already has
// vectors (so it never starts a model download on its own). stdout carries the protocol.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("granite-mcp: \(message)\n".utf8))
    exit(1)
}

func value(after flag: String) -> String? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

guard let vaultPath = value(after: "--vault") else { fail("missing --vault <folder>") }
let databasePath = value(after: "--db")
let semantic = !CommandLine.arguments.contains("--no-semantic")

do {
    var embedder: MLXEmbedder?
    if semantic {
        let probe = try GraniteServer.tools(vaultPath: vaultPath, databasePath: databasePath)
        if let model = GraniteServer.embeddingModel(in: probe.database),
           let id = model.split(separator: "@").first.map(String.init) {
            // Keep library chatter off stdout while models load: stdout is the protocol channel.
            let savedStdout = dup(STDOUT_FILENO)
            dup2(STDERR_FILENO, STDOUT_FILENO)
            embedder = try? await MLXEmbedder.load(id: id)
            dup2(savedStdout, STDOUT_FILENO)
            close(savedStdout)
            if embedder?.modelID != model {
                FileHandle.standardError.write(Data("granite-mcp: vectors were made with \(model); using keyword search\n".utf8))
                embedder = nil
            }
        }
    }
    let loaded = embedder
    let tools = try GraniteServer.tools(vaultPath: vaultPath, databasePath: databasePath, hybrid: { database in
        guard let loaded else { return nil }
        return HybridSearcher(database: database, vectors: VectorIndex(database: database), embedder: loaded, reranker: nil)
    }, readOnly: CommandLine.arguments.contains("--read-only"))
    FileHandle.standardError.write(Data("granite-mcp: \(loaded == nil ? "keyword" : "hybrid") search\n".utf8))
    try await GraniteServer.serveStdio(tools)
} catch {
    fail("\(error)")
}
