import Foundation

/// Exports the full word list to CSV. Always exports everything, regardless
/// of the word list window's current search/filter — this is meant as a
/// backup/migration file, and a filtered export could silently omit words
/// (e.g. everything marked "learned") without the user noticing.
enum CSVExporter {
    private static let dateFormatter = ISO8601DateFormatter()

    static let header = [
        "Word", "Phonetic", "Part of speech", "Translation", "Translation language",
        "Sentence", "Count", "Learned", "Created at", "Updated at",
    ]

    static func csv(for words: [Word]) -> String {
        var lines = [header.map(escape).joined(separator: ",")]
        for word in words {
            let fields: [String] = [
                word.displayWord,
                word.phonetic ?? "",
                word.partOfSpeech ?? "",
                word.translation ?? "",
                word.translationLang ?? "",
                word.sentence ?? "",
                String(word.count),
                word.learned ? "true" : "false",
                dateFormatter.string(from: word.createdAt),
                dateFormatter.string(from: word.updatedAt),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Writes with a leading UTF-8 byte-order mark so Excel detects the
    /// encoding and shows Cyrillic translations correctly instead of mangling
    /// them — a plain UTF-8 file without a BOM is what Excel gets wrong.
    static func write(_ words: [Word], to url: URL) throws {
        let content = "\u{FEFF}" + csv(for: words)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
