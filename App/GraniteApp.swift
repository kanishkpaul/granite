import CryptoKit
import KBCapture
import KBCore
import KBIndex
import KBPapers
import SwiftUI

/// granite: search, edit and capture into a Markdown vault. Keeps running in the menu bar
/// when its window closes, so the capture hotkey always works.
/// `--editor-bench <file> [--bench-out <json>]` runs the spike A benchmark and quits.
@main
struct GraniteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let bench = BenchArguments(ProcessInfo.processInfo.arguments)

    var body: some Scene {
        WindowGroup("granite", id: "main") {
            if let bench {
                EditorBenchView(arguments: bench)
            } else {
                MainView(shell: AppModel.shared.shell)
                    .environment(AppModel.shared.store)
                    .frame(minWidth: 980, minHeight: 560)
            }
        }
        .commands { ShellCommands(shell: AppModel.shared.shell, store: AppModel.shared.store) }
        // One window per PDF, keyed by its vault path.
        WindowGroup("PDF", id: "pdf", for: String.self) { $path in
            if let path {
                PDFReaderView(path: path)
                    .environment(AppModel.shared.store)
                    .frame(minWidth: 520, minHeight: 600)
            }
        }
        MenuBarExtra("granite", image: "MenuBarIcon", isInserted: .constant(bench == nil)) {
            MenuBarContent()
        }
        Settings {
            SettingsView().environment(AppModel.shared.store)
        }
    }
}

/// Receives `granite://` URLs (AppKit delivers them to the delegate, not to a scene,
/// so no new window opens for a capture from a bookmarklet or another app).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            for url in urls { AppModel.shared.handle(url) }
        }
    }

    /// Commit pending vault changes before quitting (bounded to 10 s).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard BenchArguments(ProcessInfo.processInfo.arguments) == nil,
              MainActor.assumeIsolated({ AppModel.shared.git.hasPendingChanges }) else { return .terminateNow }
        Task { @MainActor in
            await AppModel.shared.git.commitBeforeQuit()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard BenchArguments(ProcessInfo.processInfo.arguments) == nil else { return }
            AppModel.shared.start()
            SnapshotMode.runIfRequested()
        }
    }
}
