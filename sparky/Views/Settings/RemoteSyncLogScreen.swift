import SwiftUI
#if os(macOS)
import AppKit
#endif

struct RemoteSyncLogScreen: View {
    @ObservedObject var service: RemoteSyncService
    #if os(macOS)
    private enum CopyTarget: Equatable {
        case all
        case entry(UUID)
    }

    @State private var copiedTarget: CopyTarget?
    @State private var copyFeedbackRevision = 0
    #endif

    var body: some View {
        #if os(macOS)
        logContent
            .frame(minWidth: 480, minHeight: 320)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(
                        copiedTarget == .all ? "Copied" : "Copy Logs",
                        systemImage: copiedTarget == .all ? "checkmark" : "doc.on.doc"
                    ) {
                        copyLogs(Array(service.syncLog.reversed()), target: .all)
                    }
                    .labelStyle(.titleAndIcon)
                    .disabled(service.syncLog.isEmpty)
                    Button("Clear") {
                        copiedTarget = nil
                        service.clearSyncLog()
                    }
                    .disabled(service.syncLog.isEmpty)
                }
            }
            .task(id: copyFeedbackRevision) {
                guard copiedTarget != nil else { return }
                do {
                    try await Task.sleep(for: .seconds(2))
                    copiedTarget = nil
                } catch {}
            }
        #else
        logContent
            .navigationTitle("Logs")
            .inlinePhoneNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") { service.clearSyncLog() }
                        .disabled(service.syncLog.isEmpty)
                }
            }
        #endif
    }

    private var logContent: some View {
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
    }

    private func logRow(_ entry: RemoteSyncLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(logTime(entry.date))  \(entry.method)  \(entry.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                #if os(macOS)
                Spacer(minLength: 0)
                Button(
                    copiedTarget == .entry(entry.id) ? "Copied" : "Copy",
                    systemImage: copiedTarget == .entry(entry.id) ? "checkmark" : "doc.on.doc"
                ) {
                    copyLogs([entry], target: .entry(entry.id))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .frame(width: 78, alignment: .trailing)
                .help("Copy all details for this log")
                .accessibilityLabel(copiedTarget == .entry(entry.id) ? "Log copied" : "Copy Log")
                #endif
            }
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
        #if os(macOS)
        .contextMenu {
            Button("Copy Log", systemImage: "doc.on.doc") {
                copyLogs([entry], target: .entry(entry.id))
            }
        }
        #endif
    }

    #if os(macOS)
    private func copyLogs(_ entries: [RemoteSyncLogEntry], target: CopyTarget) {
        let text = entries.map { entry in
            """
            ID: \(entry.id.uuidString)
            Date: \(entry.date.ISO8601Format())
            Method: \(entry.method)
            Path: \(entry.path)
            HTTP Status: \(entry.status)
            Message: \(safeMessage(entry.message))
            """
        }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(text, forType: .string) {
            copiedTarget = target
            copyFeedbackRevision += 1
        }
    }
    #endif

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
