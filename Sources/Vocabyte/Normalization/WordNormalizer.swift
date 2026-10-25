import Foundation

/// Result of normalizing a raw text selection before it's considered for saving.
enum NormalizationResult: Equatable {
    /// Accepted. `displayWord` keeps the original casing/text for showing in
    /// the UI; `normalizedWord` is the lowercase, apostrophe-unified key used
    /// for deduplication.
    case accepted(displayWord: String, normalizedWord: String)
    /// Nothing usable was left after trimming (e.g. the selection was only
    /// whitespace or punctuation).
    case empty
    /// Too long, too many words, or contains a line break — not a
    /// single word/short phrase.
    case tooMuchText
}

enum WordNormalizer {
    private static let maxCharacterCount = 60
    private static let maxWordCount = 3

    /// Punctuation/quote characters trimmed only from the start and end of
    /// the selection. Apostrophes and hyphens are included here too, but
    /// since trimming only strips from the edges, an apostrophe or hyphen
    /// *inside* a word (e.g. "don't", "well-known") is left untouched.
    private static let edgeTrimCharacterSet: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.formUnion(CharacterSet(charactersIn: ".,!?;:\"'-–—()[]{}\u{2018}\u{2019}\u{201C}\u{201D}«»"))
        return set
    }()

    static func normalize(_ raw: String) -> NormalizationResult {
        let trimmed = raw.trimmingCharacters(in: edgeTrimCharacterSet)

        guard !trimmed.isEmpty else {
            return .empty
        }
        guard !trimmed.contains("\n"), !trimmed.contains("\r") else {
            return .tooMuchText
        }
        guard trimmed.count <= maxCharacterCount else {
            return .tooMuchText
        }

        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard (1...maxWordCount).contains(tokens.count) else {
            return .tooMuchText
        }

        let normalizedWord = trimmed
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")

        return .accepted(displayWord: trimmed, normalizedWord: normalizedWord)
    }
}
