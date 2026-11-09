import AppKit
import WebKit

/// Debug: `granite --snapshot <out.png> [--open <vault-relative path>]` renders the main window
/// (and the editor's web view, which draws out of process) to PNGs, then quits. Lets agents check
/// layout without screen-recording permission.
@MainActor
enum SnapshotMode {
    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count else { return }
        let output = URL(filePath: arguments[index + 1])
        let open = arguments.firstIndex(of: "--open").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        Task {
            try? await Task.sleep(for: .seconds(3))
            let store = AppModel.shared.store
            if let open { store.openNote(open) }
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
            if let image = try? await store.editor.webView.takeSnapshot(configuration: nil),
               let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: output.deletingPathExtension().appendingPathExtension("editor.png"))
            }
            let folders: String = store.folders.map { folder -> String in "\(folder.path) (\(folder.noteCount))" }.joined(separator: ", ")
            NSLog("granite snapshot: inbox %d; folders %@; listed %d; status %@", store.inboxCount, folders,
                  store.listed.count, store.status)
            // Quit from the run loop, not from inside this task.
            NSApplication.shared.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
        }
    }
}
