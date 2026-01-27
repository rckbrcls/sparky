//
//  DataManagementView.swift
//  i-cant-miss
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
        // ViewModel will be initialized in onAppear with environment
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
                exportSection
            }
            
            Section {
                importSection
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $viewModel.isExporting,
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
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Data")
                .font(.headline)
            
            Text("Export all your memories, minds, and lobes to a JSON file for backup or migration.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Export Options", selection: $viewModel.exportOptions) {
                Text("Full Export").tag(DataExportService.ExportOptions.full)
                Text("Without Attachments").tag(DataExportService.ExportOptions.withoutAttachments)
                Text("Active Only").tag(DataExportService.ExportOptions.activeOnly)
                Text("Active Only (No Attachments)").tag(DataExportService.ExportOptions.activeOnlyWithoutAttachments)
            }
            .pickerStyle(.menu)
            
            Button {
                Task {
                    await viewModel.exportData()
                }
            } label: {
                HStack {
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Export Data")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting)
        }
        .padding(.vertical, 8)
    }
    
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Data")
                .font(.headline)
            
            Text("Import memories, minds, and lobes from a previously exported JSON file.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                viewModel.isImporting = true
            } label: {
                HStack {
                    if viewModel.isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("Import Data")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isImporting)
        }
        .padding(.vertical, 8)
    }
}

@MainActor
final class DataManagementViewModel: ObservableObject {
    @Published var exportOptions: DataExportService.ExportOptions = .full
    @Published var isExporting = false
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
                lobeService: env.lobeService,
                attachmentStore: env.attachmentStore
            )
            self.importService = DataImportService(
                memoryService: env.memoryService,
                mindService: env.mindService,
                lobeService: env.lobeService,
                attachmentStore: env.attachmentStore
            )
        }
    }
    
    func updateEnvironment(_ environment: AppEnvironment) {
        self.environment = environment
        self.exportService = DataExportService(
            memoryService: environment.memoryService,
            mindService: environment.mindService,
            lobeService: environment.lobeService,
            attachmentStore: environment.attachmentStore
        )
        self.importService = DataImportService(
            memoryService: environment.memoryService,
            mindService: environment.mindService,
            lobeService: environment.lobeService,
            attachmentStore: environment.attachmentStore
        )
    }
    
    func exportData() async {
        guard let exportService = exportService else { return }
        isExporting = true
        defer { isExporting = false }
        
        do {
            let data = try await exportService.export(options: exportOptions)
            exportDocument = ExportDocument(data: data)
            exportMessage = "Export completed successfully. Choose where to save the file."
            showExportAlert = true
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
            
            do {
                let importResult = try await importService.importFromFile(at: url)
                
                var message = "Import completed!\n\n"
                message += "• Minds: \(importResult.importedMinds)\n"
                message += "• Lobes: \(importResult.importedLobes)\n"
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
