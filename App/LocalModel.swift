import Foundation
import KBAI
import KBAIMLX

/// The opt-in local language model (MLX route): which model, whether it's on, and its download.
@MainActor
@Observable
final class LocalModel {
    nonisolated static let enabledKey = "granite.mlx.enabled"
    nonisolated static let modelKey = "granite.mlx.model"

    private(set) var status: String?
    private(set) var isDownloaded = false
    private(set) var provider: MLXLanguageProvider
    private var download: Task<Void, Never>?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var modelID: String {
        get { UserDefaults.standard.string(forKey: Self.modelKey) ?? MLXLanguageProvider.defaultModel }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.modelKey)
            provider = Self.makeProvider()
            refresh()
        }
    }

    init() {
        provider = Self.makeProvider()
        refresh()
    }

    static func makeProvider() -> MLXLanguageProvider {
        MLXLanguageProvider(modelID: UserDefaults.standard.string(forKey: modelKey) ?? MLXLanguageProvider.defaultModel,
                            isEnabled: { UserDefaults.standard.bool(forKey: enabledKey) })
    }

    func refresh() {
        isDownloaded = MLXLanguageProvider.isDownloaded(modelID)
    }

    /// Downloads and loads the weights once; the route becomes available afterwards.
    func downloadAndLoad() {
        guard download == nil else { return }
        let provider = provider
        status = "Starting the download…"
        download = Task {
            do {
                try await provider.load { progress in
                    let percent = Int(progress.fractionCompleted * 100)
                    Task { @MainActor in self.status = "Downloading the local model… \(percent)%" }
                }
                status = nil
            } catch {
                status = "Download failed: \(ModelError.brief(error))"
            }
            refresh()
            download = nil
        }
    }
}
