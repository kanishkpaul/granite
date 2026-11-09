import Foundation
import KBCore

public enum DoclingError: Error, Equatable, CustomStringConvertible {
    case notInstalled
    case failed(String)
    case noOutput

    public var description: String {
        switch self {
        case .notInstalled: "Docling isn't installed (pipx install docling, or uv tool install docling)"
        case .failed(let message): "Docling failed: \(message)"
        case .noOutput: "Docling produced no Markdown"
        }
    }
}

/// Structured text for papers you mark "study" (master plan §5 step 4): runs the Docling CLI as a
/// subprocess per paper (never resident), caches its Markdown outside the vault, and rewrites the
/// paper's full-text note from it (tables and sections instead of page text).
public struct DoclingRunner: Sendable {
    public let executable: URL
    public let cache: URL

    /// The `docling` executable on PATH or in the usual tool folders, if any.
    public static func locate(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let folders = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
            + ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        for folder in folders {
            let candidate = URL(filePath: folder).appending(path: "docling")
            if FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) { return candidate }
        }
        return nil
    }

    public init(executable: URL, cache: URL) {
        self.executable = executable
        self.cache = cache
    }

    /// Converts the PDF (cached by citekey) and returns Docling's Markdown.
    public func markdown(pdf: URL, citekey: String, timeout: Duration = .seconds(600)) async throws -> String {
        let cached = cache.appending(path: "\(citekey).md")
        if let text = try? String(contentsOf: cached, encoding: .utf8), !text.isEmpty { return text }
        let out = FileManager.default.temporaryDirectory.appending(path: "granite-docling-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: out) }
        let status = try await Self.run(executable, ["--to", "md", "--output", out.path(percentEncoded: false), pdf.path(percentEncoded: false)],
                                        timeout: timeout)
        guard status.code == 0 else { throw DoclingError.failed(status.stderr.split(separator: "\n").last.map(String.init) ?? "exit \(status.code)") }
        let produced = (try? FileManager.default.contentsOfDirectory(atPath: out.path(percentEncoded: false)))?.first { $0.hasSuffix(".md") }
        guard let produced, let text = try? String(contentsOf: out.appending(path: produced), encoding: .utf8), !text.isEmpty else {
            throw DoclingError.noOutput
        }
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: cached)
        return text
    }

    /// The full-text note rebuilt from Docling's Markdown: its headings sit under the note title.
    public static func textNote(paths: PaperPaths, title: String, markdown: String) -> String {
        var lines = ["---", "type: source", "kind: paper-text", "origin: source", "paper: \"[[\(paths.citekey)]]\"",
                     "pdf: \(FrontmatterEditor.yamlScalar(paths.pdf))", "text: docling", "---", "# \(title) (full text)", ""]
        var inFence = false
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("```") { inFence.toggle() }
            // One level deeper, so the paper's own "#" doesn't compete with the note title.
            if !inFence, line.hasPrefix("#"), line.count < 200 {
                lines.append("#" + line)
            } else {
                lines.append(inFence ? line : line.replacingOccurrences(of: "[[", with: "[\\["))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    struct Status { let code: Int32; let stderr: String }

    static func run(_ executable: URL, _ arguments: [String], timeout: Duration) async throws -> Status {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let errURL = FileManager.default.temporaryDirectory.appending(path: "granite-docling-err-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: errURL.path(percentEncoded: false), contents: nil)
        defer { try? FileManager.default.removeItem(at: errURL) }
        let errHandle = try FileHandle(forWritingTo: errURL)
        process.standardError = errHandle
        process.standardOutput = FileHandle.nullDevice
        let code: Int32 = try await withThrowingTaskGroup(of: Int32?.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    process.terminationHandler = { finished in continuation.resume(returning: finished.terminationStatus) }
                    do { try process.run() } catch { continuation.resume(throwing: error) }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            if first == nil, process.isRunning { process.terminate() }
            return first ?? -1
        }
        try? errHandle.close()
        let stderr = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
        if code == -1 { throw DoclingError.failed("timed out") }
        return Status(code: code, stderr: stderr)
    }
}
