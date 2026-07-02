@preconcurrency import AppKit
import CoreText
import MediaAccessibility

public enum SystemCaptionTextEdgeStyle: Equatable {
    case none
    case raised
    case depressed
    case uniform
    case dropShadow

    init(mediaAccessibilityStyle: MACaptionAppearanceTextEdgeStyle) {
        switch mediaAccessibilityStyle {
        case .raised:
            self = .raised
        case .depressed:
            self = .depressed
        case .uniform:
            self = .uniform
        case .dropShadow:
            self = .dropShadow
        case .none, .undefined:
            self = .none
        @unknown default:
            self = .none
        }
    }
}

public struct SystemCaptionAppearance {
    public static let baseFontSize: CGFloat = 36
    public static let minimumFontSize: CGFloat = 18
    public static let maximumFontSize: CGFloat = 96

    public let font: NSFont
    public let foregroundColor: NSColor
    public let textBackgroundColor: NSColor
    public let windowColor: NSColor
    public let windowCornerRadius: CGFloat
    public let textEdgeStyle: SystemCaptionTextEdgeStyle

    public init(
        font: NSFont,
        foregroundColor: NSColor,
        textBackgroundColor: NSColor,
        windowColor: NSColor,
        windowCornerRadius: CGFloat,
        textEdgeStyle: SystemCaptionTextEdgeStyle
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.textBackgroundColor = textBackgroundColor
        self.windowColor = windowColor
        self.windowCornerRadius = windowCornerRadius
        self.textEdgeStyle = textEdgeStyle
    }

    public static func current() -> SystemCaptionAppearance {
        let domain = MACaptionAppearanceDomain.user

        var foregroundBehavior = MACaptionAppearanceBehavior.useValue
        let foregroundColor = color(
            from: MACaptionAppearanceCopyForegroundColor(domain, &foregroundBehavior).takeRetainedValue(),
            opacity: MACaptionAppearanceGetForegroundOpacity(domain, &foregroundBehavior),
            fallback: .white
        )

        var backgroundBehavior = MACaptionAppearanceBehavior.useValue
        let textBackgroundColor = color(
            from: MACaptionAppearanceCopyBackgroundColor(domain, &backgroundBehavior).takeRetainedValue(),
            opacity: MACaptionAppearanceGetBackgroundOpacity(domain, &backgroundBehavior),
            fallback: .clear
        )

        var windowBehavior = MACaptionAppearanceBehavior.useValue
        let windowColor = color(
            from: MACaptionAppearanceCopyWindowColor(domain, &windowBehavior).takeRetainedValue(),
            opacity: MACaptionAppearanceGetWindowOpacity(domain, &windowBehavior),
            fallback: .clear
        )
        let cornerRadius = max(0, MACaptionAppearanceGetWindowRoundedCornerRadius(domain, &windowBehavior))

        var fontBehavior = MACaptionAppearanceBehavior.useValue
        let fontDescriptor = MACaptionAppearanceCopyFontDescriptorForStyle(
            domain,
            &fontBehavior,
            .default
        ).takeRetainedValue()
        let fontSize = clampedFontSize(relativeSize: MACaptionAppearanceGetRelativeCharacterSize(domain, &fontBehavior))
        let font = NSFont(descriptor: fontDescriptor as NSFontDescriptor, size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .semibold)

        var edgeBehavior = MACaptionAppearanceBehavior.useValue
        let edgeStyle = SystemCaptionTextEdgeStyle(
            mediaAccessibilityStyle: MACaptionAppearanceGetTextEdgeStyle(domain, &edgeBehavior)
        )

        return SystemCaptionAppearance(
            font: font,
            foregroundColor: foregroundColor,
            textBackgroundColor: textBackgroundColor,
            windowColor: windowColor,
            windowCornerRadius: cornerRadius,
            textEdgeStyle: edgeStyle
        )
    }

    public func subtitleAttributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foregroundColor,
            .backgroundColor: textBackgroundColor,
            .paragraphStyle: paragraphStyle
        ]

        switch textEdgeStyle {
        case .none:
            break
        case .uniform:
            attributes[.strokeColor] = Self.edgeContrastColor(for: foregroundColor)
            attributes[.strokeWidth] = CGFloat(-3.0)
        case .dropShadow:
            attributes[.shadow] = Self.shadow(color: Self.edgeContrastColor(for: foregroundColor), offset: CGSize(width: 2, height: -2), blur: 3)
        case .raised:
            attributes[.shadow] = Self.shadow(color: .white.withAlphaComponent(0.72), offset: CGSize(width: -1, height: 1), blur: 1)
        case .depressed:
            attributes[.shadow] = Self.shadow(color: .black.withAlphaComponent(0.72), offset: CGSize(width: 1, height: -1), blur: 1)
        }

        return attributes
    }

    static func clampedFontSize(relativeSize: CGFloat) -> CGFloat {
        clamp(baseFontSize * relativeSize, minimumFontSize, maximumFontSize)
    }

    static func color(from cgColor: CGColor, opacity: CGFloat, fallback: NSColor) -> NSColor {
        let alpha = clamp(cgColor.alpha * opacity, 0, 1)
        guard let color = cgColor.copy(alpha: alpha).flatMap(NSColor.init(cgColor:)) else {
            return fallback.withAlphaComponent(alpha)
        }
        return color
    }

    static func edgeContrastColor(for color: NSColor) -> NSColor {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return .black.withAlphaComponent(0.85)
        }
        let brightness = (rgbColor.redComponent * 0.299)
            + (rgbColor.greenComponent * 0.587)
            + (rgbColor.blueComponent * 0.114)
        return brightness > 0.5
            ? .black.withAlphaComponent(0.85)
            : .white.withAlphaComponent(0.85)
    }

    private static func shadow(color: NSColor, offset: CGSize, blur: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowOffset = offset
        shadow.shadowBlurRadius = blur
        return shadow
    }

    private static func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }
}

public final class SystemCaptionAppearanceMonitor {
    private let onChange: () -> Void

    public init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            Self.notificationCallback,
            kMACaptionAppearanceSettingsChangedNotification,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(kMACaptionAppearanceSettingsChangedNotification),
            nil
        )
    }

    private static let notificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
        guard let observer else {
            return
        }
        let monitor = Unmanaged<SystemCaptionAppearanceMonitor>.fromOpaque(observer).takeUnretainedValue()
        DispatchQueue.main.async {
            monitor.onChange()
        }
    }
}

public enum SystemCaptionDisplayReporter {
    public static func report(displayedText: String?) {
        guard let displayedText,
              !displayedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            MACaptionAppearanceDidDisplayCaptions(NSArray() as CFArray)
            return
        }

        MACaptionAppearanceDidDisplayCaptions(NSArray(array: [displayedText]) as CFArray)
    }
}
