import SwiftUI

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case ukrainian = "uk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .russian: return "Russian"
        case .ukrainian: return "Ukrainian"
        }
    }
}

/// The app's appearance is always one of these two, chosen explicitly by
/// the user in Settings — it does not follow the system's light/dark mode.
enum ColorTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

/// User-configurable settings, persisted via `UserDefaults` — there's no
/// need for anything heavier for a couple of simple preference values.
enum AppPreferences {
    private static let translationLanguageKey = "translationLanguage"
    static let colorThemeKey = "colorTheme"

    static var translationLanguage: TranslationLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: translationLanguageKey),
                  let language = TranslationLanguage(rawValue: raw)
            else {
                return .russian
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: translationLanguageKey)
        }
    }

    static var colorTheme: ColorTheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: colorThemeKey),
                  let theme = ColorTheme(rawValue: raw)
            else {
                return .light
            }
            return theme
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: colorThemeKey)
        }
    }
}
