import Foundation

enum TranslationProviderError: Error {
    case unexpectedResponse
    case invalidQuery
    /// MyMemory sometimes responds with HTTP 200 but an error message
    /// instead of a translation (e.g. the free daily quota is used up).
    case quotaExceeded
}

/// Translates via MyMemory (https://mymemory.translated.net/). Free,
/// keyless, but has an unauthenticated daily usage limit.
struct MyMemoryTranslationProvider: TranslationProvider {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 8) {
        self.session = session
        self.timeout = timeout
    }

    func translate(_ text: String, to languageCode: String) async throws -> String {
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "en|\(languageCode)"),
        ]
        guard let url = components?.url else {
            throw TranslationProviderError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw TranslationProviderError.unexpectedResponse
        }

        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        let translated = decoded.responseData.translatedText

        // Not a documented, guaranteed format - this is a best-effort check
        // based on observed behavior. Revisit if it ever misfires.
        if translated.uppercased().contains("MYMEMORY WARNING") {
            throw TranslationProviderError.quotaExceeded
        }

        return translated
    }

    private struct MyMemoryResponse: Decodable {
        let responseData: ResponseData

        struct ResponseData: Decodable {
            let translatedText: String
        }
    }
}
