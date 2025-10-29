//
//  MemoryEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import Contacts
import PhotosUI
import UIKit

struct MemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MemoryEditorViewModel
    @State private var showScheduleSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showTrigger = false
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false
    @State private var checklistDraftRows: [ChecklistDraftRow] = [ChecklistDraftRow()]
    @FocusState private var focusedDraftID: UUID?
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var showCameraPicker = false
    @State private var mediaErrorMessage: String?
    @State private var scrollOffset: CGFloat = 20
    private let isEditing: Bool
    private let defaultHeaderHeight: CGFloat = 150
    private let minHeaderHeight: CGFloat = 80
    private let transitionThreshold: CGFloat = 36

    init(environment: AppEnvironment,
         memory: MemoryModel? = nil,
         defaultSpace: SpaceModel? = nil,
        template: MemoryEditorTemplate = .blank) {
        _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: memory,
            defaultSpace: defaultSpace,
            template: template
        ))
        self.isEditing = memory != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                let showMinimizedHeader = scrollOffset >= transitionThreshold
                
                // Calcula a opacidade baseada no scroll
                let expandedOpacity = max(0, min(1, 1 - (scrollOffset / transitionThreshold)))
                let minimizedOpacity = max(0, min(1, (scrollOffset - transitionThreshold / 2) / transitionThreshold))

                // Expanded Header
                if !showMinimizedHeader {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .frame(height: max(minHeaderHeight, defaultHeaderHeight - scrollOffset))
                            .allowsHitTesting(true)

                        let minOffset = defaultHeaderHeight - minHeaderHeight
                        let offset = scrollOffset <= 0 ? -scrollOffset : scrollOffset <= minOffset ? -scrollOffset : -minOffset

                        titleHeaderView()
                            .padding()
                            .frame(height: defaultHeaderHeight)
                            .frame(maxWidth: .infinity)
                            .offset(y: offset)
                            .opacity(expandedOpacity)
                    }
                    .zIndex(10)
                }

                // List with Form content
                List {
                    Color.clear
                        .frame(height: defaultHeaderHeight - 36)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    bodySection
                    triggersSection
                    photosSection
                    detailsSection
                    dueDateSection
                    extrasSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    return geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, new in
                    self.scrollOffset = new
                }

                // Minimized Header
                if showMinimizedHeader {
                    VStack(spacing: 0) {
                        // Spacer para a safe area do topo
                        Color.clear
                            .frame(height: 0)

                        TextField("Title", text: $viewModel.title, axis: .vertical)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .padding(.horizontal, 76)
                            .padding(.vertical, 20)
                            .frame(height: minHeaderHeight)
                            .opacity(minimizedOpacity)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                    )
                    .allowsHitTesting(true)
                    .zIndex(10)
                }

                // Toolbar buttons overlay
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .tint(.white)
                                .glassEffect(.regular.interactive())
                        }

                        Spacer()

                        Button {
                            commitChecklistDrafts()
                            Task {
                                let success = await viewModel.save()
                                if success { dismiss() }
                            }
                        } label: {
                            Group {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive().tint(.accent))
                        }
                        .disabled(viewModel.isSaving || (viewModel.title.isEmpty && viewModel.body.isEmpty))
                        .opacity(viewModel.isSaving || (viewModel.title.isEmpty && viewModel.body.isEmpty) ? 0.5 : 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()
                }
                .zIndex(100)
            }
            .onAppear {
                viewModel.loadLatestDataIfNeeded()
            }
            .onChange(of: photoSelections) { _, newValue in
                handlePhotoSelections(newValue)
            }
            .alert("Unable to save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showScheduleSheet) {
                MemoryScheduleTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView { name, latitude, longitude, radius, event in
                    viewModel.addLocationTrigger(name: name,
                                                 latitude: latitude,
                                                 longitude: longitude,
                                                 radius: radius,
                                                 event: event)
                    showLocationPicker = false
                }
            }
            .sheet(isPresented: $showPersonSheet) {
                MemoryPersonTriggerSheet(
                    viewModel: viewModel,
                    showContactPicker: $showContactPicker,
                    showAccessDeniedAlert: $showAccessDeniedAlert
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { contactName, contactId in
                    if let trigger = viewModel.triggers.first(where: { $0.type == .person }) {
                        var updated = trigger
                        updated.person = .init(name: contactName, contactIdentifier: contactId)
                        viewModel.updateTrigger(id: trigger.id, with: updated)
                    } else {
                        viewModel.addPersonTrigger(name: contactName, identifier: contactId)
                    }
                    showContactPicker = false
                }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraCaptureView {
                    addAttachment($0)
                    showCameraPicker = false
                } onCancel: {
                    showCameraPicker = false
                }
                .ignoresSafeArea()
            }
            .alert("Contacts Access Required", isPresented: $showAccessDeniedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Allow contact access in Settings to pick a person trigger.")
            }
            .alert("Unable to add photo", isPresented: Binding(
                get: { mediaErrorMessage != nil },
                set: { _ in mediaErrorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(mediaErrorMessage ?? "")
            }
        }
    }

    private var navigationTitle: String { isEditing ? "Edit Memory" : "New Memory" }

    private func titleHeaderView() -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 70)

            TextField("Title", text: $viewModel.title, axis: .vertical)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .submitLabel(.done)
                .lineLimit(1...2)
            Divider()
        }
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    private var detailsSection: some View {
        Section("Details") {
            SpacePicker(selection: Binding(
                get: { viewModel.selectedSpaceID ?? spacesForPicker.first?.id ?? SpaceModel.inbox.id },
                set: { viewModel.selectedSpaceID = $0 }
            ), spaces: spacesForPicker)

            Toggle("Pinned", isOn: $viewModel.isPinned)

            Picker("Status", selection: $viewModel.status) {
                ForEach(MemoryStatus.allCases) { status in
                    Text(status.rawValue.capitalized).tag(status)
                }
            }

            Picker("Priority", selection: $viewModel.priority) {
                ForEach(MemoryPriority.allCases) { priority in
                    Label(priorityLabel(for: priority), systemImage: priority.iconName)
                        .tag(priority)
                }
            }
        }
    }
    private var bodySection: some View {
        Section("Content") {
            TextEditor(text: $viewModel.body)
                .frame(minHeight: 100)

            ForEach(viewModel.checklistItems) { item in
                ChecklistItemEditor(
                    item: binding(for: item),
                    onToggle: { viewModel.toggleChecklistCompletion(for: item.id) },
                    onDelete: { removeChecklist(item) }
                )
            }
            ForEach(checklistDraftRows) { draft in
                ChecklistNewItemRow(
                    draft: draftBinding(for: draft),
                    focus: $focusedDraftID,
                    onSubmit: handleDraftSubmit,
                    onTitleChange: handleDraftTitleChange
                )
            }
        }
    }

    private var photosSection: some View {
        Section {
            if viewModel.attachments.isEmpty {
                Text("Attach photos to give this memory more context.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.attachments) { attachment in
                            if let image = UIImage(data: attachment.data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.thinMaterial, lineWidth: 1)
                                        )
                                    Button {
                                        removeAttachment(attachment.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.secondary.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.secondary)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity)
            }

            PhotosPicker(selection: $photoSelections,
                         maxSelectionCount: 5,
                         matching: .images) {
                HStack {
                    if isProcessingPhotos {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Label("Add from Library", systemImage: "photo.on.rectangle")
                }
            }
            .disabled(isProcessingPhotos)

            Button {
                handleCameraButtonTapped()
            } label: {
                Label("Open Camera", systemImage: "camera")
            }
            .disabled(isProcessingPhotos)
        } header: {
            Label("Photos", systemImage: "photo.stack")
        }
    }

    private var triggersSection: some View {
        Section {
            MemoryScheduleTriggerInlineForm(viewModel: viewModel, showSheet: $showScheduleSheet)

            MemoryLocationTriggerInlineForm(
                viewModel: viewModel,
                showLocationPicker: $showLocationPicker
            )

            MemoryPersonTriggerInlineForm(
                viewModel: viewModel,
                showSheet: $showPersonSheet
            )
        } header: {
            Label("Triggers", systemImage: "bolt.fill")
        }
    }

    private var dueDateSection: some View {
        Section("Due Date") {
            Toggle("Add due date", isOn: $viewModel.dueDateEnabled.animation())
            if viewModel.dueDateEnabled {
                DatePicker("Date", selection: $viewModel.dueDate, displayedComponents: [.date])
                DatePicker("Time", selection: $viewModel.dueDate, displayedComponents: [.hourAndMinute])
            }
        }
    }

    private var extrasSection: some View {
        Section("Preferences") {
            Toggle("Auto-complete when checklist is done", isOn: $viewModel.autoCompleteChecklist)
                .disabled(!viewModel.canToggleAutoComplete)
                .foregroundStyle(viewModel.canToggleAutoComplete ? .primary : .secondary)
        }
    }

    private func binding(for item: CheckItemDraft) -> Binding<CheckItemDraft> {
        guard let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $viewModel.checklistItems[index]
    }

    private func draftBinding(for draft: ChecklistDraftRow) -> Binding<ChecklistDraftRow> {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draft.id }) else {
            return .constant(draft)
        }
        return $checklistDraftRows[index]
    }

    private func handleDraftSubmit(_ draftID: UUID) {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draftID }) else { return }
        let trimmedTitle = checklistDraftRows[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            DispatchQueue.main.async {
                focusedDraftID = draftID
            }
            return
        }

        let trimmedDetail = checklistDraftRows[index].detail.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.addChecklistItem(title: trimmedTitle, detail: trimmedDetail)

        let nextID: UUID
        if index + 1 < checklistDraftRows.count {
            nextID = checklistDraftRows[index + 1].id
        } else {
            let placeholder = ChecklistDraftRow()
            checklistDraftRows.append(placeholder)
            nextID = placeholder.id
        }

        focusedDraftID = nextID
        checklistDraftRows.remove(at: index)

        if checklistDraftRows.isEmpty {
            let placeholder = ChecklistDraftRow()
            checklistDraftRows = [placeholder]
            focusedDraftID = placeholder.id
            return
        }

        cleanupTrailingPlaceholders()
    }

    private func handleDraftTitleChange(_ draftID: UUID, _ text: String) {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draftID }) else { return }
        guard !checklistDraftRows.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastIndex = checklistDraftRows.count - 1

        if trimmed.isEmpty {
            if checklistDraftRows.count > 1 && index != lastIndex {
                checklistDraftRows.remove(at: index)
            }
            cleanupTrailingPlaceholders()
        } else if index == lastIndex {
            checklistDraftRows.append(ChecklistDraftRow())
        }
    }

    private func cleanupTrailingPlaceholders() {
        while checklistDraftRows.count > 1 {
            guard let last = checklistDraftRows.last else { break }
            let beforeLast = checklistDraftRows[checklistDraftRows.count - 2]
            if last.isEffectivelyEmpty && beforeLast.isEffectivelyEmpty {
                checklistDraftRows.removeLast()
            } else {
                break
            }
        }

        if checklistDraftRows.isEmpty {
            checklistDraftRows = [ChecklistDraftRow()]
        }
    }

    private func commitChecklistDrafts() {
        let draftsToCommit = checklistDraftRows.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !draftsToCommit.isEmpty else { return }

        for draft in draftsToCommit {
            let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { continue }
            let trimmedDetail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.addChecklistItem(title: trimmedTitle, detail: trimmedDetail)
        }

        let committedIDs = Set(draftsToCommit.map(\.id))
        checklistDraftRows.removeAll { committedIDs.contains($0.id) }
        focusedDraftID = nil

        if checklistDraftRows.isEmpty {
            let placeholder = ChecklistDraftRow()
            checklistDraftRows = [placeholder]
            focusedDraftID = placeholder.id
        } else {
            cleanupTrailingPlaceholders()
        }
    }

    private func removeChecklist(_ item: CheckItemDraft) {
        if let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) {
            viewModel.checklistItems.remove(at: index)
            if viewModel.checklistItems.isEmpty {
                viewModel.showChecklist = false
            }
        }
    }

    private func priorityLabel(for priority: MemoryPriority) -> String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    private var spacesForPicker: [SpaceModel] {
        let spaces = viewModel.availableSpaces
        return spaces.isEmpty ? [SpaceModel.inbox] : spaces
    }

    private func handlePhotoSelections(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            await loadPhotos(from: items)
        }
    }

    private func handleCameraButtonTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            mediaErrorMessage = "Camera is not available on this device."
            return
        }
        showCameraPicker = true
    }

    @MainActor
    private func addAttachment(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            mediaErrorMessage = "The selected photo could not be processed."
            return
        }
        viewModel.addAttachment(data: data)
    }

    @MainActor
    private func removeAttachment(_ id: UUID) {
        viewModel.removeAttachment(id: id)
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        await MainActor.run {
            isProcessingPhotos = true
        }

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpegData = image.jpegData(compressionQuality: 0.85) {
                    await MainActor.run {
                        viewModel.addAttachment(data: jpegData)
                    }
                } else {
                    await MainActor.run {
                        mediaErrorMessage = "One of the selected photos could not be loaded."
                    }
                }
            } catch {
                await MainActor.run {
                    mediaErrorMessage = "One of the selected photos could not be loaded."
                }
            }
        }

        await MainActor.run {
            isProcessingPhotos = false
            photoSelections = []
        }
    }
}

