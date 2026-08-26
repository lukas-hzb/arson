import Combine
import Foundation
import Sparkle

@MainActor
final class UpdateService: ObservableObject {
    let isConfigured: Bool
    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController
    private var didStart = false

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        isConfigured = Self.isValidConfiguration(feedURL: feedURL, publicKey: publicKey)
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        if isConfigured {
            controller.updater.publisher(for: \.canCheckForUpdates)
                .assign(to: &$canCheckForUpdates)
        }
    }

    func start() {
        guard isConfigured, !didStart else { return }
        didStart = true
        controller.startUpdater()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    nonisolated static func isValidConfiguration(
        feedURL: String?,
        publicKey: String?
    ) -> Bool {
        guard let feedURL,
              let url = URL(string: feedURL),
              url.scheme == "https",
              url.host != nil,
              let publicKey,
              Data(base64Encoded: publicKey)?.count == 32 else {
            return false
        }
        return true
    }
}
