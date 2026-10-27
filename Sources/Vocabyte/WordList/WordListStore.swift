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
}
