//
//  SettingsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import SwiftUI

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
    
    // MARK: Notification Settings
    @AppStorage(
        "morningSummaryEnabled",
        store: UserDefaults.shared
    ) private var morningSummaryEnabled: Bool = true
    
    @AppStorage(
        "mesoNotificationEnabled",
        store: UserDefaults.shared
    ) private var mesoNotificationEnabled: Bool = true
    
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
                HStack {
                    Toggle(isOn: $morningSummaryEnabled) {
                        Text("Enable Morning Summaries")
                    }
                }
                HStack {
                    Toggle(isOn: $mesoNotificationEnabled) {
                        Text("Enable Meso Notifications")
                    }
                }
            }
            
            Section(header: Text("Onboarding Debug")) {
                HStack {
                    Toggle(isOn: $onboardingComplete) {
                        Text("Onboarding flow complete")
                    }
                }
                HStack {
                    Text("Disclaimer Accepted Version: \(disclaimerVersion)")
                }
                HStack {
                    Button("Reset disclaimer") {
                        UserDefaults.shared?.removeObject(forKey: "onboardingCompleted")
                        UserDefaults.shared?.removeObject(forKey: "disclaimerAcceptedVersion")
                    }
                }
            }
            
            //            Section(header: Text("AI PREFERENCES")) {
            //                HStack{
            //                    Toggle(isOn: $aiSummariesEnabled) {
            //                        Text("Enable AI summaries")
            //                    }
            //                }
            //                
            //                if aiSummariesEnabled {
            //                    HStack{
            //                        Toggle(isOn: $aiShareLocation) {
            //                            Text("Include location for summary")
            //                        }
            //                    }
            //                    HStack{
            //                        // Image(uiImage: UIImage(named: "Language")!)
            //                        Picker(selection: brevityBinding, label: Text("Level of detail")) {
            //                            ForEach(BrevityLevel.allCases) { level in
            //                                Text(level.title).tag(level)
            //                            }
            //                        }
            //                        // .pickerStyle(SegmentedPickerStyle())
            //                    }
            //                    HStack{
            //                        // Image(uiImage: UIImage(named: "Language")!)
            //                        Picker(selection: audienceBinding, label: Text("Interest level")) {
            //                            ForEach(AudienceLevel.allCases) { level in
            //                                Text(level.title).tag(level)
            //                            }
            //                        }
            //                        // .pickerStyle(SegmentedPickerStyle())
            //                    }
            //                }
            //            }
            
            Section("Diagnostics") {
                NavigationLink("Background Refresh History") {
                    BgHealthDiagnosticsView()
                        .navigationTitle("Background Refresh History")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
                NavigationLink("Diagnostic Info") {
                    DiagnosticsView()
                        .navigationTitle("Diagnostic Info")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
                NavigationLink("Log Viewer") {
                    LogViewerView()
                        .navigationTitle("Log Viewer")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                        .scrollContentBackground(.hidden)
                        .background(.skyAwareBackground)
                }
            }
            .foregroundColor(.orange) // Visual indicator it's debug-only
            
            Section("About") {
                HStack {
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
                HStack {
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
