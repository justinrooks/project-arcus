//
//  Dependencies.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/24/25.
//

import Foundation
import OSLog
import SwiftData

final class Dependencies: Sendable {
    // MARK: Core config

    let appRefreshID: String
    let logger: Logger
    
    // MARK: Data / persistence
    
    private let _modelContainer: ModelContainer?
    
    private let _outlookRepo: ConvectiveOutlookRepo?
    private let _mesoRepo: MesoRepo?
    private let _watchRepo: WatchRepo?
    private let _stormRiskRepo: StormRiskRepo?
    private let _severeRiskRepo: SevereRiskRepo?
    private let _healthStore: BgHealthStore?
    
    // MARK: Location / grid
    
    private let _locationProvider: LocationProvider?
    private let _locationManager: LocationManager?
    private let _gridProvider: GridPointProvider?
    
    // MARK: Providers
    
    private let _spcProvider: SpcProvider?
    private let _nwsProvider: NwsProvider?
    
    // MARK: Background orchestration
    
    private let _refreshPolicy: RefreshPolicy?
    private let _cadencePolicy: CadencePolicy?
    private let _orchestrator: BackgroundOrchestrator?
    private let _scheduler: BackgroundScheduler?
    
    // MARK: Public non-optional accessors
    var modelContainer: ModelContainer {
        guard let value = _modelContainer else {
            fatalError("Dependencies.modelContainer used while unconfigured")
        }
        return value
    }
    var outlookRepo: ConvectiveOutlookRepo {
        guard let value = _outlookRepo else {
            fatalError("Dependencies.outlookRepo used while unconfigured")
        }
        return value
    }
    var mesoRepo: MesoRepo {
        guard let value = _mesoRepo else {
            fatalError("Dependencies.mesoRepo used while unconfigured")
        }
        return value
    }
    var watchRepo: WatchRepo {
        guard let value = _watchRepo else {
            fatalError("Dependencies.watchRepo used while unconfigured")
        }
        return value
    }
    var stormRiskRepo: StormRiskRepo {
        guard let value = _stormRiskRepo else {
            fatalError("Dependencies.stormRiskRepo used while unconfigured")
        }
        return value
    }
    var severeRiskRepo: SevereRiskRepo {
        guard let value = _severeRiskRepo else {
            fatalError("Dependencies.severeRiskRepo used while unconfigured")
        }
        return value
    }
    var healthStore: BgHealthStore {
        guard let value = _healthStore else {
            fatalError("Dependencies.healthStore used while unconfigured")
        }
        return value
    }
    var locationProvider: LocationProvider {
        guard let value = _locationProvider else {
            fatalError("Dependencies.locationProvider used while unconfigured")
        }
        return value
    }
    var locationManager: LocationManager {
        guard let value = _locationManager else {
            fatalError("Dependencies.locationManager used while unconfigured")
        }
        return value
    }
    var gridProvider: GridPointProvider {
        guard let value = _gridProvider else {
            fatalError("Dependencies.gridProvider used while unconfigured")
        }
        return value
    }
    var spcProvider: SpcProvider {
        guard let value = _spcProvider else {
            fatalError("Dependencies.spcProvider used while unconfigured")
        }
        return value
    }
    var nwsProvider: NwsProvider {
        guard let value = _nwsProvider else {
            fatalError("Dependencies.nwsProvider used while unconfigured")
        }
        return value
    }
    var refreshPolicy: RefreshPolicy {
        guard let value = _refreshPolicy else {
            fatalError("Dependencies.refreshPolicy used while unconfigured")
        }
        return value
    }
    var cadencePolicy: CadencePolicy {
        guard let value = _cadencePolicy else {
            fatalError("Dependencies.cadencePolicy used while unconfigured")
        }
        return value
    }
    var orchestrator: BackgroundOrchestrator {
        guard let value = _orchestrator else {
            fatalError("Dependencies.orchestrator used while unconfigured")
        }
        return value
    }
    var scheduler: BackgroundScheduler {
        guard let value = _scheduler else {
            fatalError("Dependencies.scheduler used while unconfigured")
        }
        return value
    }
    
    // MARK: Protocol surfaces - SPC
    var spcSync: any SpcSyncing {
        guard let _spcProvider else {
            fatalError("Dependencies.spcSync used while unconfigured")
        }
        return _spcProvider
    }
    
    var spcRisk: any SpcRiskQuerying {
        guard let _spcProvider else {
            fatalError("Dependencies.spcRisk used while unconfigured")
        }
        return _spcProvider
    }
    
