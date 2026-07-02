import OneMoreCapAppCommon
import OneMoreCapAppSupport

runOneMoreCapApp(
    configuration: OneMoreCapAppConfiguration(
        playbackClients: [
            QuickTimePlaybackClient()
        ],
        defaultPlaybackTargetID: ExternalPlaybackTarget.quickTime.id,
        updateController: NoopAppUpdateController(),
        accessibilityPermissionGranted: { false },
        showsAutomationSettings: true,
        showsAccessibilitySettings: false,
        showsUpdateMenu: false
    )
)
