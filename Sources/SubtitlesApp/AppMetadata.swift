import Foundation

enum AppMetadata {
    static var displayName: String {
        string(forInfoDictionaryKey: "CFBundleDisplayName")
            ?? string(forInfoDictionaryKey: "CFBundleName")
            ?? "Subtitles"
    }

    static var statusItemTitle: String {
        string(forInfoDictionaryKey: "SUBStatusItemTitle") ?? "Sub"
    }

    private static func string(forInfoDictionaryKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
