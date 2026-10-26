import XCTest
@testable import Vocabyte

private enum StubError: Error { case boom }

private struct StubDictionaryProvider: DictionaryProvider {
    let result: Result<DictionaryLookupResult?, Error>
    func lookup(word: String) async throws -> DictionaryLookupResult? {
        try result.get()
    }
}

private struct StubTranslationProvider: TranslationProvider {
    let result: Result<String, Error>
    func translate(_ text: String, to languageCode: String) async throws -> String {
        try result.get()
    }
}

private final class CountingTranslationProvider: TranslationProvider {
    private(set) var callCount = 0
    func translate(_ text: String, to languageCode: String) async throws -> String {
        callCount += 1
        return "unexpectedly called"
    }
}

final class WordLookupServiceTests: XCTestCase {
    private func insertedId(_ result: SaveResult) -> Int64 {
        switch result {
        case .created(let id): return id
        case .incremented(let id, _): return id
        }
    }

    func testSuccessfulTranslationMarksWordSuccessEvenIfDictionaryFails() async throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        let service = WordLookupService(
            dictionaryProvider: StubDictionaryProvider(result: .failure(StubError.boom)),
            translationProvider: StubTranslationProvider(result: .success("яблоко")),
            database: db
        )
        await service.lookup(wordId: id, text: "apple")

        let word = try db.word(withId: id)!
        XCTAssertEqual(word.lookupStatus, .success)
        XCTAssertEqual(word.translation, "яблоко")
        XCTAssertNil(word.phonetic)
    }

    func testFailedTranslationMarksWordFailedEvenIfDictionarySucceeds() async throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))

        let service = WordLookupService(
            dictionaryProvider: StubDictionaryProvider(
                result: .success(DictionaryLookupResult(phonetic: "ˈæpəl", partOfSpeech: "noun"))
            ),
            translationProvider: StubTranslationProvider(result: .failure(StubError.boom)),
            database: db
        )
        await service.lookup(wordId: id, text: "apple")

        let word = try db.word(withId: id)!
        XCTAssertEqual(word.lookupStatus, .failed)
        XCTAssertNil(word.translation)
        XCTAssertEqual(word.phonetic, "ˈæpəl", "dictionary data is kept even though the word still needs a translation retry")
    }

    func testWordAlreadyTranslatedIsNotRetried() async throws {
        let db = try DatabaseManager.openInMemory()
        let id = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))
        try db.recordLookupResult(
            wordId: id, phonetic: nil, partOfSpeech: nil,
            translation: "яблоко", translationLang: "ru", succeeded: true
        )

        let counting = CountingTranslationProvider()
        let service = WordLookupService(
            dictionaryProvider: StubDictionaryProvider(result: .success(nil)),
            translationProvider: counting,
            database: db
        )
        await service.lookup(wordId: id, text: "apple")

        XCTAssertEqual(counting.callCount, 0, "a word that already has a translation shouldn't trigger another network call")
    }

    func testRefreshPendingRetriesOnlyNonSuccessfulWords() async throws {
        let db = try DatabaseManager.openInMemory()
        let pendingId = insertedId(try db.saveWord(displayWord: "apple", normalizedWord: "apple", sentence: nil))
        let failedId = insertedId(try db.saveWord(displayWord: "banana", normalizedWord: "banana", sentence: nil))
        try db.recordLookupResult(
            wordId: failedId, phonetic: nil, partOfSpeech: nil,
            translation: nil, translationLang: nil, succeeded: false
        )
        let successId = insertedId(try db.saveWord(displayWord: "cherry", normalizedWord: "cherry", sentence: nil))
        try db.recordLookupResult(
            wordId: successId, phonetic: nil, partOfSpeech: nil,
            translation: "вишня", translationLang: "ru", succeeded: true
        )

        let service = WordLookupService(
            dictionaryProvider: StubDictionaryProvider(result: .success(nil)),
            translationProvider: StubTranslationProvider(result: .success("translated")),
            database: db
        )
        await service.refreshPending()

        XCTAssertEqual(try db.word(withId: pendingId)?.lookupStatus, .success)
        XCTAssertEqual(try db.word(withId: failedId)?.lookupStatus, .success)
        XCTAssertEqual(try db.word(withId: successId)?.translation, "вишня", "an already-successful word is left untouched")
    }
}
