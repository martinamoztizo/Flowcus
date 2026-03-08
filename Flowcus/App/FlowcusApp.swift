//
//  FlowcusApp.swift
//  Flowcus
//
//  Created by E on 2/3/26.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct FlowcusApp: App {
    private static let incompatibleStoreErrorCodes: Set<Int> = [
        NSPersistentStoreIncompatibleSchemaError,
        NSPersistentStoreIncompatibleVersionHashError,
        NSMigrationMissingSourceModelError,
        NSMigrationMissingMappingModelError
    ]

    private static func shouldResetStore(for error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && incompatibleStoreErrorCodes.contains(nsError.code)
    }

    private static func removeStoreFiles(at url: URL) throws {
        let fm = FileManager.default
        let paths: Set<String> = [
            url.path,
            "\(url.path)-shm",
            "\(url.path)-wal",
            url.deletingPathExtension().appendingPathExtension("sqlite").path,
            url.deletingPathExtension().appendingPathExtension("sqlite-shm").path,
            url.deletingPathExtension().appendingPathExtension("sqlite-wal").path
        ]

        for path in paths where fm.fileExists(atPath: path) {
            try fm.removeItem(atPath: path)
        }
    }

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
            #if DEBUG
            if FlowcusApp.shouldResetStore(for: error) {
                print("Incompatible data model detected. Resetting local store...")
                let storeURL = modelConfiguration.url

                do {
                    try FlowcusApp.removeStoreFiles(at: storeURL)
                    return try ModelContainer(for: schema, configurations: [modelConfiguration])
                } catch {
                    fatalError("Could not create ModelContainer after migration reset: \(error)")
                }
            }
            #endif

            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
