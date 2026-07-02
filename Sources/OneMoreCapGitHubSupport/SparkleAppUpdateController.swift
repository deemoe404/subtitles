import Cocoa
import Sparkle
import OneMoreCapAppCommon
import OneMoreCapAppSupport

public final class SparkleAppUpdateController: AppUpdateControlling {
    private let updaterController: SPUStandardUpdaterController?
    private var canCheckForUpdatesObservation: NSKeyValueObservation?

    public var onCanCheckForUpdatesChanged: (() -> Void)?

    public var isConfigured: Bool {
        updaterController != nil
    }

    public var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    public init(bundle: Bundle = .main) {
        if Self.hasRequiredConfiguration(in: bundle) {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            canCheckForUpdatesObservation = updaterController?.updater.observe(
                \.canCheckForUpdates,
                options: [.initial, .new]
            ) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.onCanCheckForUpdatesChanged?()
                }
            }
        } else {
            updaterController = nil
        }
    }

    public func checkForUpdates() {
        guard let updaterController else {
            presentNotConfiguredAlert()
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }

    private static func hasRequiredConfiguration(in bundle: Bundle) -> Bool {
        hasNonEmptyString("SUFeedURL", in: bundle)
            && hasNonEmptyString("SUPublicEDKey", in: bundle)
    }

    private static func hasNonEmptyString(_ key: String, in bundle: Bundle) -> Bool {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentNotConfiguredAlert() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.string(
            "alert.updates_not_configured.title",
            value: "Updates are not configured for this build"
        )
        alert.informativeText = L10n.string(
            "alert.updates_not_configured.message",
            value: "This build does not include a Sparkle feed URL and public update key."
        )
        alert.addButton(withTitle: L10n.string("button.ok", value: "OK"))
        alert.runModal()
    }
}
