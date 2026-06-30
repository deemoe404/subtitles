import XCTest
@testable import SubtitlesAppSupport

final class AppleTVPlaybackParserTests: XCTestCase {
    func testParsesPlayingSnapshot() throws {
        let observedAt = Date(timeIntervalSince1970: 10)

        let snapshot = try AppleTVPlaybackParser.parseAppleScriptResult(
            "playing|12.5|3600.0",
            observedAt: observedAt
        )

        XCTAssertEqual(snapshot.state, .playing)
        XCTAssertEqual(snapshot.position, 12.5)
        XCTAssertEqual(snapshot.duration, 3600)
        XCTAssertEqual(snapshot.observedAt, observedAt)
    }

    func testParsesPausedSnapshot() throws {
        let snapshot = try AppleTVPlaybackParser.parseAppleScriptResult("paused|30|90")

        XCTAssertEqual(snapshot.state, .paused)
        XCTAssertEqual(snapshot.position, 30)
        XCTAssertEqual(snapshot.duration, 90)
    }

    func testParsesStoppedWithMissingValues() throws {
        let snapshot = try AppleTVPlaybackParser.parseAppleScriptResult("stopped|missing value|missing value")

        XCTAssertEqual(snapshot.state, .stopped)
        XCTAssertNil(snapshot.position)
        XCTAssertNil(snapshot.duration)
    }

    func testParsesFastForwardingAndRewinding() throws {
        let fastForwarding = try AppleTVPlaybackParser.parseAppleScriptResult("fast forwarding|20|100")
        let rewinding = try AppleTVPlaybackParser.parseAppleScriptResult("rewinding|18|100")

        XCTAssertEqual(fastForwarding.state, .fastForwarding)
        XCTAssertEqual(rewinding.state, .rewinding)
        XCTAssertTrue(fastForwarding.state.isActivelyAdvancing)
        XCTAssertTrue(rewinding.state.isActivelyAdvancing)
    }

    func testThrowsForMissingPositionWhilePlaying() {
        XCTAssertThrowsError(try AppleTVPlaybackParser.parseAppleScriptResult("playing|missing value|100")) { error in
            XCTAssertEqual(error as? AppleTVPlaybackError, .missingPosition)
        }
    }

    func testMapsPlaybackButtonDescriptionToActualState() {
        XCTAssertEqual(AppleTVPlaybackParser.stateFromPlaybackButtonDescription("Pause"), .playing)
        XCTAssertEqual(AppleTVPlaybackParser.stateFromPlaybackButtonDescription("Play"), .paused)
        XCTAssertNil(AppleTVPlaybackParser.stateFromPlaybackButtonDescription("AirPlay"))
    }
}
