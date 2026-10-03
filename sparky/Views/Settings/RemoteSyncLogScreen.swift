import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct RemoteSyncLogScreen: View {
    @ObservedObject var service: RemoteSyncService
    private enum CopyTarget: Equatable {
        case all
        case entry(UUID)
    }

    @State private var copiedTarget: CopyTarget?
    @State private var copyFeedbackRevision = 0

    var body: some View {
        #if os(macOS)
        logContent
            .frame(minWidth: 480, minHeight: 320)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    copyLogsButton
                    clearLogsButton
                }
            }
        #else
        logContent
            .navigationTitle("Logs")
            .inlinePhoneNavigationTitle()
            .toolbar {
                ToolbarItemGroup(placement: .confirmationAction) {
                    copyLogsButton
                    clearLogsButton
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
        .task(id: copyFeedbackRevision) {
            guard copiedTarget != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                copiedTarget = nil
            } catch {}
        }
    }

    private var copyLogsButton: some View {
        Button(
            copiedTarget == .all ? "Copied" : "Copy Logs",
            systemImage: copiedTarget == .all ? "checkmark" : "doc.on.doc"
        ) {
            copyLogs(Array(service.syncLog.reversed()), target: .all)
        }
        .labelStyle(.titleAndIcon)
        .disabled(service.syncLog.isEmpty)
    }

    private var clearLogsButton: some View {
        Button("Clear") {
            copiedTarget = nil
            service.clearSyncLog()
        }
        .disabled(service.syncLog.isEmpty)
    }

    private func logRow(_ entry: RemoteSyncLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(logTime(entry.date))  \(entry.method)  \(entry.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                copyEntryButton(entry)
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
        .contextMenu {
            Button("Copy Log", systemImage: "doc.on.doc") {
                copyLogs([entry], target: .entry(entry.id))
            }
        }
    }

    @ViewBuilder
    private func copyEntryButton(_ entry: RemoteSyncLogEntry) -> some View {
        let copied = copiedTarget == .entry(entry.id)
        #if os(macOS)
        Button(
            copied ? "Copied" : "Copy",
            systemImage: copied ? "checkmark" : "doc.on.doc"
        ) {
            copyLogs([entry], target: .entry(entry.id))
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .frame(width: 78, alignment: .trailing)
        .help("Copy all details for this log")
        .accessibilityLabel(copied ? "Log copied" : "Copy Log")
        #else
        Button {
            copyLogs([entry], target: .entry(entry.id))
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .frame(width: 28, height: 28)
                .buttonHitArea(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(copied ? "Log copied" : "Copy Log")
        #endif
    }

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
        guard writeToPasteboard(text) else { return }
        copiedTarget = target
        copyFeedbackRevision += 1
    }

    private func writeToPasteboard(_ text: String) -> Bool {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        return true
        #endif
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
