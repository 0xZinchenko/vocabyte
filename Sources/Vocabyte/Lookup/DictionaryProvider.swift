/// Phonetic transcription and part of speech for a word. Either field may
/// be missing even on success — that's expected, especially for phrases.
struct DictionaryLookupResult: Equatable {
    let phonetic: String?
    let partOfSpeech: String?
}

/// Abstracts "look up a word's transcription/part of speech" behind a
/// protocol, so the backing service (today: Free Dictionary API) can be
/// swapped for a different one, or a future Vocabyte server, without
/// touching the storage or lookup-orchestration code.
protocol DictionaryProvider {
    /// Returns `nil` if the word genuinely has no dictionary entry — not
    /// an error, just no data (common for phrases). Throws only for actual
    /// failures (network error, timeout, unexpected response).
    func lookup(word: String) async throws -> DictionaryLookupResult?
}
