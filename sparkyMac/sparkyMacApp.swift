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
import Sparkle

@main
struct sparkyMacApp: App {
    @StateObject private var appEnvironment = AppEnvironment(dataController: DataController.shared)
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    private let updaterController: SPUStandardUpdaterController

    init() {
        UNUserNotificationCenter.current().delegate = AppEnvironment.notificationDelegate
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
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
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var observation: NSKeyValueObservation?
    
    init(updater: SPUUpdater) {
        observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }
}

#endif
