import Foundation

enum RemotePairingError: Error, Equatable {
    case invalidCode, invalidRequest, network, unexpectedResponse
    case tooManyAttempts(retryAfter: Int?)
}

@MainActor
final class RemotePairingClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? URLSession(configuration: Self.sessionConfiguration())
    }

    nonisolated static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        return configuration
    }

    nonisolated static func normalizeCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "-" }
    }

    nonisolated static func makeRequest(serverURL: String, code: String) throws -> URLRequest {
        guard let base = RemoteSyncSettings.normalizedServerURL(serverURL) else {
            throw RemotePairingError.invalidRequest
        }
        let normalizedCode = normalizeCode(code)
        guard !normalizedCode.isEmpty else { throw RemotePairingError.invalidRequest }
        let url = base.appendingPathComponent("api").appendingPathComponent("pair").appendingPathComponent("redeem")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": normalizedCode])
        return request
    }

    func redeemPairingCode(serverURL: String, code: String) async throws -> String {
        let request = try Self.makeRequest(serverURL: serverURL, code: code)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw RemotePairingError.network
        }
        guard let response = response as? HTTPURLResponse else { throw RemotePairingError.unexpectedResponse }
        switch response.statusCode {
        case 200:
            struct Response: Decodable { let apiToken: String }
            guard let result = try? JSONDecoder().decode(Response.self, from: data),
                  !result.apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RemotePairingError.unexpectedResponse
            }
            return result.apiToken
        case 400: throw RemotePairingError.invalidRequest
        case 401: throw RemotePairingError.invalidCode
        case 429:
            let seconds = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            throw RemotePairingError.tooManyAttempts(retryAfter: seconds.flatMap { $0 >= 0 ? $0 : nil })
        default: throw RemotePairingError.unexpectedResponse
        }
    }
}
