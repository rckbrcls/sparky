import SwiftUI

private enum TimelineViewConstants {
    static let defaultFolderIconName = "folder.fill"
    static let defaultFolderColorHex = "#6366F1"
}

private enum TimelineSheet: Int, Identifiable {
    case triggers
    case createFolder

    var id: Int { rawValue }
}

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    let environment: AppEnvironment
    let onCreateReminder: () -> Void
    let onEditReminder: (ReminderModel) -> Void
    @State private var activeSheet: TimelineSheet?
    private let accentColor = Color("AccentColor")
    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)
    @State private var newFolderName = ""
    @State private var newFolderIcon = TimelineViewConstants.defaultFolderIconName
    @State private var newFolderColor = TimelineViewConstants.defaultFolderColorHex
    private let folderIcons = [
        "folder.fill",
        "folder.badge.person.crop",
        "briefcase.fill",
        "house.fill",
        "heart.fill",
        "star.fill",
        "flag.fill",
        "book.fill",
        "lightbulb.fill",
        "cart.fill"
    ]
    private let iconDisplayNames: [String: String] = [
        "folder.fill": "Folder",
        "folder.badge.person.crop": "Shared Folder",
        "briefcase.fill": "Briefcase",
        "house.fill": "House",
        "heart.fill": "Heart",
        "star.fill": "Star",
        "flag.fill": "Flag",
        "book.fill": "Book",
        "lightbulb.fill": "Idea",
        "cart.fill": "Shopping"
    ]

    init(environment: AppEnvironment,
         onCreateReminder: @escaping () -> Void,
         onEditReminder: @escaping (ReminderModel) -> Void) {
        self.environment = environment
        self.onCreateReminder = onCreateReminder
        self.onEditReminder = onEditReminder
        _viewModel = StateObject(wrappedValue: TimelineViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    TimelineListDetailView(
                        environment: environment,
                        viewModel: viewModel,
                        folder: nil,
                        onCreateReminder: onCreateReminder,
                        onEditReminder: onEditReminder
                    )
                } label: {
                    overviewRow(
                        title: "All Reminders",
                        subtitle: remindersSubtitle(for: nil),
                        iconName: "square.grid.2x2.fill",
                        iconColor: accentColor
                    )
                }

                ForEach(viewModel.folders) { folder in
                    NavigationLink {
                        TimelineListDetailView(
                            environment: environment,
                            viewModel: viewModel,
                            folder: folder,
                            onCreateReminder: onCreateReminder,
                            onEditReminder: onEditReminder
                        )
                    } label: {
                        overviewRow(
                            title: folder.name,
                            subtitle: remindersSubtitle(for: folder.id),
                            iconName: folder.iconName ?? TimelineViewConstants.defaultFolderIconName,
                            iconColor: folderColor(for: folder)
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        resetNewFolderInputs()
                        activeSheet = .createFolder
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .tint(accentColor)
                    .accessibilityLabel("Create Folder")
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        activeSheet = .triggers
                    } label: {
                        Image(systemName: "bolt.fill")
                    }
                    .tint(accentColor)
                    .accessibilityLabel("Triggers")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateReminder) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accentColor)
                    .accessibilityLabel("Create Reminder")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .triggers:
                TriggersView(environment: environment,
                             onEditReminder: onEditReminder)
            case .createFolder:
                createFolderSheet
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.dismissError() }
        ), actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .onAppear {
            viewModel.refresh(force: false)
        }
    }

    private var createFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Folder Name", text: $newFolderName)
                }

                Section("Icon") {
                    iconSelectionGrid(selection: $newFolderIcon)
                }

                Section("Color") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(Color.PresetColors.all) { presetColor in
                            Button {
                                newFolderColor = presetColor.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(presetColor.color)
                                        .frame(width: 50, height: 50)

                                    if newFolderColor == presetColor.hex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 3)
                                            .frame(width: 50, height: 50)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetNewFolderInputs()
                        activeSheet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { return }
                        viewModel.createFolder(
                            name: trimmedName,
                            colorHex: newFolderColor,
                            iconName: newFolderIcon
                        )
                        resetNewFolderInputs()
                        activeSheet = nil
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func resetNewFolderInputs() {
        newFolderName = ""
        newFolderIcon = TimelineViewConstants.defaultFolderIconName
        newFolderColor = TimelineViewConstants.defaultFolderColorHex
    }

    @ViewBuilder
    private func iconSelectionGrid(selection: Binding<String>) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(folderIcons, id: \.self) { icon in
                Button {
                    selection.wrappedValue = icon
                } label: {
                    ZStack {
                        Circle()
                            .fill(selection.wrappedValue == icon ? accentColor.opacity(0.18) : Color(.systemGray6))
                            .frame(width: 50, height: 50)

                        Image(systemName: icon)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selection.wrappedValue == icon ? accentColor : Color.primary)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(iconAccessibilityLabel(for: icon)))
            }
        }
        .padding(.vertical, 8)
    }

    private func iconAccessibilityLabel(for icon: String) -> String {
        iconDisplayNames[icon] ?? "Folder Icon"
    }

    private func overviewRow(title: String,
                             subtitle: String,
                             iconName: String,
                             iconColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }

    private func remindersSubtitle(for folderID: UUID?) -> String {
        let count = viewModel.reminderCount(in: folderID)
        return "\(count) reminder\(count == 1 ? "" : "s")"
    }

    private func folderColor(for folder: FolderModel) -> Color {
        if let hex = folder.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return accentColor
    }
}

