import XCTest
@testable import SubtitlesAppSupport

final class PlaybackSyncCoordinatorTests: XCTestCase {
    func testUsesManualClockByDefault() {
        let coordinator = PlaybackSyncCoordinator(
            manualTimeProvider: { 9 },
            manualIsPlayingProvider: { true }
        )

        let state = coordinator.renderState(offset: 0.25)

        XCTAssertEqual(state.mediaTime, 9)
        XCTAssertEqual(state.effectiveTime, 9.25)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "Manual")
    }

    func testAppleTVCalibrationChangesOnlySourceLabel() {
        let manualTime = MutablePlaybackState(mediaTime: 3, isPlaying: false)
        let coordinator = PlaybackSyncCoordinator(
            manualTimeProvider: { manualTime.mediaTime },
            manualIsPlayingProvider: { manualTime.isPlaying }
        )

        coordinator.markAppleTVCalibrated()

        var state = coordinator.renderState(offset: 0.5)
        XCTAssertEqual(state.mediaTime, 3)
        XCTAssertEqual(state.effectiveTime, 3.5)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "TV calibrated")

        manualTime.mediaTime = 7
        manualTime.isPlaying = true

        state = coordinator.renderState(offset: -1)
        XCTAssertEqual(state.mediaTime, 7)
        XCTAssertEqual(state.effectiveTime, 6)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "TV calibrated")
    }

    func testMarkManualRestoresManualSourceLabel() {
        let coordinator = PlaybackSyncCoordinator(
            manualTimeProvider: { 5 },
            manualIsPlayingProvider: { false }
        )

        coordinator.markAppleTVCalibrated()
        coordinator.markManual()

        let state = coordinator.renderState(offset: 2)

        XCTAssertEqual(state.mediaTime, 5)
        XCTAssertEqual(state.effectiveTime, 7)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "Manual")
    }

    func testNegativeEffectiveTimeIsClampedToZero() {
        let coordinator = PlaybackSyncCoordinator(
            manualTimeProvider: { 0.25 },
            manualIsPlayingProvider: { false }
        )

        let state = coordinator.renderState(offset: -1)

        XCTAssertEqual(state.mediaTime, 0.25)
        XCTAssertEqual(state.effectiveTime, 0)
    }
}

private final class MutablePlaybackState {
    var mediaTime: TimeInterval
    var isPlaying: Bool

    init(mediaTime: TimeInterval, isPlaying: Bool) {
        self.mediaTime = mediaTime
        self.isPlaying = isPlaying
    }
}
