import Foundation

public enum AppleTVPlaybackState: String, Equatable, Sendable {
    case playing
    case paused
    case unknown

    public var isActivelyAdvancing: Bool {
        switch self {
        case .playing:
            return true
        case .paused, .unknown:
            return false
        }
    }
}

public struct AppleTVPlaybackSnapshot: Equatable, Sendable {
    public let state: AppleTVPlaybackState
    public let position: TimeInterval

    public init(
        state: AppleTVPlaybackState,
        position: TimeInterval
    ) {
        self.state = state
        self.position = position
    }
}

public enum AppleTVPlaybackError: Error, Equatable, LocalizedError, Sendable {
    case notRunning
    case accessibilityPermissionDenied
    case missingPosition

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "TV.app is not running."
        case .accessibilityPermissionDenied:
            return "Accessibility permission for Subtitles is not granted."
        case .missingPosition:
            return "TV.app did not return a playback position."
        }
    }
}

public struct PlaybackRenderState: Equatable, Sendable {
    public let mediaTime: TimeInterval
    public let effectiveTime: TimeInterval
    public let isPlaying: Bool
    public let sourceLabel: String

    public init(
        mediaTime: TimeInterval,
        effectiveTime: TimeInterval,
        isPlaying: Bool,
        sourceLabel: String
    ) {
        self.mediaTime = mediaTime
        self.effectiveTime = effectiveTime
        self.isPlaying = isPlaying
        self.sourceLabel = sourceLabel
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
}
