//
//  MesoDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct MesoDetailView: View {
    let discussion: MesoscaleDiscussion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 🔷 Header
                Text(discussion.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.leading)
                
                // 🕓 Published Date
                Text("Published: \(formattedDate(discussion.published))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // 🌩️ Key Threats Summary (if any)
                if let keyThreats = parseKeyThreats(from: discussion.summary), !keyThreats.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Threat Summary")
                            .font(.headline)
                        
                        ForEach(keyThreats, id: \.self) { threat in
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: threat.icon)
                                    .foregroundColor(threat.color)
                                    .font(.title2)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(threat.color.opacity(0.2)))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(threat.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(threat.detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemGray6))
                    )
                }
                
                // 📝 Full Discussion (DisclosureGroup)
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        //                        Text("Full Discussion")
                        //                            .font(.headline)
                        
                        Text(discussion.summary)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 4)
                    }
                } label: {
                    Text("Full Detail")
                        .font(.headline)
                }
                
                
                // 🔗 Link Button
                Link(destination: discussion.link) {
                    Label("Read Full Mesoscale Discussion", systemImage: "link")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Meso Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func parseKeyThreats(from text: String) -> [ThreatItem]? {
        var items: [ThreatItem] = []
        
        let threats: [(pattern: String, icon: String, title: String, color: Color)] = [
            ("probability of watch issuance.*?(\\d+)", "percent", "Watch Issuance Probability", .orange),
            ("tornado.*?(\\d+\\.?\\d*)", "tornado", "Tornado", .red),
            ("wind.*?(\\d+[-–]\\d+|\\d+).*?mph", "wind", "Wind Gusts", .blue),
            ("hail.*?(\\d+\\.?\\d*)", "cloud.hail", "Hail Size", .gray)
        ]
        
        for threat in threats {
            if let regex = try? NSRegularExpression(pattern: threat.pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let matchRange = Range(match.range(at: 1), in: text) {
                    let value = String(text[matchRange])
                    let detail: String
                    switch threat.title {
                    case "Watch Issuance Probability": detail = "\(value)% chance"
                    case "Tornado": detail = "Estimated up to \(value) mph"
                    case "Wind Gusts": detail = "Expected range: \(value) mph"
                    case "Hail Size": detail = "Estimated size: \(value) in"
                    default: detail = value
                    }
                    items.append(ThreatItem(icon: threat.icon, title: threat.title, detail: detail, color: threat.color))
                }
            }
        }
        
        return items.isEmpty ? nil : items
    }
    
    struct ThreatItem: Hashable {
        let icon: String
        let title: String
        let detail: String
        let color: Color
    }
}

#Preview {
    MesoDetailView(discussion: SpcProvider.previewData.meso.first!)
}
