@preconcurrency import Cocoa

protocol SubtitleToolbarViewDelegate: AnyObject {
    func subtitleToolbarViewDidEnter(_ view: SubtitleToolbarView)
    func subtitleToolbarViewDidExit(_ view: SubtitleToolbarView)
    func subtitleToolbarView(_ view: SubtitleToolbarView, didRequestScale factor: CGFloat)
    func subtitleToolbarView(_ view: SubtitleToolbarView, didAdjustOffsetBy delta: TimeInterval)
    func subtitleToolbarViewDidRequestCaptionSettings(_ view: SubtitleToolbarView)
    func subtitleToolbarViewDidRequestAppleTVCalibration(_ view: SubtitleToolbarView)
    func subtitleToolbarViewDidRequestPlayPause(_ view: SubtitleToolbarView)
    func subtitleToolbarViewDidRequestReset(_ view: SubtitleToolbarView)
    func subtitleToolbarViewDidRequestClose(_ view: SubtitleToolbarView)
}

final class SubtitleToolbarView: NSView {
    weak var delegate: SubtitleToolbarViewDelegate?

    private let controlsStack = NSStackView()
    private let playPauseButton = NSButton(title: "Play", target: nil, action: nil)
    private var trackingAreaRef: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        let stackSize = controlsStack.fittingSize
        return NSSize(width: stackSize.width + 16, height: stackSize.height + 8)
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

    override func mouseEntered(with event: NSEvent) {
        delegate?.subtitleToolbarViewDidEnter(self)
    }

    override func mouseExited(with event: NSEvent) {
        delegate?.subtitleToolbarViewDidExit(self)
    }

    func setPlaybackState(isPlaying: Bool) {
        playPauseButton.title = isPlaying ? "Pause" : "Play"
        invalidateIntrinsicContentSize()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor

        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.distribution = .fill
        controlsStack.spacing = 8

        let controls = [
            makeButton("W-", action: #selector(decreaseWindowSize)),
            makeButton("W+", action: #selector(increaseWindowSize)),
            makeButton("-0.5s", action: #selector(decreaseOffset)),
            makeButton("+0.5s", action: #selector(increaseOffset)),
            makeButton("Captions", action: #selector(openCaptionSettings)),
            makeButton("Calibrate TV", action: #selector(calibrateAppleTV)),
            playPauseButton,
            makeButton("Reset", action: #selector(resetPlayback)),
            makeButton("Close", action: #selector(closePanel))
        ]

        playPauseButton.target = self
        playPauseButton.action = #selector(playPause)
        styleButton(playPauseButton)
        controls.forEach { controlsStack.addArrangedSubview($0) }

        addSubview(controlsStack)

        NSLayoutConstraint.activate([
            controlsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            controlsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            controlsStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            controlsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        styleButton(button)
        return button
    }

    private func styleButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.setButtonType(.momentaryPushIn)
    }

    @objc private func decreaseWindowSize() {
        delegate?.subtitleToolbarView(self, didRequestScale: 0.9)
    }

    @objc private func increaseWindowSize() {
        delegate?.subtitleToolbarView(self, didRequestScale: 1.1)
    }

    @objc private func decreaseOffset() {
        delegate?.subtitleToolbarView(self, didAdjustOffsetBy: -0.5)
    }

    @objc private func increaseOffset() {
        delegate?.subtitleToolbarView(self, didAdjustOffsetBy: 0.5)
    }

    @objc private func openCaptionSettings() {
        delegate?.subtitleToolbarViewDidRequestCaptionSettings(self)
    }

    @objc private func calibrateAppleTV() {
        delegate?.subtitleToolbarViewDidRequestAppleTVCalibration(self)
    }

    @objc private func playPause() {
        delegate?.subtitleToolbarViewDidRequestPlayPause(self)
    }

    @objc private func resetPlayback() {
        delegate?.subtitleToolbarViewDidRequestReset(self)
    }

    @objc private func closePanel() {
        delegate?.subtitleToolbarViewDidRequestClose(self)
    }
}
