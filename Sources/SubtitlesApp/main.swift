import SubtitlesAppleTVSupport
import SubtitlesAppCommon
import SubtitlesAppSupport
import SubtitlesGitHubSupport

runSubtitlesApp(
    configuration: SubtitlesAppConfiguration(
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