private struct SpacePicker: View {
    @Binding var selection: UUID
    let spaces: [SpaceModel]

    var body: some View {
        Picker("Space", selection: $selection) {
            ForEach(spaces) { space in
                Text(space.name).tag(space.id)
            }
        }
    }
}

private struct ChecklistItemEditor: View {
    @Binding var item: CheckItemDraft
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                TextField("Item title", text: $item.title)
                    .submitLabel(.next)

                if shouldShowDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }

            TextField("Details", text: $item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .submitLabel(.next)
        }
        .padding(.vertical, 4)
    }

    private var shouldShowDelete: Bool {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || !detail.isEmpty
    }
}

private struct ChecklistNewItemRow: View {
    @Binding var draft: ChecklistDraftRow
    let focus: FocusState<UUID?>.Binding
    let onSubmit: (UUID) -> Void
    let onTitleChange: (UUID, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                TextField("New item", text: $draft.title)
                    .submitLabel(.next)
                    .focused(focus, equals: draft.id)
                    .onSubmit { onSubmit(draft.id) }
                    .onChange(of: draft.title) { _, newValue in
                        onTitleChange(draft.id, newValue)
                    }

                if shouldShowClear {
                    Button {
                        draft.title = ""
                        draft.detail = ""
                        onTitleChange(draft.id, "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }

            if shouldShowDetailField {
                TextField("Details", text: $draft.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .submitLabel(.next)
                    .onSubmit { onSubmit(draft.id) }
            }
        }
        .padding(.vertical, 4)
    }

    private var shouldShowClear: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !draft.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowDetailField: Bool {
        shouldShowClear
    }
}

private struct ChecklistDraftRow: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String

    init(id: UUID = UUID(), title: String = "", detail: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
    }

    var isEffectivelyEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                let onCapture = self.onCapture
                picker.dismiss(animated: true) {
                    onCapture(image)
                }
            } else {
                let onCancel = self.onCancel
                picker.dismiss(animated: true) {
                    onCancel()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            let onCancel = self.onCancel
            picker.dismiss(animated: true) {
                onCancel()
            }
        }
    }
}

// MARK: - Trigger Inline Forms

private struct MemoryScheduleTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var timeTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    private var weekdayTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    private var hasSchedule: Bool {
        timeTrigger != nil || weekdayTrigger != nil
    }

