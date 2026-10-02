import SwiftUI

struct RemoteMCPSettingsSection: View {
    @ObservedObject private var service: RemoteSyncService
    @ObservedObject private var settings: RemoteSyncSettings
    @State private var serverURL = ""
    @State private var token = ""
    @State private var hasSavedToken = false
    @State private var tokenError: String?
    @State private var isTesting = false
    @State private var connectionResult: Result<Void, Error>?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case serverURL, token
    }

    init(service: RemoteSyncService) {
        self.service = service
        self.settings = service.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Remote MCP", systemImage: "server.rack")
                .font(.headline)

            Text("Optional. Lets AI assistants read and edit your Minds and Memories through a server you host yourself.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Enable", isOn: Binding(
                get: { settings.isEnabled },
                set: { enabled in
                    saveServerURL()
                    settings.isEnabled = enabled
                    connectionResult = nil
                    if enabled { service.start() }
                    else { service.stop() }
                }
            ))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.subheadline)
                serverURLField
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .serverURL)
                    .onSubmit { saveServerURL() }

                Text("API token")
                    .font(.subheadline)
                tokenField
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .token)
                    .onSubmit { if !token.isEmpty { saveToken(token) } }

                HStack {
                    Button("Save token") { saveToken(token) }
                        .disabled(token.isEmpty || isTesting)
                    Button("Clear token", role: .destructive) { saveToken(nil) }
                        .disabled((!hasSavedToken && token.isEmpty) || isTesting)
                }

                if let tokenError {
                    Text(tokenError)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(isTesting)

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
                Button("Sync now") {
                    focusedField = nil
                    Task { await service.syncNow() }
                }
            }
            .disabled(!canPerformActions)

            if let connectionResult {
                switch connectionResult {
                case .success:
                    Text("Connection successful")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.success)
                case .failure(let error):
                    Text("Error: \(safeMessage(error.localizedDescription))")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .onAppear {
            serverURL = settings.serverURL
            refreshSavedToken()
        }
        .onChange(of: focusedField) { oldField, _ in
            if oldField == .serverURL { saveServerURL() }
        }
        .onChange(of: serverURL) { _, _ in connectionResult = nil }
        .onChange(of: token) { _, _ in connectionResult = nil }
        .onChange(of: settings.tokenRevision) { _, _ in refreshSavedToken() }
        .onDisappear {
            saveServerURL()
            token = ""
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

    private var tokenField: some View {
        SecureField(hasSavedToken ? "••••••••" : "API token", text: $token)
            .accessibilityLabel(hasSavedToken ? "API token, saved. Enter a replacement." : "API token")
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
            case .error(let message):
                Text("Error: \(safeMessage(message))")
                    .foregroundStyle(Color.Theme.destructive)
            }
        }
    }

    private var canPerformActions: Bool {
        guard settings.isEnabled, service.client.isConfigured, !isTesting,
              serverURL.trimmingCharacters(in: .whitespacesAndNewlines) == settings.serverURL,
              token.isEmpty else { return false }
        if case .syncing = service.status { return false }
        return true
    }

    private func saveServerURL() {
        let value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.serverURL != value {
            settings.serverURL = value
            connectionResult = nil
        }
    }

    private func saveToken(_ value: String?) {
        do {
            try settings.setToken(value)
            token = ""
            tokenError = nil
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
