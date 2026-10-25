import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows a dialog explaining why Vocabyte needs Accessibility access,
    /// with a button to jump straight to the right System Settings pane.
    /// Does nothing (and returns `true`) if the permission is already granted.
    @discardableResult
    static func explainAndOfferSettingsIfNeeded() -> Bool {
        guard !isGranted else { return true }

        let alert = NSAlert()
        alert.messageText = "Нужен доступ к Accessibility"
        alert.informativeText = """
        Vocabyte читает выделенный текст в других приложениях через системный \
        Accessibility API — только так можно сохранить слово по горячей клавише. \
        Больше это разрешение ни для чего не используется.

        Выдать его можно в Системных настройках.
        """
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Отмена")

        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings()
        }
        return false
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
