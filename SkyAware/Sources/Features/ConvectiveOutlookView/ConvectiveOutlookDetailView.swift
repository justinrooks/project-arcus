//
//  ConvectiveOutlookDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct ConvectiveOutlookDetailView: View {
    let outlook: ConvectiveOutlookDTO

    private var trimmedDiscussion: String? {
        outlook.cleanText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metadataCard

                if let trimmedDiscussion {
                    Text(trimmedDiscussion)
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
    
    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let issued = outlook.issued {
                Text("Issued: \(issued.shorten())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if let until = outlook.validUntil {
                Text("Valid Until: \(until.shorten())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .cardBackground(cornerRadius: 20, shadowOpacity: 0.1, shadowRadius: 10, shadowY: 4)
    }
}

#Preview {
    NavigationStack {
        ConvectiveOutlookDetailView(outlook: ConvectiveOutlook.sampleOutlookDtos[0])
            .navigationTitle("Outlook Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
