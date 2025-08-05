//
//  SkyAwareApp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData

@main
struct SkyAwareApp: App {
    @StateObject private var provider = SpcProvider()
    @StateObject private var locationProvider = LocationManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            //            ItemTest.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            if (locationProvider.isAuthorized) {
                iPhoneHomeView()
                    .environmentObject(provider)
                    .environmentObject(locationProvider)
            } else {
                Text("Missing Location Authorization")
            }

        }
        .modelContainer(sharedModelContainer)
    }
}
