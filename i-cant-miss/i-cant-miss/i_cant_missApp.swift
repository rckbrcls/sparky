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
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
