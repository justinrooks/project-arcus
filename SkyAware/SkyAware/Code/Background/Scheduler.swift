//
//  Scheduler.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/28/25.
//

import Foundation
import OSLog
import BackgroundTasks

enum ScheduleType: String {
    case convective
    case meso
    case watch
}

struct Scheduler {
    private let logger = Logger.scheduler
    private let scheduleType: ScheduleType = .convective
    
    // TODO: This could be handled better
    private let appRefreshID = "com.skyaware.app.refresh"
    
//    init(scheduleType: ScheduleType) {
//        self.logger.info("Initializing Scheduler for \(scheduleType.rawValue)")
//        self.scheduleType = scheduleType
//    }
    
    
    
    func getNextRunTime() -> Date? {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        
        // Helper function to create a Date for a specific hour and minute today
        func createDate(hour: Int, minute: Int) -> Date {
            let today = Calendar.current.startOfDay(for: .now)
            dateComponents.hour = hour
            dateComponents.minute = minute
            // random seconds between 3-27
            let sec = Int.random(in: 3...27)
            dateComponents.second = sec
            return calendar.date(byAdding: dateComponents, to: today)!
        }
        
        let scheduledTimes: [Date] = [
            createDate(hour: 7, minute: 23),   // 7:23 AM
            createDate(hour: 10, minute: 47), // 10:47 AM
            createDate(hour: 14, minute: 13), // 2:13 PM
            createDate(hour: 19, minute: 17)  // 7:17 PM
        ]
        
        // 2. Get the current time
        let currentTime = Date()
        logger.debug("Current Time: \(currentTime.formatted(date: .omitted, time: .shortened))")
        
        // 3. Find all times that are in the future
        let futureTimes = scheduledTimes.filter { $0 > currentTime }
        
        // 4. From the future times, find the earliest one (which will be the "next" time)
        let nextTime = futureTimes.min { (date1, date2) in
            date1 < date2
        }
        
        // 5. Print the result
        if let next = nextTime {
            logger.debug("The next scheduled time is: \(next.formatted(date: .omitted, time: .shortened))")
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            todayComponents.hour = calendar.component(.hour, from: next)
            todayComponents.minute = calendar.component(.minute, from: next)
            todayComponents.second = calendar.component(.second, from: next)
            
            // Just a sample of setting one up for the next day.
            //            let today = Calendar.current.startOfDay(for: .now)
            //            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            //            let amComponent = DateComponents(hour:8, minute: 15)
            //            let am = Calendar.current.date(byAdding: amComponent, to: tomorrow)
            //
            
            return calendar.date(from: todayComponents)!
        } else {
            // If no future times are found, wrap around to the first time in the list
            // This assumes the `scheduledTimes` array is already sorted in ascending order.
            // If it's not sorted, you'd need to sort it first: `scheduledTimes.sorted().first`
            if let firstTimeOfNextCycle = scheduledTimes.first {
                let today = Calendar.current.startOfDay(for: .now)
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                let amComponent = calendar.dateComponents([.hour, .minute, .second], from: firstTimeOfNextCycle)
                let am = Calendar.current.date(byAdding: amComponent, to: tomorrow)
                
                if let am {
                    logger.debug("All times for today have passed. The next scheduled time (wrapping around) is: \(am.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    logger.warning("Error determining next scheduled runtime")
                }

                return am
            } else {
                logger.warning("The list of scheduled times is empty.")
            }
        }
        
        logger.warning("Should have a next time... investigate")
        return nil
    }
    
    // MARK: - Schedule Next App Refresh
    func scheduleNextAppRefresh(_ outcome: BackgroundResult) {
        logger.debug("Checking if we need to schedule an app refresh")
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            logger.debug("Pending tasks: \(requests.count)")
            
            guard requests.isEmpty else { return } // If we don't have any pending requests, schedule a new one
            
            let nextRun = getNextRunTime()
            
            guard let nextRun else { return } // Ensure we received the next runtime from teh scheduler
            
            // Create the task and set its next runtime
            let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
            request.earliestBeginDate = nextRun
            
            do { try BGTaskScheduler.shared.submit(request) }
            catch { logger.error("Error submitting background task: \(error.localizedDescription)")}
        }
    }
    
    func does(_ date: Date, matchHour targetHour: Int) -> Bool {
        // Get the hour component from the date using the current calendar
        let hour = Calendar.current.component(.hour, from: date)
        return hour == targetHour
    }
}
