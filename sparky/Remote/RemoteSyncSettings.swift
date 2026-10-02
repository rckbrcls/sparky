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

    func readToken() throws -> String? { try tokenStore.read() }
    func setToken(_ token: String?) throws {
        if let token, !token.isEmpty { try tokenStore.write(token) }
        else { try tokenStore.delete() }
        tokenRevision += 1
    }
}
