import XCTest
@testable import SubtitlesAppCommon

final class OnboardingPermissionStateTests: XCTestCase {
    func testAppStoreChecklistOnlyIncludesAutomation() {
        let state = OnboardingPermissionState(
            showsAutomation: true,
            automationGranted: false,
            showsAccessibility: false,
            accessibilityGranted: false
        )

        XCTAssertEqual(state.checklistItems.map(\.kind), [.automation])
        XCTAssertFalse(state.allVisiblePermissionsGranted)
    }

    func testFullChannelChecklistIncludesAutomationAndAccessibility() {
        let state = OnboardingPermissionState(
            showsAutomation: true,
            automationGranted: true,
            showsAccessibility: true,
            accessibilityGranted: false
        )

        XCTAssertEqual(state.checklistItems.map(\.kind), [.automation, .accessibility])
        XCTAssertFalse(state.allVisiblePermissionsGranted)
    }

    func testHiddenPermissionsDoNotBlockCompletionState() {
        let state = OnboardingPermissionState(
            showsAutomation: false,
            automationGranted: false,
            showsAccessibility: false,
            accessibilityGranted: false
        )

        XCTAssertTrue(state.checklistItems.isEmpty)
        XCTAssertTrue(state.allVisiblePermissionsGranted)
    }
}
