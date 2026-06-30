import XCTest
@testable import SubtitlesAppSupport

final class PlaybackSyncCoordinatorTests: XCTestCase {
    func testAppleTVSnapshotOverridesManualClock() {
        let observedAt = Date(timeIntervalSince1970: 100)
        let coordinator = PlaybackSyncCoordinator(
            mode: .appleTV,
            appleTVSnapshotProvider: {
                .success(AppleTVPlaybackSnapshot(
                    state: .playing,
                    position: 12,
                    duration: 100,
                    observedAt: observedAt
                ))
            },
            manualTimeProvider: { 3 },
            manualIsPlayingProvider: { false },
            dateProvider: { observedAt }
        )

        let state = coordinator.renderState(offset: 0.5)

        XCTAssertEqual(state.mediaTime, 12)
        XCTAssertEqual(state.effectiveTime, 12.5)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "TV playing")
        XCTAssertEqual(state.mode, .appleTV)
    }

    func testPausedAppleTVSnapshotKeepsPositionButMarksNotPlaying() {
        let observedAt = Date(timeIntervalSince1970: 100)
        let coordinator = PlaybackSyncCoordinator(
            mode: .appleTV,
            appleTVSnapshotProvider: {
                .success(AppleTVPlaybackSnapshot(
                    state: .paused,
                    position: 40,
                    duration: 100,
                    observedAt: observedAt
                ))
            },
            manualTimeProvider: { 3 },
            manualIsPlayingProvider: { true },
            dateProvider: { observedAt.addingTimeInterval(10) }
        )

        let state = coordinator.renderState(offset: -1)

        XCTAssertEqual(state.mediaTime, 40)
        XCTAssertEqual(state.effectiveTime, 39)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "TV paused")
    }

    func testPlayingAppleTVSnapshotAdvancesFromObservationTime() {
        let observedAt = Date(timeIntervalSince1970: 100)
        let coordinator = PlaybackSyncCoordinator(
            mode: .appleTV,
            appleTVSnapshotProvider: {
                .success(AppleTVPlaybackSnapshot(
                    state: .playing,
                    position: 10,
                    duration: 20,
                    observedAt: observedAt
                ))
            },
            manualTimeProvider: { 0 },
            manualIsPlayingProvider: { false },
            dateProvider: { observedAt.addingTimeInterval(2.5) }
        )

        let state = coordinator.renderState(offset: 0)

        XCTAssertEqual(state.mediaTime, 12.5)
        XCTAssertEqual(state.effectiveTime, 12.5)
    }

    func testFallbacksToManualWhenTVIsNotRunning() {
        let coordinator = PlaybackSyncCoordinator(
            mode: .appleTV,
            appleTVSnapshotProvider: { .failure(.notRunning) },
            manualTimeProvider: { 9 },
            manualIsPlayingProvider: { true }
        )

        let state = coordinator.renderState(offset: 0.25)

        XCTAssertEqual(state.mediaTime, 9)
        XCTAssertEqual(state.effectiveTime, 9.25)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "Manual")
        XCTAssertEqual(state.mode, .manual)
    }

    func testManualModeDoesNotPollAppleTV() {
        var didPollAppleTV = false
        let coordinator = PlaybackSyncCoordinator(
            mode: .manual,
            appleTVSnapshotProvider: {
                didPollAppleTV = true
                return .failure(.scriptError("should not poll"))
            },
            manualTimeProvider: { 5 },
            manualIsPlayingProvider: { false }
        )

        let state = coordinator.renderState(offset: 2)

        XCTAssertFalse(didPollAppleTV)
        XCTAssertEqual(state.mediaTime, 5)
        XCTAssertEqual(state.effectiveTime, 7)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "Manual")
    }

    func testCalibrationSnapshotCarriesAppleTVSyncWhenPollingFails() {
        let observedAt = Date(timeIntervalSince1970: 100)
        let coordinator = PlaybackSyncCoordinator(
            mode: .appleTV,
            appleTVSnapshotProvider: { .failure(.missingPosition) },
            manualTimeProvider: { 1 },
            manualIsPlayingProvider: { false },
            dateProvider: { observedAt.addingTimeInterval(4) }
        )

        coordinator.calibrate(with: AppleTVPlaybackSnapshot(
            state: .playing,
            position: 20,
            duration: 40,
            observedAt: observedAt
        ))

        let state = coordinator.renderState(offset: 0.5)

        XCTAssertEqual(state.mediaTime, 24)
        XCTAssertEqual(state.effectiveTime, 24.5)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.sourceLabel, "TV calibrated")
        XCTAssertEqual(state.mode, .appleTV)
    }
}
