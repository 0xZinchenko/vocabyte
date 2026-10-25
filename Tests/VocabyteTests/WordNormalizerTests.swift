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

    // MARK: - Regressions found in review

    func testWindowsStyleLineBreakIsRejected() {
        // "\r\n" is a single Character in Swift, so a naive "\n"/"\r"
        // substring check misses it entirely.
        XCTAssertEqual(WordNormalizer.normalize("hello\r\nworld"), .tooMuchText)
    }

    func testUnicodeLineSeparatorIsRejected() {
        XCTAssertEqual(WordNormalizer.normalize("hello\u{2028}world"), .tooMuchText)
    }

    func testDoubleSpaceCollapsesToSingleSpaceInKey() {
        guard case .accepted(let display, let normalized) = WordNormalizer.normalize("get  rid of") else {
            return XCTFail("expected acceptance")
        }
        XCTAssertEqual(normalized, "get rid of")
        XCTAssertEqual(display, "get  rid of", "the visible text keeps the exact whitespace it was selected with")
    }

    func testNonBreakingSpaceDedupesWithRegularSpace() {
        guard case .accepted(_, let withNBSP) = WordNormalizer.normalize("get\u{00A0}rid of") else {
            return XCTFail("expected acceptance")
        }
        guard case .accepted(_, let withRegularSpace) = WordNormalizer.normalize("get rid of") else {
            return XCTFail("expected acceptance")
        }
        XCTAssertEqual(withNBSP, withRegularSpace)
    }

    func testParenthesizedCallExpressionIsKeptWhole() {
        // Brackets are not edge-trimmed, so a one-sided strip can no longer
        // mangle this into "getOrDefault(key".
        XCTAssertEqual(
            WordNormalizer.normalize("getOrDefault(key)"),
            .accepted(displayWord: "getOrDefault(key)", normalizedWord: "getordefault(key)")
        )
    }

    func testDecomposedAndPrecomposedAccentsDedupeTogether() {
        let precomposed = "café" // single scalar é (U+00E9)
        let decomposed = "cafe\u{0301}" // "e" + combining acute accent
        guard case .accepted(_, let key1) = WordNormalizer.normalize(precomposed) else {
            return XCTFail("expected acceptance")
        }
        guard case .accepted(_, let key2) = WordNormalizer.normalize(decomposed) else {
            return XCTFail("expected acceptance")
        }
        XCTAssertEqual(key1, key2)
    }
}
