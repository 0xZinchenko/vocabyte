import Foundation

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

/// User-configurable settings, persisted via `UserDefaults` — there's no
/// need for anything heavier for a couple of simple preference values.
enum AppPreferences {
    private static let translationLanguageKey = "translationLanguage"

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
}
