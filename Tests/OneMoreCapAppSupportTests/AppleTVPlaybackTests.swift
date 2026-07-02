import XCTest
@testable import OneMoreCapAppleTVSupport
@testable import OneMoreCapAppSupport

final class AppleTVPlaybackTests: XCTestCase {
    func testMapsPlaybackButtonDescriptionToActualState() {
        XCTAssertEqual(AppleTVPlaybackParser.stateFromPlaybackButtonDescription("Pause"), .playing)
        XCTAssertEqual(AppleTVPlaybackParser.stateFromPlaybackButtonDescription("Play"), .paused)
        XCTAssertNil(AppleTVPlaybackParser.stateFromPlaybackButtonDescription("AirPlay"))
    }

    func testPermissionErrorDescriptionIsAccessibilitySpecific() {
        XCTAssertEqual(
            ExternalPlaybackError.accessibilityPermissionDenied(appName: AppleTVPlaybackClient.appName).localizedDescription,
            "Accessibility permission for One More Cap to read TV.app is not granted."
        )
    }
}
