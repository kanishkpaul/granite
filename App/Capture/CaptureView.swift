import SwiftUI

struct CaptureView: View {
    @Bindable var controller: CaptureController
    @FocusState private var focus: Field?

    enum Field { case text, why }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch controller.phase {
            case .writing:
                ZStack(alignment: .topLeading) {
                    if controller.text.isEmpty {
                        Text("Capture anything…").foregroundStyle(.tertiary).padding(.top, 1).padding(.leading, 5)
                    }
                    TextEditor(text: $controller.text)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .focused($focus, equals: .text)
                }
                HStack {
                    Text("Saved to Inbox/. ⌘↩ save · Esc cancel").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Save") { controller.save() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(controller.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isSaving)
                }
            case .why(let path):
                Label("Saved to \(path)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                TextField("Why did you save this?", text: $controller.why)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($focus, equals: .why)
                    .onSubmit { controller.saveWhy() }
                Spacer()
                Text("↩ save · Esc skip").font(.caption).foregroundStyle(.secondary)
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                Spacer()
                Text("Esc to close").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 560, height: 230)
        .background(.regularMaterial)
        .onExitCommand { controller.cancel() }
        .onChange(of: controller.showCount, initial: true) { refocus() }
        .onChange(of: controller.phase) { refocus() }
    }

    private func refocus() {
        switch controller.phase {
        case .writing: focus = .text
        case .why: focus = .why
        case .error: focus = nil
        }
    }
}
