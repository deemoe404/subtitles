import Foundation

public final class PlaybackSyncCoordinator {
    public typealias ManualTimeProvider = () -> TimeInterval
    public typealias ManualIsPlayingProvider = () -> Bool

    private let manualTimeProvider: ManualTimeProvider
    private let manualIsPlayingProvider: ManualIsPlayingProvider
    private var sourceLabel = "Manual"

    public init(
        manualTimeProvider: @escaping ManualTimeProvider,
        manualIsPlayingProvider: @escaping ManualIsPlayingProvider
    ) {
        self.manualTimeProvider = manualTimeProvider
        self.manualIsPlayingProvider = manualIsPlayingProvider
    }

    public func renderState(offset: TimeInterval) -> PlaybackRenderState {
        let mediaTime = max(0, manualTimeProvider())
        return PlaybackRenderState(
            mediaTime: mediaTime,
            effectiveTime: max(0, mediaTime + offset),
            isPlaying: manualIsPlayingProvider(),
            sourceLabel: sourceLabel
        )
    }

    public func markQuickTimeSynced() {
        markSynced(with: "QuickTime synced")
    }

    public func markSynced(with sourceLabel: String) {
        self.sourceLabel = sourceLabel
    }

    public func markManual() {
        sourceLabel = "Manual"
    }
}
