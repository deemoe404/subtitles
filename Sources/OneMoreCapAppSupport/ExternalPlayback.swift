import Foundation

public struct ExternalPlaybackTarget: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let symbolName: String

    public init(
        id: String,
        displayName: String,
        symbolName: String
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
    }

    public static let quickTime = ExternalPlaybackTarget(
        id: "quicktime",
        displayName: "QuickTime",
        symbolName: "play.rectangle.fill"
    )
}

public protocol ExternalPlaybackClient: AnyObject {
    var target: ExternalPlaybackTarget { get }

    func currentSnapshot() -> Result<ExternalPlaybackSnapshot, ExternalPlaybackError>
}

public enum ExternalPlaybackState: String, Equatable, Sendable {
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

public struct ExternalPlaybackSnapshot: Equatable, Sendable {
    public let state: ExternalPlaybackState
    public let position: TimeInterval
    public let duration: TimeInterval?

    public init(
        state: ExternalPlaybackState,
        position: TimeInterval,
        duration: TimeInterval? = nil
    ) {
        self.state = state
        self.position = position
        self.duration = duration
    }
}

public enum ExternalPlaybackError: Error, Equatable, LocalizedError, Sendable {
    case notRunning(appName: String)
    case accessibilityPermissionDenied(appName: String)
    case automationPermissionDenied(appName: String)
    case missingDocument(appName: String)
    case missingPosition(appName: String)

    public var errorDescription: String? {
        switch self {
        case let .notRunning(appName):
            return "\(appName) is not running."
        case let .accessibilityPermissionDenied(appName):
            return "Accessibility permission for One More Cap to read \(appName) is not granted."
        case let .automationPermissionDenied(appName):
            return "Automation permission for One More Cap to read \(appName) is not granted."
        case let .missingDocument(appName):
            return "\(appName) does not have an open movie document."
        case let .missingPosition(appName):
            return "\(appName) did not return a playback position."
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
