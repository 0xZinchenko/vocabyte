import Foundation
import os

/// Runs on every hotkey press: checks the Accessibility permission, captures
/// the current selection, normalizes it, and saves it to the database.
///
/// There's no visible feedback yet (that's the "save confirmation panel"
/// stage) — results are only logged, visible in Console.app under the
/// subsystem below, or by querying the database directly.
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

    func handleHotkeyPress() {
        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.explainAndOfferSettingsIfNeeded()
            return
        }

        guard let captured = SelectionCaptureService.captureSelection() else {
            logger.notice("Nothing selected.")
            return
        }

        switch WordNormalizer.normalize(captured.text) {
        case .empty:
            logger.notice("Selection was empty after trimming; nothing to save.")
        case .tooMuchText:
            logger.notice("Selection rejected: too much text.")
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
            case .incremented(let count):
                logger.notice("Repeat save (\(count, privacy: .public)x): \(displayWord, privacy: .public)")
            }
        } catch {
            logger.error("Failed to save word: \(error.localizedDescription, privacy: .public)")
        }
    }
}
