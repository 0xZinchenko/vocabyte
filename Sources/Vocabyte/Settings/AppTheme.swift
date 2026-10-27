import SwiftUI

/// Color tokens for the "Minimal Premium" palette: warm light / deep dark,
/// a muted indigo accent, graphite typography. Each resolves automatically
/// to its light/dark variant based on the active `ColorScheme` — forced
/// explicitly by the user's `AppPreferences.colorTheme`, not the system
/// appearance (see `appTheme()` below).
enum AppColor {
    static let background = Color("AppBackground")
    static let surface = Color("AppSurface")
    static let textPrimary = Color("AppTextPrimary")
    static let textSecondary = Color("AppTextSecondary")
    static let accent = Color("AppAccent")
    static let border = Color("AppBorder")
}

/// Forces the view's color scheme to the user's explicit Settings choice
/// instead of following the system appearance, and keeps it live-updated
/// (via `@AppStorage`) across every open window as soon as it's changed.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppPreferences.colorThemeKey) private var colorThemeRaw = ColorTheme.light.rawValue

    func body(content: Content) -> some View {
        content
            .tint(AppColor.accent)
            .preferredColorScheme((ColorTheme(rawValue: colorThemeRaw) ?? .light).colorScheme)
    }
}

extension View {
    func appTheme() -> some View {
        modifier(AppThemeModifier())
    }
}
