import SwiftUI

/// Menu-bar commands (and their shortcuts) for the main window.
struct ShellCommands: Commands {
    let shell: ShellState
    let store: VaultStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { shell.switcherCreates = true; shell.showSwitcher = true }
                .keyboardShortcut("n")
            Button("Today's Daily Note") { Task { await store.openToday() } }
                .keyboardShortcut("d")
            Button("Capture…") { AppModel.shared.capture.show(trigger: .menu) }
        }
        CommandMenu("Go") {
            Button("Open Note…") { shell.switcherCreates = false; shell.showSwitcher = true }
                .keyboardShortcut("o")
            Button("Command Palette…") { shell.showPalette = true }
                .keyboardShortcut("k")
            Button("Search Notes") { shell.focusSearch += 1 }
                .keyboardShortcut("f")
            Button("Ask Your Notes…") { shell.showAsk = true }
                .keyboardShortcut("j")
            Divider()
            Button("Copy Link to Note") { store.copyWikilink() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Reveal in Finder") { store.revealInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Rename Note…") { shell.showRename = true }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Move Note to Folder…") { shell.showMove = true }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
            Button("Promote to Claim…") { shell.promoteSelection(store) }
                .keyboardShortcut("p", modifiers: [.command, .option])
            Button("Supersede Claim…") { shell.showSupersede = true }
                .disabled(!store.openNoteIsClaim)
        }
        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector") { shell.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
