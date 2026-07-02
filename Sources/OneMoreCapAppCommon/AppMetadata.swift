import Foundation

enum AppMetadata {
    static var displayName: String {
        string(forInfoDictionaryKey: "CFBundleDisplayName")
            ?? string(forInfoDictionaryKey: "CFBundleName")
            ?? "One More Cap"
    }

    static var statusItemTitle: String {
        string(forInfoDictionaryKey: "SUBStatusItemTitle") ?? "Cap"
    }

    private static func string(forInfoDictionaryKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
