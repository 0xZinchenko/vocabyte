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
        MenuBarExtra("Vocabyte", systemImage: "character.book.closed") {
            Button("Open List") {
                openWindow(id: "wordList")
            }
            Button("Settings") {
                // Placeholder — implemented in a later stage.
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
    }
}
