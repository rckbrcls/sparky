import SwiftUI

struct RemoteSyncLogScreen: View {
    @ObservedObject var service: RemoteSyncService

    var body: some View {
        SettingsPane {
            if service.syncLog.isEmpty {
                Text("No sync errors yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardStyle()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(service.syncLog.reversed().enumerated()), id: \.element.id) { index, entry in
                        logRow(entry)
                        if index < service.syncLog.count - 1 {
                            Divider()
                        }
                    }
                }
                .cardStyle()
            }
        }
        .navigationTitle("Logs")
        .inlinePhoneNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Clear") { service.clearSyncLog() }
                    .disabled(service.syncLog.isEmpty)
            }
        }
    }

    private func logRow(_ entry: RemoteSyncLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(logTime(entry.date))  \(entry.method)  \(entry.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(safeMessage(entry.message))
                .font(.caption)
                .foregroundStyle(Color.Theme.destructive)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func logTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func safeMessage(_ message: String) -> String {
        guard let savedToken = try? service.settings.readToken(), !savedToken.isEmpty else { return message }
        return message.replacingOccurrences(of: savedToken, with: "••••••••")
    }
}
