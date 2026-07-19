#if os(macOS)
//
//  sparkyMacApp.swift
//  sparkyMac
//
//  macOS entry point — shared domain via sparky sources.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct sparkyMacApp: App {
    @StateObject private var appEnvironment = AppEnvironment(dataController: DataController.shared)
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = AppEnvironment.notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            DesktopRootView(environment: appEnvironment)
                .modelContainer(appEnvironment.dataController.container)
                .environmentObject(appEnvironment)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .task {
                    appEnvironment.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await appEnvironment.mindService.refresh(force: false)
                            await appEnvironment.mindService.refreshTags(force: false)
                            await appEnvironment.memoryService.refresh(force: false)
                        }
                    }
                }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                // New Memory is handled in DesktopRootView toolbar (⌘N).
            }
        }
    }
}

#endif
