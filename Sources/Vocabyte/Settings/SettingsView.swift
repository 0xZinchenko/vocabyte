import KeyboardShortcuts
import SwiftUI

/// A single labeled row inside the settings card — a thin divider between
/// rows (not individual boxes) keeps the "thin borders, minimal shadows"
/// look from feeling busy.
private struct SettingsRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            content
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

struct SettingsView: View {
    @AppStorage(AppPreferences.colorThemeKey) private var colorThemeRaw = ColorTheme.light.rawValue
    @State private var translationLanguage = AppPreferences.translationLanguage
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    private var colorTheme: Binding<ColorTheme> {
        Binding(
            get: { ColorTheme(rawValue: colorThemeRaw) ?? .light },
            set: { colorThemeRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 0) {
                SettingsRow(title: "Appearance") {
                    Picker("", selection: colorTheme) {
                        ForEach(ColorTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                Divider().overlay(AppColor.border)

                SettingsRow(title: "Translation language") {
                    Picker("", selection: $translationLanguage) {
                        ForEach(TranslationLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .onChange(of: translationLanguage) { newValue in
                        AppPreferences.translationLanguage = newValue
                    }
                }

                Divider().overlay(AppColor.border)

                SettingsRow(title: "Save word hotkey") {
                    KeyboardShortcuts.Recorder("", name: .saveSelectedWord)
                }

                Divider().overlay(AppColor.border)

                SettingsRow(title: "Launch at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { newValue in
                            do {
                                try LaunchAtLogin.setEnabled(newValue)
                            } catch {
                                launchAtLoginError = error.localizedDescription
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                        }
                }
            }
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .frame(width: 380)
        .background(AppColor.background)
        .appTheme()
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
