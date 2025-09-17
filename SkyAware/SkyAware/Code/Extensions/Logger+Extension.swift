//
//  Logger+Extension.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/21/25.
//

import Foundation
import OSLog

extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier!
    static let spcClient = Logger(subsystem: subsystem, category: "SpcClient")
    static let spcService = Logger(subsystem: subsystem, category: "SpcService")
    static let spcProvider = Logger(subsystem: subsystem, category: "SpcProvider")
    static let spcRepo = Logger(subsystem: subsystem, category: "SpcRepo")
    static let downloader = Logger(subsystem: subsystem, category: "Downloader")
    
//    static let downloader = Logger(subsystem: subsystem, category: "Downloader")
    static let locationMgr = Logger(subsystem: subsystem, category: "LocationMgr")
    static let rssParser = Logger(subsystem: subsystem, category: "RssParser")
    static let alertView = Logger(subsystem: subsystem, category: "AlertView")
    static let convectiveView = Logger(subsystem: subsystem, category: "ConvectiveView")
    static let mainView = Logger(subsystem: subsystem, category: "MainView")
    static let mapping = Logger(subsystem: subsystem, category: "Mapping")
    static let summaryProvider = Logger(subsystem: subsystem, category: "SummaryProvider")
    
    static let notifications = Logger(subsystem: subsystem, category: "NotificationManager")
    static let scheduler = Logger(subsystem: subsystem, category: "Scheduler")
    static let mainApp = Logger(subsystem: subsystem, category: "MainApp")
}
