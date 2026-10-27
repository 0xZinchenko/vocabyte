import XCTest
@testable import Vocabyte

final class CSVExporterTests: XCTestCase {
    private func makeWord(
        displayWord: String = "apple",
        phonetic: String? = "ˈæpəl",
        partOfSpeech: String? = "noun",
        translation: String? = "яблоко",
        translationLang: String? = "ru",
        sentence: String? = "I ate an apple.",
        count: Int = 1,
        learned: Bool = false
    ) -> Word {
        Word(
            id: 1,
            normalizedWord: displayWord.lowercased(),
            displayWord: displayWord,
            phonetic: phonetic,
            partOfSpeech: partOfSpeech,
            translation: translation,
            translationLang: translationLang,
            sentence: sentence,
            count: count,
            learned: learned,
            lookupStatus: .success,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testCSVIncludesHeaderRow() {
        let csv = CSVExporter.csv(for: [])
        XCTAssertEqual(csv, CSVExporter.header.joined(separator: ","))
    }

    func testCSVIncludesWordFields() {
        let csv = CSVExporter.csv(for: [makeWord()])
        let rows = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[1].hasPrefix("apple,ˈæpəl,noun,яблоко,ru,I ate an apple.,1,false,"))
    }

    func testFieldsContainingCommasAreQuoted() {
        let csv = CSVExporter.csv(for: [makeWord(sentence: "Well, I ate it.")])
        XCTAssertTrue(csv.contains("\"Well, I ate it.\""))
    }

    func testFieldsContainingQuotesAreEscapedByDoubling() {
        let csv = CSVExporter.csv(for: [makeWord(translation: "так называемый \"перевод\"")])
        XCTAssertTrue(csv.contains("\"так называемый \"\"перевод\"\"\""))
    }

    func testNilOptionalFieldsBecomeEmptyStrings() {
        let csv = CSVExporter.csv(for: [makeWord(phonetic: nil, partOfSpeech: nil, translation: nil, translationLang: nil, sentence: nil)])
        let rows = csv.components(separatedBy: "\r\n")
        XCTAssertTrue(rows[1].hasPrefix("apple,,,,,,1,false,"))
    }

    func testWriteAddsUTF8BOMAndIsReadableBack() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try CSVExporter.write([makeWord()], to: tempURL)

        let data = try Data(contentsOf: tempURL)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF], "a UTF-8 BOM is required for Excel to detect the encoding and show Cyrillic correctly")

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("яблоко"))
    }
}
