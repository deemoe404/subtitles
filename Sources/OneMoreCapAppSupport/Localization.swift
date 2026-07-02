import Foundation

public enum L10n {
    public enum Language: String, CaseIterable, Sendable {
        case automatic = "auto"
        case english = "en"
        case simplifiedChinese = "zh-Hans"

        var resourceIdentifier: String? {
            switch self {
            case .automatic:
                nil
            case .english:
                "en"
            case .simplifiedChinese:
                "zh-Hans"
            }
        }

        var localeIdentifier: String? {
            resourceIdentifier
        }

        public var menuTitle: String {
            switch self {
            case .automatic:
                L10n.string("menu.language.auto", value: "Auto")
            case .english:
                L10n.string("menu.language.english", value: "English")
            case .simplifiedChinese:
                L10n.string("menu.language.simplified_chinese", value: "简体中文")
            }
        }
    }

    public static let languageDidChangeNotification = Notification.Name("OneMoreCapLanguageDidChange")

    private static let languageDefaultsKey = "appLanguageOverride"

    public static var languageSelection: Language {
        guard let rawValue = UserDefaults.standard.string(forKey: languageDefaultsKey),
              let language = Language(rawValue: rawValue) else {
            return .automatic
        }
        return language
    }

    public static func setLanguageSelection(_ language: Language) {
        guard language != languageSelection else {
            return
        }

        switch language {
        case .automatic:
            UserDefaults.standard.removeObject(forKey: languageDefaultsKey)
        case .english, .simplifiedChinese:
            UserDefaults.standard.set(language.rawValue, forKey: languageDefaultsKey)
        }

        NotificationCenter.default.post(name: languageDidChangeNotification, object: nil)
    }

    public static func string(_ key: String, value: String) -> String {
        localizedBundle().localizedString(forKey: key, value: value, table: nil)
    }

    public static func format(_ key: String, value: String, _ arguments: CVarArg...) -> String {
        let format = string(key, value: value)
        return String(format: format, locale: formatLocale(), arguments: arguments)
    }

    private static func localizedBundle() -> Bundle {
        guard let resourceIdentifier = languageSelection.resourceIdentifier,
              let path = Bundle.main.path(forResource: resourceIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }

    private static func formatLocale() -> Locale {
        guard let localeIdentifier = languageSelection.localeIdentifier else {
            return .current
        }

        return Locale(identifier: localeIdentifier)
    }
}
