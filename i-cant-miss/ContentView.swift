//
//  ContentView.swift
//  i-cant-miss
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject private var environment: AppEnvironment
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var terminalViewModel: TerminalCommandViewModel
    @State private var showReminderSheet = false
    @State private var showNoteSheet = false
    @State private var selectedReminder: ReminderModel?
    @State private var selectedNote: NoteModel?

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
        _terminalViewModel = StateObject(wrappedValue: TerminalCommandViewModel(environment: environment))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tabRouter.selection) {
                TimelineView(environment: environment,
                             onCreateReminder: { showReminderSheet = true },
                             onEditReminder: { reminder in
                                 selectedReminder = reminder
                                 showReminderSheet = true
                             })
                .tabItem {
                    Label("Timeline", systemImage: "list.bullet.rectangle")
                }
                .tag(TabRouter.Selection.timeline)

                TriggersView(environment: environment,
                             onEditReminder: { reminder in
                                 selectedReminder = reminder
                                 showReminderSheet = true
                             })
                .tabItem {
                    Label("Triggers", systemImage: "bolt.circle")
                }
                .tag(TabRouter.Selection.triggers)

                NotesView(environment: environment,
                          onCreateNote: { showNoteSheet = true },
                          onEditNote: { note in
                              selectedNote = note
                              showNoteSheet = true
                          })
                .tabItem {
                    Label("Notes", systemImage: "square.and.pencil")
                }
                .tag(TabRouter.Selection.notes)
            }

            TerminalInputBar(viewModel: terminalViewModel)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showReminderSheet, onDismiss: { selectedReminder = nil }) {
            ReminderEditorView(
                environment: environment,
                existingReminder: selectedReminder
            )
        }
        .sheet(isPresented: $showNoteSheet, onDismiss: { selectedNote = nil }) {
            NoteEditorView(
                environment: environment,
                existingNote: selectedNote
            )
        }
        .task {
            await environment.reminderService.refresh(force: true)
            await environment.folderService.refreshFolders(force: true)
            await environment.folderService.refreshTags(force: true)
            await environment.noteService.refresh(force: true)
        }
    }
}

final class TabRouter: ObservableObject {
    enum Selection {
        case timeline
        case triggers
        case notes
    }

    @Published var selection: Selection = .timeline
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
}
