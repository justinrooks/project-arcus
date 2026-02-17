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
    private let logger = Logger.uiSettings
    
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
        "watchNotificationEnabled",
        store: UserDefaults.shared
    ) private var watchNotificationEnabled: Bool = true
    
    // MARK: Debugging
    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false
    
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
        Form {
            Section(header: Text("Notification Preferences")) {
                Toggle("Enable Morning Summaries", isOn: $morningSummaryEnabled)
                    .onChange(of: morningSummaryEnabled) { _, newValue in
                        handleNotificationToggle(newValue, for: "Morning Summaries")
                    }
                Toggle("Enable Meso Notifications", isOn: $mesoNotificationEnabled)
                    .onChange(of: mesoNotificationEnabled) { _, newValue in
                        handleNotificationToggle(newValue, for: "Meso Notifications")
                    }
                Toggle("Enable Watch Notifications", isOn: $watchNotificationEnabled)
                    .onChange(of: watchNotificationEnabled) { _, newValue in
                        handleNotificationToggle(newValue, for: "Watch Notifications")
                    }
            }
            
            Section(header: Text("Onboarding Debug")) {
                Toggle(isOn: $onboardingComplete) {
                    Text("Onboarding flow complete")
                }
                Text("Disclaimer Accepted Version: \(disclaimerVersion)")
                Button("Reset disclaimer") {
                    UserDefaults.shared?.removeObject(forKey: "onboardingCompleted")
                    UserDefaults.shared?.removeObject(forKey: "disclaimerAcceptedVersion")
                }
                .skyAwareGlassButtonStyle()
            }

            Section("Diagnostics") {
                NavigationLink {
                    BgHealthDiagnosticsView()
                        .navigationTitle("Background Refresh History")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                } label: {
                    Label("Background Refresh History", systemImage: "waveform.path.ecg")
                }
                NavigationLink {
                    DiagnosticsView()
                        .navigationTitle("Diagnostic Info")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                } label: {
                    Label("Diagnostic Info", systemImage: "stethoscope")
                }
                NavigationLink {
                    LogViewerView()
                        .navigationTitle("Log Viewer")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                } label: {
                    Label("Log Viewer", systemImage: "doc.text.magnifyingglass")
                }
            }
            .foregroundColor(.orange) // Visual indicator it's debug-only
            
            Section("About") {
                HStack(spacing: 8) {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.fullVersion) // e.g., "1.0.0 (1)"
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    //                    tapCount += 1
                    //                    if tapCount >= 7 {
                    //                        devMode = true
                    //                        tapCount = 0
                    //                    }
                }
                HStack(spacing: 8) {
                    Text("Disclaimer")
                    Spacer()
                    Text("\(disclaimerVersion)") // e.g., "1.0.0 (1)"
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    //                    tapCount += 1
                    //                    if tapCount >= 7 {
                    //                        devMode = true
                    //                        tapCount = 0
                    //                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
    }
}

extension SettingsView {
    func handleNotificationToggle(_ enabled: Bool, for notificationType: String) {
        if !enabled { return }
        
        logger.info("Notification enabled for \(notificationType, privacy: .public)")
        Task {
            await checkAuthorization()
        }
    }
    
    func checkAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
//        logger.info("Current notification authorization status: \(String(describing: settings.authorizationStatus), privacy: .public)")
        if settings.authorizationStatus == .notDetermined {
            do {
                try await center.requestAuthorization(options: [.alert, .sound, .badge])
//                logger.notice("Notification authorization requested: user responded (status may update asynchronously)")
            } catch {
//                logger.error("Error requesting notification permission: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

#Preview {
    return NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
