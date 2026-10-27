import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @State private var translationLanguage = AppPreferences.translationLanguage

    var body: some View {
        Form {
            Picker("Translation language", selection: $translationLanguage) {
                ForEach(TranslationLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .onChange(of: translationLanguage) { newValue in
                AppPreferences.translationLanguage = newValue
            }

            KeyboardShortcuts.Recorder("Save word hotkey:", name: .saveSelectedWord)
        }
        .padding()
        .frame(width: 360)
    }
}
