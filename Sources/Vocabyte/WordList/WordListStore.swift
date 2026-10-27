import Foundation
import GRDB
import os

/// Keeps `words` in sync with the database so the word list window updates
/// itself as new words are captured and background lookups complete, with
/// no manual refresh.
final class WordListStore: ObservableObject {
    @Published var words: [Word] = []

    private let database: DatabaseManager?
    private var cancellable: DatabaseCancellable?
    private let logger = Logger(subsystem: "com.example.Vocabyte", category: "wordList")

    init(database: DatabaseManager? = DatabaseManager.shared) {
        self.database = database
        guard let database else {
            logger.error("Failed to open the database; word list will stay empty.")
            return
        }
        cancellable = database.allWordsObservation().start(
            in: database.dbQueue,
            onError: { [logger] error in
                logger.error("Word list observation failed: \(error.localizedDescription, privacy: .public)")
            },
            onChange: { [weak self] words in
                self?.words = words
            }
        )
    }

    func setLearned(_ word: Word, learned: Bool) {
        guard let id = word.id, let database else { return }
        do {
            try database.setLearned(id: id, learned: learned)
        } catch {
            logger.error("Failed to update learned status: \(error.localizedDescription, privacy: .public)")
        }
    }

    func delete(_ word: Word) {
        guard let id = word.id, let database else { return }
        do {
            try database.deleteWord(id: id)
        } catch {
            logger.error("Failed to delete word: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Corrects a capture mistake (a dropped letter, a stray bracket) by
    /// editing the word's text in place. Invalid edits (empty, too long) are
    /// silently ignored rather than reverting the text field, since this is
    /// a quick inline fix, not a full save flow with its own feedback UI.
    func rename(_ word: Word, to newDisplayWord: String) {
        guard let id = word.id, let database else { return }
        guard case .accepted(let displayWord, let normalizedWord) = WordNormalizer.normalize(newDisplayWord) else {
            return
        }
        guard normalizedWord != word.normalizedWord || displayWord != word.displayWord else {
            return
        }

        do {
            switch try database.renameWord(id: id, displayWord: displayWord, normalizedWord: normalizedWord) {
            case .renamed:
                Task { await WordLookupService.shared.lookup(wordId: id, text: displayWord) }
            case .mergedIntoExisting:
                break // The row this merged into already has its own lookup data.
            }
        } catch {
            logger.error("Failed to rename word: \(error.localizedDescription, privacy: .public)")
        }
    }
}
