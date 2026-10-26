import Foundation
import os

/// Runs the dictionary + translation lookup for a word and records the
/// result. Triggered right after a word is saved, and at app launch for
/// everything still pending/failed — never on a timer, so there's no
/// unbounded automatic retry loop.
final class WordLookupService {
    static let shared = WordLookupService()

    /// Default target language. Not yet configurable — Settings (a later
    /// stage) will let the user pick "ru" or "uk"; this matches the spec's
    /// stated default in the meantime.
    private let translationLanguage = "ru"

    private let dictionaryProvider: DictionaryProvider
    private let translationProvider: TranslationProvider
    private let database: DatabaseManager?
    private let logger = Logger(subsystem: "com.example.Vocabyte", category: "lookup")

    init(
        dictionaryProvider: DictionaryProvider = FreeDictionaryProvider(),
        translationProvider: TranslationProvider = MyMemoryTranslationProvider(),
        database: DatabaseManager? = try? DatabaseManager.openDefault()
    ) {
        self.dictionaryProvider = dictionaryProvider
        self.translationProvider = translationProvider
        self.database = database
    }

    /// Looks up one word and persists the result. Safe to call for a word
    /// that already succeeded (it'll just succeed again), but callers
    /// normally only call this for pending/failed words.
    func lookup(wordId: Int64, text: String) async {
        guard let database else { return }

        // Skip words that already have a successful translation, so a
        // repeat save of the same word doesn't burn through MyMemory's
        // daily quota for nothing.
        if let existing = try? database.word(withId: wordId), existing.lookupStatus == .success {
            return
        }

        async let dictionaryTask: DictionaryLookupResult? = try? dictionaryProvider.lookup(word: text)

        let translation: String?
        do {
            translation = try await translationProvider.translate(text, to: translationLanguage)
        } catch {
            logger.notice("Translation failed for \"\(text, privacy: .public)\": \(error.localizedDescription, privacy: .public)")
            translation = nil
        }

        let dictionary = await dictionaryTask
        let succeeded = translation != nil

        do {
            try database.recordLookupResult(
                wordId: wordId,
                phonetic: dictionary?.phonetic,
                partOfSpeech: dictionary?.partOfSpeech,
                translation: translation,
                translationLang: succeeded ? translationLanguage : nil,
                succeeded: succeeded
            )
            logger.notice("Lookup \(succeeded ? "succeeded" : "failed", privacy: .public) for \"\(text, privacy: .public)\"")
        } catch {
            logger.error("Failed to persist lookup result: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Retries every word that doesn't have a successful translation yet.
    /// Called at app launch; a later stage will also expose this as a
    /// manual "Refresh" button once the word list UI exists.
    func refreshPending() async {
        guard let database else { return }

        let pending: [Word]
        do {
            pending = try database.wordsNeedingLookup()
        } catch {
            logger.error("Failed to fetch words needing lookup: \(error.localizedDescription, privacy: .public)")
            return
        }

        for word in pending {
            guard let id = word.id else { continue }
            await lookup(wordId: id, text: word.displayWord)
        }
    }
}
