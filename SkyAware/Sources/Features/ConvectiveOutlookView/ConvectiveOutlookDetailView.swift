//
//  ConvectiveOutlookDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct ConvectiveOutlookDetailView: View {
    let outlook: ConvectiveOutlookDTO
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // 🔷 Header
//                VStack(alignment: .leading, spacing: 4) {
//                    if let day = outlook.day {
//                        Text("Day \(day) Convective Outlook")
//                            .font(.title)
//                            .bold()
//                    } else {
//                        Text(outlook.title)
//                            .font(.title)
//                            .bold()
//                    }
//                    
//                    if let risk = outlook.riskLevel {
//                        Text("Risk Level: \(risk)")
//                            .font(.headline)
//                            .foregroundColor(colorForRisk(risk))
//                    }
//                }
                
                // 🕓 Metadata
                if let issued = outlook.issued{
                    Text("Issued: \(formattedDate(issued))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let until = outlook.validUntil{
                    Text("Valid Until: \(formattedDate(until))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Divider()
                
                // 📝 Summary
                if let fullText = outlook.cleanText {
                    Text(fullText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }

                
                Divider()
                
                // 🔗 Link Button
                Link(destination: outlook.link) {
                    Label("View Outlook Online", systemImage: "link")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accentColor(.teal)
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Day \(outlook.day ?? 1) Outlook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
    }
}

extension ConvectiveOutlookDetailView {
    // 📆 Helper for formatting the date
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 🌈 Optional: color code by risk level
    func colorForRisk(_ risk: String) -> Color {
        switch risk.uppercased() {
        case "MRGL": return .green
        case "SLGT": return .yellow
        case "ENH": return .orange
        case "MDT": return .red
        case "HIGH": return .purple
        default: return .gray
        }
    }
}

#Preview {
    let preview = Preview(ConvectiveOutlook.self)
    
    return NavigationStack {
        ConvectiveOutlookDetailView(outlook: ConvectiveOutlook.sampleOutlookDtos[0])
            .navigationTitle("Outlook Details")
            .navigationBarTitleDisplayMode(.inline)
        //            .toolbarBackground(.visible, for: .navigationBar)      // <- non-translucent
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
//        ConvectiveOutlookDetailView(outlook: ConvectiveOutlook.sampleOutlookDtos[0])
    }
}
