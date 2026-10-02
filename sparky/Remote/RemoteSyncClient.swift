import Foundation

enum RemoteSyncError: LocalizedError {
    case notConfigured, unauthorized, network
    case http(status: Int, method: String, path: String, detail: String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Remote sync is not configured"
        case .unauthorized: "Remote sync authorization failed"
        case .http(let status, _, _, let detail):
            detail.flatMap { $0.isEmpty ? nil : $0 } ?? "Remote server returned HTTP \(status)"
        case .network: "Could not reach the remote server"
        }
    }

    /// Turns `{ error, issues: [{ path, message }] }` into one line. Returns nil when the body has no error string.
    static func failureDetail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? String else { return nil }
        let summary = error.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return nil }
        let issues = ((object["issues"] as? [Any]) ?? []).prefix(3).compactMap { item -> String? in
            guard let issue = item as? [String: Any],
                  let message = issue["message"] as? String else { return nil }
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let path = ((issue["path"] as? [Any]) ?? []).compactMap(pathComponent).joined(separator: ".")
            return path.isEmpty ? text : "\(path): \(text)"
        }
        let line = issues.isEmpty ? summary : "\(summary) \(issues.joined(separator: " "))"
        return line.count > 500 ? String(line.prefix(500)) : line
    }

    private static func pathComponent(_ value: Any) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            return number.stringValue
        }
        return nil
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
            guard (200..<300).contains(response.statusCode) else {
                let route = path.hasPrefix("/") ? path : "/\(path)"
                throw RemoteSyncError.http(status: response.statusCode, method: method, path: route, detail: RemoteSyncError.failureDetail(from: data))
            }
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
