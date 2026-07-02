import AppKit
import ApplicationServices
import Foundation
import OneMoreCapAppSupport

public extension ExternalPlaybackTarget {
    static let appleTV = ExternalPlaybackTarget(
        id: "apple-tv",
        displayName: "Apple TV",
        symbolName: "appletv.fill"
    )
}

public final class AppleTVPlaybackClient: ExternalPlaybackClient {
    public static let bundleIdentifier = "com.apple.TV"
    public static let appName = "TV.app"
    public let target = ExternalPlaybackTarget.appleTV

    private let runningApplicationProvider: (String) -> [NSRunningApplication]

    public convenience init() {
        self.init(
            runningApplicationProvider: NSRunningApplication.runningApplications(withBundleIdentifier:)
        )
    }

    public static func isAccessibilityPermissionGranted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    init(
        runningApplicationProvider: @escaping (String) -> [NSRunningApplication]
    ) {
        self.runningApplicationProvider = runningApplicationProvider
    }

    public func currentSnapshot() -> Result<ExternalPlaybackSnapshot, ExternalPlaybackError> {
        guard !runningApplicationProvider(Self.bundleIdentifier).isEmpty else {
            return .failure(.notRunning(appName: Self.appName))
        }

        if let accessibilitySnapshot = snapshotFromAccessibility(revealControls: true) {
            return accessibilitySnapshot
        }

        return .failure(.missingPosition(appName: Self.appName))
    }

    private func snapshotFromAccessibility(
        revealControls: Bool
    ) -> Result<ExternalPlaybackSnapshot, ExternalPlaybackError>? {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionDenied(appName: Self.appName))
        }
        guard let app = runningApplicationProvider(Self.bundleIdentifier).first else {
            return .failure(.notRunning(appName: Self.appName))
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

    private func accessibilitySnapshot(in root: AXUIElement) -> ExternalPlaybackSnapshot? {
        var position: TimeInterval?
        var state: ExternalPlaybackState?

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

        return ExternalPlaybackSnapshot(
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

public enum AppleTVPlaybackParser {
    public static func stateFromPlaybackButtonDescription(_ description: String?) -> ExternalPlaybackState? {
        switch description?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pause":
            return .playing
        case "play":
            return .paused
        default:
            return nil
        }
    }
}
