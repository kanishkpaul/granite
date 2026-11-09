import AppKit
import SwiftUI
import WebKit

/// Debug: `granite --snapshot <out.png> [--open <path>] [--ask <question>] [--suggest] [--select proposals|all]` renders the main window
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
        let select = arguments.firstIndex(of: "--select").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        Task {
            let store = AppModel.shared.store
            if select == "proposals" { store.selection = .proposals }
            try? await Task.sleep(for: .seconds(3))
            if let open { store.openNote(open) }
            if suggest { await store.suggestLinks() }
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
            NSLog("granite snapshot: inbox %d; proposals %d; folders %@; listed %d; status %@", store.inboxCount,
                  store.openProposals.count, folders, store.listed.count, store.status)
            AppModel.shared.shell.showAsk = false
            // Quit from the run loop, not from inside this task.
            NSApplication.shared.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
        }
    }
}
