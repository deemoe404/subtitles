import AppKit
import XCTest
@testable import OneMoreCapAppSupport

final class SystemCaptionAppearanceTests: XCTestCase {
    func testColorCombinesSourceAlphaAndOpacity() {
        let source = NSColor(
            calibratedRed: 0.2,
            green: 0.4,
            blue: 0.6,
            alpha: 0.5
        )

        let color = SystemCaptionAppearance.color(
            from: source.cgColor,
            opacity: 0.25,
            fallback: .clear
        )

        XCTAssertEqual(color.alphaComponent(in: .deviceRGB), 0.125, accuracy: 0.001)
    }

    func testRelativeCharacterSizeIsClamped() {
        XCTAssertEqual(
            SystemCaptionAppearance.clampedFontSize(relativeSize: 0.1),
            SystemCaptionAppearance.minimumFontSize
        )
        XCTAssertEqual(
            SystemCaptionAppearance.clampedFontSize(relativeSize: 10),
            SystemCaptionAppearance.maximumFontSize
        )
        XCTAssertEqual(
            SystemCaptionAppearance.clampedFontSize(relativeSize: 1.5),
            54,
            accuracy: 0.001
        )
    }

    func testUniformEdgeStyleAddsStrokeAttributes() {
        let appearance = makeAppearance(textEdgeStyle: .uniform)

        let attributes = appearance.subtitleAttributes()

        XCTAssertEqual(attributes[.strokeWidth] as? CGFloat, -3)
        XCTAssertNotNil(attributes[.strokeColor] as? NSColor)
        XCTAssertNil(attributes[.shadow])
    }

    func testDropShadowEdgeStyleAddsShadowAttribute() {
        let appearance = makeAppearance(textEdgeStyle: .dropShadow)

        let attributes = appearance.subtitleAttributes()

        XCTAssertNotNil(attributes[.shadow] as? NSShadow)
        XCTAssertNil(attributes[.strokeWidth])
    }

    func testNoEdgeStyleDoesNotAddStrokeOrShadowAttributes() {
        let appearance = makeAppearance(textEdgeStyle: .none)

        let attributes = appearance.subtitleAttributes()

        XCTAssertNil(attributes[.shadow])
        XCTAssertNil(attributes[.strokeWidth])
        XCTAssertNil(attributes[.strokeColor])
    }

    func testMediaAccessibilityEdgeStyleMapping() {
        XCTAssertEqual(SystemCaptionTextEdgeStyle(mediaAccessibilityStyle: .raised), .raised)
        XCTAssertEqual(SystemCaptionTextEdgeStyle(mediaAccessibilityStyle: .depressed), .depressed)
        XCTAssertEqual(SystemCaptionTextEdgeStyle(mediaAccessibilityStyle: .uniform), .uniform)
        XCTAssertEqual(SystemCaptionTextEdgeStyle(mediaAccessibilityStyle: .dropShadow), .dropShadow)
        XCTAssertEqual(SystemCaptionTextEdgeStyle(mediaAccessibilityStyle: .none), .none)
        XCTAssertEqual(SystemCaptionTextEdgeStyle(mediaAccessibilityStyle: .undefined), .none)
    }

    private func makeAppearance(textEdgeStyle: SystemCaptionTextEdgeStyle) -> SystemCaptionAppearance {
        SystemCaptionAppearance(
            font: .systemFont(ofSize: 36),
            foregroundColor: .white,
            textBackgroundColor: .black.withAlphaComponent(0.4),
            windowColor: .black.withAlphaComponent(0.5),
            windowCornerRadius: 8,
            textEdgeStyle: textEdgeStyle
        )
    }
}

private extension NSColor {
    func alphaComponent(in colorSpace: NSColorSpace) -> CGFloat {
        usingColorSpace(colorSpace)?.alphaComponent ?? alphaComponent
    }
}
