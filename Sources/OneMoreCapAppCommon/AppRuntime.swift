@preconcurrency import Cocoa
import OneMoreCapAppSupport

public protocol AppUpdateControlling: AnyObject {
    var onCanCheckForUpdatesChanged: (() -> Void)? { get set }
    var isConfigured: Bool { get }
    var canCheckForUpdates: Bool { get }

    func checkForUpdates()
}

public final class NoopAppUpdateController: AppUpdateControlling {
    public var onCanCheckForUpdatesChanged: (() -> Void)?

    public var isConfigured: Bool {
        false
    }

    public var canCheckForUpdates: Bool {
        false
    }

    public init() {}

    public func checkForUpdates() {}
}

public struct OneMoreCapAppConfiguration {
    let playbackClients: [any ExternalPlaybackClient]
    let defaultPlaybackTargetID: String?
    let updateController: any AppUpdateControlling
    let accessibilityPermissionGranted: () -> Bool
    let requestAccessibilityPermission: (() -> Bool)?
    let showsAutomationSettings: Bool
    let showsAccessibilitySettings: Bool
    let showsUpdateMenu: Bool

    public init(
        playbackClients: [any ExternalPlaybackClient],
        defaultPlaybackTargetID: String?,
        updateController: any AppUpdateControlling,
        accessibilityPermissionGranted: @escaping () -> Bool,
        requestAccessibilityPermission: (() -> Bool)? = nil,
        showsAutomationSettings: Bool,
        showsAccessibilitySettings: Bool,
        showsUpdateMenu: Bool
    ) {
        self.playbackClients = playbackClients
        self.defaultPlaybackTargetID = defaultPlaybackTargetID
        self.updateController = updateController
        self.accessibilityPermissionGranted = accessibilityPermissionGranted
        self.requestAccessibilityPermission = requestAccessibilityPermission
        self.showsAutomationSettings = showsAutomationSettings
        self.showsAccessibilitySettings = showsAccessibilitySettings
        self.showsUpdateMenu = showsUpdateMenu
    }
}

private var appDelegateRetainer: AppDelegate?

public func runOneMoreCapApp(configuration: OneMoreCapAppConfiguration) {
    let app = NSApplication.shared
    let delegate = AppDelegate(configuration: configuration)
    appDelegateRetainer = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
