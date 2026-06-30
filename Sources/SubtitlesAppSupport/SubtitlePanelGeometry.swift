import CoreGraphics

public enum SubtitlePanelGeometry {
    public struct ResizeEdges: OptionSet, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let left = ResizeEdges(rawValue: 1 << 0)
        public static let right = ResizeEdges(rawValue: 1 << 1)
        public static let top = ResizeEdges(rawValue: 1 << 2)
        public static let bottom = ResizeEdges(rawValue: 1 << 3)
    }

    public static let chromeInset: CGFloat = 12
    public static let resizeEdgeThickness: CGFloat = 12
    public static let minimumWidth: CGFloat = 420
    public static let maximumWidth: CGFloat = 1400
    public static let minimumHeight: CGFloat = 96

    public static func containerRect(in bounds: CGRect) -> CGRect {
        let inset = min(chromeInset, bounds.width / 2, bounds.height / 2)
        return bounds.insetBy(dx: inset, dy: inset)
    }

    public static func resizeEdges(
        at point: CGPoint,
        in containerRect: CGRect,
        isChromeVisible: Bool
    ) -> ResizeEdges? {
        guard isChromeVisible, containerRect.containsInclusively(point) else {
            return nil
        }

        var edges: ResizeEdges = []

        if point.x <= containerRect.minX + resizeEdgeThickness {
            edges.insert(.left)
        } else if point.x >= containerRect.maxX - resizeEdgeThickness {
            edges.insert(.right)
        }

        if point.y <= containerRect.minY + resizeEdgeThickness {
            edges.insert(.bottom)
        } else if point.y >= containerRect.maxY - resizeEdgeThickness {
            edges.insert(.top)
        }

        return edges.isEmpty ? nil : edges
    }

    public static func resizeCursorRects(in containerRect: CGRect) -> [(CGRect, ResizeEdges)] {
        let edge = min(resizeEdgeThickness, containerRect.width / 2, containerRect.height / 2)
        guard edge > 0 else {
            return []
        }

        return [
            (CGRect(x: containerRect.minX, y: containerRect.maxY - edge, width: edge, height: edge), ResizeEdges([.top, .left])),
            (CGRect(x: containerRect.maxX - edge, y: containerRect.maxY - edge, width: edge, height: edge), ResizeEdges([.top, .right])),
            (CGRect(x: containerRect.minX, y: containerRect.minY, width: edge, height: edge), ResizeEdges([.bottom, .left])),
            (CGRect(x: containerRect.maxX - edge, y: containerRect.minY, width: edge, height: edge), ResizeEdges([.bottom, .right])),
            (CGRect(x: containerRect.minX + edge, y: containerRect.maxY - edge, width: containerRect.width - edge * 2, height: edge), .top),
            (CGRect(x: containerRect.minX + edge, y: containerRect.minY, width: containerRect.width - edge * 2, height: edge), .bottom),
            (CGRect(x: containerRect.minX, y: containerRect.minY + edge, width: edge, height: containerRect.height - edge * 2), .left),
            (CGRect(x: containerRect.maxX - edge, y: containerRect.minY + edge, width: edge, height: containerRect.height - edge * 2), .right)
        ].filter { rect, _ in
            rect.width > 0 && rect.height > 0
        }
    }

    public static func resizedFrame(
        initialFrame: CGRect,
        initialMouseLocation: CGPoint,
        currentMouseLocation: CGPoint,
        edges: ResizeEdges,
        screenFrame: CGRect
    ) -> CGRect {
        let delta = CGPoint(
            x: currentMouseLocation.x - initialMouseLocation.x,
            y: currentMouseLocation.y - initialMouseLocation.y
        )
        let minimumWidth = min(Self.minimumWidth, screenFrame.width)
        let maximumWidth = min(max(Self.maximumWidth, minimumWidth), screenFrame.width)
        let minimumHeight = min(Self.minimumHeight, screenFrame.height)
        let maximumHeight = screenFrame.height

        var left = initialFrame.minX
        var right = initialFrame.maxX
        var bottom = initialFrame.minY
        var top = initialFrame.maxY

        if edges.contains(.left) {
            let fixedRight = initialFrame.maxX
            let minimumLeft = max(screenFrame.minX, fixedRight - maximumWidth)
            let maximumLeft = fixedRight - minimumWidth
            left = clampLowerResizeEdge(initialFrame.minX + delta.x, minimumLeft, maximumLeft)
            right = fixedRight
        } else if edges.contains(.right) {
            let fixedLeft = initialFrame.minX
            let minimumRight = fixedLeft + minimumWidth
            let maximumRight = min(screenFrame.maxX, fixedLeft + maximumWidth)
            left = fixedLeft
            right = clampUpperResizeEdge(initialFrame.maxX + delta.x, minimumRight, maximumRight)
        }

        if edges.contains(.bottom) {
            let fixedTop = initialFrame.maxY
            let minimumBottom = max(screenFrame.minY, fixedTop - maximumHeight)
            let maximumBottom = fixedTop - minimumHeight
            bottom = clampLowerResizeEdge(initialFrame.minY + delta.y, minimumBottom, maximumBottom)
            top = fixedTop
        } else if edges.contains(.top) {
            let fixedBottom = initialFrame.minY
            let minimumTop = fixedBottom + minimumHeight
            let maximumTop = min(screenFrame.maxY, fixedBottom + maximumHeight)
            bottom = fixedBottom
            top = clampUpperResizeEdge(initialFrame.maxY + delta.y, minimumTop, maximumTop)
        }

        return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    public static func clampedFrame(_ frame: CGRect, to screenFrame: CGRect) -> CGRect {
        let width = min(max(frame.width, min(Self.minimumWidth, screenFrame.width)), min(Self.maximumWidth, screenFrame.width))
        let height = min(max(frame.height, min(Self.minimumHeight, screenFrame.height)), screenFrame.height)
        let x = clamp(frame.minX, screenFrame.minX, screenFrame.maxX - width)
        let y = clamp(frame.minY, screenFrame.minY, screenFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }

    private static func clampLowerResizeEdge(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return upperBound
        }
        return clamp(value, lowerBound, upperBound)
    }

    private static func clampUpperResizeEdge(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return lowerBound
        }
        return clamp(value, lowerBound, upperBound)
    }
}

private extension CGRect {
    func containsInclusively(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}
