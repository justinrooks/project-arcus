//
//  SkyAwareApp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import OSLog

@main
struct SkyAwareApp: App {
    private let appRefreshID = "com.skyaware.app.refresh"
    private let logger = Logger.mainApp
    
    @State private var locationProvider = LocationManager()
    @State private var prov = SpcProvider(service: SpcService(client: SpcClient()))
    
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FeedCache.self])
        //        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: []) }// configurations: [modelConfiguration] }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()
    
    // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.skyaware.app.refresh"]
    
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
            await scheduleNextAppRefresh() // Ensure we schedule again
            
            // TODO: Run our scheduled code
            await prov.loadFeed()
            
            let ol = await prov.outlooks
            let newest = ol.max { (event1, event2) in
                event1.published < event2.published
            }
            
            let mgr = NotificationManager()
            await mgr.notify(for: newest)
        }
        .backgroundTask(.urlSession("com.skyaware.background.url")) {
            
            logger.debug("background url task. TODO: Figure it out")
            // I think this gets called when the matching url session call returns...
        }
        .onChange(of: scenePhase) { _, newPhase in
            scheduleNextAppRefresh()
            //            if newPhase == .background {
            //                // Optionally re-schedule when going to background
            //                scheduleNextAppRefresh(earliest: Date().addingTimeInterval(30 * 60)) // placeholder; replace using CadencePlanner
            //            }
        }
    }
    
//    private func getNextRunTime() -> Date? {
//        let calendar = Calendar.current
//        var dateComponents = DateComponents()
//        
//        // Helper function to create a Date for a specific hour and minute today
//        func createDate(hour: Int, minute: Int) -> Date {
//            let today = Calendar.current.startOfDay(for: .now)
//            dateComponents.hour = hour
//            dateComponents.minute = minute
//            // random seconds between 13-37
//            let sec = Int.random(in: 13...37)
//            dateComponents.second = sec
//            return calendar.date(byAdding: dateComponents, to: today)!
//        }
//        
//        let scheduledTimes: [Date] = [
//            createDate(hour: 7, minute: 23),   // 7:23 AM
//            createDate(hour: 10, minute: 43), // 10:43 AM
//            createDate(hour: 14, minute: 13), // 2:13 PM
//            createDate(hour: 19, minute: 17)  // 7:17 PM
//        ]
//        
//        // 2. Get the current time
//        let currentTime = Date()
//        logger.debug("Current Time: \(currentTime.formatted(date: .omitted, time: .shortened))")
//        
//        // 3. Find all times that are in the future
//        let futureTimes = scheduledTimes.filter { $0 > currentTime }
//        
//        // 4. From the future times, find the earliest one (which will be the "next" time)
//        let nextTime = futureTimes.min { (date1, date2) in
//            date1 < date2
//        }
//        
//        // 5. Print the result
//        if let next = nextTime {
//            logger.debug("The next scheduled time is: \(next.formatted(date: .omitted, time: .shortened))")
//            var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
//            todayComponents.hour = calendar.component(.hour, from: next)
//            todayComponents.minute = calendar.component(.minute, from: next)
//            todayComponents.second = calendar.component(.second, from: next)
//            
//            return calendar.date(from: todayComponents)!
//        } else {
//            // If no future times are found, wrap around to the first time in the list
//            // This assumes the `scheduledTimes` array is already sorted in ascending order.
//            // If it's not sorted, you'd need to sort it first: `scheduledTimes.sorted().first`
//            if let firstTimeOfNextCycle = scheduledTimes.first {
//                let today = Calendar.current.startOfDay(for: .now)
//                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
//                let amComponent = calendar.dateComponents([.hour, .minute, .second], from: firstTimeOfNextCycle)
//                let am = Calendar.current.date(byAdding: amComponent, to: tomorrow)
//                
//                logger.debug("All times for today have passed. The next scheduled time (wrapping around) is: \(firstTimeOfNextCycle.formatted(date: .omitted, time: .shortened))")
//                
//                return am
//            } else {
//                logger.warning("The list of scheduled times is empty.")
//            }
//        }
//        
//        logger.warning("Should have a next time... investigate")
//        return nil
//    }
//    
//    func does(_ date: Date, matchHour targetHour: Int) -> Bool {
//        // Get the hour component from the date using the current calendar
//        let hour = Calendar.current.component(.hour, from: date)
//        return hour == targetHour
//    }
    
    // MARK - Schedule Next App Refresh
    private func scheduleNextAppRefresh() {
        logger.debug("Checking if we need to schedule an app refresh")
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            logger.debug("Pending tasks: \(requests.count)")
            
            guard requests.isEmpty else { return } // If we don't have any pending requests, schedule a new one
            
            let sch = Scheduler()
            let nextRun = sch.getNextRunTime()
            
            guard let nextRun else { return } // Ensure we received the next runtime from teh scheduler
            
            // Create the task and set its next runtime
            let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
            request.earliestBeginDate = nextRun
            
            do { try BGTaskScheduler.shared.submit(request) }
            catch { logger.error("Error submitting background task: \(error.localizedDescription)")}
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
