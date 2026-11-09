import AppKit
import SwiftUI

/// `granite --editor-bench <file.md> [--bench-out <result.json>]`
struct BenchArguments {
    let file: URL
    let output: URL?

    init?(_ arguments: [String]) {
        guard let index = arguments.firstIndex(of: "--editor-bench"), index + 1 < arguments.count else { return nil }
        file = URL(filePath: arguments[index + 1])
        if let out = arguments.firstIndex(of: "--bench-out"), out + 1 < arguments.count {
            output = URL(filePath: arguments[out + 1])
        } else {
            output = nil
        }
    }
}

/// Spike A gates, measured in the real WKWebView: open time, keystroke-to-paint, scrolling, undo/redo.
struct EditorBenchView: View {
    let arguments: BenchArguments
    @State private var controller = EditorController()
    @State private var status = "Running editor benchmark…"

    var body: some View {
        EditorView(controller: controller)
            .frame(width: 1000, height: 800)
            .overlay(alignment: .top) { Text(status).font(.caption).padding(6).background(.regularMaterial) }
            .task { await run() }
    }

    private func run() async {
        // WebKit pauses animation frames for occluded windows, which would stall every measurement.
        NSApplication.shared.activate()
        for window in NSApplication.shared.windows { window.orderFrontRegardless() }
        let deadline = Task {
            try? await Task.sleep(for: .seconds(180))
            guard !Task.isCancelled else { return }
            finish(["error": "benchmark timed out (window occluded or editor not responding)"])
        }
        defer { deadline.cancel() }
        let text: String
        do {
            text = try String(contentsOf: arguments.file, encoding: .utf8)
        } catch {
            finish(["error": "cannot read \(arguments.file.path(percentEncoded: false)): \(error)"])
            return
        }
        if !controller.isReady {
            _ = await controller.next { if case .ready = $0 { true } else { false } }
        }
        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        Self.log("editor ready; opening \(lineCount) lines")

        // Open: host send → editor laid out and painted (two frames after setState).
        var openWall: [Double] = []
        var openEditor: [Double] = []
        let clock = ContinuousClock()
        for version in 1...5 {
            let start = clock.now
            controller.send(.load(path: "bench.md", text: text, version: version, cursor: 0))
            let message = await controller.next { if case .loaded(let v, _) = $0 { v == version } else { false } }
            openWall.append(Self.milliseconds(clock.now - start))
            if case .loaded(_, let ms) = message { openEditor.append(ms) }
        }

        Self.log("opened: \(openWall.map { Int($0) }) ms; typing and scrolling")
        status = "Typing and scrolling…"
        controller.send(.bench(lines: [1, max(1, lineCount / 2), lineCount], keystrokes: 60, scrollMs: 3000))
        let message = await controller.next { if case .benchResult = $0 { true } else { false } }
        guard case .benchResult(let result) = message else { return }

        let report: [String: Any] = [
            "file": arguments.file.lastPathComponent,
            "docLines": result.docLines,
            "docBytes": text.utf8.count,
            "openWallMs": ["first": openWall.first ?? 0, "warmMedian": Self.percentile(Array(openWall.dropFirst()), 0.5)],
            "openEditorMs": ["first": openEditor.first ?? 0, "warmMedian": Self.percentile(Array(openEditor.dropFirst()), 0.5)],
            "typingMs": Self.summary(result.typing),
            "typingByPosition": Self.segments(result.typing, labels: ["start", "middle", "end"]),
            "domTypingByPosition": Self.segments(result.domTyping, labels: ["start", "middle", "end"]),
            "parsedTypingMs": Self.summary(result.parsedTyping),
            "parsedTypingByPosition": Self.segments(result.parsedTyping, labels: ["start", "middle", "end"]),
            "parseToPositionMs": result.parseMs.map { ($0 * 10).rounded() / 10 },
            "domTypingMs": Self.summary(result.domTyping),
            "scrollFrameMs": Self.summary(result.scrollFrames),
            "scrollFramesOver20ms": result.scrollFrames.filter { $0 > 20 }.count,
            "undoRestored": result.undoRestored,
            "redoReapplied": result.redoReapplied,
        ]
        finish(report)
    }

    private func finish(_ report: [String: Any]) {
        let data = (try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        print(String(decoding: data, as: UTF8.self))
        if let output = arguments.output { try? data.write(to: output) }
        NSApplication.shared.terminate(nil)
    }

    static func log(_ text: String) {
        FileHandle.standardError.write(Data("[bench] \(text)\n".utf8))
    }

    static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
    }

    /// Splits per-keystroke samples into equal runs, one per document position typed at.
    static func segments(_ values: [Double], labels: [String]) -> [String: [String: Double]] {
        guard !labels.isEmpty, !values.isEmpty else { return [:] }
        let size = values.count / labels.count
        var result: [String: [String: Double]] = [:]
        for (index, label) in labels.enumerated() {
            result[label] = summary(Array(values[(index * size)..<min(values.count, (index + 1) * size)]))
        }
        return result
    }

    static func summary(_ values: [Double]) -> [String: Double] {
        let round = { (value: Double) in (value * 100).rounded() / 100 }
        return ["p50": round(percentile(values, 0.5)), "p95": round(percentile(values, 0.95)),
                "max": round(values.max() ?? 0), "n": Double(values.count)]
    }
}
