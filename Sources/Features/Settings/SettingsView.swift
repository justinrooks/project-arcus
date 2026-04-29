//
//  SettingsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import SwiftUI
import OSLog

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
    @Environment(LocationSession.self) private var locationSession
    private let logger = Logger.uiSettings
    private let locationReliabilityLogger = Logger.uiLocationReliability
    
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
    
    var body: some View {
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
                                if newValue, sendL8nToSignal == false {
                                    sendL8nToSignal = true
                                    return
                                }
                                Task {
                                    await locationSession.pushServerNotificationPreferenceUpdate()
                                }
                            }
                        Text("Subscribe this device to server-driven push alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

//                sectionCard(title: "AI Summary Preferences", symbol: "sparkles") {
//                    Toggle("AI summaries", isOn: $aiSummariesEnabled)
//                    Toggle("Share location context", isOn: $aiShareLocation)
//
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("Brevity")
//                            .font(.subheadline.weight(.semibold))
//                        Picker("Brevity", selection: brevityBinding) {
//                            ForEach(BrevityLevel.allCases) { level in
//                                Text(level.title).tag(level)
//                            }
//                        }
//                        .pickerStyle(.segmented)
//                    }
//
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("Audience")
//                            .font(.subheadline.weight(.semibold))
//                        Picker("Audience", selection: audienceBinding) {
//                            ForEach(AudienceLevel.allCases) { level in
//                                Text(level.title).tag(level)
//                            }
//                        }
//                        .pickerStyle(.segmented)
//                    }
//                }

                sectionCard(title: "Location", symbol: "iphone.badge.location", accent: .orange) {
                    VStack() {
                        Toggle("Share Location with Signal", isOn: $sendL8nToSignal)
                            .onChange(of: sendL8nToSignal) { _, newValue in
                                handleNotificationToggle(newValue, for: "Send Location to Signal")
                                if newValue {
                                    _ = locationSession.requestAlwaysAuthorizationUpgradeIfNeeded()
                                    Task {
                                        await locationSession.pushServerNotificationPreferenceUpdate()
                                    }
                                } else {
                                    serverNotificationEnabled = false
                                    Task {
                                        await locationSession.pushServerNotificationPreferenceUpdate(forceUpload: true)
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
            _ = locationSession.requestAlwaysAuthorizationUpgradeIfNeeded()
        case .openSettings:
            locationSession.openSettings()
        case .none:
            return
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
