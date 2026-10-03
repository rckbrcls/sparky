import Foundation
import Testing
@testable import sparky

@MainActor
struct RemoteSyncClientTests {
    @Test func successUsesMirrorClaimAndResultContracts() async throws {
        let fixture = try RemoteTransportFixture(host: "success")
        defer { fixture.cleanup() }
        let mirror = MirrorDTO(syncedAt: Date(timeIntervalSince1970: 1_800_000_000), minds: [], memories: [])
        try await fixture.client.putMirror(mirror)
        let commands = try await fixture.client.commands()
        #expect(commands.count == 1)
        #expect(commands.first?.id == "00000000-0000-0000-0000-000000000001")
        #expect(commands.first?.type == "memory.create")
        try await fixture.client.report(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            result: CommandResultDTO(status: "done", result: .object(["deletedId": .string("test")]), error: nil))
    }

    @Test(arguments: ["unauthorized", "servererror", "network", "timeout", "malformed"])
    func failureClassification(host: String) async throws {
        let fixture = try RemoteTransportFixture(host: host)
        defer { fixture.cleanup() }
        do {
            _ = try await fixture.client.commands()
            Issue.record("Expected transport failure for \(host)")
        } catch {
            switch (host, error) {
            case ("unauthorized", RemoteSyncError.unauthorized): break
            case ("servererror", RemoteSyncError.http(let status, let method, let path, let detail)):
                #expect(status == 500 && method == "GET" && path == "/api/commands")
                #expect(detail == "Synthetic failure payload.title: Invalid title")
            case ("network", RemoteSyncError.network), ("timeout", RemoteSyncError.network): break
            case ("malformed", is DecodingError): break
            default: Issue.record("Unexpected transport error for \(host): \(error)")
            }
        }
    }

    @Test func absentInjectedTokenNeverFallsBackToKeychain() throws {
        let fixture = try RemoteTransportFixture(host: "success", token: nil)
        defer { fixture.cleanup() }
        #expect(!fixture.client.isConfigured)
    }

    @Test func invalidResultIDRejectedBeforeTransport() async throws {
        let fixture = try RemoteTransportFixture(host: "network")
        defer { fixture.cleanup() }
        do {
            try await fixture.client.report(id: "invalid", result: CommandResultDTO(status: "done", result: .null, error: nil))
            Issue.record("Expected invalid command ID")
        } catch RemoteCommandError.invalid(let message) {
            #expect(message == "Invalid command ID")
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}

@MainActor
private final class RemoteTransportFixture {
    let suiteName = "SparkyRemoteTransportTests-\(UUID().uuidString)"
    let defaults: UserDefaults
    let session: URLSession
    let client: RemoteSyncClient

    init(host: String, token: String? = "synthetic-test-token") throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        let settings = RemoteSyncSettings(defaults: defaults)
        settings.serverURL = "https://\(host).example.com/base"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteSyncTestURLProtocol.self]
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        client = RemoteSyncClient(settings: settings, session: session, tokenProvider: { token })
    }

    func cleanup() {
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class RemoteSyncTestURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    nonisolated override func stopLoading() { }

    nonisolated private func bodyData() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    nonisolated override func startLoading() {
        guard let url = request.url else { return }
        let host = url.host?.components(separatedBy: ".").first ?? ""
        if host == "network" || host == "timeout" {
            client?.urlProtocol(self, didFailWithError: URLError(host == "timeout" ? .timedOut : .cannotConnectToHost))
            return
        }
        var status = host == "unauthorized" ? 401 : host == "servererror" ? 500 : 200
        var body = host == "malformed" ? "not json"
            : "{\"error\":\"Synthetic failure\",\"issues\":[{\"path\":[\"payload\",\"title\"],\"message\":\"Invalid title\"}]}"
        if host == "success" {
            let authorized = request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token"
                && request.value(forHTTPHeaderField: "Content-Type") == "application/json"
            let object = bodyData().flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            switch url.path {
            case "/base/api/mirror":
                status = authorized && request.httpMethod == "PUT" && object?["minds"] is [Any]
                    && object?["memories"] is [Any] && object?["syncedAt"] is String ? 200 : 400
                body = "{}"
            case "/base/api/commands":
                status = authorized && request.httpMethod == "GET" && url.query == "limit=20" ? 200 : 400
                body = "{\"commands\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"type\":\"memory.create\",\"targetId\":null,\"baseVersion\":null,\"payload\":{\"title\":\"Synthetic\"},\"createdAt\":\"2026-01-01T00:00:00.000Z\"}]}"
            case "/base/api/commands/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/result":
                status = authorized && request.httpMethod == "POST" && object?["status"] as? String == "done"
                    && object?["result"] is [String: Any] ? 200 : 400
                body = "{}"
            default: status = 404
            }
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
