@preconcurrency import Cocoa
import Combine
import SwiftUI
import OneMoreCapAppSupport

struct OnboardingPermissionState: Equatable {
    let showsAutomation: Bool
    let automationGranted: Bool
    let showsAccessibility: Bool
    let accessibilityGranted: Bool

    var checklistItems: [OnboardingPermissionChecklistItem] {
        var items: [OnboardingPermissionChecklistItem] = []
        if showsAutomation {
            items.append(
                OnboardingPermissionChecklistItem(
                    kind: .automation,
                    title: L10n.string(
                        "onboarding.permission.quicktime.title",
                        value: "QuickTime Automation"
                    ),
                    detail: L10n.string(
                        "onboarding.permission.quicktime.detail",
                        value: "Allows Sync to read the current movie time from QuickTime Player."
                    ),
                    isGranted: automationGranted
                )
            )
        }
        if showsAccessibility {
            items.append(
                OnboardingPermissionChecklistItem(
                    kind: .accessibility,
                    title: L10n.string(
                        "onboarding.permission.apple_tv.title",
                        value: "Apple TV Accessibility"
                    ),
                    detail: L10n.string(
                        "onboarding.permission.apple_tv.detail",
                        value: "Allows the GitHub build to read playback state from TV.app."
                    ),
                    isGranted: accessibilityGranted
                )
            )
        }
        return items
    }

    var allVisiblePermissionsGranted: Bool {
        checklistItems.allSatisfy(\.isGranted)
    }
}

struct OnboardingPermissionChecklistItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case automation
        case accessibility
    }

    let kind: Kind
    let title: String
    let detail: String
    let isGranted: Bool

    var id: Kind {
        kind
    }

    var statusText: String {
        isGranted
            ? L10n.string("onboarding.permission.allowed", value: "Allowed")
            : L10n.string("onboarding.permission.needs_setup", value: "Needs setup")
    }

    var statusSystemImage: String {
        isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    var requestButtonTitle: String {
        isGranted
            ? L10n.string("onboarding.permission.allowed", value: "Allowed")
            : L10n.string("onboarding.permission.request_access", value: "Request Access")
    }
}

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let model: OnboardingViewModel
    private let hostingController: NSHostingController<OnboardingView>
    private let onDismiss: () -> Void

    init(
        appName: String,
        permissionState: OnboardingPermissionState,
        onRequestAutomationPermission: @escaping () -> Void,
        onOpenAutomationSettings: @escaping () -> Void,
        onRequestAccessibilityPermission: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void,
        onOpenCaptionSettings: @escaping () -> Void,
        onRefreshPermissionState: @escaping () -> Void,
        onComplete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        let model = OnboardingViewModel(
            appName: appName,
            permissionState: permissionState,
            onRequestAutomationPermission: onRequestAutomationPermission,
            onOpenAutomationSettings: onOpenAutomationSettings,
            onRequestAccessibilityPermission: onRequestAccessibilityPermission,
            onOpenAccessibilitySettings: onOpenAccessibilitySettings,
            onOpenCaptionSettings: onOpenCaptionSettings,
            onRefreshPermissionState: onRefreshPermissionState,
            onComplete: onComplete
        )
        self.model = model
        self.onDismiss = onDismiss

        let hostingController = NSHostingController(rootView: OnboardingView(model: model))
        self.hostingController = hostingController
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.format("onboarding.window.title", value: "Set Up %@", appName)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        super.init(window: window)
        window.delegate = self
        resizeWindowToFitContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        model.refreshPermissionState()
    }

    func update(permissionState: OnboardingPermissionState) {
        model.permissionState = permissionState
        DispatchQueue.main.async { [weak self] in
            self?.resizeWindowToFitContent()
        }
    }

    func refreshLocalization() {
        window?.title = L10n.format("onboarding.window.title", value: "Set Up %@", model.appName)
        model.refreshLocalization()
        DispatchQueue.main.async { [weak self] in
            self?.resizeWindowToFitContent()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refreshPermissionState()
    }

    func windowWillClose(_ notification: Notification) {
        onDismiss()
    }

    private func resizeWindowToFitContent() {
        guard let window else {
            return
        }

        let nextContentSize = fittingContentSize()

        let currentContentSize = window.contentRect(forFrameRect: window.frame).size
        guard abs(currentContentSize.width - nextContentSize.width) > 0.5
            || abs(currentContentSize.height - nextContentSize.height) > 0.5 else {
            return
        }

        let currentFrame = window.frame
        let nextFrameSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: nextContentSize)
        ).size
        let nextFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - nextFrameSize.height,
            width: nextFrameSize.width,
            height: nextFrameSize.height
        )
        window.setFrame(nextFrame, display: true, animate: false)
    }

    private func fittingContentSize() -> NSSize {
        let view = hostingController.view
        view.frame.size = NSSize(width: OnboardingView.contentWidth, height: 10_000)
        view.layoutSubtreeIfNeeded()

        let fittingSize = view.fittingSize
        return NSSize(
            width: OnboardingView.contentWidth,
            height: ceil(fittingSize.height)
        )
    }
}

