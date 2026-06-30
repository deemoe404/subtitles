import Foundation

public enum AppleTVPlaybackState: String, Equatable, Sendable {
    case stopped
    case playing
    case paused
    case fastForwarding
    case rewinding
    case unavailable
    case permissionDenied

    public var isActivelyAdvancing: Bool {
        switch self {
        case .playing, .fastForwarding, .rewinding:
            return true
        case .stopped, .paused, .unavailable, .permissionDenied:
            return false
        }
    }

    public var displayLabel: String {
        switch self {
        case .stopped:
            return "TV stopped"
        case .playing:
            return "TV playing"
        case .paused:
            return "TV paused"
        case .fastForwarding:
            return "TV fast-forwarding"
        case .rewinding:
            return "TV rewinding"
        case .unavailable:
            return "TV unavailable"
        case .permissionDenied:
            return "Permission Needed"
        }
    }
}

public struct AppleTVPlaybackSnapshot: Equatable, Sendable {
    public let state: AppleTVPlaybackState
    public let position: TimeInterval?
    public let duration: TimeInterval?
    public let observedAt: Date

    public init(
        state: AppleTVPlaybackState,
        position: TimeInterval?,
        duration: TimeInterval?,
        observedAt: Date
    ) {
        self.state = state
        self.position = position
        self.duration = duration
        self.observedAt = observedAt
    }
}

public enum AppleTVPlaybackError: Error, Equatable, LocalizedError, Sendable {
    case notRunning
    case accessibilityPermissionDenied
    case automationPermissionDenied
    case missingPosition
    case scriptError(String)

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "TV.app is not running."
        case .accessibilityPermissionDenied:
            return "Accessibility permission for Subtitles is not granted."
        case .automationPermissionDenied:
            return "Automation permission for TV.app is not granted."
        case .missingPosition:
            return "TV.app did not return a playback position."
        case let .scriptError(message):
            return message
        }
    }
}

public enum PlaybackSyncMode: Equatable, Sendable {
    case manual
    case appleTV
}

public struct PlaybackRenderState: Equatable, Sendable {
    public let mediaTime: TimeInterval
    public let effectiveTime: TimeInterval
    public let isPlaying: Bool
    public let sourceLabel: String
    public let mode: PlaybackSyncMode

    public init(
        mediaTime: TimeInterval,
        effectiveTime: TimeInterval,
        isPlaying: Bool,
        sourceLabel: String,
        mode: PlaybackSyncMode
    ) {
        self.mediaTime = mediaTime
        self.effectiveTime = effectiveTime
        self.isPlaying = isPlaying
        self.sourceLabel = sourceLabel
        self.mode = mode
    }
}

public enum AppleTVPlaybackParser {
    public static func stateFromPlaybackButtonDescription(_ description: String?) -> AppleTVPlaybackState? {
        switch description?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pause":
            return .playing
        case "play":
            return .paused
        default:
            return nil
        }
    }

    public static func parseAppleScriptResult(
        _ rawValue: String,
        observedAt: Date = Date()
    ) throws -> AppleTVPlaybackSnapshot {
        let parts = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "|")

        guard !parts.isEmpty else {
            throw AppleTVPlaybackError.scriptError("TV.app returned an empty Apple Events response.")
        }

        let state = parseState(parts[0])
        let position = parts.count > 1 ? parseOptionalTime(parts[1]) : nil
        let duration = parts.count > 2 ? parseOptionalTime(parts[2]) : nil

        if state != .stopped, state != .unavailable, state != .permissionDenied, position == nil {
            throw AppleTVPlaybackError.missingPosition
        }

        return AppleTVPlaybackSnapshot(
            state: state,
            position: position,
            duration: duration,
            observedAt: observedAt
        )
    }

    public static func parseState(_ rawValue: String) -> AppleTVPlaybackState {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "stopped":
            return .stopped
        case "playing":
            return .playing
        case "paused":
            return .paused
        case "fast forwarding", "fast-forwarding", "fastforwarding":
            return .fastForwarding
        case "rewinding":
            return .rewinding
        default:
            return .unavailable
        }
    }

    private static func parseOptionalTime(_ rawValue: String) -> TimeInterval? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "missing value" else {
            return nil
        }
        return TimeInterval(trimmed)
    }
}