    var spcMapData: any SpcMapData {
        guard let _spcProvider else {
            fatalError("Dependencies.spcMapData used while unconfigured")
        }
        return _spcProvider
    }
    
    var spcOutlook: any SpcOutlookQuerying {
        guard let _spcProvider else {
            fatalError("Dependencies.spcOulook used while unconfigured")
        }
        return _spcProvider
    }
    
    // MARK: Protocol surfaces - NWS
    var nwsRisk: any NwsRiskQuerying {
        guard let _nwsProvider else {
            fatalError("Dependencies.nwsRisk used while unconfigured")
        }
        return _nwsProvider
    }
    
    var nwsSync: any NwsSyncing {
        guard let _nwsProvider else {
            fatalError("Dependencies.nwsRisk used while unconfigured")
        }
        return _nwsProvider
    }
    
    var nwsMetadata: any NwsMetadataProviding {
        guard let _nwsProvider else {
            fatalError("Dependencies.nwsMetadata used while unconfigured")
        }
        return _nwsProvider
    }
    
    // MARK: Protocol surfaces - Location
    var locationClient: LocationClient {
        guard let _locationProvider else {
            fatalError("Dependencies.locationClient used while unconfigured")
        }
        return makeLocationClient(provider: _locationProvider)
    }
    
    
    // MARK: - Designated initializer
    init(
        appRefreshID: String,
        logger: Logger,
        modelContainer: ModelContainer?,
        outlookRepo: ConvectiveOutlookRepo?,
        mesoRepo: MesoRepo?,
        watchRepo: WatchRepo?,
        stormRiskRepo: StormRiskRepo?,
        severeRiskRepo: SevereRiskRepo?,
        healthStore: BgHealthStore?,
        locationProvider: LocationProvider?,
        locationManager: LocationManager?,
        gridProvider: GridPointProvider?,
        spcProvider: SpcProvider?,
        nwsProvider: NwsProvider?,
        refreshPolicy: RefreshPolicy?,
        cadencePolicy: CadencePolicy?,
        orchestrator: BackgroundOrchestrator?,
        scheduler: BackgroundScheduler?
    ) {
        self.appRefreshID = appRefreshID
        self.logger = logger
        self._modelContainer = modelContainer
        self._outlookRepo = outlookRepo
        self._mesoRepo = mesoRepo
        self._watchRepo = watchRepo
        self._stormRiskRepo = stormRiskRepo
        self._severeRiskRepo = severeRiskRepo
        self._healthStore = healthStore
        self._locationProvider = locationProvider
        self._locationManager = locationManager
        self._gridProvider = gridProvider
        self._spcProvider = spcProvider
        self._nwsProvider = nwsProvider
        self._refreshPolicy = refreshPolicy
        self._cadencePolicy = cadencePolicy
        self._orchestrator = orchestrator
        self._scheduler = scheduler
    }
    
