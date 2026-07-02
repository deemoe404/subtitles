import OneMoreCapAppleTVSupport
import OneMoreCapAppCommon
import OneMoreCapAppSupport
import OneMoreCapGitHubSupport

runOneMoreCapApp(
    configuration: OneMoreCapAppConfiguration(
        playbackClients: [
            QuickTimePlaybackClient(),
            AppleTVPlaybackClient()
        ],
        defaultPlaybackTargetID: ExternalPlaybackTarget.appleTV.id,
        updateController: SparkleAppUpdateController(),
        accessibilityPermissionGranted: AppleTVPlaybackClient.isAccessibilityPermissionGranted,
        requestAccessibilityPermission: AppleTVPlaybackClient.requestAccessibilityPermission,
        showsAutomationSettings: true,
        showsAccessibilitySettings: true,
        showsUpdateMenu: true
    )
)
