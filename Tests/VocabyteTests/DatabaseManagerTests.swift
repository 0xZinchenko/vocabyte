import XCTest
import GRDB
@testable import Vocabyte

final class DatabaseManagerTests: XCTestCase {
    func testSavingNewWordCreatesRowWithCountOne() throws {
        let db = try DatabaseManager.openInMemory()

        let result = try db.saveWord(displayWord: "Apple", normalizedWord: "apple", sentence: nil)

        XCTAssertEqual(result, .created)
        let word = try db.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchOne($0) }
        XCTAssertEqual(word?.count, 1)
        XCTAssertEqual(word?.displayWord, "Apple")
        XCTAssertEqual(word?.lookupStatus, .pending)
    }

    func testSavingSameNormalizedWordIncrementsCount() throws {
        let db = try DatabaseManager.openInMemory()

        _ = try db.saveWord(displayWord: "Apple", normalizedWord: "apple", sentence: nil)
        let second = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)
        let third = try db.saveWord(displayWord: "APPLE", normalizedWord: "apple", sentence: nil)

        XCTAssertEqual(second, .incremented(count: 2))
        XCTAssertEqual(third, .incremented(count: 3))

        let rows = try db.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchAll($0) }
        XCTAssertEqual(rows.count, 1, "a repeat must update the existing row, not insert a new one")
        XCTAssertEqual(rows.first?.count, 3)
    }

    func testRepeatUpdatesTimestampButKeepsOriginalDisplayWord() throws {
        let db = try DatabaseManager.openInMemory()

        _ = try db.saveWord(displayWord: "Apple", normalizedWord: "apple", sentence: nil)
        let firstUpdatedAt = try db.dbQueue.read {
            try Word.filter(Column("normalizedWord") == "apple").fetchOne($0)!.updatedAt
        }

        Thread.sleep(forTimeInterval: 0.01)
        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)

        let word = try db.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchOne($0)! }
        XCTAssertGreaterThan(word.updatedAt, firstUpdatedAt)
        XCTAssertEqual(word.displayWord, "Apple", "the first saved casing is kept; it's not overwritten by later repeats")
    }

    func testDifferentWordsCreateSeparateRows() throws {
        let db = try DatabaseManager.openInMemory()

        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)
        _ = try db.saveWord(displayWord: "banana", normalizedWord: "banana", sentence: nil)

        let rows = try db.dbQueue.read { try Word.fetchAll($0) }
        XCTAssertEqual(rows.count, 2)
    }

    // MARK: - Regressions found in review

    func testInsertedWordGetsAnAssignedId() throws {
        // Regression: Word previously conformed to PersistableRecord, whose
        // own non-mutating didInsert default silently shadowed our mutating
        // one, so `id` stayed nil after insert.
        let db = try DatabaseManager.openInMemory()

        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)

        let word = try db.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchOne($0)! }
        XCTAssertNotNil(word.id)
    }

    func testRepeatBackfillsMissingSentence() throws {
        let db = try DatabaseManager.openInMemory()

        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)
        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: "I ate an apple.")

        let word = try db.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchOne($0)! }
        XCTAssertEqual(word.sentence, "I ate an apple.")
    }

    func testRepeatDoesNotOverwriteExistingSentence() throws {
        let db = try DatabaseManager.openInMemory()

        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: "First sentence.")
        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: "Second sentence.")

        let word = try db.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchOne($0)! }
        XCTAssertEqual(word.sentence, "First sentence.")
    }

    func testOnDiskDatabasePersistsDataAcrossReopening() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let dbPath = tempDirectory.appendingPathComponent("words.sqlite").path

        do {
            let db = try DatabaseManager(dbQueue: try DatabaseQueue(path: dbPath))
            _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)
        }

        // Reopening must re-run the migrator without failing (it should see
        // "v1_createWordTable" already applied) and the row must still be there.
        let reopened = try DatabaseManager(dbQueue: try DatabaseQueue(path: dbPath))
        let word = try reopened.dbQueue.read { try Word.filter(Column("normalizedWord") == "apple").fetchOne($0) }
        XCTAssertEqual(word?.displayWord, "apple")
    }
}
