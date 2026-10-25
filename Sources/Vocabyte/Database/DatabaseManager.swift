import Foundation
import GRDB

/// Outcome of saving a word, so callers (e.g. the save confirmation panel)
/// know whether this was a brand new word or a repeat.
enum SaveResult: Equatable {
    case created
    case incremented(count: Int)
}

final class DatabaseManager {
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
                return .incremented(count: existing.count)
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
            return .created
        }
    }
}
