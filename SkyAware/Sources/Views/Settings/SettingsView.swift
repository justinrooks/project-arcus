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
            Section(header: Text("AI PREFERENCES"), content: {
                HStack{
                    // Image(uiImage: UIImage(named: "DarkMode")!)
                    Toggle(isOn: $aiSummariesEnabled) {
                        Text("Enable AI summaries")
                    }
                }
                
                if aiSummariesEnabled {
                    HStack{
                        // Image(uiImage: UIImage(named: "DarkMode")!)
                        Toggle(isOn: $aiShareLocation) {
                            Text("Include location for summary")
                        }
                    }
                    HStack{
                        // Image(uiImage: UIImage(named: "Language")!)
                        Picker(selection: brevityBinding, label: Text("Level of detail")) {
                            ForEach(BrevityLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        // .pickerStyle(SegmentedPickerStyle())
                    }
                    HStack{
                        // Image(uiImage: UIImage(named: "Language")!)
                        Picker(selection: audienceBinding, label: Text("Interest level")) {
                            ForEach(AudienceLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        // .pickerStyle(SegmentedPickerStyle())
                    }
                }
            })
        }
        Spacer()
    }
}

#Preview {
    SettingsView()
}
