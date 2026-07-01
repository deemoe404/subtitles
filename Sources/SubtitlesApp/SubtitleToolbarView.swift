@preconcurrency import Cocoa
import Combine
import SwiftUI

protocol SubtitleToolbarViewDelegate: AnyObject {
    func subtitleToolbarViewDidEnter(_ view: SubtitleToolbarView)
    func subtitleToolbarViewDidExit(_ view: SubtitleToolbarView)
    func subtitleToolbarView(_ view: SubtitleToolbarView, didAdjustOffsetBy delta: TimeInterval)
    func subtitleToolbarViewDidRequestAppleTVCalibration(_ view: SubtitleToolbarView)
}

final class SubtitleToolbarView: NSView {
    weak var delegate: SubtitleToolbarViewDelegate?

    private let model = SubtitleToolbarModel()
    private var hostingView: NSHostingView<SubtitleToolbarContentView>?
    private var trackingAreaRef: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        guard let hostingView else {
            return NSSize(width: 280, height: 38)
        }
        return hostingView.fittingSize
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.subtitleToolbarViewDidEnter(self)
    }

    override func mouseExited(with event: NSEvent) {
        delegate?.subtitleToolbarViewDidExit(self)
    }

    func setPlaybackState(isPlaying _: Bool, time: TimeInterval, offset: TimeInterval, sourceLabel: String) {
        model.playbackTime = time
        model.offset = offset
        model.sourceLabel = sourceLabel
        invalidateIntrinsicContentSize()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.width, .height]

        model.adjustOffset = { [weak self] delta in
            guard let self else {
                return
            }
            delegate?.subtitleToolbarView(self, didAdjustOffsetBy: delta)
        }
        model.requestAppleTVCalibration = { [weak self] in
            guard let self else {
                return
            }
            delegate?.subtitleToolbarViewDidRequestAppleTVCalibration(self)
        }

        let contentView = FirstMouseHostingView(rootView: SubtitleToolbarContentView(model: model))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.setContentHuggingPriority(.required, for: .horizontal)
        contentView.setContentHuggingPriority(.required, for: .vertical)
        addSubview(contentView)
        hostingView = contentView

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class SubtitleToolbarModel: ObservableObject {
    @Published var playbackTime: TimeInterval = 0
    @Published var offset: TimeInterval = 0
    @Published var sourceLabel = "Manual"

    var adjustOffset: ((TimeInterval) -> Void)?
    var requestAppleTVCalibration: (() -> Void)?

    var statusKind: SubtitleToolbarStatusKind {
        SubtitleToolbarStatusKind(sourceLabel: sourceLabel)
    }

    var playbackTimeText: String {
        formatTime(playbackTime)
    }

    var offsetText: String {
        formatOffset(offset)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatOffset(_ offset: TimeInterval) -> String {
        String(format: "%+.1fs", offset)
    }
}

private enum SubtitleToolbarStatusKind {
    case manual
    case appleTVCalibrated
    case unknown

    init(sourceLabel: String) {
        switch sourceLabel {
        case "Manual":
            self = .manual
        case "TV calibrated":
            self = .appleTVCalibrated
        default:
            self = .unknown
        }
    }

    var symbolName: String {
        switch self {
        case .manual:
            return "hand.tap.fill"
        case .appleTVCalibrated:
            return "appletv.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .manual:
            return .yellow
        case .appleTVCalibrated:
            return .green
        case .unknown:
            return .gray
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .manual:
            return "Manual playback"
        case .appleTVCalibrated:
            return "Apple TV calibrated playback"
        case .unknown:
            return "Unknown playback source"
        }
    }
}

private struct SubtitleToolbarContentView: View {
    private static let bubbleHeight: CGFloat = 44
    private static let syncBubbleWidth: CGFloat = 76

    @ObservedObject var model: SubtitleToolbarModel

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 10) {
                statusView
                    .frame(maxWidth: 420, alignment: .leading)
                    .frame(height: Self.bubbleHeight)
                    .padding(.horizontal, 12)
                    .glassEffect(.regular.interactive(), in: Capsule())

                syncControl
                    .layoutPriority(1)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .environment(\.controlActiveState, .active)
    }

    private var syncControl: some View {
        HStack(spacing: 0) {
            Button {
                model.requestAppleTVCalibration?()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 42, height: Self.bubbleHeight)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Sync with Apple TV")
            .accessibilityLabel(Text("Sync with Apple TV"))

            Divider()
                .frame(height: 22)

            Menu {
                Button {
                    model.requestAppleTVCalibration?()
                } label: {
                    Label("Apple TV", systemImage: "appletv.fill")
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 32, height: Self.bubbleHeight)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .contentShape(Rectangle())
            .help("Choose sync target")
            .accessibilityLabel(Text("Choose sync target"))
        }
        .frame(width: Self.syncBubbleWidth, height: Self.bubbleHeight)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var statusView: some View {
        HStack(spacing: 6) {
            Image(systemName: model.statusKind.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(model.statusKind.tint)
                .accessibilityLabel(Text(model.statusKind.accessibilityLabel))
                .help(model.statusKind.accessibilityLabel)

            Text(model.playbackTimeText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(model.offsetText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
                stepperButton(
                    systemName: "chevron.up",
                    help: "Increase subtitle offset by 0.5 seconds"
                ) {
                    model.adjustOffset?(0.5)
                }
                stepperButton(
                    systemName: "chevron.down",
                    help: "Decrease subtitle offset by 0.5 seconds"
                ) {
                    model.adjustOffset?(-0.5)
                }
            }
        }
    }

    private func stepperButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .bold))
                .frame(width: 18, height: 8)
        }
        .buttonStyle(.glass)
        .controlSize(.mini)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}