    @MainActor
    static func live() -> Dependencies {
        let logger = Logger.deps
        let appRefreshID = "com.skyaware.app.refresh"
        
        // Shared SwiftData context
        let schema = Schema([
            ConvectiveOutlook.self,
            MD.self,
            StormRisk.self,
            SevereRisk.self,
            BgRunSnapshot.self,
            Watch.self
        ])
        let config = ModelConfiguration("SkyAware_Data", schema: schema) //isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: config)
            Logger.mainApp.debug("ModelContainer created for schema: SkyAware_Data")
        } catch {
            Logger.mainApp.critical("Failed to create ModelContainer: \(error.localizedDescription, privacy: .public)")
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Location
        let locationProvider = LocationProvider()
        let sink: LocationSink = { [locationProvider] update in await locationProvider.send(update: update) }
        let locationManager = LocationManager(onUpdate: sink)
        logger.info("LocationManager configured")
        
        // Configure the network cache
        URLCache.shared = .skyAwareCache
        logger.debug("URLCache configured for SkyAware")
        
        // HTTP clients
        let nwsClient = NwsHttpClient()
        let spcClient = SpcHttpClient()
        
        // Create our data layer repos
        let outlookRepo    = ConvectiveOutlookRepo(modelContainer: container)
        let mesoRepo       = MesoRepo(modelContainer: container)
        let watchRepo      = WatchRepo(modelContainer: container)
        let stormRiskRepo  = StormRiskRepo(modelContainer: container)
        let severeRiskRepo = SevereRiskRepo(modelContainer: container)
        let healthStore    = BgHealthStore(modelContainer: container)
        let metadataRepo   = NwsMetadataRepo()
        
        logger.debug("Repositories initialized")
        
        // Providers
        let spc = SpcProvider(outlookRepo: outlookRepo,
                              mesoRepo: mesoRepo,
                              watchRepo: watchRepo,
                              stormRiskRepo: stormRiskRepo,
                              severeRiskRepo: severeRiskRepo,
                              client: spcClient)
        let spcProvider = spc
        logger.debug("SPC provider initialized")

        let gridProvider = GridPointProvider(client: nwsClient, locationProvider: locationProvider, repo: metadataRepo)
        logger.info("GridPoint provider initialized")
        
        let nws = NwsProvider(
            watchRepo: watchRepo,
            metadataRepo: metadataRepo,
            gridMetadataProvider: gridProvider,
            client: nwsClient)
        let nwsProvider = nws
        logger.debug("NWS provider initialized")
        
        // Background policies
        let refreshPolicy = RefreshPolicy()
        let cadencePolicy = CadencePolicy()
        logger.info("Refresh policy & cadence configured")
        
        logger.debug("Composing morning summary engine")
        let morning = MorningEngine(
            rule: AmRangeLocalRule(),
            gate: MorningGate(store: DefaultMorningStore()),
            composer: MorningComposer(),
            sender: Sender()
        )
        
        logger.debug("Composing meso notification engine")
        let meso = MesoEngine(
            rule: MesoRule(),
            gate: MesoGate(store: DefaultMesoStore()),
            composer: MesoComposer(),
            sender: Sender(),
            spc: spc
        )
        
        logger.debug("Composing watch notification engine")
        let watch = WatchEngine(
            rule: WatchRule(),
            gate: WatchGate(store: DefaultWatchStore()),
            composer: WatchComposer(),
            sender: Sender(),
            nws: nws
        )
        
        let notificationSettingsProvider = UserDefaultsNotificationSettingsProvider()
        
        let orchestrator = BackgroundOrchestrator(
            spcProvider: spc,
            nwsProvider: nws,
            locationProvider: locationProvider,
            policy: refreshPolicy,
            engine: morning,
            mesoEngine: meso,
            watchEngine: watch,
            health: healthStore,
            cadence: cadencePolicy,
            notificationSettingsProvider: notificationSettingsProvider
        )
        
        let scheduler = BackgroundScheduler(refreshId: appRefreshID)
        logger.info("Providers ready; background orchestrator configured")
        
        return Dependencies(
            appRefreshID: appRefreshID,
            logger: logger,
            modelContainer: container,
            outlookRepo: outlookRepo,
            mesoRepo: mesoRepo,
            watchRepo: watchRepo,
            stormRiskRepo: stormRiskRepo,
            severeRiskRepo: severeRiskRepo,
            healthStore: healthStore,
            locationProvider: locationProvider,
            locationManager: locationManager,
            gridProvider: gridProvider,
            spcProvider: spcProvider,
            nwsProvider: nwsProvider,
            refreshPolicy: refreshPolicy,
            cadencePolicy: cadencePolicy,
            orchestrator: orchestrator,
            scheduler: scheduler
        )
    }
    
    static var unconfigured: Dependencies { Dependencies(appRefreshID: "UNCONFIGURED",
                                                         logger: Logger(subsystem: "SkyAware", category: "UnconfiguredDeps"),
                                                         modelContainer: nil,
                                                         outlookRepo: nil,
                                                         mesoRepo: nil,
                                                         watchRepo: nil,
                                                         stormRiskRepo: nil,
                                                         severeRiskRepo: nil,
                                                         healthStore: nil,
                                                         locationProvider: nil,
                                                         locationManager: nil,
                                                         gridProvider: nil,
                                                         spcProvider: nil,
                                                         nwsProvider: nil,
                                                         refreshPolicy: nil,
                                                         cadencePolicy: nil,
                                                         orchestrator: nil,
                                                         scheduler: nil)
    }

    private struct UserDefaultsNotificationSettingsProvider: NotificationSettingsProviding {
        func current() async -> NotificationSettings {
            await MainActor.run {
                NotificationSettings(
                    morningSummariesEnabled: readBoolSetting(forKey: "morningSummaryEnabled", defaultValue: true),
                    mesoNotificationsEnabled: readBoolSetting(forKey: "mesoNotificationEnabled", defaultValue: true),
                    watchNotificationsEnabled: readBoolSetting(forKey: "watchNotificationEnabled", defaultValue: true)
                )
            }
        }

        @MainActor
        private func readBoolSetting(forKey key: String, defaultValue: Bool) -> Bool {
            if let value = UserDefaults.shared?.object(forKey: key) as? Bool {
                return value
            }
            return defaultValue
        }
    }
}
