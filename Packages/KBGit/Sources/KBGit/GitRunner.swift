import Foundation

public struct GitOutput: Sendable {
    public let status: Int32
    public let stdout: Data
    public let stderr: String

    public var text: String { String(decoding: stdout, as: UTF8.self) }
    public var succeeded: Bool { status == 0 }
}

public enum GitError: Error, CustomStringConvertible, Equatable {
    case launch(String)
    case failed(command: String, status: Int32, stderr: String)

    public var description: String {
        switch self {
        case .launch(let reason): "could not run git: \(reason)"
        case .failed(let command, let status, let stderr):
            "git \(command) failed (\(status)): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

/// Runs `/usr/bin/git` in one directory. Output goes to temporary files rather than pipes, so a
/// large diff can never fill a pipe buffer and deadlock. Git never prompts: no terminal, ssh in
/// batch mode.
struct GitRunner: Sendable {
    let executable: URL
    let directory: URL

    @discardableResult
    func run(_ arguments: [String], environment extra: [String: String] = [:], check: Bool = true) async throws -> GitOutput {
        let scratch = FileManager.default.temporaryDirectory.appending(path: "granite-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let outURL = scratch.appending(path: "out")
        let errURL = scratch.appending(path: "err")
        FileManager.default.createFile(atPath: outURL.path(percentEncoded: false), contents: nil)
        FileManager.default.createFile(atPath: errURL.path(percentEncoded: false), contents: nil)
        let out = try FileHandle(forWritingTo: outURL)
        let err = try FileHandle(forWritingTo: errURL)
        defer {
            try? out.close()
            try? err.close()
        }

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["LC_ALL"] = "C"
        for (key, value) in extra { environment[key] = value }

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = ["-C", directory.path(percentEncoded: false)] + arguments
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = out
            process.standardError = err
            process.terminationHandler = { finished in continuation.resume(returning: finished.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GitError.launch(error.localizedDescription))
            }
        }
        let output = GitOutput(status: status, stdout: (try? Data(contentsOf: outURL)) ?? Data(),
                               stderr: String(decoding: (try? Data(contentsOf: errURL)) ?? Data(), as: UTF8.self))
        if check && !output.succeeded {
            throw GitError.failed(command: arguments.first ?? "", status: status, stderr: output.stderr)
        }
        return output
    }
}
