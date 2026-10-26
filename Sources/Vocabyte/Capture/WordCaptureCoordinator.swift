import Foundation
import os

/// Runs on every hotkey press: checks the Accessibility permission, captures
/// the current selection, normalizes it, saves it to the database, and shows
/// a brief confirmation panel. Everything is also logged (visible via
/// `log stream --predicate 'subsystem == "com.example.Vocabyte"'`), which is
/// how this was tested before the panel existed.
final class WordCaptureCoordinator {
    static let shared = WordCaptureCoordinator()

    private let logger = Logger(subsystem: "com.example.Vocabyte", category: "capture")
    private let database: DatabaseManager?

    private init() {
        database = try? DatabaseManager.openDefault()
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
            logger.notice("Nothing selected.")
            SaveFeedbackPanel.shared.show(message: "Nothing selected")
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
            case .created:
                logger.notice("Saved new word: \(displayWord, privacy: .public)")
                SaveFeedbackPanel.shared.show(message: "Saved: \(displayWord)")
            case .incremented(let count):
                logger.notice("Repeat save (\(count, privacy: .public)x): \(displayWord, privacy: .public)")
                SaveFeedbackPanel.shared.show(message: "Already saved ×\(count)")
            }
        } catch {
            logger.error("Failed to save word: \(error.localizedDescription, privacy: .public)")
        }
    }
}
