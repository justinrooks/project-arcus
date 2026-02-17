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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                sectionCard(title: "Notification Preferences", symbol: "bell.badge.fill") {
                    Toggle("Morning Summaries", isOn: $morningSummaryEnabled)
                        .onChange(of: morningSummaryEnabled) { _, newValue in
                            handleNotificationToggle(newValue, for: "Morning Summaries")
                        }
                    Toggle("Meso Notifications", isOn: $mesoNotificationEnabled)
                        .onChange(of: mesoNotificationEnabled) { _, newValue in
                            handleNotificationToggle(newValue, for: "Meso Notifications")
                        }
                    Toggle("Watch Notifications", isOn: $watchNotificationEnabled)
                        .onChange(of: watchNotificationEnabled) { _, newValue in
                            handleNotificationToggle(newValue, for: "Watch Notifications")
                        }
                }

                sectionCard(title: "AI Summary Preferences", symbol: "sparkles") {
                    Toggle("AI summaries", isOn: $aiSummariesEnabled)
                    Toggle("Share location context", isOn: $aiShareLocation)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brevity")
                            .font(.subheadline.weight(.semibold))
                        Picker("Brevity", selection: brevityBinding) {
                            ForEach(BrevityLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Audience")
                            .font(.subheadline.weight(.semibold))
                        Picker("Audience", selection: audienceBinding) {
                            ForEach(AudienceLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                sectionCard(title: "Diagnostics", symbol: "stethoscope", accent: .orange) {
                    NavigationLink {
                        BgHealthDiagnosticsView()
                            .navigationTitle("Background Refresh History")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    } label: {
                        settingsNavRow("Background Refresh History", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    NavigationLink {
                        DiagnosticsView()
                            .navigationTitle("Diagnostic Info")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    } label: {
                        settingsNavRow("Diagnostic Info", systemImage: "stethoscope")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    NavigationLink {
                        LogViewerView()
                            .navigationTitle("Log Viewer")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    } label: {
                        settingsNavRow("Log Viewer", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }

                sectionCard(title: "Onboarding Debug", symbol: "ladybug.fill", accent: .orange) {
                    Toggle("Onboarding flow complete", isOn: $onboardingComplete)
                    infoRow("Disclaimer Accepted Version", "\(disclaimerVersion)")
                    Button("Reset disclaimer") {
                        UserDefaults.shared?.removeObject(forKey: "onboardingCompleted")
                        UserDefaults.shared?.removeObject(forKey: "disclaimerAcceptedVersion")
                    }
                    .skyAwareGlassButtonStyle()
                }

                sectionCard(title: "About", symbol: "info.circle.fill") {
                    infoRow("Version", Bundle.main.fullVersion)
                    infoRow("Disclaimer", "\(disclaimerVersion)")
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
        .cardBackground(cornerRadius: 24, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
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

    private func settingsNavRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 4)
        .font(.subheadline.weight(.medium))
        .contentShape(Rectangle())
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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
