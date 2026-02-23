//
//  sparkyApp.swift
//  sparky
//
//  Created by Erick Barcelos on 13/10/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct sparkyApp: App {
    @StateObject private var appEnvironment = AppEnvironment(dataController: DataController.shared)
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = AppEnvironment.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: appEnvironment)
                .modelContainer(appEnvironment.dataController.container)
                .environmentObject(appEnvironment)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .task {
                    appEnvironment.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Refresh data when app becomes active
                        Task {
                            await appEnvironment.mindService.refresh(force: false)
                            await appEnvironment.mindService.refreshTags(force: false)
                            await appEnvironment.memoryService.refresh(force: false)
                        }
                    }
                }
        }
    }
}
