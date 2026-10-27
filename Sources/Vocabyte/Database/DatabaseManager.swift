import Foundation
import GRDB

/// Outcome of saving a word, so callers (e.g. the save confirmation panel)
/// know whether this was a brand new word or a repeat. `id` lets the caller
/// kick off a background dictionary/translation lookup for this row.
enum SaveResult: Equatable {
    case created(id: Int64)
    case incremented(id: Int64, count: Int)
}

final class DatabaseManager {
    /// The single connection to the on-disk database, shared by every part
    /// of the app. Using one shared `DatabaseQueue` (rather than each
    /// component opening its own) is required for `allWordsObservation()`
    /// to see writes made elsewhere: GRDB only notifies a `ValueObservation`
    /// about changes committed through the same connection it's observing.
    static let shared = try? DatabaseManager.openDefault()

    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try Self.migrator.migrate(dbQueue)
    }

    /// Opens (creating if needed) the real on-disk database used by the app.
    static func openDefault() throws -> DatabaseManager {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("Vocabyte", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbURL = directory.appendingPathComponent("words.sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        return try DatabaseManager(dbQueue: dbQueue)
    }

    /// An in-memory database, used by tests so they never touch disk.
    static func openInMemory() throws -> DatabaseManager {
        try DatabaseManager(dbQueue: DatabaseQueue())
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_createWordTable") { db in
            try db.create(table: "word") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("normalizedWord", .text).notNull().unique()
                t.column("displayWord", .text).notNull()
                t.column("phonetic", .text)
                t.column("partOfSpeech", .text)
                t.column("translation", .text)
                t.column("translationLang", .text)
                t.column("sentence", .text)
                t.column("count", .integer).notNull().defaults(to: 1)
                t.column("learned", .boolean).notNull().defaults(to: false)
                // Spelled out literally, not via LookupStatus.pending.rawValue:
                // this migration must keep producing the same schema forever,
                // even if the enum is later renamed.
                t.column("lookupStatus", .text).notNull().defaults(to: "pending")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }
        return migrator
    }

    /// Saves a normalized word, deduplicating by `normalizedWord`: a repeat
    /// bumps `count` and `updatedAt` instead of creating a new row. If the
    /// word was saved before without a sentence and one is available now,
    /// it's filled in — but an existing sentence is never overwritten.
    @discardableResult
    func saveWord(displayWord: String, normalizedWord: String, sentence: String?) throws -> SaveResult {
        let now = Date()
        return try dbQueue.write { db in
            if var existing = try Word
                .filter(Column("normalizedWord") == normalizedWord)
                .fetchOne(db)
            {
                existing.count += 1
                existing.updatedAt = now
                if existing.sentence == nil || existing.sentence?.isEmpty == true {
                    existing.sentence = sentence
                }
                try existing.update(db)
                return .incremented(id: existing.id!, count: existing.count)
            }

            var word = Word(
                id: nil,
                normalizedWord: normalizedWord,
                displayWord: displayWord,
                phonetic: nil,
                partOfSpeech: nil,
                translation: nil,
                translationLang: nil,
                sentence: sentence,
                count: 1,
                learned: false,
                lookupStatus: .pending,
                createdAt: now,
                updatedAt: now
            )
            try word.insert(db)
            return .created(id: word.id!)
        }
    }

    func word(withId id: Int64) throws -> Word? {
        try dbQueue.read { db in
            try Word.filter(Column("id") == id).fetchOne(db)
        }
    }

    /// All saved words, newest-captured first (by `createdAt`, not
    /// `updatedAt`) — so a word's position in this default order stays put
    /// when it's edited, re-translated, or its repeat count changes; only
    /// capturing it for the first time changes where it sits. The word list
    /// UI re-sorts and filters this in memory rather than via separate
    /// queries, since a personal vocabulary is small enough that there's no
    /// need to push that work down to SQLite.
    func allWords() throws -> [Word] {
        try dbQueue.read { db in
            try Word.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    /// A live-updating observation of `allWords()`, used by the word list
    /// window so it reflects new captures and background lookup results
    /// without a manual refresh.
    func allWordsObservation() -> ValueObservation<ValueReducers.Fetch<[Word]>> {
        ValueObservation.tracking { db in
            try Word.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func setLearned(id: Int64, learned: Bool) throws {
        try dbQueue.write { db in
            guard var word = try Word.filter(Column("id") == id).fetchOne(db) else { return }
            word.learned = learned
            word.updatedAt = Date()
            try word.update(db)
        }
    }

    func deleteWord(id: Int64) throws {
        _ = try dbQueue.write { db in
            try Word.deleteOne(db, key: id)
        }
    }

    enum RenameResult: Equatable {
        /// The word's text changed; dictionary/translation data was reset
        /// and a fresh lookup for `id` is needed.
        case renamed
        /// The corrected text matches a word that was already saved under a
        /// different row — the edited row was merged into it (count summed,
        /// sentence backfilled if missing) and deleted. No new lookup is
        /// needed: `existingId` already has its own lookup data.
        case mergedIntoExisting(existingId: Int64)
    }

    /// Corrects a saved word's text — used by the word list UI to fix a
    /// capture mistake (a dropped letter, a stray trailing bracket) without
    /// deleting and re-saving the word.
    func renameWord(id: Int64, displayWord: String, normalizedWord: String) throws -> RenameResult {
        try dbQueue.write { db in
            guard var word = try Word.filter(Column("id") == id).fetchOne(db) else {
                return .renamed
            }

            // A casing-only correction doesn't change what the word *is* —
            // keep the dictionary/translation data already found for it.
            if normalizedWord == word.normalizedWord {
                word.displayWord = displayWord
                word.updatedAt = Date()
                try word.update(db)
                return .renamed
            }

            if var existing = try Word
                .filter(Column("normalizedWord") == normalizedWord && Column("id") != id)
                .fetchOne(db)
            {
                existing.count += word.count
                existing.updatedAt = Date()
                if (existing.sentence?.isEmpty ?? true), let sentence = word.sentence, !sentence.isEmpty {
                    existing.sentence = sentence
                }
                try existing.update(db)
                try Word.deleteOne(db, key: id)
                return .mergedIntoExisting(existingId: existing.id!)
            }

            word.displayWord = displayWord
            word.normalizedWord = normalizedWord
            word.phonetic = nil
            word.partOfSpeech = nil
            word.translation = nil
            word.translationLang = nil
            word.lookupStatus = .pending
            word.updatedAt = Date()
            try word.update(db)
            return .renamed
        }
    }

    /// Words whose translation hasn't been fetched successfully yet —
    /// `pending` (never tried) or `failed` (tried and hit a network/API
    /// error). Dictionary data (phonetic/part of speech) is best-effort and
    /// doesn't affect this list; see `recordLookupResult`.
    func wordsNeedingLookup() throws -> [Word] {
        try dbQueue.read { db in
            try Word.filter(Column("lookupStatus") != LookupStatus.success).fetchAll(db)
        }
    }

    /// Records the outcome of a dictionary/translation lookup attempt.
    ///
    /// `phonetic`/`partOfSpeech` are only written when non-nil, so a retry
    /// that fails to find dictionary data again doesn't erase data a
    /// previous attempt already found. `translation` is only written when
    /// `succeeded` is true, for the same reason — a failed retry never
    /// erases a translation obtained earlier (which normally can't happen
    /// anyway, since a word with a translation already has
    /// `lookupStatus == .success` and isn't retried, but this keeps the
    /// method safe to call either way).
    func recordLookupResult(
        wordId: Int64,
        phonetic: String?,
        partOfSpeech: String?,
        translation: String?,
        translationLang: String?,
        succeeded: Bool
    ) throws {
        try dbQueue.write { db in
            guard var word = try Word.filter(Column("id") == wordId).fetchOne(db) else {
                return
            }
            if let phonetic {
                word.phonetic = phonetic
            }
            if let partOfSpeech {
                word.partOfSpeech = partOfSpeech
            }
            if succeeded {
                if let translation {
                    word.translation = translation
                }
                word.translationLang = translationLang
            }
            word.lookupStatus = succeeded ? .success : .failed
            word.updatedAt = Date()
            try word.update(db)
        }
    }
}
