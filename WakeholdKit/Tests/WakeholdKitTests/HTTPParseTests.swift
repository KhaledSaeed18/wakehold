import Testing
import Foundation
@testable import WakeholdKit

struct HTTPParseTests {
    @Test func parsesCompleteGetWithNoBody() {
        let raw = Data("GET /status HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8)
        let request = HTTP.parse(raw)
        #expect(request?.method == "GET")
        #expect(request?.path == "/status")
        #expect(request?.body.isEmpty == true)
    }

    @Test func parsesCompletePostWithMatchingContentLength() {
        let body = #"{"kind":"agent"}"#
        let raw = Data(
            "POST /session/start HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)".utf8
        )
        let request = HTTP.parse(raw)
        #expect(request?.method == "POST")
        #expect(request?.path == "/session/start")
        #expect(request.map { String(data: $0.body, encoding: .utf8) } == body)
    }

    @Test func returnsNilWhenBodyShorterThanContentLength() {
        let raw = Data("POST /x HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc".utf8)
        #expect(HTTP.parse(raw) == nil)
    }

    @Test func returnsNilWithoutHeaderBodySeparator() {
        let raw = Data("GET /status HTTP/1.1\r\nHost: localhost".utf8)
        #expect(HTTP.parse(raw) == nil)
    }

    @Test func returnsNilForNegativeContentLength() {
        let raw = Data("POST /x HTTP/1.1\r\nContent-Length: -1\r\n\r\n".utf8)
        #expect(HTTP.parse(raw) == nil)
    }

    @Test func returnsNilForNonNumericContentLength() {
        let raw = Data("POST /x HTTP/1.1\r\nContent-Length: abc\r\n\r\n".utf8)
        #expect(HTTP.parse(raw) == nil)
    }

    @Test func returnsNilForDuplicateContentLengthHeaders() {
        let raw = Data("POST /x HTTP/1.1\r\nContent-Length: 3\r\nContent-Length: 5\r\n\r\nabc".utf8)
        #expect(HTTP.parse(raw) == nil)
    }

    @Test func returnsNilForMalformedRequestLine() {
        let raw = Data("GET\r\nHost: localhost\r\n\r\n".utf8)
        #expect(HTTP.parse(raw) == nil)
    }
}
