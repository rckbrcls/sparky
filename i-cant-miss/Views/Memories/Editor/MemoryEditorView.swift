//
//  MemoryEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import PhotosUI
import UIKit

struct MemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MemoryEditorViewModel
    @State private var showDueDateSheet = false
    @State private var showExactTimeSheet = false
    @State private var showWeekdaySheet = false
    @State private var showTriggerPickerSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showContactPicker = false
    @State private var showSequentialSheet = false
    @State private var pendingTriggerDestination: MemoryTriggerPickerDestination?
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
                let headerTransitionRange = expandedHeaderHeight - minHeaderHeight
                let showMinimizedHeader = scrollOffset >= headerTransitionRange

                let fadeZoneStart = headerTransitionRange - 50
                let fadeZoneRange: CGFloat = 50

                let expandedOpacity = scrollOffset < fadeZoneStart ? 1.0 : max(0, min(1, 1 - ((scrollOffset - fadeZoneStart) / fadeZoneRange)))
                let minimizedOpacity = scrollOffset < fadeZoneStart ? 0.0 : max(0, min(1, (scrollOffset - fadeZoneStart) / fadeZoneRange))

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
                            showTriggerPicker: $showTriggerPickerSheet,
                            showDueDateSheet: $showDueDateSheet,
                            showExactTimeSheet: $showExactTimeSheet,
                            showWeekdaySheet: $showWeekdaySheet,
                            showLocationPicker: $showLocationPicker,
                            showPersonSheet: $showPersonSheet,
                            showSequentialSheet: $showSequentialSheet,
                            memoryLookup: memoryLookup
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
                                .frame(height: expandedHeaderHeight - transitionThreshold)
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
                        scrollOffset = new
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
                            ControlGroup {
                                Button {
                                    viewModel.isPinned.toggle()
                                } label: {
                                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                                        .foregroundStyle(viewModel.isPinned ? Color.accentColor : .primary)
                                }
                                .accessibilityLabel(viewModel.isPinned ? "Unpin memory" : "Pin memory")

                                Button {
                                    showPhotoLibraryPicker = true
                                } label: {
                                    Image(systemName: isProcessingPhotos ? "hourglass" : "photo.on.rectangle")
                                }
                                .disabled(isProcessingPhotos)
                                .accessibilityLabel(isProcessingPhotos ? "Processing photos" : "Add photo from library")

                                Button {
                                    handleCameraButtonTapped()
                                } label: {
                                    Image(systemName: "camera")
                                }
                                .disabled(isProcessingPhotos)
                                .accessibilityLabel("Take photo with camera")
                            }

                            Section("Details") {
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
            .sheet(isPresented: $showDueDateSheet) {
                MemoryDueDateTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showExactTimeSheet) {
                MemoryExactTimeTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showWeekdaySheet) {
                MemoryWeekdayTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showTriggerPickerSheet) {
                MemoryTriggerPickerSheet(
                    viewModel: viewModel
                ) { destination in
                    pendingTriggerDestination = destination
                }
                .presentationDetents([.large])
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
            .sheet(isPresented: $showSequentialSheet) {
                MemorySequentialTriggerSheet(
                    viewModel: viewModel,
                    excludedMemoryID: viewModel.editingMemoryID
                )
                .presentationDetents([.large])
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
        .onChange(of: showTriggerPickerSheet) { _, isPresented in
            guard !isPresented, let destination = pendingTriggerDestination else { return }
            handleTriggerPickerDestination(destination)
            pendingTriggerDestination = nil
        }
    }

    private var memoryLookup: [UUID: MemoryModel] {
        Dictionary(uniqueKeysWithValues: viewModel.environment.memoryService.memories.map { ($0.id, $0) })
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

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            proxy.scrollTo("scrollTop", anchor: .bottom)
        }

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

    private func handleTriggerPickerDestination(_ destination: MemoryTriggerPickerDestination) {
        switch destination {
        case .dueDate:
            showDueDateSheet = true
        case .exactTime:
            showExactTimeSheet = true
        case .weekdayRoutine:
            showWeekdaySheet = true
        case .location:
            showLocationPicker = true
        case .person:
            showPersonSheet = true
        case .sequential:
            showSequentialSheet = true
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryEditorView(environment: environment)
}
