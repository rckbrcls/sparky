import SwiftUI

struct RemoteMCPSettingsSection: View {
    private static let repositoryURL = URL(string: "https://github.com/rckbrcls/sparky-mcp")!

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @FocusState private var focusedField: Field?
    private let onOpenLogs: () -> Void

    private enum Field: Hashable {
        case serverURL, pairingCode
    }

    init(service: RemoteSyncService, onOpenLogs: @escaping () -> Void = {}) {
        self.service = service
        self.settings = service.settings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        Group {
            #if os(iOS)
            iosScreen
            #else
            macScreen
            #endif
        }
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

    #if os(iOS)
    private var iosScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerCard

            if settings.isEnabled {
                fieldsCard
                actionsCard
                logsCard
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label("Remote MCP", systemImage: "server.rack")
                    .font(.headline)

                Spacer(minLength: 0)

                Toggle("Enable Remote MCP", isOn: Binding(
                    get: { settings.isEnabled },
                    set: { setEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(isPairing)
            }

            Text("Lets AI assistants read and edit your Minds and Memories through a server you host yourself.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            glassButton(
                title: "Get sparky-mcp on GitHub",
                systemImage: "arrow.up.right.square",
                prominent: false
            ) {
                openURL(Self.repositoryURL)
            }
        }
        .padding(12)
        .cardStyle()
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.subheadline)
                phoneField(
                    serverURLField
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .serverURL)
                        .onSubmit { saveServerURL() }
                )

                Text("Pairing code")
                    .font(.subheadline)
                phoneField(
                    pairingCodeField
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .pairingCode)
                        .onSubmit { if canPair { pair() } }
                )

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
            .padding(12)
            .disabled(isTesting || isPairing)

