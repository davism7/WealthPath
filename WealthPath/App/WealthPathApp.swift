//
//  WealthPathApp.swift
//  WealthPath
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct WealthPathApp: App {
    let modelContainer: ModelContainer
    let authManager: AuthenticationManager

    init() {
        FirebaseApp.configure()

        let schema = Schema([
            SDUser.self, SDPaycheck.self, SDBill.self,
            SDSavingsAccount.self, SDContribution.self,
            SDPaycheckSettings.self, SDAllocation.self,
            SDNote.self, SDBillChecklist.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed to initialize: \(error)")
        }

        authManager = AuthenticationManager(modelContext: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(authManager)
        }
    }
}
