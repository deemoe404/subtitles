import AppKit
import ApplicationServices
import Foundation

public final class AppleTVPlaybackClient {
    public static let tvBundleIdentifier = "com.apple.TV"

    private let bundleIdentifier: String
    private let runningApplicationProvider: (String) -> [NSRunningApplication]

    public convenience init() {
        self.init(
            bundleIdentifier: Self.tvBundleIdentifier,
            runningApplicationProvider: NSRunningApplication.runningApplications(withBundleIdentifier:)
        )
    }

    init(
        bundleIdentifier: String,
        runningApplicationProvider: @escaping (String) -> [NSRunningApplication]
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.runningApplicationProvider = runningApplicationProvider
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

    private func snapshotFromAccessibility(revealControls: Bool) -> Result<AppleTVPlaybackSnapshot, AppleTVPlaybackError>? {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionDenied)
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
            state: state ?? .unknown,
            position: position
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
