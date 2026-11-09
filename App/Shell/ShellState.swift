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
}
