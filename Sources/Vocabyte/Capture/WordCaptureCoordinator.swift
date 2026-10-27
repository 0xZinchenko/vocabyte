import AppKit
import Foundation
import os

/// Runs on every hotkey press: checks the Accessibility permission, captures
/// the current selection, normalizes it, saves it to the database, and shows
/// a brief confirmation panel. Everything is also logged (visible via
/// `log stream --predicate 'subsystem == "com.example.Vocabyte"'`), which is
/// how this was tested before the panel existed.
final class WordCaptureCoordinator {
    static let shared = WordCaptureCoordinator()

    /// Terminal emulators are a known case where capture never works: their
    /// content is custom-rendered, not a standard text view, so
    /// Accessibility can't read a selection, and (at least for Terminal.app)
    /// "Secure Keyboard Entry", when enabled, blocks the synthetic Cmd+C the
    /// clipboard fallback relies on. Rather than chase a fix for what's
    /// often a macOS security feature working as intended, this is called
    /// out with its own message instead of the generic "Nothing selected" —
    /// which would otherwise wrongly suggest the user just didn't select
    /// anything.
    ///
    /// There's no API to ask "is this app a terminal emulator" — this is a
    /// manually maintained list of the common ones, not exhaustive. An
    /// unlisted terminal will fall back to the generic "Nothing selected"
    /// message.
    private static let unsupportedAppBundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
    ]

    private let logger = Logger(subsystem: "com.example.Vocabyte", category: "capture")
    private let database: DatabaseManager?

    private init() {
        database = DatabaseManager.shared
        if database == nil {
            logger.error("Failed to open the database; captured words won't be saved.")
        }
    }

    /// Called from the global hotkey handler, which KeyboardShortcuts
    /// already invokes on the main thread — required here since this
    /// touches the feedback panel (an NSPanel).
    func handleHotkeyPress() {
        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.explainAndOfferSettingsIfNeeded()
            return
        }

        guard let captured = SelectionCaptureService.captureSelection() else {
            if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               Self.unsupportedAppBundleIdentifiers.contains(bundleId)
            {
                logger.notice("Word capture isn't supported in this app (\(bundleId, privacy: .public)).")
                SaveFeedbackPanel.shared.show(message: "Not supported in terminal apps")
            } else {
                logger.notice("Nothing selected.")
                SaveFeedbackPanel.shared.show(message: "Nothing selected")
            }
            return
        }

        switch WordNormalizer.normalize(captured.text) {
        case .empty:
            logger.notice("Selection was empty after trimming; nothing to save.")
            SaveFeedbackPanel.shared.show(message: "Nothing selected")
        case .tooMuchText:
            logger.notice("Selection rejected: too much text.")
            SaveFeedbackPanel.shared.show(message: "Too much text, not saved")
        case .accepted(let displayWord, let normalizedWord):
            save(displayWord: displayWord, normalizedWord: normalizedWord, sentence: captured.sentence)
        }
    }

    private func save(displayWord: String, normalizedWord: String, sentence: String) {
        guard let database else { return }
        do {
            let result = try database.saveWord(
                displayWord: displayWord,
                normalizedWord: normalizedWord,
                sentence: sentence.isEmpty ? nil : sentence
            )
            switch result {
            case .created(let id):
                logger.notice("Saved new word: \(displayWord, privacy: .public)")
                SaveFeedbackPanel.shared.show(message: "Saved: \(displayWord)")
                Task { await WordLookupService.shared.lookup(wordId: id, text: displayWord) }
            case .incremented(let id, let count):
                logger.notice("Repeat save (\(count, privacy: .public)x): \(displayWord, privacy: .public)")
                SaveFeedbackPanel.shared.show(message: "Already saved ×\(count)")
                Task { await WordLookupService.shared.lookup(wordId: id, text: displayWord) }
            }
        } catch {
            logger.error("Failed to save word: \(error.localizedDescription, privacy: .public)")
        }
    }
}
