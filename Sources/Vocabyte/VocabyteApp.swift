import KeyboardShortcuts
import SwiftUI

@main
struct VocabyteApp: App {
    init() {
        KeyboardShortcuts.onKeyUp(for: .saveSelectedWord) {
            WordCaptureCoordinator.shared.handleHotkeyPress()
        }
    }

    var body: some Scene {
        MenuBarExtra("Vocabyte", systemImage: "character.book.closed") {
            Button("Открыть список") {
                // Placeholder — implemented in a later stage.
            }
            Button("Настройки") {
                // Placeholder — implemented in a later stage.
            }
            Divider()
            Button("Выйти") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
