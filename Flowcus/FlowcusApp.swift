//
//  FlowcusApp.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI
import SwiftData

@main
struct FocusFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            JournalEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Could not create ModelContainer: \(error)")
            print("Data schema changed. Attempting to delete old incompatible data...")
            
            // AUTO-FIX: Delete the old database file if schema mismatch occurs
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            // Also clean up helper files
            let shmUrl = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let walUrl = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
            try? FileManager.default.removeItem(at: shmUrl)
            try? FileManager.default.removeItem(at: walUrl)

            // Retry creating the container from scratch
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}