//
//  SkyAwareApp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct SkyAwareApp: App {
    private let appRefreshID = "com.skyaware.app.refresh"
    @State private var locationProvider = LocationManager()
    @State private var prov = SpcProvider(service: SpcService(client: SpcClient()))
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FeedCache.self
        ])
//        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: []) // configurations: [modelConfiguration]
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if (locationProvider.isAuthorized) {
                iPhoneHomeView()
                    .environment(prov)
                    .environment(locationProvider)
            } else {
                Text("Missing Location Authorization")
            }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(appRefreshID)) {
//            await handleAppRefresh()
            print("background task trigger. TODO: Figure it out")
        }
        .backgroundTask(.urlSession("com.skyaware.background.url")) {
            print("background url task. TODO: Figure it out")
        }
        .onChange(of: scenePhase) { _, newPhase in
            print("scene phase changed: \(newPhase). TODO: Decide how to handle phase changes...")
//            if newPhase == .background {
//                // Optionally re-schedule when going to background
//                scheduleNextAppRefresh(earliest: Date().addingTimeInterval(30 * 60)) // placeholder; replace using CadencePlanner
//            }
        }
    }
    
    // MARK - Background App Refresh
    private func scheduleNextAppRefresh(earliest date: Date) {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
        request.earliestBeginDate = date
        do { try BGTaskScheduler.shared.submit(request) } catch {
#if DEBUG
            print("BG submit failed: \(error)")
#endif
        }
    }

    private func handleAppRefresh() {
//        // Always schedule the next one (best effort). Replace with CadencePlanner-derived date.
//        scheduleNextAppRefresh(earliest: Date().addingTimeInterval(45 * 60))
//
//        // Do work quickly: create a ModelContext for this background run
//        let context = ModelContext(sharedModelContainer)
//
//        // Compose dependencies for a one-shot refresh (no UI; keep under ~30s)
//        let client = SpcClient()
//        let repo = FeedCacheRepositoryImpl(context: context)
//        let service = SpcService(client: client, feeds: repo)

//        let taskExpiration = Task {
//            await withTaskCancellationHandler {
//                // Run the refresh pass
//                do { _ = try await service.refreshAll() } catch { /* log if desired */ }
//            } onCancel: {}
//        }
//
//        // Inform the system when finished
//        task.setTaskCompleted(success: true)
//
//        // Cancel any outstanding work if still running
//        taskExpiration.cancel()
    }
}
