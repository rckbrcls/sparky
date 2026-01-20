//
//  i_cant_missApp.swift
//  i-cant-miss
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import CoreData

@main
struct i_cant_missApp: App {
    @StateObject private var appEnvironment = AppEnvironment(persistence: PersistenceController.shared)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(environment: appEnvironment)
                .environment(\.managedObjectContext, appEnvironment.persistence.container.viewContext)
                .environmentObject(appEnvironment)
                .task {
                    appEnvironment.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Refresh data when app becomes active
                        Task {
                            await appEnvironment.lobeService.refresh(force: false)
                            await appEnvironment.lobeService.refreshTags(force: false)
                            await appEnvironment.memoryService.refresh(force: false)
                        }
                    }
                }
        }
    }
}
