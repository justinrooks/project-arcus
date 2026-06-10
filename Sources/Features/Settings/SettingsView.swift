//
//  SettingsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import SwiftUI
import OSLog
import UserNotifications

enum BrevityLevel: Int, CaseIterable, Identifiable, Codable {
    case essential = 0
    case standard = 1
    case detailed = 2
    
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .essential: return "Essential"
        case .standard:  return "Standard"
        case .detailed:  return "Detailed"
        }
    }
}

enum AudienceLevel: Int, CaseIterable, Identifiable, Codable {
    case novice = 0
    case enthusiast = 1
    case stormChaser = 2
    
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .novice:       return "Novice"
        case .enthusiast:   return "Enthusiast"
        case .stormChaser:  return "Storm Chaser"
        }
    }
}


struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocationSession.self) private var locationSession
    private let logger = Logger.uiSettings
    private let locationReliabilityLogger = Logger.uiLocationReliability
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var suppressNextServerNotificationSync = false
    
    // MARK: Notification Settings
    @AppStorage(
        "morningSummaryEnabled",
        store: UserDefaults.shared
    ) private var morningSummaryEnabled: Bool = true
    
    @AppStorage(
        "mesoNotificationEnabled",
        store: UserDefaults.shared
    ) private var mesoNotificationEnabled: Bool = true
    
    @AppStorage(
        "serverNotificationEnabled",
        store: UserDefaults.shared
    ) private var serverNotificationEnabled: Bool = true
    
    // MARK: Debugging
    @AppStorage(
        "sendL8ntoSignal",
        store: UserDefaults.shared
    ) private var sendL8nToSignal: Bool = true
    
    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0

    @AppStorage(
        "mapWarningGeometryVisible",
        store: UserDefaults.shared
    ) private var mapWarningGeometryVisible: Bool = true
    
    // MARK: AI Settings
    @AppStorage("aiSummaryEnabled", store: UserDefaults.shared) private var aiSummariesEnabled: Bool = true
    @AppStorage("aiShareLocation", store: UserDefaults.shared) private var aiShareLocation: Bool = true
    @AppStorage("aiBrevity", store: UserDefaults.shared) private var brevityIndex: Int = 0
    @AppStorage("aiAudience", store: UserDefaults.shared) private var audienceIndex: Int = 0
    
    private var brevityBinding: Binding<BrevityLevel> {
        Binding(
            get: { BrevityLevel(rawValue: brevityIndex) ?? .essential },
            set: { brevityIndex = $0.rawValue }
        )
    }
    
    private var audienceBinding: Binding<AudienceLevel> {
        Binding(
            get: { AudienceLevel(rawValue: audienceIndex) ?? .novice },
            set: { audienceIndex = $0.rawValue }
        )
    }

    private var notificationPreferenceState: NotificationPreferenceState {
        .init(
            authorizationStatus: notificationAuthorizationStatus,
            morningSummariesEnabled: morningSummaryEnabled,
            mesoNotificationsEnabled: mesoNotificationEnabled,
            serverNotificationsEnabled: serverNotificationEnabled
        )
    }
    
    var body: some View {
        let notificationState = notificationPreferenceState

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                sectionCard(title: "Notification Preferences", symbol: "bell.badge", accent: .orange) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Morning Summaries", isOn: $morningSummaryEnabled)
                            .onChange(of: morningSummaryEnabled) { _, newValue in
                                handleNotificationToggle(newValue, for: "Morning Summaries")
                            }
                        Text("Get a daily morning update with a concise overview of local weather hazards and outlook conditions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Meso Notifications", isOn: $mesoNotificationEnabled)
                            .onChange(of: mesoNotificationEnabled) { _, newValue in
                                handleNotificationToggle(newValue, for: "Meso Notifications")
                            }
                        Text("Receive alerts when new mesoscale discussions are issued for your area.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Subscribe to Server Notifications", isOn: $serverNotificationEnabled)
                            .onChange(of: serverNotificationEnabled) { _, newValue in
                                handleNotificationToggle(newValue, for: "Server Notifications")
                                if suppressNextServerNotificationSync {
                                    suppressNextServerNotificationSync = false
                                    return
                                }
                                if newValue, sendL8nToSignal == false {
                                    sendL8nToSignal = true
                                    return
                                }
                                Task {
                                    await locationSession.syncNotificationPreference(enabled: newValue)
                                }
                            }
                        Text("Subscribe this device to server-driven push alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("iOS Notification Access")
                            Spacer()
                            Text(notificationState.authorizationStatusTitle)
                                .foregroundStyle(.secondary)
                        }

                        Text(notificationState.systemAvailabilityCopy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if let actionTitle = notificationState.recoveryActionTitle {
                        Button(actionTitle) {
                            locationSession.openSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.subheadline.weight(.semibold))
                    }
                }

                sectionCard(title: "Location", symbol: "iphone.badge.location", accent: .orange) {
                    VStack() {
                        Toggle("Share Location with Signal", isOn: $sendL8nToSignal)
                            .onChange(of: sendL8nToSignal) { _, newValue in
                                handleNotificationToggle(newValue, for: "Send Location to Signal")
                                if newValue {
                                    Task {
                                        await locationSession.updateLocationSharingPreference(enabled: true)
                                    }
                                } else {
                                    let wasSubscribed = serverNotificationEnabled
                                    suppressNextServerNotificationSync = wasSubscribed
                                    serverNotificationEnabled = false
                                    Task {
                                        await locationSession.updateLocationSharingPreference(enabled: false)
                                        if wasSubscribed {
                                            await locationSession.syncNotificationPreference(enabled: false)
                                        }
                                    }
                                }
                            }
                        Text("Share your approximate location information with the alert server. This allows SkyAware to send you notifications relevant to your current location.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                sectionCard(title: "Alerts / Location Reliability", symbol: "checkmark.circle", accent: .orange) {
                    let reliability = locationSession.reliabilityState
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Location Access")
                            Spacer()
                            Text(reliability.settingsAuthorizationText)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Text("Location Precision")
                            Spacer()
                            Text(reliability.settingsAccuracyText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)

                    Text(reliability.settingsReliabilityCopy)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if let actionTitle = reliability.settingsActionTitle {
                        Button(actionTitle) {
                            handleReliabilityAction(reliability.settingsAction)
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.subheadline.weight(.semibold))
                    }
                }

                sectionCard(title: "Map", symbol: "map", accent: .orange) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Show Active Alerts on Map", isOn: $mapWarningGeometryVisible)
                        Text("Controls whether active warning geometry is shown on the map.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                sectionCard(title: "About", symbol: "info.circle", accent: .orange) {
                    infoRow("Version", Bundle.main.fullVersion)
                    infoRow("Disclaimer", "\(disclaimerVersion)")
                    NavigationLink("Diagnostics") {
                        SettingsDiagnosticsView()
                            .navigationTitle("Diagnostics")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .task {
            await refreshNotificationAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshNotificationAuthorizationStatus()
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        symbol: String,
        accent: Color = .primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(accent)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

}

extension SettingsView {
    @MainActor
    func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await Self.currentNotificationAuthorizationStatus()
    }

    func handleNotificationToggle(_ enabled: Bool, for notificationType: String) {
        guard enabled else { return }
        
        logger.info("Notification enabled for \(notificationType, privacy: .public)")
        Task {
            await RemoteNotificationRegistrar.shared.requestAuthorizationAndRegister()
        }
    }

    func handleReliabilityAction(_ action: LocationReliabilitySettingsAction) {
        let reliability = locationSession.reliabilityState
        locationReliabilityLogger.debug(
            "Settings reliability action=\(action.logName, privacy: .public) authorization=\(reliability.authorization.logName, privacy: .public) accuracy=\(reliability.accuracy.logName, privacy: .public)"
        )

        switch action {
        case .requestWhenInUse:
            locationSession.requestInteractiveAuthorization()
        case .requestAlwaysUpgrade:
            locationSession.openSettings()
        case .openSettings:
            locationSession.openSettings()
        case .none:
            return
        }
    }
}

struct NotificationPreferenceState: Equatable {
    let authorizationStatus: UNAuthorizationStatus
    let morningSummariesEnabled: Bool
    let mesoNotificationsEnabled: Bool
    let serverNotificationsEnabled: Bool

    var allowsNotificationDelivery: Bool {
        authorizationStatus.allowsNotificationDelivery
    }

    var effectiveMorningSummariesEnabled: Bool {
        morningSummariesEnabled && allowsNotificationDelivery
    }

    var effectiveMesoNotificationsEnabled: Bool {
        mesoNotificationsEnabled && allowsNotificationDelivery
    }

    var effectiveServerNotificationsEnabled: Bool {
        serverNotificationsEnabled && allowsNotificationDelivery
    }

    var authorizationStatusTitle: String {
        authorizationStatus.skyAwareTitle
    }

    var systemAvailabilityCopy: String {
        authorizationStatus.skyAwareAvailabilityCopy
    }

    var recoveryActionTitle: String? {
        authorizationStatus.skyAwareRecoveryActionTitle
    }
}

private extension SettingsView {
    static func currentNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        if let override = notificationAuthorizationOverride {
            return override
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static var notificationAuthorizationOverride: UNAuthorizationStatus? {
        guard let rawValue = ProcessInfo.processInfo.environment["UI_TESTS_NOTIFICATION_AUTH_MODE"] else {
            return nil
        }

        switch rawValue {
        case "authorized":
            return .authorized
        case "provisional":
            return .provisional
        case "ephemeral":
            return .ephemeral
        case "denied":
            return .denied
        case "notDetermined":
            return .notDetermined
        default:
            return nil
        }
    }
}

private extension UNAuthorizationStatus {
    var allowsNotificationDelivery: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    var skyAwareTitle: String {
        switch self {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Quiet"
        case .ephemeral:
            return "Temporary"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }

    var skyAwareAvailabilityCopy: String {
        switch self {
        case .authorized:
            return "iOS can deliver SkyAware notifications normally."
        case .provisional:
            return "iOS can deliver SkyAware notifications quietly until you promote them in Settings."
        case .ephemeral:
            return "iOS can deliver SkyAware notifications temporarily for this app session."
        case .denied:
            return "Notifications are disabled for SkyAware in iOS Settings. Your preferences are preserved and will apply again if you re-enable notifications."
        case .notDetermined:
            return "SkyAware can ask iOS for notification access. Your preferences are saved now and will apply if you allow notifications."
        @unknown default:
            return "SkyAware cannot determine notification availability right now."
        }
    }

    var skyAwareRecoveryActionTitle: String? {
        switch self {
        case .denied:
            return "Open Settings"
        case .authorized, .provisional, .ephemeral, .notDetermined:
            return nil
        @unknown default:
            return nil
        }
    }
}

#Preview {
    return NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
    .environment(LocationSession.preview)
}
