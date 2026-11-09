import SwiftUI

/// Window-level UI state that menu commands also drive.
@MainActor
@Observable
final class ShellState {
    var showSwitcher = false
    var showPalette = false
    var showInspector = true
    var query = ""
    var focusSearch = 0
    /// When set, the switcher is in "new note" mode: ↩ creates rather than opens.
    var switcherCreates = false
    /// Rename prompt for the open note.
    var showRename = false
    /// Folder picker for moving the open note.
    var showMove = false
    /// "Ask your notes" (grounded Q&A).
    var showAsk = false
    /// "Import PDF…" file picker.
    var showImportPDF = false
    /// A question to run as soon as the Ask window opens (snapshot/debug mode).
    var pendingQuestion: String?
}
