import Foundation
import GRDB

/// Whether a background lookup (dictionary/translation) still needs to run for a word.
enum LookupStatus: String, Codable, DatabaseValueConvertible {
    case pending
    case success
    case failed
}

struct Word: Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "word"

    var id: Int64?
    var normalizedWord: String
    var displayWord: String
    var phonetic: String?
    var partOfSpeech: String?
    var translation: String?
    var translationLang: String?
    var sentence: String?
    var count: Int
    var learned: Bool
    var lookupStatus: LookupStatus
    var createdAt: Date
    var updatedAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
