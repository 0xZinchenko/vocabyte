import XCTest
import GRDB
@testable import Vocabyte

final class DatabaseManagerTests: XCTestCase {
    func testSavingNewWordCreatesRowWithCountOne() throws {
        let db = try DatabaseManager.openInMemory()

        let result = try db.saveWord(displayWord: "Apple", normalizedWord: "apple", sentence: nil)

        guard case .created = result else {
            return XCTFail("expected .created, got \(result)")
        }
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

        guard case .incremented(_, let secondCount) = second else {
            return XCTFail("expected .incremented, got \(second)")
        }
        guard case .incremented(_, let thirdCount) = third else {
            return XCTFail("expected .incremented, got \(third)")
        }
        XCTAssertEqual(secondCount, 2)
        XCTAssertEqual(thirdCount, 3)

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

    // MARK: - Lookup results

    private func insertedId(_ result: SaveResult) -> Int64 {
        switch result {
        case .created(let id): return id
        case .incremented(let id, _): return id
        }
    }

    func testNewWordNeedsLookup() throws {
        let db = try DatabaseManager.openInMemory()
        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)

        let pending = try db.wordsNeedingLookup()
        XCTAssertEqual(pending.map(\.normalizedWord), ["apple"])
    }

    func testSuccessfulLookupRemovesWordFromPendingList() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        try db.recordLookupResult(
            wordId: id,
            phonetic: "ˈæpəl",
            partOfSpeech: "noun",
            translation: "яблоко",
            translationLang: "ru",
            succeeded: true
        )

