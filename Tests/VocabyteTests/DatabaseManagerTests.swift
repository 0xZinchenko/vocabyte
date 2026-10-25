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
}