            pairButton
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .cardStyle()
    }

    private var pairButton: some View {
        glassButton(
            title: isPairing ? "Pairing…" : "Pair",
            systemImage: "link",
            showsProgress: isPairing,
            prominent: true,
            action: pair
        )
        .disabled(!canPair || isTesting || isPairing)
        .opacity((canPair || isPairing) && !isTesting ? 1 : 0.45)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text("Status")
                    .foregroundStyle(.secondary)
                Spacer()
                statusLabel
                    .multilineTextAlignment(.trailing)
            }
            .font(.caption)
            .padding(12)

            connectionButtons
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            if hasSavedToken {
                cardDivider

                Button { saveToken(nil) } label: {
                    settingsActionLabel(
                        title: "Disconnect",
                        systemImage: "xmark.circle",
                        tint: Color.Theme.destructive
                    )
                }
                .buttonStyle(.plain)
                .disabled(isTesting || isPairing)
            }

            if let connectionResult {
                cardDivider
                connectionResultLabel(connectionResult)
                    .padding(12)
            }
        }
        .cardStyle()
    }

    private var connectionButtons: some View {
        HStack(spacing: 8) {
            glassButton(
                title: "Test connection",
                systemImage: "antenna.radiowaves.left.and.right",
                showsProgress: isTesting,
                prominent: false
            ) {
                focusedField = nil
                connectionResult = nil
                isTesting = true
                Task {
                    let result = await service.testConnection()
                    connectionResult = settings.isEnabled ? result : nil
                    isTesting = false
                }
            }
            .disabled(!canPerformActions)
            .opacity(canPerformActions ? 1 : 0.45)

            glassButton(
                title: "Sync now",
                systemImage: "arrow.triangle.2.circlepath",
                prominent: false
            ) {
                focusedField = nil
                Task { await service.syncNow() }
            }
            .disabled(!canPerformActions)
            .opacity(canPerformActions ? 1 : 0.45)
        }
    }

    private func glassButton(
        title: String,
        systemImage: String,
        showsProgress: Bool = false,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsProgress {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.Theme.accentForeground : Color.Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .glassEffect(
            prominent
                ? .regular.interactive().tint(Color.accentColor)
                : .regular.interactive(),
            in: .capsule
        )
    }

    private var logsCard: some View {
        Button(action: onOpenLogs) {
            settingsActionLabel(
                title: service.syncLog.isEmpty ? "Logs" : "Logs (\(service.syncLog.count))",
                systemImage: "doc.text.magnifyingglass",
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .cardStyle()
        .accessibilityLabel("Open Logs")
    }

    private var cardDivider: some View {
        Divider()
            .padding(.leading, 52)
            .padding(.trailing, 12)
    }

    private func phoneField<Content: View>(_ content: Content) -> some View {
        content
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.Theme.elementBackground)
            }
    }

    private func settingsActionLabel(
        title: String,
        systemImage: String,
        tint: Color = .primary,
        showsProgress: Bool = false,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 24, height: 24, alignment: .center)
                .foregroundStyle(tint)

            Text(title)
                .foregroundStyle(tint)

            Spacer(minLength: 0)

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .contentShape(Rectangle())
    }

    private func connectionResultLabel(_ result: Result<Void, Error>) -> some View {
        switch result {
        case .success:
            Text("Connection successful")
                .font(.caption)
                .foregroundStyle(Color.Theme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failure(let error):
            Text(connectionFailureText(error))
                .font(.caption)
                .foregroundStyle(Color.Theme.destructive)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    #endif

    private var macScreen: some View {
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private func setEnabled(_ enabled: Bool) {
        guard enabled != settings.isEnabled else { return }
        if !enabled {
            focusedField = nil
        }
        saveServerURL()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            settings.isEnabled = enabled
        }
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
                pairingCodeControls

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

            connectionActions

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

            #if os(macOS)
            Divider()

            Button {
                openWindow(id: "remote-sync-logs")
            } label: {
                logsLabel
            }
            .accessibilityLabel("Open Logs")
            #endif
        }
    }

    private var pairingCodeControls: some View {
        let field = pairingCodeField
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .pairingCode)
            .onSubmit { if canPair { pair() } }

        #if os(iOS)
        return VStack(alignment: .leading, spacing: 8) {
            field
            Button(action: pair) {
                actionRow(
                    title: isPairing ? "Pairing…" : "Pair",
                    systemImage: "link",
                    showsProgress: isPairing
                )
            }
            .buttonStyle(.borderless)
            .disabled(!canPair)
        }
        #else
        return HStack(spacing: 8) {
            field
            Button(action: pair) {
                HStack(spacing: 6) {
                    if isPairing { ProgressView().controlSize(.small) }
                    Text(isPairing ? "Pairing…" : "Pair")
                }
            }
            .disabled(!canPair)
        }
        #endif
    }

    private var connectionActions: some View {
        #if os(iOS)
        VStack(spacing: 0) {
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
                actionRow(
                    title: "Test connection",
                    systemImage: "antenna.radiowaves.left.and.right",
                    showsProgress: isTesting
                )
            }
            .buttonStyle(.borderless)
            .disabled(!canPerformActions)

            Divider()
                .padding(.leading, 40)

            Button {
                focusedField = nil
                Task { await service.syncNow() }
            } label: {
                actionRow(title: "Sync now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderless)
            .disabled(!canPerformActions)

            if hasSavedToken {
                Divider()
                    .padding(.leading, 40)

                Button { saveToken(nil) } label: {
                    actionRow(
                        title: "Disconnect",
                        systemImage: "xmark.circle",
                        tint: Color.Theme.destructive
                    )
                }
                .buttonStyle(.borderless)
                .disabled(isTesting || isPairing)
            }
        }
        #else
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
        #endif
    }

    private func actionRow(title: String, systemImage: String, tint: Color = .primary, showsProgress: Bool = false) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 24, height: 24, alignment: .center)
                .foregroundStyle(tint)

            Text(title)
                .foregroundStyle(tint)

            Spacer(minLength: 0)

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var logsLabel: some View {
        Label(
            service.syncLog.isEmpty ? "Logs" : "Logs (\(service.syncLog.count))",
            systemImage: "doc.text.magnifyingglass"
        )
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
