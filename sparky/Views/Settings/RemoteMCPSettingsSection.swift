import SwiftUI

struct RemoteMCPSettingsSection: View {
    private static let repositoryURL = URL(string: "https://github.com/rckbrcls/sparky-mcp")!

    @Environment(\.openURL) private var openURL
    @ObservedObject private var service: RemoteSyncService
    @ObservedObject private var settings: RemoteSyncSettings
    @State private var serverURL = ""
    @State private var hasSavedToken = false
    @State private var tokenError: String?
    @State private var pairingCode = ""
    @State private var isPairing = false
    @State private var pairingMessage: String?
    @State private var pairingSucceeded = false
    @State private var pairingTask: Task<Void, Never>?
    @State private var isTesting = false
    @State private var connectionResult: Result<Void, Error>?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case serverURL, pairingCode
    }

    init(service: RemoteSyncService) {
        self.service = service
        self.settings = service.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Remote MCP", systemImage: "server.rack")
                        .font(.headline)

                    Text("Lets AI assistants read and edit your Minds and Memories through a server you host yourself.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Toggle("Enable Remote MCP", isOn: Binding(
                    get: { settings.isEnabled },
                    set: { setEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(isPairing)
            }

            if settings.isEnabled {
                configurationContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: settings.isEnabled)
        .onAppear {
            serverURL = settings.serverURL
            refreshSavedToken()
        }
        .onChange(of: focusedField) { oldField, _ in
            if oldField == .serverURL { saveServerURL() }
        }
        .onChange(of: serverURL) { _, _ in
            connectionResult = nil
            if !isPairing && !(pairingSucceeded && serverURL == settings.serverURL) {
                pairingMessage = nil
                pairingSucceeded = false
            }
        }
        .onChange(of: pairingCode) { _, _ in
            if !isPairing && !(pairingSucceeded && pairingCode.isEmpty) {
                pairingMessage = nil
                pairingSucceeded = false
            }
        }
        .onChange(of: settings.tokenRevision) { _, _ in refreshSavedToken() }
        .onDisappear {
            pairingTask?.cancel()
            saveServerURL()
            pairingCode = ""
        }
    }

    private func setEnabled(_ enabled: Bool) {
        guard enabled != settings.isEnabled else { return }
        saveServerURL()
        settings.isEnabled = enabled
        connectionResult = nil
        if enabled { service.start() }
        else { service.stop() }
    }

    private var configurationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Button {
                openURL(Self.repositoryURL)
            } label: {
                Label("Get sparky-mcp on GitHub", systemImage: "arrow.up.right.square")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.subheadline)
                serverURLField
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .serverURL)
                    .onSubmit { saveServerURL() }

                Text("Pairing code")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    pairingCodeField
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .pairingCode)
                        .onSubmit { if canPair { pair() } }
                    Button(action: pair) {
                        HStack(spacing: 6) {
                            if isPairing { ProgressView().controlSize(.small) }
                            Text(isPairing ? "Pairing…" : "Pair")
                        }
                    }
                    .disabled(!canPair)
                }

                if let pairingMessage {
                    Text(pairingMessage)
                        .font(.caption)
                        .foregroundStyle(pairingSucceeded ? Color.Theme.success : Color.Theme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let tokenError {
                    Text(tokenError)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(isTesting || isPairing)

            Divider()

            HStack(alignment: .top) {
                Text("Status")
                    .foregroundStyle(.secondary)
                Spacer()
                statusLabel
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption)

            HStack(spacing: 12) {
                Button {
                    focusedField = nil
                    connectionResult = nil
                    isTesting = true
                    Task {
                        let result = await service.testConnection()
                        connectionResult = settings.isEnabled ? result : nil
                        isTesting = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Test connection")
                    }
                }
                .disabled(!canPerformActions)

                Button("Sync now") {
                    focusedField = nil
                    Task { await service.syncNow() }
                }
                .disabled(!canPerformActions)

                Spacer()

                if hasSavedToken {
                    Button("Disconnect", role: .destructive) { saveToken(nil) }
                        .foregroundStyle(Color.Theme.destructive)
                        .disabled(isTesting || isPairing)
                }
            }

            if let connectionResult {
                switch connectionResult {
                case .success:
                    Text("Connection successful")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.success)
                case .failure(let error):
                    Text(connectionFailureText(error))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.destructive)
                }
            }

            Divider()

            NavigationLink {
                RemoteSyncLogScreen(service: service)
            } label: {
                HStack {
                    Text("Logs")
                    Spacer()
                    if !service.syncLog.isEmpty {
                        Text("\(service.syncLog.count)")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var serverURLField: some View {
        TextField("https://your-server.example.ts.net", text: $serverURL)
            .accessibilityLabel("Server URL")
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            #endif
    }

    private var pairingCodeField: some View {
        TextField("XXXX-XXXX", text: $pairingCode)
            .accessibilityLabel("Pairing code")
            .font(.body.monospaced())
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !settings.isEnabled {
            Text("Disabled")
        } else if !service.client.isConfigured {
            Text("Not configured")
        } else {
            switch service.status {
            case .disabled:
                Text("Disabled")
            case .notConfigured:
                Text("Not configured")
            case .idle(let lastSync):
                if let date = lastSync ?? service.lastSyncedAt {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text("Synced \(relativeTime(date, to: context.date))")
                    }
                } else {
                    Text("Not synced yet")
                }
            case .syncing:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Syncing…")
                }
            case .error:
                Text("Sync failed")
                    .foregroundStyle(Color.Theme.destructive)
            }
        }
    }

    private var canPerformActions: Bool {
        guard settings.isEnabled, service.client.isConfigured, !isTesting, !isPairing,
              (RemoteSyncSettings.normalizedServerURL(serverURL)?.absoluteString
                ?? serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) == settings.serverURL else { return false }
        if case .syncing = service.status { return false }
        return true
    }

    private func saveServerURL() {
        let value = RemoteSyncSettings.normalizedServerURL(serverURL)?.absoluteString
            ?? serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.serverURL != value {
            settings.serverURL = value
            connectionResult = nil
        }
    }

    private var canPair: Bool {
        !isPairing && !isTesting
            && !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !RemotePairingClient.normalizeCode(pairingCode).isEmpty
    }

    private func pair() {
        guard canPair else { return }
        focusedField = nil
        pairingMessage = nil
        pairingSucceeded = false
        connectionResult = nil
        guard let url = RemoteSyncSettings.normalizedServerURL(serverURL) else {
            pairingMessage = "Enter a valid HTTPS server URL. HTTP is only allowed for local development servers."
            return
        }
        let code = pairingCode
        isPairing = true
        pairingTask = Task {
            defer { isPairing = false; pairingTask = nil }
            let redeemedToken: String
            do {
                redeemedToken = try await RemotePairingClient().redeemPairingCode(serverURL: url.absoluteString, code: code)
                try Task.checkCancellation()
            } catch is CancellationError {
                return
            } catch let error as RemotePairingError {
                pairingMessage = pairingErrorMessage(error)
                return
            } catch {
                pairingMessage = "Cannot reach the server. Check the URL."
                return
            }
            do {
                try settings.setToken(redeemedToken)
            } catch {
                pairingMessage = "Could not save the API token in Keychain. Please try again."
                return
            }
            settings.serverURL = url.absoluteString
            serverURL = url.absoluteString
            settings.isEnabled = true
            tokenError = nil
            pairingCode = ""
            refreshSavedToken()
            pairingSucceeded = true
            pairingMessage = "Paired. Sync is on."
            service.start()
            isTesting = true
            let result = await service.testConnection()
            if !Task.isCancelled { connectionResult = settings.isEnabled ? result : nil }
            isTesting = false
        }
    }

    private func pairingErrorMessage(_ error: RemotePairingError) -> String {
        switch error {
        case .invalidCode:
            return "That code is invalid or expired. Run sparky-mcp pair on your server for a new one."
        case .tooManyAttempts(let retryAfter):
            if let seconds = retryAfter {
                let minutes = max(1, seconds / 60 + (seconds % 60 == 0 ? 0 : 1))
                return "Too many attempts. Try again in \(minutes) \(minutes == 1 ? "minute" : "minutes")."
            } else {
                return "Too many attempts. Try again later."
            }
        case .invalidRequest:
            return "The pairing request was rejected. Check the URL and code."
        case .network:
            return "Cannot reach the server. Check the URL."
        case .unexpectedResponse:
            return "The server returned an unexpected response. Check the URL and try again."
        }
    }

    private func saveToken(_ value: String?) {
        do {
            try settings.setToken(value)
            tokenError = nil
            pairingMessage = nil
            connectionResult = nil
            refreshSavedToken()
        } catch {
            tokenError = "Could not save the API token in Keychain. Please try again."
        }
    }

    private func refreshSavedToken() {
        do {
            hasSavedToken = try settings.readToken().map { !$0.isEmpty } ?? false
            tokenError = nil
        } catch {
            hasSavedToken = false
            tokenError = "Could not read the API token from Keychain. Please try again."
        }
    }

    private func connectionFailureText(_ error: Error) -> String {
        if case RemoteSyncError.http = error { return "Connection failed" }
        return "Error: \(safeMessage(error.localizedDescription))"
    }

    private func safeMessage(_ message: String) -> String {
        guard let savedToken = try? settings.readToken(), !savedToken.isEmpty else { return message }
        return message.replacingOccurrences(of: savedToken, with: "••••••••")
    }

    private func relativeTime(_ date: Date, to now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
