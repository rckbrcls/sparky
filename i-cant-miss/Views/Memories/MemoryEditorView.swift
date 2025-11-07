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
    @FocusState private var isTitleFocused: Bool
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var mediaErrorMessage: String?
    @State private var scrollOffset: CGFloat = 20
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var isDetailsExpanded = false
    @State private var isPreferencesExpanded = false
    @State private var expandedHeaderHeight: CGFloat = 210
    @StateObject private var bodyEditorController = RichTextEditorController()
    private let richTextFormatter = MemoryRichTextFormatter()

    private let isEditing: Bool
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
                // Calcula quando o header expandido está totalmente comprimido
                let headerTransitionRange = expandedHeaderHeight - minHeaderHeight
                let showMinimizedHeader = scrollOffset >= headerTransitionRange

                // Define a zona de transição - começa mais cedo (últimos 50 pontos da compressão)
                let fadeZoneStart = headerTransitionRange - 50
                let fadeZoneRange: CGFloat = 50

                // Calcula a opacidade baseada no scroll
                // O expanded some gradualmente nos últimos 50 pontos
                let expandedOpacity = scrollOffset < fadeZoneStart ? 1.0 : max(0, min(1, 1 - ((scrollOffset - fadeZoneStart) / fadeZoneRange)))
                // O minimized aparece gradualmente quando o expanded está sumindo
                let minimizedOpacity = scrollOffset < fadeZoneStart ? 0.0 : max(0, min(1, (scrollOffset - fadeZoneStart) / fadeZoneRange))

                // Expanded Header - sempre visível até ser completamente comprimido
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .frame(height: max(minHeaderHeight, expandedHeaderHeight - scrollOffset))
                        .allowsHitTesting(true)

                    let minOffset = expandedHeaderHeight - minHeaderHeight
                    let offset = scrollOffset <= 0 ? -scrollOffset : scrollOffset <= minOffset ? -scrollOffset : -minOffset


                    VStack(spacing: 12) {
                        titleHeaderView()
                        MemoryEditorTriggerButtonsBar(
                            viewModel: viewModel,
                            showScheduleSheet: $showScheduleSheet,
                            showLocationPicker: $showLocationPicker,
                            showPersonSheet: $showPersonSheet
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 80)
                    .padding(.bottom, 20)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: HeaderHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .offset(y: offset)
                    .opacity(expandedOpacity)
                }
                .onPreferenceChange(HeaderHeightPreferenceKey.self) { newHeight in
                    guard newHeight > 0 else { return }
                    let clampedHeight = max(newHeight, minHeaderHeight + 20)
                    if abs(expandedHeaderHeight - clampedHeight) > 0.5 {
                        expandedHeaderHeight = clampedHeight
                    }
                }
                .zIndex(10)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Color.clear
                                .frame(height: expandedHeaderHeight - 36)
                                .frame(maxWidth: .infinity)
                                .id("scrollTop")

                            editorContent
                                .padding(.top, 32)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, new in
                        self.scrollOffset = new
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                    }
                }

                VStack(spacing: 0) {
                    Button {
                        scrollToTopAndFocus()
                    } label: {
                        let displayTitle = viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(displayTitle.isEmpty ? "Memory" : displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(displayTitle.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .padding(.horizontal, 76)
                            .padding(.vertical, 20)
                            .frame(height: minHeaderHeight)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .opacity(minimizedOpacity)
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(minimizedOpacity > 0.3)
                .zIndex(showMinimizedHeader ? 11 : 9)

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

                        Menu {
                            HStack(spacing: 12) {
                                Button {
                                    viewModel.isPinned.toggle()
                                } label: {
                                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(viewModel.isPinned ? Color.accentColor : .primary)
                                        .glassEffect(.regular.interactive())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(viewModel.isPinned ? "Unpin memory" : "Pin memory")

                                Button {
                                    showPhotoLibraryPicker = true
                                } label: {
                                    Image(systemName: isProcessingPhotos ? "hourglass" : "photo.on.rectangle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.interactive())
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessingPhotos)
                                .accessibilityLabel(isProcessingPhotos ? "Processing photos" : "Add photo from library")

                                Button {
                                    handleCameraButtonTapped()
                                } label: {
                                    Image(systemName: "camera")
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.interactive())
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessingPhotos)
                                .accessibilityLabel("Take photo with camera")
                            }

                            Section ("Details"){
                                SpacePicker(selection: Binding(
                                    get: { viewModel.selectedSpaceID ?? spacesForPicker.first?.id ?? SpaceModel.inbox.id },
                                    set: { viewModel.selectedSpaceID = $0 }
                                ), spaces: spacesForPicker)

                                Picker(selection: $viewModel.status) {
                                    ForEach(MemoryStatus.allCases) { status in
                                        Text(status.rawValue.capitalized).tag(status)
                                    }
                                } label: {
                                    Label("Status", systemImage: "circle.circle")
                                }
                                .pickerStyle(.menu)

                                Picker(selection: $viewModel.priority) {
                                    ForEach(MemoryPriority.allCases) { priority in
                                        Label(priorityLabel(for: priority), systemImage: priority.iconName)
                                            .tag(priority)
                                    }
                                } label: {
                                    Label("Priority", systemImage: "flag.fill")
                                }
                                .pickerStyle(.menu)
                            }

                            Menu("Preferences") {
                                Toggle(isOn: $viewModel.autoCompleteChecklist) {
                                    Label("Auto-complete when checklist is done", systemImage: "checkmark.circle")
                                }
                                .disabled(!viewModel.canToggleAutoComplete)
                                .foregroundStyle(viewModel.canToggleAutoComplete ? .primary : .secondary)

                                Toggle(isOn: $viewModel.isPinned) {
                                    Label("Show in Today view", systemImage: "calendar")
                                }

                                Toggle(isOn: Binding(
                                    get: { !viewModel.triggers.isEmpty },
                                    set: { _ in }
                                )) {
                                    Label("Enable notifications", systemImage: "bell.badge")
                                }
                                .disabled(true)
                                .foregroundStyle(.secondary)

                                Toggle(isOn: .constant(false)) {
                                    Label("Archive when completed", systemImage: "archivebox")
                                }
                                .disabled(true)
                                .foregroundStyle(.secondary)
                            }

                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .tint(.white)
                        .glassEffect(.regular.interactive())
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveActionBar
            }
            .photosPicker(isPresented: $showPhotoLibraryPicker,
                          selection: $photoSelections,
                          maxSelectionCount: 5,
                          matching: .images)
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
                    insertInlineImage($0)
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

    private var saveButtonTitle: String { isEditing ? "Save" : "Create" }

    private var isSaveDisabled: Bool {
        viewModel.isSaving || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var saveActionBar: some View {
        HStack {
            Spacer()
            Button(role: .confirm) {
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
                            .font(.title3.bold())
                    }
                }
                .padding(10)
            }
            .buttonBorderShape(.circle)
            .buttonStyle(.glassProminent)
            .disabled(isSaveDisabled)
            .opacity(isSaveDisabled ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }

    private func titleHeaderView() -> some View {
        VStack(spacing: 12) {
            TextField("Memory", text: $viewModel.title, axis: .vertical)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .submitLabel(.done)
                .lineLimit(2)
                .focused($isTitleFocused)
                .onSubmit {
                    isTitleFocused = false
                }
                .onChange(of: viewModel.title) { _, newValue in
                    guard newValue.contains(where: { $0.isNewline }) else { return }
                    let sanitized = newValue
                        .split(whereSeparator: \.isNewline)
                        .joined(separator: " ")
                    if sanitized != newValue {
                        viewModel.title = sanitized
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        isTitleFocused = false
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive())
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    private func scrollToTopAndFocus() {
        guard let proxy = scrollViewProxy else { return }

        // Esconde o teclado primeiro para garantir scroll suave
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Usa spring animation para um efeito mais natural
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            proxy.scrollTo("scrollTop", anchor: .bottom)
        }

        // Aguarda a animação completar e depois foca
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isTitleFocused = true
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            checklistContent
            editorView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var checklistContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    private var editorView: some View {
        ZStack(alignment: .topLeading) {
            // Custom UITextView-backed editor renders rich text content with inline attachments.
            RichTextEditor(
                text: $viewModel.body,
                attachments: viewModel.attachments,
                formatter: richTextFormatter,
                controller: bodyEditorController
            ) { referencedIDs in
                viewModel.syncAttachments(withReferencedIDs: referencedIDs)
            }
            .frame(minHeight: 160)

            if viewModel.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Write something memorable…")
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

            }
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
    private func insertInlineImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            mediaErrorMessage = "The selected photo could not be processed."
            return
        }
        insertAttachmentData(data)
    }

    @MainActor
    private func insertAttachmentData(_ data: Data) {
        let attachment = viewModel.createAttachment(data: data)
        // Try to inject directly at the current caret; fall back to token insertion if the editor is not ready yet.
        if !bodyEditorController.insertAttachment(attachment) {
            appendTokenToBody(for: attachment.id)
        }
    }

    private func appendTokenToBody(for attachmentID: UUID) {
        let token = MemoryRichTextFormatter.attachmentToken(for: attachmentID)
        var updatedBody = viewModel.body

        if !updatedBody.contains(token) {
            if !updatedBody.isEmpty {
                if updatedBody.hasSuffix("\n\n") {
                    // already has enough spacing
                } else if updatedBody.hasSuffix("\n") {
                    updatedBody.append("\n")
                } else {
                    updatedBody.append("\n\n")
                }
            }

            updatedBody.append(token)
            if !updatedBody.hasSuffix("\n") {
                updatedBody.append("\n")
            }
            viewModel.body = updatedBody
        }
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
                        insertAttachmentData(jpegData)
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
        Picker(selection: $selection) {
            ForEach(spaces) { space in
                Text(space.name).tag(space.id)
            }
        } label: {
            Label("Space", systemImage: "folder")
        }
        .pickerStyle(.menu)
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

private struct HeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Trigger Inline Forms

private struct MemoryEditorTriggerButtonsBar: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showScheduleSheet: Bool
    @Binding var showLocationPicker: Bool
    @Binding var showPersonSheet: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MemoryScheduleTriggerInlineForm(
                viewModel: viewModel,
                showSheet: $showScheduleSheet
            )
            MemoryLocationTriggerInlineForm(
                viewModel: viewModel,
                showLocationPicker: $showLocationPicker
            )
            MemoryPersonTriggerInlineForm(
                viewModel: viewModel,
                showSheet: $showPersonSheet
            )
        }
        .frame(maxWidth: .infinity)
    }
}

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
        timeTrigger != nil || weekdayTrigger != nil || viewModel.dueDateEnabled
    }

    var body: some View {
        if hasSchedule {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Label(schedulePrimaryText, systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
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
                Label("Schedule", systemImage: "calendar.badge.plus")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
        }
    }

    private var schedulePrimaryText: String {
        if viewModel.dueDateEnabled {
            return "Due: " + viewModel.dueDate.formatted(date: .abbreviated, time: .shortened)
        }
        if let date = timeTrigger?.fireDate ?? weekdayTrigger?.fireDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if let mask = weekdayTrigger?.weekdayMask, mask != 0 {
            return weekdayMaskSummary(mask: mask)
        }
        return "Custom schedule"
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
                    Label(location.name ?? "Location", systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
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
                Label("Location", systemImage: "mappin.circle.fill")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
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
                    Label(person.name, systemImage: "person.crop.circle.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
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
                Label("Person", systemImage: "person.crop.circle.badge.plus")
                    .foregroundStyle(.accent)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
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
                Section("Due Date") {
                    Toggle("Add due date", isOn: $viewModel.dueDateEnabled.animation())
                    if viewModel.dueDateEnabled {
                        DatePicker("Date", selection: $viewModel.dueDate, displayedComponents: [.date])
                        DatePicker("Time", selection: $viewModel.dueDate, displayedComponents: [.hourAndMinute])
                    }
                }

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