        XCTAssertEqual(try db.wordsNeedingLookup().count, 0)
        let word = try db.dbQueue.read { try Word.filter(Column("id") == id).fetchOne($0)! }
        XCTAssertEqual(word.phonetic, "ˈæpəl")
        XCTAssertEqual(word.partOfSpeech, "noun")
        XCTAssertEqual(word.translation, "яблоко")
        XCTAssertEqual(word.translationLang, "ru")
        XCTAssertEqual(word.lookupStatus, .success)
    }

    func testFailedLookupKeepsWordInPendingListForRetry() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        try db.recordLookupResult(
            wordId: id,
            phonetic: nil,
            partOfSpeech: nil,
            translation: nil,
            translationLang: nil,
            succeeded: false
        )

        XCTAssertEqual(try db.wordsNeedingLookup().count, 1)
        let word = try db.dbQueue.read { try Word.filter(Column("id") == id).fetchOne($0)! }
        XCTAssertEqual(word.lookupStatus, .failed)
    }

    func testFailedTranslationStillKeepsDictionaryDataFoundThatAttempt() throws {
        // The dictionary lookup can succeed even when translation fails
        // (they're independent network calls) - that data shouldn't be lost.
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        try db.recordLookupResult(
            wordId: id,
            phonetic: "ˈæpəl",
            partOfSpeech: "noun",
            translation: nil,
            translationLang: nil,
            succeeded: false
        )

        let word = try db.dbQueue.read { try Word.filter(Column("id") == id).fetchOne($0)! }
        XCTAssertEqual(word.phonetic, "ˈæpəl")
        XCTAssertEqual(word.partOfSpeech, "noun")
        XCTAssertEqual(word.lookupStatus, .failed, "still needs a retry since translation failed")
    }

    func testRetryDoesNotErasePreviouslyFoundDictionaryData() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        try db.recordLookupResult(
            wordId: id, phonetic: "ˈæpəl", partOfSpeech: "noun",
            translation: nil, translationLang: nil, succeeded: false
        )
        // Retry: translation succeeds this time, but the dictionary call
        // itself failed/found nothing on this attempt.
        try db.recordLookupResult(
            wordId: id, phonetic: nil, partOfSpeech: nil,
            translation: "яблоко", translationLang: "ru", succeeded: true
        )

        let word = try db.dbQueue.read { try Word.filter(Column("id") == id).fetchOne($0)! }
        XCTAssertEqual(word.phonetic, "ˈæpəl", "earlier dictionary data must survive a retry that didn't find it again")
        XCTAssertEqual(word.partOfSpeech, "noun")
        XCTAssertEqual(word.translation, "яблоко")
        XCTAssertEqual(word.lookupStatus, .success)
    }

    // MARK: - Word list

    func testAllWordsOrdersByMostRecentlyCapturedFirst() throws {
        let db = try DatabaseManager.openInMemory()
        _ = try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil)
        Thread.sleep(forTimeInterval: 0.01)
        _ = try db.saveWord(displayWord: "banana", normalizedWord: "banana", sentence: nil)

        let words = try db.allWords()
        XCTAssertEqual(words.map(\.normalizedWord), ["banana", "apple"])
    }

    func testEditingAWordDoesNotChangeItsPositionInTheDefaultOrder() throws {
        // Regression: the default order previously sorted by `updatedAt`,
        // so correcting a word's text (or anything else that touches it)
        // jumped it to the top of the list — confusing when all you did was
        // fix a typo. It must sort by `createdAt` instead, which a rename
        // doesn't change.
        let db = try DatabaseManager.openInMemory()
        let appleId = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))
        Thread.sleep(forTimeInterval: 0.01)
        _ = try db.saveWord(displayWord: "banana", normalizedWord: "banana", sentence: nil)

        _ = try db.renameWord(id: appleId, displayWord: "apples", normalizedWord: "apples")

        let words = try db.allWords()
        XCTAssertEqual(words.map(\.displayWord), ["banana", "apples"], "apple's edit shouldn't move it ahead of banana")
    }

    func testSetLearnedTogglesFlagAndBumpsUpdatedAt() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))
        let originalUpdatedAt = try db.word(withId: id)!.updatedAt

        Thread.sleep(forTimeInterval: 0.01)
        try db.setLearned(id: id, learned: true)

        let word = try db.word(withId: id)!
        XCTAssertTrue(word.learned)
        XCTAssertGreaterThan(word.updatedAt, originalUpdatedAt)

        try db.setLearned(id: id, learned: false)
        XCTAssertFalse(try db.word(withId: id)!.learned)
    }

    func testDeleteWordRemovesRowAndIsSafeToCallTwice() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        try db.deleteWord(id: id)
        XCTAssertNil(try db.word(withId: id))

        // Deleting an already-gone row must not throw.
        try db.deleteWord(id: id)
    }

    func testRenameWordUpdatesTextAndResetsLookupData() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "ocal", normalizedWord: "ocal", sentence: nil))
        try db.recordLookupResult(
            wordId: id, phonetic: nil, partOfSpeech: nil,
            translation: "ocal", translationLang: "ru", succeeded: true
        )

        let result = try db.renameWord(id: id, displayWord: "local", normalizedWord: "local")
        XCTAssertEqual(result, .renamed)

        let word = try db.word(withId: id)!
        XCTAssertEqual(word.displayWord, "local")
        XCTAssertEqual(word.normalizedWord, "local")
        XCTAssertNil(word.translation, "stale translation for the old, wrong text must be cleared")
        XCTAssertEqual(word.lookupStatus, .pending, "needs a fresh lookup for the corrected text")
    }

    func testRenameToSameNormalizedWordOnlyFixesCasingAndKeepsLookupData() throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "Apple", normalizedWord: "apple", sentence: nil))
        try db.recordLookupResult(
            wordId: id, phonetic: "ˈæpəl", partOfSpeech: "noun",
            translation: "яблоко", translationLang: "ru", succeeded: true
        )

        let result = try db.renameWord(id: id, displayWord: "apple", normalizedWord: "apple")
        XCTAssertEqual(result, .renamed)

        let word = try db.word(withId: id)!
        XCTAssertEqual(word.displayWord, "apple")
        XCTAssertEqual(word.translation, "яблоко", "a casing-only fix shouldn't throw away data already found for this word")
        XCTAssertEqual(word.lookupStatus, .success)
    }

    func testRenameToAnExistingWordMergesAndDeletesTheEditedRow() throws {
        let db = try DatabaseManager.openInMemory()
        let localId = insertedId(try db.saveWord(displayWord: "local", normalizedWord: "local", sentence: "Keep it local."))
        try db.recordLookupResult(
            wordId: localId, phonetic: "ˈləʊkl̩", partOfSpeech: "adjective",
            translation: "местный", translationLang: "ru", succeeded: true
        )
        let typoId = insertedId(try db.saveWord(displayWord: "ocal", normalizedWord: "ocal", sentence: nil))

        let result = try db.renameWord(id: typoId, displayWord: "local", normalizedWord: "local")
        XCTAssertEqual(result, .mergedIntoExisting(existingId: localId))

        XCTAssertNil(try db.word(withId: typoId), "the edited row is merged away, not left behind as a duplicate")
        let merged = try db.word(withId: localId)!
        XCTAssertEqual(merged.count, 2, "both saves of what turned out to be the same word are counted")
        XCTAssertEqual(merged.translation, "местный", "the existing word's own lookup data is kept, not overwritten")
        XCTAssertEqual(merged.sentence, "Keep it local.")
    }
}
