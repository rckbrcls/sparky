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
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView(environment: appEnvironment)
                .environment(\.managedObjectContext, appEnvironment.persistence.container.viewContext)
                .task {
                    appEnvironment.bootstrap()
                }
        }
    }
}
