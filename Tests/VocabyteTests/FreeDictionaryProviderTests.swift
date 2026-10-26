import XCTest
@testable import Vocabyte

final class FreeDictionaryProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testParsesTopLevelPhoneticAndFirstPartOfSpeech() async throws {
        let json = Data("""
        [{"word":"hello","phonetic":"həˈloʊ","phonetics":[{"text":"həˈloʊ"}],
          "meanings":[{"partOfSpeech":"exclamation"}]}]
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let result = try await FreeDictionaryProvider(session: .mocked()).lookup(word: "hello")

        XCTAssertEqual(result, DictionaryLookupResult(phonetic: "həˈloʊ", partOfSpeech: "exclamation"))
    }

    func testFallsBackToPhoneticsArrayWhenTopLevelFieldIsEmpty() async throws {
        let json = Data("""
        [{"word":"example","phonetic":"","phonetics":[{"text":""},{"text":"ɪɡˈzæmpəl"}],
          "meanings":[{"partOfSpeech":"noun"}]}]
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let result = try await FreeDictionaryProvider(session: .mocked()).lookup(word: "example")

        XCTAssertEqual(result?.phonetic, "ɪɡˈzæmpəl")
    }

    func testNotFoundReturnsNilNotAnError() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let result = try await FreeDictionaryProvider(session: .mocked()).lookup(word: "get rid of")

        XCTAssertNil(result)
    }

    func testServerErrorThrows() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await FreeDictionaryProvider(session: .mocked()).lookup(word: "hello")
            XCTFail("expected an error")
        } catch {
            // expected
        }
    }

    func testNetworkFailureThrows() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await FreeDictionaryProvider(session: .mocked()).lookup(word: "hello")
            XCTFail("expected an error")
        } catch {
            // expected
        }
    }

    func testMalformedResponseBodyThrows() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("not json".utf8))
        }

        do {
            _ = try await FreeDictionaryProvider(session: .mocked()).lookup(word: "hello")
            XCTFail("expected a decoding error")
        } catch {
            // expected
        }
    }
}
