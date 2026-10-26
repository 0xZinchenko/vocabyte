import Foundation

enum DictionaryProviderError: Error {
    case unexpectedResponse
}

/// Looks up a word via the Free Dictionary API (https://dictionaryapi.dev/).
/// Free, keyless, but coverage is uneven — especially for anything that
/// isn't a single common word.
struct FreeDictionaryProvider: DictionaryProvider {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 8) {
        self.session = session
        self.timeout = timeout
    }

    func lookup(word: String) async throws -> DictionaryLookupResult? {
        guard let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encodedWord)")
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DictionaryProviderError.unexpectedResponse
        }
        if httpResponse.statusCode == 404 {
            // No dictionary entry for this word/phrase — not an error.
            return nil
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DictionaryProviderError.unexpectedResponse
        }

        let entries = try JSONDecoder().decode([Entry].self, from: data)
        guard let first = entries.first else { return nil }

        // The API sometimes sends an empty string rather than omitting the
        // field entirely, so an empty top-level `phonetic` is treated the
        // same as a missing one.
        let topLevelPhonetic = first.phonetic?.isEmpty == false ? first.phonetic : nil
        let phonetic = topLevelPhonetic ?? first.phonetics?.first { !($0.text ?? "").isEmpty }?.text
        let partOfSpeech = first.meanings?.first?.partOfSpeech

        guard phonetic != nil || partOfSpeech != nil else { return nil }
        return DictionaryLookupResult(phonetic: phonetic, partOfSpeech: partOfSpeech)
    }

    private struct Entry: Decodable {
        let phonetic: String?
        let phonetics: [Phonetic]?
        let meanings: [Meaning]?

        struct Phonetic: Decodable {
            let text: String?
        }

        struct Meaning: Decodable {
            let partOfSpeech: String?
        }
    }
}
