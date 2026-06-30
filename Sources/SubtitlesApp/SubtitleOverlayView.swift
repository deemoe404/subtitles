@preconcurrency import Cocoa
import SwiftUI
import SubtitlesAppSupport

protocol SubtitleOverlayViewDelegate: AnyObject {
    func subtitleOverlayViewDidEnterInteractiveArea(_ view: SubtitleOverlayView)
    func subtitleOverlayViewDidExitInteractiveArea(_ view: SubtitleOverlayView)
    func subtitleOverlayViewDidLayout(_ view: SubtitleOverlayView)
    func subtitleOverlayViewDidBeginContainerResize(_ view: SubtitleOverlayView)
    func subtitleOverlayView(_ view: SubtitleOverlayView, didResizeContainerTo frame: NSRect)
    func subtitleOverlayViewDidEndContainerResize(_ view: SubtitleOverlayView)
    func subtitleOverlayView(_ view: SubtitleOverlayView, didRequestLoadURL url: URL)
}

final class SubtitleOverlayView: NSView {
    private enum TrackingRole: String {
        case subtitle
        case container
    }

    private struct ResizeEdges: OptionSet {
        let rawValue: Int

        static let left = ResizeEdges(rawValue: 1 << 0)
        static let right = ResizeEdges(rawValue: 1 << 1)
        static let top = ResizeEdges(rawValue: 1 << 2)
        static let bottom = ResizeEdges(rawValue: 1 << 3)

        var cursorPosition: NSCursor.FrameResizePosition {
            switch (contains(.top), contains(.left), contains(.bottom), contains(.right)) {
            case (true, true, _, _):
                return .topLeft
            case (true, _, _, true):
                return .topRight
            case (_, true, true, _):
                return .bottomLeft
            case (_, _, true, true):
                return .bottomRight
            case (true, _, _, _):
                return .top
            case (_, true, _, _):
                return .left
            case (_, _, true, _):
                return .bottom
            case (_, _, _, true):
                return .right
            default:
                return .right
            }
        }
    }

    private static let trackingRoleKey = "SubtitleOverlayTrackingRole"
    private static let containerChromeInset: CGFloat = 12
    private static let resizeEdgeThickness: CGFloat = 10
    private static let minimumPanelWidth: CGFloat = 420
    private static let maximumPanelWidth: CGFloat = 1400
    private static let minimumPanelHeight: CGFloat = 96
    weak var delegate: SubtitleOverlayViewDelegate?

    private static let placeholderText = "Drop SRT or VTT subtitle here"

    var subtitleText: String = placeholderText {
        didSet {
            updateSubtitleText()
        }
    }

    private let subtitleBackdropView = NSView()
    private let subtitleLabel = NSTextField(labelWithString: placeholderText)
    private let containerChromeView = NSHostingView(rootView: SubtitleContainerChromeContentView())

