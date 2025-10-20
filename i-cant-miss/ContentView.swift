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
    @State private var showReminderForCreate = false
    @State private var showNoteForCreate = false
    @State private var selectedReminder: ReminderModel?
    @State private var selectedNote: NoteModel?
    @State private var showTodoForCreate = false
    @State private var selectedTodoList: TodoListModel?

    init(environment: AppEnvironment) {
        _environment = ObservedObject(wrappedValue: environment)
    }

    var body: some View {
        TabView(selection: $tabRouter.selection) {
            TimelineView(environment: environment,
                         onCreateReminder: { showReminderForCreate = true },
                         onEditReminder: { reminder in
                             selectedReminder = reminder
                         })
            .tabItem {
                Label("Timeline", systemImage: "list.bullet.rectangle")
            }
            .tag(TabRouter.Selection.timeline)

            NotesView(environment: environment,
                      onCreateNote: { showNoteForCreate = true },
                      onEditNote: { note in
                          selectedNote = note
                      })
            .tabItem {
                Label("Notes", systemImage: "square.and.pencil")
            }
            .tag(TabRouter.Selection.notes)

            TodosView(environment: environment,
                      onCreateList: { showTodoForCreate = true },
                      onEditList: { list in
                          selectedTodoList = environment.todoService.fetchListWithItems(id: list.id) ?? list
                      })
            .tabItem {
                Label("To-dos", systemImage: "checklist")
            }
            .tag(TabRouter.Selection.todos)

            SettingsView(environment: environment)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(TabRouter.Selection.settings)
        }
        .sheet(isPresented: $showReminderForCreate) {
            ReminderEditorView(
                environment: environment,
                existingReminder: nil
            )
        }
        .sheet(item: $selectedReminder) { reminder in
            ReminderEditorView(
                environment: environment,
                existingReminder: reminder
            )
        }
        .sheet(isPresented: $showNoteForCreate) {
            NoteEditorView(
                environment: environment,
                existingNote: nil
            )
        }
        .sheet(item: $selectedNote) { note in
            NoteEditorView(
                environment: environment,
                existingNote: note
            )
        }
        .sheet(isPresented: $showTodoForCreate) {
            TodoEditorView(
                environment: environment,
                existingList: nil
            )
        }
        .sheet(item: $selectedTodoList) { list in
            TodoEditorView(
                environment: environment,
                existingList: list
            )
        }
    }
}

final class TabRouter: ObservableObject {
    enum Selection {
        case timeline
        case notes
        case todos
        case settings
    }

    @Published var selection: Selection = .timeline
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ContentView(environment: environment)
}
