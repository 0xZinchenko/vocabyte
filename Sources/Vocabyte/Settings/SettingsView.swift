import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @State private var translationLanguage = AppPreferences.translationLanguage
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

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

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        try LaunchAtLogin.setEnabled(newValue)
                    } catch {
                        launchAtLoginError = error.localizedDescription
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
        }
        .padding()
        .frame(width: 360)
        .alert("Couldn't change login item", isPresented: Binding(
            get: { launchAtLoginError != nil },
            set: { if !$0 { launchAtLoginError = nil } }
        )) {
            Button("OK") { launchAtLoginError = nil }
        } message: {
            Text(launchAtLoginError ?? "")
        }
    }
}
