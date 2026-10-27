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
                openWindow(id: "wordList")
            }
            Button("Settings") {
                openWindow(id: "settings")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Window("Word List", id: "wordList") {
            WordListView()
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
    }
}
