import XCTest
@testable import OneMoreCapAppCommon
import OneMoreCapAppleTVSupport
import OneMoreCapAppSupport

final class SubtitleToolbarModelTests: XCTestCase {
    func testDefaultTargetSelectsAppleTVForFullChannel() {
        let model = SubtitleToolbarModel()

        model.setSyncTargets(
            [.quickTime, .appleTV],
            defaultTargetID: ExternalPlaybackTarget.appleTV.id
        )

        XCTAssertEqual(model.selectedSyncTargetID, ExternalPlaybackTarget.appleTV.id)
        XCTAssertEqual(model.selectedSyncTarget, .appleTV)
    }

    func testInvalidDefaultTargetFallsBackToFirstAvailableTarget() {
        let model = SubtitleToolbarModel()

        model.setSyncTargets(
            [.quickTime, .appleTV],
            defaultTargetID: "missing"
        )

        XCTAssertEqual(model.selectedSyncTargetID, ExternalPlaybackTarget.quickTime.id)
        XCTAssertEqual(model.selectedSyncTarget, .quickTime)
    }

    func testEmptyTargetListKeepsQuickTimeFallback() {
        let model = SubtitleToolbarModel()

        model.setSyncTargets([], defaultTargetID: nil)

        XCTAssertEqual(model.selectedSyncTargetID, ExternalPlaybackTarget.quickTime.id)
        XCTAssertEqual(model.selectedSyncTarget, .quickTime)
    }
}
