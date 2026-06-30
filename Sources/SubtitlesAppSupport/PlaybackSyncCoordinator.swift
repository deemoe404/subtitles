import Foundation

public final class PlaybackSyncCoordinator {
    public typealias AppleTVSnapshotProvider = () -> Result<AppleTVPlaybackSnapshot, AppleTVPlaybackError>
    public typealias ManualTimeProvider = () -> TimeInterval
    public typealias ManualIsPlayingProvider = () -> Bool
    public typealias DateProvider = () -> Date

    public var mode: PlaybackSyncMode

    private let appleTVSnapshotProvider: AppleTVSnapshotProvider
    private let manualTimeProvider: ManualTimeProvider
    private let manualIsPlayingProvider: ManualIsPlayingProvider
    private let dateProvider: DateProvider
    private var calibratedSnapshot: AppleTVPlaybackSnapshot?

    public init(
        mode: PlaybackSyncMode = .appleTV,
        appleTVSnapshotProvider: @escaping AppleTVSnapshotProvider,
        manualTimeProvider: @escaping ManualTimeProvider,
        manualIsPlayingProvider: @escaping ManualIsPlayingProvider,
        dateProvider: @escaping DateProvider = Date.init
    ) {
        self.mode = mode
        self.appleTVSnapshotProvider = appleTVSnapshotProvider
        self.manualTimeProvider = manualTimeProvider
        self.manualIsPlayingProvider = manualIsPlayingProvider
        self.dateProvider = dateProvider
    }

    public func renderState(offset: TimeInterval) -> PlaybackRenderState {
        switch mode {
        case .manual:
            return manualRenderState(offset: offset, sourceLabel: "Manual")
        case .appleTV:
            return appleTVRenderState(offset: offset)
        }
    }

    public func calibrate(with snapshot: AppleTVPlaybackSnapshot) {
        calibratedSnapshot = snapshot
    }

    private func appleTVRenderState(offset: TimeInterval) -> PlaybackRenderState {
        switch appleTVSnapshotProvider() {
        case let .success(snapshot):
            calibratedSnapshot = snapshot
            guard let position = currentPosition(from: snapshot) else {
                return manualRenderState(offset: offset, sourceLabel: manualFallbackLabel(for: snapshot.state))
            }
            return PlaybackRenderState(
                mediaTime: max(0, position),
                effectiveTime: max(0, position + offset),
                isPlaying: snapshot.state.isActivelyAdvancing,
                sourceLabel: snapshot.state.displayLabel,
                mode: .appleTV
            )

        case let .failure(error):
            if let calibratedSnapshot,
               let position = currentPosition(from: calibratedSnapshot) {
                return PlaybackRenderState(
                    mediaTime: max(0, position),
                    effectiveTime: max(0, position + offset),
                    isPlaying: calibratedSnapshot.state.isActivelyAdvancing,
                    sourceLabel: "TV calibrated",
                    mode: .appleTV
                )
            }
            return manualRenderState(offset: offset, sourceLabel: manualFallbackLabel(for: error))
        }
    }

    private func currentPosition(from snapshot: AppleTVPlaybackSnapshot) -> TimeInterval? {
        guard let position = snapshot.position else {
            return nil
        }
        guard snapshot.state == .playing else {
            return position
        }

        let elapsed = max(0, dateProvider().timeIntervalSince(snapshot.observedAt))
        let advancedPosition = position + elapsed
        if let duration = snapshot.duration {
            return min(advancedPosition, duration)
        }
        return advancedPosition
    }

    private func manualRenderState(offset: TimeInterval, sourceLabel: String) -> PlaybackRenderState {
        let mediaTime = max(0, manualTimeProvider())
        return PlaybackRenderState(
            mediaTime: mediaTime,
            effectiveTime: max(0, mediaTime + offset),
            isPlaying: manualIsPlayingProvider(),
            sourceLabel: sourceLabel,
            mode: .manual
        )
    }

    private func manualFallbackLabel(for state: AppleTVPlaybackState) -> String {
        switch state {
        case .stopped:
            return "Manual (TV stopped)"
        case .permissionDenied:
            return "Permission Needed"
        case .unavailable:
            return "Manual (TV unavailable)"
        case .playing, .paused, .fastForwarding, .rewinding:
            return "Manual (TV position missing)"
        }
    }

    private func manualFallbackLabel(for error: AppleTVPlaybackError) -> String {
        switch error {
        case .notRunning:
            return "Manual"
        case .permissionDenied:
            return "Permission Needed"
        case .missingPosition:
            return "Manual (TV position missing)"
        case .scriptError:
            return "Manual (TV error)"
        }
    }
}
