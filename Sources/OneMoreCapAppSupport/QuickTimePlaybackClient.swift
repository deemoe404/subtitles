import AppKit
import Foundation

struct QuickTimeScriptExecutionResult {
    let descriptor: NSAppleEventDescriptor?
    let error: NSDictionary?
}

public final class QuickTimePlaybackClient: ExternalPlaybackClient {
    public static let bundleIdentifier = "com.apple.QuickTimePlayerX"
    public static let appName = "QuickTime Player"
    public let target = ExternalPlaybackTarget.quickTime

    private static let automationNotPermittedErrorNumber = -1743

    private let runningApplicationProvider: (String) -> [NSRunningApplication]
    private let scriptExecutor: (String) -> QuickTimeScriptExecutionResult

    public convenience init() {
        self.init(
            runningApplicationProvider: NSRunningApplication.runningApplications(withBundleIdentifier:),
            scriptExecutor: Self.executeAppleScript
        )
    }

    init(
        runningApplicationProvider: @escaping (String) -> [NSRunningApplication],
        scriptExecutor: @escaping (String) -> QuickTimeScriptExecutionResult
    ) {
        self.runningApplicationProvider = runningApplicationProvider
        self.scriptExecutor = scriptExecutor
    }

    public func currentSnapshot() -> Result<ExternalPlaybackSnapshot, ExternalPlaybackError> {
        guard !runningApplicationProvider(Self.bundleIdentifier).isEmpty else {
            return .failure(.notRunning(appName: Self.appName))
        }

        let result = scriptExecutor(Self.currentSnapshotScript)
        if let error = result.error {
            return .failure(Self.playbackError(from: error))
        }

        guard let descriptor = result.descriptor else {
            return .failure(.missingPosition(appName: Self.appName))
        }

        return Self.snapshot(from: descriptor)
    }

    private static func executeAppleScript(_ source: String) -> QuickTimeScriptExecutionResult {
        var error: NSDictionary?
        let descriptor = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return QuickTimeScriptExecutionResult(
            descriptor: descriptor,
            error: error
        )
    }

    private static let currentSnapshotScript = """
    tell application id "\(bundleIdentifier)"
        if (count of documents) is 0 then
            return {"missingDocument", "", "", ""}
        end if

        tell document 1
            return {"ok", current time as text, duration as text, playing as text}
        end tell
    end tell
    """

    private static func snapshot(from descriptor: NSAppleEventDescriptor) -> Result<ExternalPlaybackSnapshot, ExternalPlaybackError> {
        guard descriptor.numberOfItems >= 4,
              let status = descriptor.atIndex(1)?.stringValue else {
            return .failure(.missingPosition(appName: Self.appName))
        }

        if status == "missingDocument" {
            return .failure(.missingDocument(appName: Self.appName))
        }

        guard status == "ok",
              let positionText = descriptor.atIndex(2)?.stringValue,
              let position = TimeInterval(positionText),
              position.isFinite else {
            return .failure(.missingPosition(appName: Self.appName))
        }

        let duration = descriptor
            .atIndex(3)?
            .stringValue
            .flatMap(TimeInterval.init)
            .flatMap { $0.isFinite ? $0 : nil }
        let state = playbackState(from: descriptor.atIndex(4)?.stringValue)

        return .success(
            ExternalPlaybackSnapshot(
                state: state,
                position: position,
                duration: duration
            )
        )
    }

    private static func playbackState(from playingText: String?) -> ExternalPlaybackState {
        switch playingText?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true":
            return .playing
        case "false":
            return .paused
        default:
            return .unknown
        }
    }

    private static func playbackError(from error: NSDictionary) -> ExternalPlaybackError {
        let errorNumber = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        if errorNumber == automationNotPermittedErrorNumber {
            return .automationPermissionDenied(appName: Self.appName)
        }
        return .missingPosition(appName: Self.appName)
    }
}