    var body: some View {
        if hasSchedule {
            Button {
                showSheet = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedulePrimaryText)
                            .font(.body)
                        if let detail = scheduleDetailText {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.clearScheduleTriggers()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Label("Add schedule", systemImage: "plus.circle.fill")
                        .foregroundStyle(.accent)
                    Spacer()
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var schedulePrimaryText: String {
        if let date = timeTrigger?.fireDate ?? weekdayTrigger?.fireDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if let mask = weekdayTrigger?.weekdayMask, mask != 0 {
            return weekdayMaskSummary(mask: mask)
        }
        return "Custom schedule"
    }

    private var scheduleDetailText: String? {
        var parts: [String] = []
        if let recurrence = timeTrigger?.recurrenceRule {
            var text = "Repeats \(recurrence.frequency.title.lowercased())"
            if recurrence.interval > 1 {
                text += " every \(recurrence.interval)"
            }
            parts.append(text)
        }
        if let mask = weekdayTrigger?.weekdayMask,
           mask != 0,
           timeTrigger?.fireDate != nil {
            parts.append(weekdayMaskSummary(mask: mask))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

private struct MemoryLocationTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showLocationPicker: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

    var body: some View {
        if let trigger, let location = trigger.location {
            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name ?? "Location")
                            .font(.body)
                        Text("\(Int(location.radius))m • \(location.event.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Label("Add location trigger", systemImage: "plus.circle.fill")
                        .foregroundStyle(.accent)
                    Spacer()
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MemoryPersonTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    var body: some View {
        if let trigger, let person = trigger.person {
            Button {
                showSheet = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(.body)
                        if person.contactIdentifier != nil {
                            Text("Linked contact")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Label("Add person trigger", systemImage: "plus.circle.fill")
                        .foregroundStyle(.accent)
                    Spacer()
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Trigger Sheets

private struct MemoryScheduleTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var date: Date
    @State private var selectedFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval: Int
    @State private var selectedWeekdays: Set<Int>
    @State private var includeTimeTrigger: Bool

    private var timeTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    private var weekdayTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    private var hasExistingSchedule: Bool {
        timeTrigger != nil || weekdayTrigger != nil
    }

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel
        let time = viewModel.triggers.first(where: { $0.type == .time })
        let weekday = viewModel.triggers.first(where: { $0.type == .dayOfWeek })

        let defaultDate = time?.fireDate ?? weekday?.fireDate ?? Date().addingTimeInterval(3600)
        _date = State(initialValue: defaultDate)
        _selectedFrequency = State(initialValue: time?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: time?.recurrenceRule?.interval ?? 1)
        _includeTimeTrigger = State(initialValue: time != nil)

        var initialDays = Set<Int>()
        if let mask = weekday?.weekdayMask {
            for day in 1...7 {
                let bit = Int16(1 << day)
                if mask & bit != 0 {
                    initialDays.insert(day)
                }
            }
        }
        _selectedWeekdays = State(initialValue: initialDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    Toggle("Specific date & time", isOn: $includeTimeTrigger.animation())
                    if includeTimeTrigger {
                        DatePicker("Date", selection: $date, displayedComponents: [.date])
                    }
                    DatePicker(includeTimeTrigger ? "Time" : "Weekday time",
                               selection: $date,
                               displayedComponents: [.hourAndMinute])
                }

                if includeTimeTrigger {
                    Section("Repeat") {
                        Picker("Frequency", selection: $selectedFrequency) {
                            Text("Never").tag(nil as RecurrenceRule.Frequency?)
                            ForEach(RecurrenceRule.Frequency.allCases, id: \.self) { frequency in
                                Text(frequency.title).tag(Optional(frequency))
                            }
                        }

                        if selectedFrequency != nil {
                            Stepper(value: $repeatInterval, in: 1...30) {
                                Text("Every \(repeatInterval) interval\(repeatInterval == 1 ? "" : "s")")
                            }
                        }
                    }
                }

                Section("Weekdays") {
                    MemoryWeekdaySelectionView(selectedDays: $selectedWeekdays)
                }

                if hasExistingSchedule {
                    Section {
                        Button("Remove schedule", role: .destructive) {
                            viewModel.clearScheduleTriggers()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(hasExistingSchedule ? "Edit Schedule" : "Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hasExistingSchedule ? "Save" : "Add") {
                        saveChanges()
                    }
                    .disabled(!includeTimeTrigger && selectedWeekdays.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        let recurrence = includeTimeTrigger ? selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) } : nil
        viewModel.updateSchedule(
            fireDate: includeTimeTrigger ? date : nil,
            recurrence: recurrence,
            weekdaySelection: selectedWeekdays,
            weekdayReferenceTime: date
        )
        dismiss()
    }
}

private struct MemoryPersonTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showContactPicker: Bool
    @Binding var showAccessDeniedAlert: Bool
    @State private var name: String
    @State private var contactIdentifier: String

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    init(viewModel: MemoryEditorViewModel,
         showContactPicker: Binding<Bool>,
         showAccessDeniedAlert: Binding<Bool>) {
        self.viewModel = viewModel
        _showContactPicker = showContactPicker
        _showAccessDeniedAlert = showAccessDeniedAlert

        let trigger = viewModel.triggers.first(where: { $0.type == .person })
        _name = State(initialValue: trigger?.person?.name ?? "")
        _contactIdentifier = State(initialValue: trigger?.person?.contactIdentifier ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    HStack {
                        TextField("Name", text: $name)
                        Button {
                            Task { await requestContactsAndShow() }
                        } label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.borderless)
                    }

                    if !contactIdentifier.isEmpty {
                        Label("Contact linked", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Text("Enter a name or choose from contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(existingTrigger == nil ? "Add Person Trigger" : "Edit Person Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTrigger == nil ? "Add" : "Save") {
                        if let trigger = existingTrigger {
                            var updated = trigger
                            updated.person = .init(
                                name: name,
                                contactIdentifier: contactIdentifier.isEmpty ? nil : contactIdentifier
                            )
                            viewModel.updateTrigger(id: trigger.id, with: updated)
                        } else {
                            viewModel.addPersonTrigger(
                                name: name,
                                identifier: contactIdentifier.isEmpty ? nil : contactIdentifier
                            )
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func requestContactsAndShow() async {
        let status = ContactAccessHelper.checkAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            showContactPicker = true
        case .notDetermined:
            let granted = await ContactAccessHelper.requestAccess()
            if granted {
                showContactPicker = true
            } else {
                showAccessDeniedAlert = true
            }
        case .denied, .restricted:
            showAccessDeniedAlert = true
        @unknown default:
            showAccessDeniedAlert = true
        }
    }
}

private struct MemoryWeekdaySelectionView: View {
    @Binding var selectedDays: Set<Int>
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        toggle(day)
                    } label: {
                        GeometryReader { proxy in
                            let diameter = proxy.size.width
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                                .overlay(
                                    Text(symbol(for: day))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                                )
                                .frame(width: diameter, height: diameter)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .accessibilityLabel(fullName(for: day))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var summaryText: String {
        if selectedDays.isEmpty {
            return "No weekdays selected."
        }
        let mask = selectedDays.reduce(into: Int16(0)) { result, day in
            result |= Int16(1 << day)
        }
        return weekdayMaskSummary(mask: mask)
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    private func symbol(for day: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.veryShortWeekdaySymbols ?? []
        guard !symbols.isEmpty else { return "" }
        return symbols[(day - 1) % symbols.count]
    }

    private func fullName(for day: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.weekdaySymbols ?? []
        guard !symbols.isEmpty else { return "" }
        return symbols[(day - 1) % symbols.count]
    }
}

private func weekdayMaskSummary(mask: Int16) -> String {
    guard mask != 0 else { return "No days selected" }
    let formatter = DateFormatter()
    let symbols = formatter.shortWeekdaySymbols ?? []
    guard !symbols.isEmpty else { return "No days selected" }
    let days = (1...7).compactMap { day -> String? in
        let bit = Int16(1 << day)
        guard mask & bit != 0 else { return nil }
        return symbols[(day - 1) % symbols.count]
    }
    return days.isEmpty ? "No days selected" : days.joined(separator: ", ")
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryEditorView(environment: environment)
}
