import Foundation
import Testing
@testable import sparky

@MainActor
struct RemotePairingClientTests {
    @Test func codeNormalization() {
        #expect(RemotePairingClient.normalizeCode("  abcd-efgh \n") == "ABCDEFGH")
        #expect(RemotePairingClient.normalizeCode("a b\tc d-2 3 4 5") == "ABCD2345")
        #expect(RemotePairingClient.normalizeCode(" - \n") == "")
    }

    @Test func requestConstruction() throws {
        let request = try RemotePairingClient.makeRequest(serverURL: " https://example.com/base/// ", code: "abcd-efgh")
        #expect(request.url?.absoluteString == "https://example.com/base/api/pair/redeem")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.timeoutInterval == 15)
        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: String]
        #expect(object == ["code": "ABCDEFGH"])
    }

    @Test func localServerURLsAndInvalidURLs() throws {
        for host in ["localhost", "127.0.0.1", "[::1]", "sparky.local"] {
            let request = try RemotePairingClient.makeRequest(serverURL: "http://\(host):8080/", code: "ABCD-EFGH")
            #expect(request.url?.path == "/api/pair/redeem")
        }
        for url in ["http://example.com", "https://user:secret@example.com", "https://example.com?query=1", "https://example.com#fragment", "example.com", ""] {
            #expect(throws: RemotePairingError.invalidRequest) {
                try RemotePairingClient.makeRequest(serverURL: url, code: "ABCD-EFGH")
            }
        }
        #expect(throws: RemotePairingError.invalidRequest) {
            try RemotePairingClient.makeRequest(serverURL: "https://example.com", code: " - ")
        }
    }

    @Test func sessionDoesNotPersistCookiesOrCache() {
        let configuration = RemotePairingClient.sessionConfiguration()
        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.timeoutIntervalForRequest == 15)
        #expect(configuration.timeoutIntervalForResource == 15)
    }

    @Test func successfulRedemption() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = RemotePairingClient(session: session)
        let token = try await client.redeemPairingCode(serverURL: "https://status200.example.com", code: "ABCD-EFGH")
        #expect(token == "test-api-token")
    }

    @Test func responseErrors() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let client = RemotePairingClient(session: session)
        let cases: [(String, RemotePairingError)] = [
            ("status400", .invalidRequest),
            ("status401", .invalidCode),
            ("status429", .tooManyAttempts(retryAfter: 125)),
            ("missingretry", .tooManyAttempts(retryAfter: nil)),
            ("invalidretry", .tooManyAttempts(retryAfter: nil)),
            ("status500", .unexpectedResponse),
            ("status204", .unexpectedResponse),
            ("malformed", .unexpectedResponse),
            ("emptytoken", .unexpectedResponse),
            ("network", .network),
        ]
        for (host, expected) in cases {
            do {
                _ = try await client.redeemPairingCode(serverURL: "https://\(host).example.com", code: "ABCD-EFGH")
                Issue.record("Expected a pairing error for \(host)")
            } catch {
                #expect(error as? RemotePairingError == expected)
            }
        }
    }

    private func makeSession() -> URLSession {
        let configuration = RemotePairingClient.sessionConfiguration()
        configuration.protocolClasses = [RemotePairingURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class RemotePairingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    nonisolated override func startLoading() {
        guard let url = request.url else { return }
        let host = url.host?.components(separatedBy: ".").first ?? ""
        if host == "network" {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let status = Int(host.replacingOccurrences(of: "status", with: ""))
            ?? (["missingretry", "invalidretry"].contains(host) ? 429 : 200)
        let headers = host == "status429" ? ["Retry-After": "125"]
            : host == "invalidretry" ? ["Retry-After": "invalid"] : [:]
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else { return }
        let body = host == "malformed" ? "not json"
            : host == "emptytoken" ? "{\"apiToken\":\"\"}" : "{\"apiToken\":\"test-api-token\"}"
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    nonisolated override func stopLoading() { }
}