private struct TimelineListDetailView: View {
    @ObservedObject private var viewModel: TimelineViewModel
    @ObservedObject private var settings: SettingsStore
    let environment: AppEnvironment
    let folder: FolderModel?
    let onCreateReminder: () -> Void
    let onEditReminder: (ReminderModel) -> Void

    @State private var showTriggers = false
    @State private var showFilterSheet = false

    private let accentColor = Color("AccentColor")
    private let timeFilters: [ReminderService.TimelineFilter] = [.today, .overdue, .thisWeek, .upcoming]
    private let triggerFilters: [ReminderService.TimelineFilter] = [.timeTriggers, .locationTriggers, .personTriggers]
    private let organizationFilters: [ReminderService.TimelineFilter] = [.byPriority, .byTriggerType]
    private let specialFilters: [ReminderService.TimelineFilter] = [.recurring, .noTriggers]

    init(environment: AppEnvironment,
         viewModel: TimelineViewModel,
         folder: FolderModel?,
         onCreateReminder: @escaping () -> Void,
         onEditReminder: @escaping (ReminderModel) -> Void) {
        self.environment = environment
        self.folder = folder
        self.onCreateReminder = onCreateReminder
        self.onEditReminder = onEditReminder
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _settings = ObservedObject(wrappedValue: environment.settings)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.reminders.isEmpty {
                EmptyStateView(
                    systemImage: viewModel.filter.iconName,
                    title: emptyStateTitle,
                    message: emptyStateMessage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.reminders) { reminder in
                        ReminderRowView(reminder: reminder)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEditReminder(reminder)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.delete(reminder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    viewModel.complete(reminder)
                                } label: {
                                    Label("Complete", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                            .contextMenu {
                                Button("Complete", systemImage: "checkmark.circle") {
                                    viewModel.complete(reminder)
                                }
                                Button(snoozeLabel, systemImage: "zzz") {
                                    viewModel.snooze(reminder, minutes: settings.defaultSnoozeMinutes)
                                }
                                Button(postponeLabel, systemImage: "clock.arrow.circlepath") {
                                    viewModel.postpone(reminder, minutes: settings.defaultPostponeMinutes)
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    viewModel.archive(reminder)
                                }
                                Divider()
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    viewModel.delete(reminder)
                                }
                            }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            viewModel.refresh(force: true)
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showTriggers = true }) {
                    Image(systemName: "bolt.fill")
                }
                .tint(accentColor)
                .accessibilityLabel("Triggers")
            }

            ToolbarItem(placement: .principal) {
                Button {
                    showFilterSheet = true
                } label: {
                    filterMenuLabel
                }
                .buttonStyle(.glass)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onCreateReminder) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(accentColor)
                .accessibilityLabel("Create Reminder")
            }
        }
        .sheet(isPresented: $showTriggers) {
            TriggersView(environment: environment,
                         onEditReminder: onEditReminder)
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                List {
                    Section("Display") {
                        Toggle(
                            isOn: Binding(
                                get: { viewModel.showCompleted },
                                set: { newValue in
                                    withAnimation {
                                        viewModel.showCompleted = newValue
                                    }
                                }
                            )
                        ) {
                            Label("Show Completed", systemImage: viewModel.showCompleted ? "eye" : "eye.slash")
                        }
                        .tint(accentColor)
                    }

                    let time = filters(in: timeFilters)
                    if !time.isEmpty {
                        Section("Time") {
                            ForEach(time, id: \.self) { filter in
                                filterButton(filter)
                            }
                        }
                    }

                    let trigger = filters(in: triggerFilters)
                    if !trigger.isEmpty {
                        Section("Triggers") {
                            ForEach(trigger, id: \.self) { filter in
                                filterButton(filter)
                            }
                        }
                    }

                    let organization = filters(in: organizationFilters)
                    if !organization.isEmpty {
                        Section("Organization") {
                            ForEach(organization, id: \.self) { filter in
                                filterButton(filter)
                            }
                        }
                    }

                    let special = filters(in: specialFilters)
                    if !special.isEmpty {
                        Section("Special") {
                            ForEach(special, id: \.self) { filter in
                                filterButton(filter)
                            }
                        }
                    }

                    if viewModel.availableFilters.contains(.all) {
                        Section {
                            filterButton(.all)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showFilterSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
        .onAppear {
            viewModel.selectedFolderID = folder?.id
        }
    }

    private var filterMenuLabel: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedFolderName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: viewModel.filter.iconName)
                        .font(.caption)
                    Text(viewModel.filter.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    if viewModel.reminders.count > 0 {
                        Text("(\(viewModel.reminders.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .foregroundColor(.primary)
    }


    private func filters(in group: [ReminderService.TimelineFilter]) -> [ReminderService.TimelineFilter] {
        group.filter { viewModel.availableFilters.contains($0) }
    }

    private var emptyStateTitle: String {
        switch viewModel.filter {
        case .all:
            return "No Reminders Yet"
        case .overdue:
            return "All Clear!"
        case .today:
            return "Nothing for Today"
        case .upcoming:
            return "No Upcoming Reminders"
        case .thisWeek:
            return "Free Week Ahead"
        case .byPriority:
            return "No Prioritized Items"
        case .byTriggerType:
            return "No Reminders"
        case .timeTriggers:
            return "No Scheduled Reminders"
        case .locationTriggers:
            return "No Location Reminders"
        case .personTriggers:
            return "No People Reminders"
        case .recurring:
            return "No Recurring Reminders"
        case .noTriggers:
            return "All Reminders Have Triggers"
        }
    }

    private var emptyStateMessage: String {
        switch viewModel.filter {
        case .all:
            return "Create a reminder to get started."
        case .overdue:
            return "You're all caught up! No overdue reminders."
        case .today:
            return "You have no reminders scheduled for today."
        case .upcoming:
            return "No reminders scheduled for the future."
        case .thisWeek:
            return "You have no reminders for this week."
        case .byPriority:
            return "Create reminders with different priorities."
        case .byTriggerType:
            return "Create reminders to see them organized by type."
        case .timeTriggers:
            return "Set up reminders based on dates or schedules."
        case .locationTriggers:
            return "Add locations to get reminded where it matters."
        case .personTriggers:
            return "Link reminders to people to see them here."
        case .recurring:
            return "No reminders are set to repeat."
        case .noTriggers:
            return "All your reminders have active triggers."
        }
    }

    private var snoozeLabel: String {
        formattedDuration(prefix: "Snooze", minutes: settings.defaultSnoozeMinutes)
    }

    private var postponeLabel: String {
        formattedDuration(prefix: "Postpone", minutes: settings.defaultPostponeMinutes)
    }

    private func formattedDuration(prefix: String, minutes: Int) -> String {
        guard minutes >= 60, minutes % 60 == 0 else {
            return "\(prefix) \(minutes) min"
        }
        let hours = minutes / 60
        return "\(prefix) \(hours) hour" + (hours == 1 ? "" : "s")
    }

    @ViewBuilder
    private func filterButton(_ filter: ReminderService.TimelineFilter) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.filter = filter
            }
            showFilterSheet = false
        }) {
            HStack {
                Label(filter.title, systemImage: filter.iconName)
                Spacer()
                let count = viewModel.count(for: filter)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if viewModel.filter == filter {
                    Image(systemName: "checkmark")
                        .foregroundColor(accentColor)
                }
            }
        }
    }
}

private extension ReminderService.TimelineFilter {
    var title: String {
        switch self {
        case .all: return "All"
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .thisWeek: return "This Week"
        case .byPriority: return "Priority"
        case .byTriggerType: return "Type"
        case .timeTriggers: return "Scheduled"
        case .locationTriggers: return "Location"
        case .personTriggers: return "People"
        case .recurring: return "Recurring"
        case .noTriggers: return "No Triggers"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .overdue: return "exclamationmark.triangle"
        case .today: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        case .thisWeek: return "calendar.day.timeline.leading"
        case .byPriority: return "exclamationmark.3"
        case .byTriggerType: return "tag"
        case .timeTriggers: return "clock.badge"
        case .locationTriggers: return "mappin.and.ellipse"
        case .personTriggers: return "person.crop.circle"
        case .recurring: return "arrow.clockwise"
        case .noTriggers: return "bell.slash"
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TimelineView(environment: environment, onCreateReminder: {}, onEditReminder: { _ in })
        .environmentObject(environment)
}
