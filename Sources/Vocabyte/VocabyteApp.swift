import KeyboardShortcuts
import SwiftUI

@main
struct VocabyteApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
        KeyboardShortcuts.onKeyUp(for: .saveSelectedWord) {
            WordCaptureCoordinator.shared.handleHotkeyPress()
        }
        Task { await WordLookupService.shared.refreshPending() }
    }

    var body: some Scene {
        MenuBarExtra("Vocabyte", image: "MenuBarIcon") {
            Button("Open List") {
                openAndActivate(windowId: "wordList", title: "Word List")
            }
            Button("Settings") {
                openAndActivate(windowId: "settings", title: "Settings")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Window("Word List", id: "wordList") {
            WordListView()
                .appTheme()
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
    }

    /// `openWindow` alone can leave the window behind other apps: as an
    /// accessory app (no Dock icon), Vocabyte isn't automatically activated
    /// just by opening a window, and if the window was already open,
    /// `openWindow` doesn't raise it either. Activating the app and
    /// explicitly bringing the matching window to the front covers both
    /// the "window already open" and "newly created window" cases.
    private func openAndActivate(windowId: String, title: String) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: windowId)
        NSApp.windows.first(where: { $0.title == title })?.makeKeyAndOrderFront(nil)
    }
}
