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
    
    // MARK: Main
    static let mainApp = Logger(subsystem: subsystem, category: "MainApp")
    static let deps = Logger(subsystem: subsystem, category: "Deps")
    
    // MARK: Plumbing
    static let spcClient = Logger(subsystem: subsystem, category: "SpcClient")
    static let downloader = Logger(subsystem: subsystem, category: "Downloader")
    static let spcProvider = Logger(subsystem: subsystem, category: "SpcProvider")
    static let rssParser = Logger(subsystem: subsystem, category: "RssParser")
    static let nwsClient = Logger(subsystem: subsystem, category: "NwsClient")
    static let nwsProvider = Logger(subsystem: subsystem, category: "NwsProvider")
    static let nwsGridProvider = Logger(subsystem: subsystem, category: "NwsGridProvider")
    
    
    // MARK: Repos
    static let convectiveRepo = Logger(subsystem: subsystem, category: "ConvectiveOutlookRepo")
    static let mesoRepo = Logger(subsystem: subsystem, category: "MesoRepo")
    static let watchRepo = Logger(subsystem: subsystem, category: "WatchRepo")
    static let stormRiskRepo = Logger(subsystem: subsystem, category: "StormRiskRepo")
    static let severeRiskRepo = Logger(subsystem: subsystem, category: "SevereRiskRepo")
    static let riskProductRepo = Logger(subsystem: subsystem, category: "RiskProductRepo")
    
    // MARK: Background
    static let orchestrator = Logger(subsystem: subsystem, category: "BGOrchestrator")
    static let scheduler = Logger(subsystem: subsystem, category: "Scheduler")
    static let refreshPolicy = Logger(subsystem: subsystem, category: "RefreshPolicy")
    static let cadencePolicy = Logger(subsystem: subsystem, category: "CadencePolicy")
    
    // MARK: Location
    static let locationMgr = Logger(subsystem: subsystem, category: "LocationMgr")
    static let locationProvider = Logger(subsystem: subsystem, category: "LocationProvider")
    
    // MARK: Views
    static let alertView = Logger(subsystem: subsystem, category: "AlertView")
    static let convectiveView = Logger(subsystem: subsystem, category: "ConvectiveView")
    static let mainView = Logger(subsystem: subsystem, category: "MainView")
    static let mapping = Logger(subsystem: subsystem, category: "Mapping")
    
    // MARK: Notification
    static let notifications = Logger(subsystem: subsystem, category: "NotificationManager")
    
    // MARK: Morning Notification
    static let engine = Logger(subsystem: subsystem, category: "notificationEngine")
    static let rule = Logger(subsystem: subsystem, category: "notificationRule")
    static let gate = Logger(subsystem: subsystem, category: "notificationGate")
    static let composer = Logger(subsystem: subsystem, category: "notificationComposer")
    static let sender = Logger(subsystem: subsystem, category: "notificationSender")
    
    // MARK: Meso Notification
    static let mesoEngine = Logger(subsystem: subsystem, category: "mesoEngine")
    static let mesoGate = Logger(subsystem: subsystem, category: "mesoGate")
    static let mesoRule = Logger(subsystem: subsystem, category: "mesoRule")
}
