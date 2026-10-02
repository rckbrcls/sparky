import Foundation
import Combine

@MainActor
final class RemoteSyncSettings: ObservableObject {
    private let defaults: UserDefaults
    private let tokenStore: KeychainTokenStore
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "settings.remoteSync.isEnabled") }
    }
    @Published var serverURL: String {
        didSet { defaults.set(serverURL, forKey: "settings.remoteSync.serverURL") }
    }
    @Published private(set) var tokenRevision = 0

    init(defaults: UserDefaults = .standard, tokenStore: KeychainTokenStore? = nil) {
        self.defaults = defaults
        self.tokenStore = tokenStore ?? KeychainTokenStore()
        isEnabled = defaults.bool(forKey: "settings.remoteSync.isEnabled")
        serverURL = defaults.string(forKey: "settings.remoteSync.serverURL") ?? ""
    }

    nonisolated static func normalizedServerURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        let isDevelopmentHost = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
            || host.hasSuffix(".local")
        guard scheme == "https" || (scheme == "http" && isDevelopmentHost) else { return nil }
        components.scheme = scheme
        while components.path.hasSuffix("/") { components.path.removeLast() }
        return components.url
    }

    func readToken() throws -> String? { try tokenStore.read() }
    func setToken(_ token: String?) throws {
        if let token, !token.isEmpty { try tokenStore.write(token) }
        else { try tokenStore.delete() }
        tokenRevision += 1
    }
}
