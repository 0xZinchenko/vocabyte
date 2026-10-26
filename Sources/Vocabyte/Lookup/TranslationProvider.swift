/// Abstracts "translate this text" behind a protocol (today: MyMemory),
/// for the same reason as `DictionaryProvider`.
protocol TranslationProvider {
    /// `languageCode` is the target language, e.g. "ru" or "uk". Always
    /// throws on failure (network error, timeout, quota exceeded, or an
    /// unexpected response) — unlike the dictionary, there's no concept of
    /// "legitimately nothing to translate".
    func translate(_ text: String, to languageCode: String) async throws -> String
}
