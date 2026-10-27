import Foundation
import os

/// Runs the dictionary + translation lookup for a word and records the
/// result. Triggered right after a word is saved, and at app launch for
/// everything still pending/failed — never on a timer, so there's no
/// unbounded automatic retry loop.
final class WordLookupService {
    static let shared = WordLookupService()

    /// Read fresh on every lookup (not cached at init) so a change made in
    /// Settings while the app is running takes effect immediately.
    private var translationLanguage: String { AppPreferences.translationLanguage.rawValue }

    private let dictionaryProvider: DictionaryProvider
    private let translationProvider: TranslationProvider
    private let database: DatabaseManager?
    private let logger = Logger(subsystem: "com.example.Vocabyte", category: "lookup")

    init(
        dictionaryProvider: DictionaryProvider = FreeDictionaryProvider(),
        translationProvider: TranslationProvider = MyMemoryTranslationProvider(),
        database: DatabaseManager? = DatabaseManager.shared
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

        let targetLanguage = translationLanguage
        let translation: String?
        do {
            translation = try await translationProvider.translate(text, to: targetLanguage)
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
                translationLang: succeeded ? targetLanguage : nil,
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
