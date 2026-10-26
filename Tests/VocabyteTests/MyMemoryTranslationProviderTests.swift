import XCTest
@testable import Vocabyte

final class MyMemoryTranslationProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testParsesTranslatedText() async throws {
        let json = Data("""
        {"responseData":{"translatedText":"привет"},"responseStatus":200}
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let result = try await MyMemoryTranslationProvider(session: .mocked()).translate("hello", to: "ru")

        XCTAssertEqual(result, "привет")
    }

    func testRequestIncludesTargetLanguage() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let json = Data("""
            {"responseData":{"translatedText":"привіт"}}
            """.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        _ = try await MyMemoryTranslationProvider(session: .mocked()).translate("hello", to: "uk")

        XCTAssertTrue(capturedURL?.query?.contains("uk") ?? false)
    }

    func testQuotaExceededMessageIsTreatedAsFailure() async {
        let json = Data("""
        {"responseData":{"translatedText":"MYMEMORY WARNING: YOU USED ALL AVAILABLE FREE TRANSLATIONS FOR TODAY"}}
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        do {
            _ = try await MyMemoryTranslationProvider(session: .mocked()).translate("hello", to: "ru")
            XCTFail("expected quotaExceeded")
        } catch TranslationProviderError.quotaExceeded {
            // expected
        } catch {
            XCTFail("expected quotaExceeded, got \(error)")
        }
    }

    func testServerErrorThrows() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await MyMemoryTranslationProvider(session: .mocked()).translate("hello", to: "ru")
            XCTFail("expected an error")
        } catch {
            // expected
        }
    }

    func testNetworkFailureThrows() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        do {
            _ = try await MyMemoryTranslationProvider(session: .mocked()).translate("hello", to: "ru")
            XCTFail("expected an error")
        } catch {
            // expected
        }
    }
}
