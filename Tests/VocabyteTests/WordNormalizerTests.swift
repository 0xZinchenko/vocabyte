import XCTest
@testable import Vocabyte

final class WordNormalizerTests: XCTestCase {
    func testSingleWordIsAccepted() {
        XCTAssertEqual(
            WordNormalizer.normalize("hello"),
            .accepted(displayWord: "hello", normalizedWord: "hello")
        )
    }

    func testThreeWordPhraseIsAccepted() {
        XCTAssertEqual(
            WordNormalizer.normalize("get rid of"),
            .accepted(displayWord: "get rid of", normalizedWord: "get rid of")
        )
    }

    func testFourWordPhraseIsRejected() {
        XCTAssertEqual(WordNormalizer.normalize("this is too much"), .tooMuchText)
    }

    func testOnlyWhitespaceIsEmpty() {
        XCTAssertEqual(WordNormalizer.normalize("   \n  "), .empty)
    }

    func testNewlineInsideSelectionIsRejected() {
        XCTAssertEqual(WordNormalizer.normalize("hello\nworld"), .tooMuchText)
    }

    func testOverLongTextIsRejected() {
        let longText = String(repeating: "a", count: 61)
        XCTAssertEqual(WordNormalizer.normalize(longText), .tooMuchText)
    }

    func testSixtyCharactersIsAccepted() {
        let text = String(repeating: "a", count: 60)
        XCTAssertEqual(
            WordNormalizer.normalize(text),
            .accepted(displayWord: text, normalizedWord: text)
        )
    }

    func testEdgePunctuationIsTrimmed() {
        XCTAssertEqual(
            WordNormalizer.normalize("\"hello,\""),
            .accepted(displayWord: "hello", normalizedWord: "hello")
        )
    }

    func testHyphenatedCompoundCountsAsOneWord() {
        XCTAssertEqual(
            WordNormalizer.normalize("well-known"),
            .accepted(displayWord: "well-known", normalizedWord: "well-known")
        )
    }

    func testContractionKeepsInternalApostrophe() {
        XCTAssertEqual(
            WordNormalizer.normalize("don't"),
            .accepted(displayWord: "don't", normalizedWord: "don't")
        )
    }

    func testIdentifierIsNotSplit() {
        XCTAssertEqual(
            WordNormalizer.normalize("getOrDefault"),
            .accepted(displayWord: "getOrDefault", normalizedWord: "getordefault")
        )
    }

    func testCurlyApostropheUnifiesWithStraightApostrophe() {
        guard case .accepted(_, let normalized) = WordNormalizer.normalize("don\u{2019}t") else {
            return XCTFail("expected acceptance")
        }
        XCTAssertEqual(normalized, "don't")
    }

    func testDedupKeyIsCaseInsensitive() {
        guard case .accepted(_, let lower) = WordNormalizer.normalize("apple") else {
            return XCTFail("expected acceptance")
        }
        guard case .accepted(_, let upper) = WordNormalizer.normalize("Apple") else {
            return XCTFail("expected acceptance")
        }
        XCTAssertEqual(lower, upper)
    }

    func testDisplayWordPreservesOriginalCasing() {
        guard case .accepted(let display, _) = WordNormalizer.normalize("Apple") else {
            return XCTFail("expected acceptance")
        }
        XCTAssertEqual(display, "Apple")
    }
}
