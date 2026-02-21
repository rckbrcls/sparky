//
//  DataManagementView.swift
//  sparky
//
//  Created by Codex on 26/01/26.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: DataManagementViewModel

    init() {
        _viewModel = StateObject(wrappedValue: DataManagementViewModel(environment: nil))
    }

    var body: some View {
        List {
            Text("Data Management")
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Section {
                exportRow
                importRow
            }
            .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $viewModel.showFileExporter,
            document: viewModel.exportDocument,
            contentType: .json,
            defaultFilename: viewModel.exportFilename
        ) { result in
            viewModel.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImportResult(result)
        }
        .alert("Export", isPresented: $viewModel.showExportAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.exportMessage)
        }
        .alert("Import", isPresented: $viewModel.showImportAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.importMessage)
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.updateEnvironment(environment)
        }
    }

    // MARK: - Export Row

    private var exportRow: some View {
        Menu {
            Button {
                exportWithOption(.full)
            } label: {
                Label("Full Export", systemImage: "doc.zipper")
            }

            Button {
                exportWithOption(.withoutAttachments)
            } label: {
                Label("Without Attachments", systemImage: "doc.text")
            }

            Button {
                exportWithOption(.activeOnly)
            } label: {
                Label("Active Only", systemImage: "checkmark.circle")
            }

            Button {
                exportWithOption(.activeOnlyWithoutAttachments)
            } label: {
                Label("Active Only (No Attachments)", systemImage: "checkmark.circle.badge.xmark")
            }
        } label: {
            HStack(spacing: 16) {
                if viewModel.isExportingData {
                    ProgressView()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 24, height: 24, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Data")
                        .foregroundStyle(.primary)

                    Text(viewModel.isExportingData ? "Preparing export..." : "Backup your memories and minds to JSON")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .cardStyle()
        }
        .disabled(viewModel.isExportingData)
    }

    // MARK: - Import Row

    private var importRow: some View {
        Button {
            viewModel.isImporting = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Data")
                        .foregroundStyle(.primary)
                    Text("Restore from a previously exported JSON file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func exportWithOption(_ option: DataExportService.ExportOptions) {
        viewModel.exportOptions = option
        Task {
            await viewModel.exportData()
        }
    }
}

@MainActor
final class DataManagementViewModel: ObservableObject {
    @Published var exportOptions: DataExportService.ExportOptions = .full
    @Published var isExportingData = false
    @Published var showFileExporter = false
    @Published var isImporting = false
    @Published var showExportAlert = false
    @Published var showImportAlert = false
    @Published var showErrorAlert = false
    @Published var exportMessage = ""
    @Published var importMessage = ""
    @Published var errorMessage = ""

    var exportDocument: ExportDocument?
    var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "sparky-export-\(formatter.string(from: Date())).json"
    }

    private var environment: AppEnvironment?
    private var exportService: DataExportService?
    private var importService: DataImportService?

    init(environment: AppEnvironment?) {
        self.environment = environment
        if let env = environment {
            self.exportService = DataExportService(
                memoryService: env.memoryService,
                mindService: env.mindService,
                attachmentStore: env.attachmentStore
            )
            self.importService = DataImportService(
                memoryService: env.memoryService,
                mindService: env.mindService,
                attachmentStore: env.attachmentStore
            )
        }
    }

    func updateEnvironment(_ environment: AppEnvironment) {
        self.environment = environment
        self.exportService = DataExportService(
            memoryService: environment.memoryService,
            mindService: environment.mindService,
            attachmentStore: environment.attachmentStore
        )
        self.importService = DataImportService(
            memoryService: environment.memoryService,
            mindService: environment.mindService,
            attachmentStore: environment.attachmentStore
        )
    }

    func exportData() async {
        guard let exportService = exportService else { return }
        isExportingData = true
        defer { isExportingData = false }

        do {
            let data = try await exportService.export(options: exportOptions)
            exportDocument = ExportDocument(data: data)
            showFileExporter = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportMessage = "Data exported successfully!"
            showExportAlert = true
        case .failure(let error):
            errorMessage = "Failed to save export file: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    func handleImportResult(_ result: Result<[URL], Error>) {
        Task {
            await performImport(result: result)
        }
    }

    private func performImport(result: Result<[URL], Error>) async {
        guard let importService = importService else { return }
        isImporting = true
        defer { isImporting = false }

        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "No file selected."
                showErrorAlert = true
                return
            }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permission denied to access the selected file."
                showErrorAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let importResult = try await importService.importFromFile(at: url)

                var message = "Import completed!\n\n"
                message += "• Minds: \(importResult.importedMinds)\n"
                message += "• Memories: \(importResult.importedMemories)\n"
                message += "• Attachments: \(importResult.importedAttachments)"

                if importResult.hasErrors {
                    message += "\n\nSome items failed to import. Check the logs for details."
                }

                importMessage = message
                showImportAlert = true
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }

        case .failure(let error):
            errorMessage = "Failed to read import file: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static var json: UTType {
        UTType(filenameExtension: "json") ?? .text
    }
}
