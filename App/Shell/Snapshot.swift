import AppKit
import KBCore
import SwiftUI
import WebKit

/// Debug: `granite --snapshot <out.png> [--open <path>] [--ask <question>] [--suggest] [--select proposals|all] [--related-line N] [--import-pdf file] [--promote-line N] [--pdf Papers/pdf/x.pdf:page]` renders the main window
/// (and the editor's web view, which draws out of process) to PNGs, then quits. Lets agents check
/// layout without screen-recording permission.
@MainActor
enum SnapshotMode {
    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count else { return }
        let output = URL(filePath: arguments[index + 1])
        let open = arguments.firstIndex(of: "--open").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let ask = arguments.firstIndex(of: "--ask").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let suggest = arguments.contains("--suggest")
        let makePrompts = arguments.contains("--make-prompts")
        let review = arguments.contains("--review")
        let digest = arguments.contains("--digest")
        let weekly = arguments.firstIndex(of: "--weekly").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let promoteLine = arguments.firstIndex(of: "--promote-line").flatMap { $0 + 1 < arguments.count ? Int(arguments[$0 + 1]) : nil }
        let importPDF = arguments.firstIndex(of: "--import-pdf").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let pdfOpen = arguments.firstIndex(of: "--pdf").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let contextLine = arguments.firstIndex(of: "--related-line").flatMap { $0 + 1 < arguments.count ? Int(arguments[$0 + 1]) : nil }
        let select = arguments.firstIndex(of: "--select").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        Task {
            let store = AppModel.shared.store
            if select == "proposals" { store.selection = .proposals }
            try? await Task.sleep(for: .seconds(3))
            if let open { store.openNote(open) }
            if suggest { await store.suggestLinks() }
            if let weekly {
                // Challenge the answer against the notes, log what came back, then save it as this week's note.
                let question = KBCore.WeeklyNote.questions[0]
                if let result = try? await store.challenge(weekly, question: question) {
                    NSLog("granite snapshot: challenge %@ · %d/%d verified: %@", result.route?.rawValue ?? "none", result.verifiedCount,
                          result.sentences.count, result.sentences.map(\.text).joined(separator: " | "))
                }
                await store.saveWeeklyNote([(question: question, answer: weekly)])
            }
            if arguments.contains("--metrics") {
                for metric in await store.computeMetrics() { NSLog("granite metric: %@ = %@ [%@]", metric.name, metric.value, metric.health.rawValue) }
                _ = await store.freezeMetrics()
            }
            if digest {
                await store.runDigest()
                NSLog("granite snapshot: %@", store.status)
            }
            if makePrompts {
                await store.makePrompts()
                NSLog("granite snapshot: %@", store.status)
            }
            if review {
                AppModel.shared.shell.showReview = true
                try? await Task.sleep(for: .seconds(2))
            }
            if let promoteLine, let path = store.openPath, let vault = store.vault,
               let text = try? String(contentsOf: vault.url(for: path), encoding: .utf8) {
                // Promote that line, then supersede the new claim once, and report the chain.
                let line = String(text.split(separator: "\n", omittingEmptySubsequences: false)[promoteLine - 1])
                await store.promoteToClaim(line, line: promoteLine, confidence: 0.75)
                await store.supersedeOpenClaim(with: "Revised: " + line, confidence: 0.6)
                let chain = await store.claimHistory(of: store.openPath ?? "").map { "\($0.title) [\($0.status.rawValue)]" }
                NSLog("granite snapshot: claims %d; chain %@", store.claims.count, chain.joined(separator: " → "))
            }
            if let importPDF { await store.importPDFs([URL(filePath: importPDF)]) }
            if let pdfOpen {
                // "Papers/pdf/x.pdf:3" opens page 3 and marks the first highlight on it, if any.
                let parts = pdfOpen.split(separator: ":")
                let path = String(parts[0])
                let page = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
                let block = store.highlights(forPDF: path).first { $0.page == page }?.id
                store.openPDF(path, page: page, block: block)
                try? await Task.sleep(for: .seconds(3))
                if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue.hasPrefix("pdf") ?? false }),
                   let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: output.deletingPathExtension().appendingPathExtension("pdf.png"))
                }
            }
            if let contextLine {
                // Put the cursor at the end of that line and ask for related notes right away.
                try? await Task.sleep(for: .seconds(2))
                _ = try? await store.editor.webView.callAsyncJavaScript("""
                    const view = window.granite.view;
                    const line = view.state.doc.line(Math.min(n, view.state.doc.lines));
                    view.dispatch({ selection: { anchor: line.to } });
                    window.granite.sendContext();
                    """, arguments: ["n": contextLine], in: nil, contentWorld: .page)
                try? await Task.sleep(for: .seconds(4))
            }
            if select == "proposals" { store.selection = .proposals }
            if select == "all" { store.selection = .all }
            if select != nil { try? await Task.sleep(for: .seconds(3)) }
            if let ask {
                AppModel.shared.shell.pendingQuestion = ask
                AppModel.shared.shell.showAsk = true
                try? await Task.sleep(for: .seconds(12))
            }
            try? await Task.sleep(for: .seconds(2))
            guard let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") ?? false }),
                  let view = window.contentView else {
                NSLog("granite snapshot: no main window")
                NSApplication.shared.terminate(nil)
                return
            }
            if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: output)
            }
            if let sheet = window.attachedSheet?.contentView, let rep = sheet.bitmapImageRepForCachingDisplay(in: sheet.bounds) {
                sheet.cacheDisplay(in: sheet.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: output.deletingPathExtension().appendingPathExtension("sheet.png"))
            }
            if let image = try? await store.editor.webView.takeSnapshot(configuration: nil),
               let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: output.deletingPathExtension().appendingPathExtension("editor.png"))
            }
            if select == "proposals", let first = store.openProposals.first {
                // The window capture can't draw this column's SwiftUI content; render it directly.
                let preview = VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.openProposals, id: \.path) { ProposalRow(proposal: $0).padding(8) }
                    Divider()
                    ProposalDetail(proposal: first, edit: {})
                }
                .frame(width: 380).environment(store).preferredColorScheme(.dark).background(Color(nsColor: .windowBackgroundColor))
                let renderer = ImageRenderer(content: preview)
                renderer.scale = 2
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: output.deletingPathExtension().appendingPathExtension("proposals.png"))
                }
            }
            let folders: String = store.folders.map { folder -> String in "\(folder.path) (\(folder.noteCount))" }.joined(separator: ", ")
            NSLog("granite snapshot: inbox %d; due %d; proposals %d; folders %@; listed %d; status %@", store.inboxCount, store.dueCount,
                  store.openProposals.count, folders, store.listed.count, store.status)
            AppModel.shared.shell.showAsk = false
            AppModel.shared.shell.showReview = false
            // Quit from the run loop, not from inside this task.
            NSApplication.shared.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
        }
    }
}
