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
                VStack(alignment: .leading, spacing: 8) {
                    if let issued = outlook.issued {
                        Text("Issued: \(issued.shorten())")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    if let until = outlook.validUntil {
                        Text("Valid Until: \(until.shorten())")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .cardBackground(cornerRadius: 20, shadowOpacity: 0.1, shadowRadius: 10, shadowY: 4)

                if let fullText = outlook.cleanText {
                    Text(fullText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding()
                        .cardBackground(cornerRadius: 20, shadowOpacity: 0.1, shadowRadius: 10, shadowY: 4)
                }

                Link(destination: outlook.link) {
                    Label("View Outlook Online", systemImage: "arrow.up.right.square")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .skyAwareGlassButtonStyle(prominent: true)

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
    NavigationStack {
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