private final class OnboardingViewModel: ObservableObject {
    let appName: String
    @Published var permissionState: OnboardingPermissionState
    @Published private var localizationRevision = 0

    private let onRequestAutomationPermission: () -> Void
    private let onOpenAutomationSettings: () -> Void
    private let onRequestAccessibilityPermission: () -> Void
    private let onOpenAccessibilitySettings: () -> Void
    private let onOpenCaptionSettings: () -> Void
    private let onRefreshPermissionState: () -> Void
    private let onComplete: () -> Void

    init(
        appName: String,
        permissionState: OnboardingPermissionState,
        onRequestAutomationPermission: @escaping () -> Void,
        onOpenAutomationSettings: @escaping () -> Void,
        onRequestAccessibilityPermission: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void,
        onOpenCaptionSettings: @escaping () -> Void,
        onRefreshPermissionState: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.appName = appName
        self.permissionState = permissionState
        self.onRequestAutomationPermission = onRequestAutomationPermission
        self.onOpenAutomationSettings = onOpenAutomationSettings
        self.onRequestAccessibilityPermission = onRequestAccessibilityPermission
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        self.onOpenCaptionSettings = onOpenCaptionSettings
        self.onRefreshPermissionState = onRefreshPermissionState
        self.onComplete = onComplete
    }

    var permissionsConfiguredText: String {
        permissionState.allVisiblePermissionsGranted
            ? L10n.string(
                "onboarding.footer.all_allowed",
                value: "All sync permissions are allowed."
            )
            : L10n.string(
                "onboarding.footer.manual_until_allowed",
                value: "Sync keeps working in manual mode until these are allowed."
            )
    }

    func requestPermission(for kind: OnboardingPermissionChecklistItem.Kind) {
        switch kind {
        case .automation:
            onRequestAutomationPermission()
        case .accessibility:
            onRequestAccessibilityPermission()
        }
        refreshPermissionState()
    }

    func openSettings(for kind: OnboardingPermissionChecklistItem.Kind) {
        switch kind {
        case .automation:
            onOpenAutomationSettings()
        case .accessibility:
            onOpenAccessibilitySettings()
        }
        refreshPermissionState()
    }

    func openCaptionSettings() {
        onOpenCaptionSettings()
    }

    func refreshPermissionState() {
        onRefreshPermissionState()
    }

    func complete() {
        onComplete()
    }

    func refreshLocalization() {
        localizationRevision += 1
    }
}

private struct OnboardingView: View {
    static let contentWidth: CGFloat = 560

    @ObservedObject var model: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            permissionChecklist
            captionSettings
            footer
        }
        .padding(.top, 14)
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .frame(width: Self.contentWidth, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.format("onboarding.header.title", value: "Set up %@", model.appName))
                    .font(.title2.weight(.semibold))
                Text(L10n.string(
                    "onboarding.header.subtitle",
                    value: "Grant the macOS permissions used for playback sync. You can still load subtitles without them."
                ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("onboarding.sync_permissions.title", value: "Sync Permissions"))
                    .font(.headline)
                Spacer()
                Button {
                    model.refreshPermissionState()
                } label: {
                    Label(
                        L10n.string("button.refresh", value: "Refresh"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.borderless)
            }

            VStack(spacing: 8) {
                ForEach(model.permissionState.checklistItems) { item in
                    OnboardingPermissionRow(
                        item: item,
                        requestAccess: {
                            model.requestPermission(for: item.kind)
                        },
                        openSettings: {
                            model.openSettings(for: item.kind)
                        }
                    )
                }
            }
        }
    }

    private var captionSettings: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "textformat.size")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("onboarding.caption_style.title", value: "Caption Style"))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.string(
                    "onboarding.caption_style.detail",
                    value: "Use macOS caption settings to choose subtitle text style."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.openCaptionSettings()
            } label: {
                Label(
                    L10n.string("button.open_settings", value: "Open Settings"),
                    systemImage: "gearshape"
                )
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(model.permissionsConfiguredText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                model.complete()
            } label: {
                Text(L10n.string("button.done", value: "Done"))
                    .frame(minWidth: 74)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct OnboardingPermissionRow: View {
    let item: OnboardingPermissionChecklistItem
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.statusSystemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.isGranted ? .green : .orange)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Text(item.statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.isGranted ? .green : .orange)
                }
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    requestAccess()
                } label: {
                    Label(item.requestButtonTitle, systemImage: item.isGranted ? "checkmark" : "hand.raised")
                }
                .disabled(item.isGranted)

                if !item.isGranted {
                    Button {
                        openSettings()
                    } label: {
                        Text(L10n.string("button.open_settings", value: "Open Settings"))
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format(
            "onboarding.permission.accessibility_label",
            value: "%@, %@",
            item.title,
            item.statusText
        ))
    }
}
