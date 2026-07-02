import AppKit
import XCTest
@testable import OneMoreCapAppSupport

final class QuickTimePlaybackTests: XCTestCase {
    func testClientParsesPausedSnapshot() {
        let client = QuickTimePlaybackClient(
            runningApplicationProvider: { _ in [.current] },
            scriptExecutor: { _ in
                QuickTimeScriptExecutionResult(
                    descriptor: Self.snapshotDescriptor(
                        status: "ok",
                        position: "13.25",
                        duration: "6496.54",
                        playing: "false"
                    ),
                    error: nil
                )
            }
        )

        XCTAssertEqual(
            client.currentSnapshot(),
            .success(
                ExternalPlaybackSnapshot(
                    state: .paused,
                    position: 13.25,
                    duration: 6496.54
                )
            )
        )
    }

    func testClientParsesPlayingSnapshot() {
        let client = QuickTimePlaybackClient(
            runningApplicationProvider: { _ in [.current] },
            scriptExecutor: { _ in
                QuickTimeScriptExecutionResult(
                    descriptor: Self.snapshotDescriptor(
                        status: "ok",
                        position: "14.5",
                        duration: "6496.54",
                        playing: "true"
                    ),
                    error: nil
                )
            }
        )

        XCTAssertEqual(
            client.currentSnapshot(),
            .success(
                ExternalPlaybackSnapshot(
                    state: .playing,
                    position: 14.5,
                    duration: 6496.54
                )
            )
        )
    }

    func testClientReportsMissingDocument() {
        let client = QuickTimePlaybackClient(
            runningApplicationProvider: { _ in [.current] },
            scriptExecutor: { _ in
                QuickTimeScriptExecutionResult(
                    descriptor: Self.snapshotDescriptor(
                        status: "missingDocument",
                        position: "",
                        duration: "",
                        playing: ""
                    ),
                    error: nil
                )
            }
        )

        XCTAssertEqual(
            client.currentSnapshot(),
            .failure(.missingDocument(appName: QuickTimePlaybackClient.appName))
        )
    }

    func testClientMapsAutomationAuthorizationFailure() {
        let client = QuickTimePlaybackClient(
            runningApplicationProvider: { _ in [.current] },
            scriptExecutor: { _ in
                QuickTimeScriptExecutionResult(
                    descriptor: nil,
                    error: [NSAppleScript.errorNumber: -1743]
                )
            }
        )

        XCTAssertEqual(
            client.currentSnapshot(),
            .failure(.automationPermissionDenied(appName: QuickTimePlaybackClient.appName))
        )
    }

    func testClientReportsNotRunning() {
        let client = QuickTimePlaybackClient(
            runningApplicationProvider: { _ in [] },
            scriptExecutor: { _ in
                XCTFail("Script should not run when QuickTime is not running")
                return QuickTimeScriptExecutionResult(descriptor: nil, error: nil)
            }
        )

        XCTAssertEqual(
            client.currentSnapshot(),
            .failure(.notRunning(appName: QuickTimePlaybackClient.appName))
        )
    }

    private static func snapshotDescriptor(
        status: String,
        position: String,
        duration: String,
        playing: String
    ) -> NSAppleEventDescriptor {
        let list = NSAppleEventDescriptor.list()
        list.insert(NSAppleEventDescriptor(string: status), at: 1)
        list.insert(NSAppleEventDescriptor(string: position), at: 2)
        list.insert(NSAppleEventDescriptor(string: duration), at: 3)
        list.insert(NSAppleEventDescriptor(string: playing), at: 4)
        return list
    }
}
