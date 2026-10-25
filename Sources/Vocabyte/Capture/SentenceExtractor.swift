import Foundation

/// Extracts the sentence surrounding a selection inside a larger text,
/// for context shown alongside a saved word.
enum SentenceExtractor {
    private static let maxLength = 300

    /// `.`, `!`, `?`, and line breaks mark a sentence boundary.
    private static let boundaryCodeUnits: Set<UInt16> = [0x2E, 0x21, 0x3F, 0x0A]

    /// `selectionLocation`/`selectionLength` are UTF-16 offsets, matching
    /// what the Accessibility API reports for `kAXSelectedTextRangeAttribute`.
    /// Returns an empty string if extraction isn't possible or the result
    /// would exceed the length limit — per spec, an empty sentence is saved
    /// rather than treating this as a failure.
    static func extractSentence(from fullText: String, selectionLocation: Int, selectionLength: Int) -> String {
        let text = fullText as NSString
        guard selectionLocation >= 0,
              selectionLength >= 0,
              selectionLocation + selectionLength <= text.length
        else {
            return ""
        }

        var start = selectionLocation
        while start > 0, !boundaryCodeUnits.contains(text.character(at: start - 1)) {
            start -= 1
        }

        var end = selectionLocation + selectionLength
        while end < text.length {
            let isBoundary = boundaryCodeUnits.contains(text.character(at: end))
            end += 1
            if isBoundary { break }
        }

        let sentence = text
            .substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard sentence.count <= maxLength else {
            return ""
        }
        return sentence
    }
}
