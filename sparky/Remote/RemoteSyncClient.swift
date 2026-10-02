import Foundation

enum RemoteSyncError: LocalizedError {
    case notConfigured, unauthorized, http(Int), network
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Remote sync is not configured"
        case .unauthorized: "Remote sync authorization failed"
        case .http(let status): "Remote server returned HTTP \(status)"
        case .network: "Could not reach the remote server"
        }
    }
}

@MainActor
final class RemoteSyncClient {
    private let settings: RemoteSyncSettings
    private let session: URLSession
    init(settings: RemoteSyncSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    var isConfigured: Bool { (try? configuration()) != nil }

    private func configuration() throws -> (URL, String) {
        guard let url = URL(string: settings.serverURL), let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              let token = try settings.readToken(), !token.isEmpty else { throw RemoteSyncError.notConfigured }
        return (url, token)
    }

    private func request(_ path: String, method: String, body: Data? = nil, limit: Int? = nil) async throws -> Data {
        let (base, token) = try configuration()
        guard var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw RemoteSyncError.notConfigured
        }
        if let limit { components.queryItems = [URLQueryItem(name: "limit", value: String(limit))] }
        guard let url = components.url else { throw RemoteSyncError.notConfigured }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw RemoteSyncError.network }
            if response.statusCode == 401 { throw RemoteSyncError.unauthorized }
            guard (200..<300).contains(response.statusCode) else { throw RemoteSyncError.http(response.statusCode) }
            return data
        } catch let error as RemoteSyncError { throw error }
        catch { if Task.isCancelled { throw CancellationError() }; throw RemoteSyncError.network }
    }

    func putMirror(_ mirror: MirrorDTO) async throws {
        _ = try await request("api/mirror", method: "PUT", body: RemoteJSON.encoder().encode(mirror))
    }
    func commands() async throws -> [CommandDTO] {
        struct Response: Decodable { let commands: [CommandDTO] }
        return try RemoteJSON.decoder().decode(Response.self, from: await request("api/commands", method: "GET", limit: 20)).commands
    }
    func report(id: String, result: CommandResultDTO) async throws {
        guard let id = UUID(uuidString: id) else { throw RemoteCommandError.invalid("Invalid command ID") }
        _ = try await request("api/commands/\(id.uuidString.lowercased())/result", method: "POST", body: RemoteJSON.encoder().encode(result))
    }
}
