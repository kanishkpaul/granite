import Foundation
import KBCore
import KBGit
import KBIndex
import SwiftUI

/// The metrics dashboard (§11): computed on demand, frozen weekly to `AI/Metrics/YYYY-Www.md`.
extension VaultStore {
    func computeMetrics() async -> [Metric] {
        guard let database, let vault else { return [] }
        var external = ExternalMeasures()
        external.linesAdded = try? await GitService(root: vault.root).linesAdded(since: Date().addingTimeInterval(-30 * 86_400))
        if let stats = try? await reviewQueue?.stats() {
            external.recall = stats.recall
            external.reviews = stats.reviewed
        }
        let ages = inboxItems.map(\.ageDays).sorted()
        if !ages.isEmpty { external.inboxMedianDays = Double(ages[ages.count / 2]) }
        return (try? VaultMetrics(database: database, state: state).compute(external: external)) ?? []
    }

    /// Writes this week's metrics file (the nightly job does this after the digest).
    @discardableResult
    func freezeMetrics() async -> String? {
        guard let database, let writer else { return nil }
        let metrics = await computeMetrics()
        let week = WeeklyNote.week(of: Date())
        let path = "AI/Metrics/\(week).md"
        do {
            let text = try VaultMetrics(database: database, state: state).freeze(metrics, week: week)
            try await writer.write(text, to: path, as: .ai)
            _ = try await indexer?.update(paths: [path])
            return path
        } catch {
            status = "Could not save metrics: \(error)"
            return nil
        }
    }
}

struct MetricsView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var metrics: [Metric] = []
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Metrics").font(.headline)
                Text(WeeklyNote.week(of: Date())).foregroundStyle(.secondary)
                Spacer()
                Button("Save to AI/Metrics") {
                    Task {
                        if let path = await store.freezeMetrics() { store.openNote(path) }
                        dismiss()
                    }
                }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
                    ForEach(metrics) { metric in
                        GridRow {
                            Image(systemName: icon(metric.health)).foregroundStyle(color(metric.health))
                            Text(metric.name).fontWeight(.medium)
                            Text(metric.value)
                            Text(metric.healthy).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("If your own writing is falling, cut capture, don't add features (§11).")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
            }
        }
        .padding(20)
        .frame(width: 860)
        .task {
            metrics = await store.computeMetrics()
            loading = false
        }
    }

    private func icon(_ health: Metric.Health) -> String {
        switch health {
        case .good: "checkmark.circle.fill"
        case .watch: "eye"
        case .alarm: "exclamationmark.triangle.fill"
        case .unknown: "circle.dotted"
        }
    }

    private func color(_ health: Metric.Health) -> Color {
        switch health {
        case .good: .green
        case .watch: .yellow
        case .alarm: .red
        case .unknown: .secondary
        }
    }
}
