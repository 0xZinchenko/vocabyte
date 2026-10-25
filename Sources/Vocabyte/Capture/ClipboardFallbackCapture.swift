import AppKit

/// Fallback capture method, used only when `AccessibilityCapture` can't find
/// a selection (e.g. apps with incomplete Accessibility support). Sends a
/// real Cmd+C keystroke to whichever app currently has focus, and reads the
/// result from the clipboard — the clipboard's original contents (all
/// types, not just text) are saved beforehand and restored right after,
/// so the user's clipboard ends up unchanged either way.
enum ClipboardFallbackCapture {
    private static let pollInterval: TimeInterval = 0.02
    private static let timeout: TimeInterval = 0.3

    static func captureSelectedText() -> String? {
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount
        let originalItems = snapshot(of: pasteboard)

        sendCopyKeystroke()

        let deadline = Date().addingTimeInterval(timeout)
        while pasteboard.changeCount == originalChangeCount, Date() < deadline {
            Thread.sleep(forTimeInterval: pollInterval)
        }

        let didCopySomething = pasteboard.changeCount != originalChangeCount
        let capturedText = didCopySomething ? pasteboard.string(forType: .string) : nil

        restore(originalItems, to: pasteboard)

        return capturedText
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restoredItems = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }

    private static func sendCopyKeystroke() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyCodeC: CGKeyCode = 0x08 // ANSI 'c'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: false)
        else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
