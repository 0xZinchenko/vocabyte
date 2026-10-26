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
        alert.messageText = "Accessibility access needed"
        alert.informativeText = """
        Vocabyte reads the selected text in other apps through the system \
        Accessibility API — that's the only way to save a word with the \
        hotkey. This permission isn't used for anything else.

        You can grant it in System Settings.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

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
