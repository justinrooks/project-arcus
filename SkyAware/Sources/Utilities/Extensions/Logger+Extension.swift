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
    static let appMain = Logger(subsystem: subsystem, category: "app.main")
    static let appDependencies = Logger(subsystem: subsystem, category: "app.dependencies")
    
    // MARK: Plumbing
    static let providersSpcClient = Logger(subsystem: subsystem, category: "providers.spc.client")
    static let networkDownloader = Logger(subsystem: subsystem, category: "network.downloader")
    static let providersSpc = Logger(subsystem: subsystem, category: "providers.spc")
    static let parsingRss = Logger(subsystem: subsystem, category: "parsing.rss")
    static let providersNwsClient = Logger(subsystem: subsystem, category: "providers.nws.client")
    static let providersNws = Logger(subsystem: subsystem, category: "providers.nws")
    static let providersNwsGrid = Logger(subsystem: subsystem, category: "providers.nws.grid")
    
    
    // MARK: Repos
    static let reposConvectiveOutlook = Logger(subsystem: subsystem, category: "repos.convectiveOutlook")
    static let reposMeso = Logger(subsystem: subsystem, category: "repos.meso")
    static let reposWatch = Logger(subsystem: subsystem, category: "repos.watch")
    static let reposStormRisk = Logger(subsystem: subsystem, category: "repos.stormRisk")
    static let reposSevereRisk = Logger(subsystem: subsystem, category: "repos.severeRisk")
    static let reposRiskProduct = Logger(subsystem: subsystem, category: "repos.riskProduct")
    static let reposFireRisk = Logger(subsystem: subsystem, category: "repos.fireRisk")
    static let reposNwsMetadata = Logger(subsystem: subsystem, category: "repos.nwsMetadata")
    
    // MARK: Background
    static let backgroundOrchestrator = Logger(subsystem: subsystem, category: "background.orchestrator")
    static let backgroundScheduler = Logger(subsystem: subsystem, category: "background.scheduler")
    static let backgroundRefreshPolicy = Logger(subsystem: subsystem, category: "background.refreshPolicy")
    static let backgroundCadencePolicy = Logger(subsystem: subsystem, category: "background.cadencePolicy")
    
    // MARK: Location
    static let locationManager = Logger(subsystem: subsystem, category: "location.manager")
    static let locationProvider = Logger(subsystem: subsystem, category: "location.provider")
    
    // MARK: Views
    static let uiAlert = Logger(subsystem: subsystem, category: "ui.alert")
    static let uiConvective = Logger(subsystem: subsystem, category: "ui.convective")
    static let uiMain = Logger(subsystem: subsystem, category: "ui.main")
    static let uiMap = Logger(subsystem: subsystem, category: "ui.map")
    static let uiSummary = Logger(subsystem: subsystem, category: "ui.summary")
    static let uiHome = Logger(subsystem: subsystem, category: "ui.home")
    static let uiSettings = Logger(subsystem: subsystem, category: "ui.settings")
    static let uiDiagnostics = Logger(subsystem: subsystem, category: "ui.diagnostics")
    static let uiOnboarding = Logger(subsystem: subsystem, category: "ui.onboarding")
    
    // MARK: Notification
    static let notificationsManager = Logger(subsystem: subsystem, category: "notifications.manager")
    
    // MARK: Morning Notification
    static let notificationsMorningEngine = Logger(subsystem: subsystem, category: "notifications.morning.engine")
    static let notificationsMorningRule = Logger(subsystem: subsystem, category: "notifications.morning.rule")
    static let notificationsMorningGate = Logger(subsystem: subsystem, category: "notifications.morning.gate")
    static let notificationsMorningComposer = Logger(subsystem: subsystem, category: "notifications.morning.composer")
    
    // MARK: Meso Notification
    static let notificationsMesoEngine = Logger(subsystem: subsystem, category: "notifications.meso.engine")
    static let notificationsMesoGate = Logger(subsystem: subsystem, category: "notifications.meso.gate")
    static let notificationsMesoRule = Logger(subsystem: subsystem, category: "notifications.meso.rule")
    static let notificationsMesoComposer = Logger(subsystem: subsystem, category: "notifications.meso.composer")
    
    // MARK: Watch Notification
    static let notificationsWatchEngine = Logger(subsystem: subsystem, category: "notifications.watch.engine")
    static let notificationsWatchRule = Logger(subsystem: subsystem, category: "notifications.watch.rule")
    static let notificationsWatchComposer = Logger(subsystem: subsystem, category: "notifications.watch.composer")
    static let notificationsWatchGate = Logger(subsystem: subsystem, category: "notifications.watch.gate")

    // MARK: Notification Delivery
    static let notificationsSender = Logger(subsystem: subsystem, category: "notifications.sender")
}
