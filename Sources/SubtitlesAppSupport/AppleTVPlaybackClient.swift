import AppKit
import ApplicationServices
import Foundation

public final class AppleTVPlaybackClient {
    public static let tvBundleIdentifier = "com.apple.TV"

    private let bundleIdentifier: String
    private let scriptRunner: (String) -> Result<String, AppleTVPlaybackError>
    private let runningApplicationProvider: (String) -> [NSRunningApplication]

    public convenience init() {
        self.init(
            bundleIdentifier: Self.tvBundleIdentifier,
            scriptRunner: Self.runAppleScript(source:),
            runningApplicationProvider: NSRunningApplication.runningApplications(withBundleIdentifier:)
        )
    }

    init(
        bundleIdentifier: String,
        scriptRunner: @escaping (String) -> Result<String, AppleTVPlaybackError>,
        runningApplicationProvider: @escaping (String) -> [NSRunningApplication]
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.scriptRunner = scriptRunner
        self.runningApplicationProvider = runningApplicationProvider
    }

    public func snapshot() -> Result<AppleTVPlaybackSnapshot, AppleTVPlaybackError> {
        guard !runningApplicationProvider(bundleIdentifier).isEmpty else {
            return .failure(.notRunning)
        }

        if let accessibilitySnapshot = snapshotFromAccessibility(revealControls: false) {
            return accessibilitySnapshot
        }

        return scriptRunner(Self.snapshotScript(bundleIdentifier: bundleIdentifier))
            .flatMap { rawValue in
                do {
                    return .success(try AppleTVPlaybackParser.parseAppleScriptResult(rawValue))
                } catch let error as AppleTVPlaybackError {
                    return .failure(error)
                } catch {
                    return .failure(.scriptError(error.localizedDescription))
                }
            }
    }

    public func calibratedSnapshot() -> Result<AppleTVPlaybackSnapshot, AppleTVPlaybackError> {
        guard !runningApplicationProvider(bundleIdentifier).isEmpty else {
            return .failure(.notRunning)
        }

        if let accessibilitySnapshot = snapshotFromAccessibility(revealControls: true) {
            return accessibilitySnapshot
        }

        return .failure(.missingPosition)
    }

    public func requestAutomationPermission() -> Result<Void, AppleTVPlaybackError> {
        scriptRunner(Self.permissionProbeScript(bundleIdentifier: bundleIdentifier)).map { _ in () }
    }

    private static func snapshotScript(bundleIdentifier: String) -> String {
        """
        tell application id "\(bundleIdentifier)"
            set tvState to (player state as text)
            set tvPosition to "missing value"
            set tvDuration to "missing value"
            try
                set tvPosition to (player position as text)
            end try
            try
                set tvDuration to (duration of current track as text)
            end try
            return tvState & "|" & tvPosition & "|" & tvDuration
        end tell
        """
    }

    private static func permissionProbeScript(bundleIdentifier: String) -> String {
        """
        tell application id "\(bundleIdentifier)"
            return player state as text
        end tell
        """
    }

    private static func runAppleScript(source: String) -> Result<String, AppleTVPlaybackError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.scriptError("Could not create AppleScript."))
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return .failure(mapAppleScriptError(errorInfo))
        }

        return .success(descriptor.stringValue ?? "")
    }

    private static func mapAppleScriptError(_ errorInfo: NSDictionary) -> AppleTVPlaybackError {
        let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        let message = errorInfo[NSAppleScript.errorMessage] as? String
        let description = message ?? "Apple Events request failed."

        if number == -1743 || description.localizedCaseInsensitiveContains("not authorized") {
            return .permissionDenied
        }

        return .scriptError(description)
    }

    private func snapshotFromAccessibility(revealControls: Bool) -> Result<AppleTVPlaybackSnapshot, AppleTVPlaybackError>? {
        guard AXIsProcessTrusted() else {
            return .failure(.permissionDenied)
        }
        guard let app = runningApplicationProvider(bundleIdentifier).first else {
            return .failure(.notRunning)
        }

        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let root = focusedWindowOrApplicationElement(applicationElement) else {
            return nil
        }

        if let snapshot = accessibilitySnapshot(in: root) {
            return .success(snapshot)
        }

        guard revealControls,
              let videoButton = firstElement(in: root, matching: { element in
            stringAttribute(kAXRoleAttribute, from: element) == "AXButton"
                && stringAttribute(kAXDescriptionAttribute, from: element) == "Video"
        }) else {
            return nil
        }

        AXUIElementPerformAction(videoButton, kAXPressAction as CFString)
        Thread.sleep(forTimeInterval: 0.12)
        if let snapshot = accessibilitySnapshot(in: root) {
            return .success(snapshot)
        }

        return nil
    }

    private func focusedWindowOrApplicationElement(_ applicationElement: AXUIElement) -> AXUIElement? {
        if let focusedWindow = attribute(kAXFocusedWindowAttribute, from: applicationElement) {
            return unsafeBitCast(focusedWindow, to: AXUIElement.self)
        }
        if let windows = attribute(kAXWindowsAttribute, from: applicationElement) as? [AXUIElement],
           let window = windows.first {
            return window
        }
        return applicationElement
    }

    private func accessibilitySnapshot(in root: AXUIElement) -> AppleTVPlaybackSnapshot? {
        var position: TimeInterval?
        var state: AppleTVPlaybackState?

        walk(root) { element in
            if position == nil,
               stringAttribute(kAXRoleAttribute, from: element) == "AXSlider",
               stringAttribute(kAXDescriptionAttribute, from: element) == "Current Position",
               let value = numericAttribute(kAXValueAttribute, from: element) {
                position = value
            }

            if state == nil,
               stringAttribute(kAXRoleAttribute, from: element) == "AXButton" {
                state = AppleTVPlaybackParser.stateFromPlaybackButtonDescription(
                    stringAttribute(kAXDescriptionAttribute, from: element)
                )
            }
        }

        guard let position else {
            return nil
        }

        return AppleTVPlaybackSnapshot(
            state: state ?? .unavailable,
            position: position,
            duration: nil,
            observedAt: Date()
        )
    }

    private func firstElement(
        in root: AXUIElement,
        matching predicate: (AXUIElement) -> Bool
    ) -> AXUIElement? {
        if predicate(root) {
            return root
        }
        for child in children(of: root) {
            if let match = firstElement(in: child, matching: predicate) {
                return match
            }
        }
        return nil
    }

    private func walk(_ root: AXUIElement, visit: (AXUIElement) -> Void) {
        visit(root)
        for child in children(of: root) {
            walk(child, visit: visit)
        }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, from: element) as? [AXUIElement] ?? []
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        guard let value = attribute(name, from: element) else {
            return nil
        }
        return String(describing: value)
    }

    private func numericAttribute(_ name: String, from element: AXUIElement) -> TimeInterval? {
        guard let value = attribute(name, from: element) else {
            return nil
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return TimeInterval(String(describing: value))
    }

    private func attribute(_ name: String, from element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard error == .success else {
            return nil
        }
        return value as AnyObject?
    }
}