    private var captionAppearance = SystemCaptionAppearance.current()
    private var captionAppearanceMonitor: SystemCaptionAppearanceMonitor?
    private var isContainerChromeVisible = false
    private var isReportingCaptions = true
    private var lastReportedCaptionText: String?
    private var trackingAreaRefs: [NSTrackingArea] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        startCaptionAppearanceMonitoring()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        startCaptionAppearanceMonitoring()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        rebuildTrackingAreas()
    }

    override func layout() {
        super.layout()
        rebuildTrackingAreas()
        window?.invalidateCursorRects(for: self)
        delegate?.subtitleOverlayViewDidLayout(self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        guard isContainerChromeVisible else {
            return
        }

        for (rect, edges) in resizeCursorRects() {
            addCursorRect(
                rect,
                cursor: NSCursor.frameResize(position: edges.cursorPosition, directions: .all)
            )
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isInteractivePoint(point) else {
            return nil
        }

        return self
    }

    override func mouseEntered(with event: NSEvent) {
        guard let role = trackingRole(from: event) else {
            return
        }

        switch role {
        case .subtitle:
            delegate?.subtitleOverlayViewDidEnterInteractiveArea(self)
        case .container:
            delegate?.subtitleOverlayViewDidEnterInteractiveArea(self)
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard let point = currentMouseLocationInView(), isInteractivePoint(point) else {
            delegate?.subtitleOverlayViewDidExitInteractiveArea(self)
            return
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let resizeEdges = resizeEdges(at: point) {
            performContainerResize(with: event, edges: resizeEdges)
            return
        }

        guard isInteractivePoint(point) else {
            super.mouseDown(with: event)
            return
        }

        window?.performDrag(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        firstSupportedURL(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = firstSupportedURL(from: sender.draggingPasteboard) else {
            return false
        }
        delegate?.subtitleOverlayView(self, didRequestLoadURL: url)
        return true
    }

    func setCaptionReportingEnabled(_ enabled: Bool) {
        isReportingCaptions = enabled
        reportDisplayedCaptions(force: true)
    }

    func setContainerChromeVisible(_ visible: Bool, animated: Bool) {
        guard visible != isContainerChromeVisible else {
            return
        }

        isContainerChromeVisible = visible
        rebuildTrackingAreas()
        window?.invalidateCursorRects(for: self)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.12 : 0
            containerChromeView.animator().alphaValue = visible ? 1 : 0
        }
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 0
        registerForDraggedTypes([.fileURL])

        containerChromeView.translatesAutoresizingMaskIntoConstraints = false
        containerChromeView.alphaValue = 0
        containerChromeView.wantsLayer = true
        containerChromeView.layer?.backgroundColor = NSColor.clear.cgColor

        subtitleBackdropView.translatesAutoresizingMaskIntoConstraints = false
        subtitleBackdropView.wantsLayer = true
        subtitleBackdropView.layer?.backgroundColor = captionAppearance.windowColor.cgColor
        subtitleBackdropView.layer?.cornerRadius = captionAppearance.windowCornerRadius

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(containerChromeView)
        addSubview(subtitleBackdropView)
        subtitleBackdropView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            containerChromeView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.containerChromeInset),
            containerChromeView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.containerChromeInset),
            containerChromeView.topAnchor.constraint(equalTo: topAnchor, constant: Self.containerChromeInset),
            containerChromeView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.containerChromeInset),

            subtitleBackdropView.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleBackdropView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            subtitleBackdropView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            subtitleBackdropView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            subtitleLabel.leadingAnchor.constraint(equalTo: subtitleBackdropView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: subtitleBackdropView.trailingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: subtitleBackdropView.topAnchor, constant: 8),
            subtitleLabel.bottomAnchor.constraint(equalTo: subtitleBackdropView.bottomAnchor, constant: -8)
        ])

        updateSubtitleText()
    }

    private func rebuildTrackingAreas() {
        trackingAreaRefs.forEach { removeTrackingArea($0) }
        trackingAreaRefs.removeAll()

        addTrackingArea(for: subtitleBackdropView.frame, role: .subtitle)
        if isContainerChromeVisible {
            addTrackingArea(for: containerChromeView.frame, role: .container)
        }
    }

    private func addTrackingArea(for rect: NSRect, role: TrackingRole) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        var options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        if let point = currentMouseLocationInView(), rect.contains(point) {
            options.insert(.assumeInside)
        }

        let trackingArea = NSTrackingArea(
            rect: rect,
            options: options,
            owner: self,
            userInfo: [Self.trackingRoleKey: role.rawValue]
        )
        addTrackingArea(trackingArea)
        trackingAreaRefs.append(trackingArea)
    }

    private func trackingRole(from event: NSEvent) -> TrackingRole? {
        guard
            let rawValue = event.trackingArea?.userInfo?[Self.trackingRoleKey] as? String,
            let role = TrackingRole(rawValue: rawValue)
        else {
            return nil
        }
        return role
    }

    private func currentMouseLocationInView() -> NSPoint? {
        guard let window else {
            return nil
        }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return convert(windowPoint, from: nil)
    }

    private func isInteractivePoint(_ point: NSPoint) -> Bool {
        if subtitleBackdropView.frame.contains(point) {
            return true
        }

        if isContainerChromeVisible, containerChromeView.frame.contains(point) {
            return true
        }

        return false
    }

    func containsScreenPointInInteractiveArea(_ screenPoint: NSPoint) -> Bool {
        guard let window else {
            return false
        }

        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let point = convert(windowPoint, from: nil)
        return isInteractivePoint(point)
    }

    func subtitleBackdropFrameInScreen() -> NSRect? {
        guard let window else {
            return nil
        }

        let windowFrame = convert(subtitleBackdropView.frame, to: nil)
        return window.convertToScreen(windowFrame)
    }

    private func resizeEdges(at point: NSPoint) -> ResizeEdges? {
        guard isContainerChromeVisible, containerChromeView.frame.contains(point) else {
            return nil
        }

        let frame = containerChromeView.frame
        var edges: ResizeEdges = []

        if point.x <= frame.minX + Self.resizeEdgeThickness {
            edges.insert(.left)
        } else if point.x >= frame.maxX - Self.resizeEdgeThickness {
            edges.insert(.right)
        }

        if point.y <= frame.minY + Self.resizeEdgeThickness {
            edges.insert(.bottom)
        } else if point.y >= frame.maxY - Self.resizeEdgeThickness {
            edges.insert(.top)
        }

        return edges.isEmpty ? nil : edges
    }

    private func resizeCursorRects() -> [(NSRect, ResizeEdges)] {
        let frame = containerChromeView.frame
        let edge = min(Self.resizeEdgeThickness, frame.width / 2, frame.height / 2)
        guard edge > 0 else {
            return []
        }

        return [
            (NSRect(x: frame.minX, y: frame.maxY - edge, width: edge, height: edge), ResizeEdges([.top, .left])),
            (NSRect(x: frame.maxX - edge, y: frame.maxY - edge, width: edge, height: edge), ResizeEdges([.top, .right])),
            (NSRect(x: frame.minX, y: frame.minY, width: edge, height: edge), ResizeEdges([.bottom, .left])),
            (NSRect(x: frame.maxX - edge, y: frame.minY, width: edge, height: edge), ResizeEdges([.bottom, .right])),
            (NSRect(x: frame.minX + edge, y: frame.maxY - edge, width: frame.width - edge * 2, height: edge), .top),
            (NSRect(x: frame.minX + edge, y: frame.minY, width: frame.width - edge * 2, height: edge), .bottom),
            (NSRect(x: frame.minX, y: frame.minY + edge, width: edge, height: frame.height - edge * 2), .left),
            (NSRect(x: frame.maxX - edge, y: frame.minY + edge, width: edge, height: frame.height - edge * 2), .right)
        ].filter { rect, _ in
            rect.width > 0 && rect.height > 0
        }
    }

    private func performContainerResize(with event: NSEvent, edges: ResizeEdges) {
        guard let window else {
            return
        }

        delegate?.subtitleOverlayViewDidBeginContainerResize(self)

        let initialMouseLocation = NSEvent.mouseLocation
        let initialFrame = window.frame
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? initialFrame

        defer {
            delegate?.subtitleOverlayViewDidEndContainerResize(self)
        }

        while let resizeEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if resizeEvent.type == .leftMouseUp {
                return
            }

            let mouseLocation = NSEvent.mouseLocation
            let delta = NSPoint(
                x: mouseLocation.x - initialMouseLocation.x,
                y: mouseLocation.y - initialMouseLocation.y
            )
            let nextFrame = resizedFrame(
                from: initialFrame,
                delta: delta,
                edges: edges,
                screenFrame: screenFrame
            )
            delegate?.subtitleOverlayView(self, didResizeContainerTo: nextFrame)
        }
    }

    private func resizedFrame(
        from initialFrame: NSRect,
        delta: NSPoint,
        edges: ResizeEdges,
        screenFrame: NSRect
    ) -> NSRect {
        let minimumWidth = min(Self.minimumPanelWidth, screenFrame.width)
        let maximumWidth = min(Self.maximumPanelWidth, screenFrame.width)
        let minimumHeight = min(Self.minimumPanelHeight, screenFrame.height)
        let maximumHeight = screenFrame.height

        var left = initialFrame.minX
        var right = initialFrame.maxX
        var bottom = initialFrame.minY
        var top = initialFrame.maxY

        if edges.contains(.left) {
            let fixedRight = initialFrame.maxX
            let minimumLeft = max(screenFrame.minX, fixedRight - maximumWidth)
            let maximumLeft = fixedRight - minimumWidth
            left = min(max(initialFrame.minX + delta.x, minimumLeft), maximumLeft)
            right = fixedRight
        } else if edges.contains(.right) {
            let fixedLeft = initialFrame.minX
            let minimumRight = fixedLeft + minimumWidth
            let maximumRight = min(screenFrame.maxX, fixedLeft + maximumWidth)
            left = fixedLeft
            right = max(min(initialFrame.maxX + delta.x, maximumRight), minimumRight)
        }

        if edges.contains(.bottom) {
            let fixedTop = initialFrame.maxY
            let minimumBottom = max(screenFrame.minY, fixedTop - maximumHeight)
            let maximumBottom = fixedTop - minimumHeight
            bottom = min(max(initialFrame.minY + delta.y, minimumBottom), maximumBottom)
            top = fixedTop
        } else if edges.contains(.top) {
            let fixedBottom = initialFrame.minY
            let minimumTop = fixedBottom + minimumHeight
            let maximumTop = min(screenFrame.maxY, fixedBottom + maximumHeight)
            bottom = fixedBottom
            top = max(min(initialFrame.maxY + delta.y, maximumTop), minimumTop)
        }

        return NSRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    private func startCaptionAppearanceMonitoring() {
        captionAppearanceMonitor = SystemCaptionAppearanceMonitor { [weak self] in
            self?.applyCaptionAppearance(SystemCaptionAppearance.current())
        }
    }

    private func applyCaptionAppearance(_ appearance: SystemCaptionAppearance) {
        captionAppearance = appearance
        subtitleBackdropView.layer?.backgroundColor = appearance.windowColor.cgColor
        subtitleBackdropView.layer?.cornerRadius = appearance.windowCornerRadius
        updateSubtitleText()
    }

    private func updateSubtitleText() {
        let displayText = subtitleText.isEmpty ? " " : subtitleText
        subtitleLabel.attributedStringValue = NSAttributedString(
            string: displayText,
            attributes: captionAppearance.subtitleAttributes()
        )
        reportDisplayedCaptions()
    }

    private func reportDisplayedCaptions(force: Bool = false) {
        let captionText = isReportingCaptions ? reportableCaptionText() : nil
        guard force || captionText != lastReportedCaptionText else {
            return
        }

        SystemCaptionDisplayReporter.report(displayedText: captionText)
        lastReportedCaptionText = captionText
    }

    private func reportableCaptionText() -> String? {
        let trimmed = subtitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, subtitleText != Self.placeholderText else {
            return nil
        }
        return subtitleText
    }

    private func firstSupportedURL(from pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.first { url in
            ["srt", "vtt", "webvtt"].contains(url.pathExtension.lowercased())
        }
    }

}

private struct SubtitleContainerChromeContentView: View {
    var body: some View {
        GlassEffectContainer {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
        }
        .environment(\.controlActiveState, .active)
    }
}
