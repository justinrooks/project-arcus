//
//  MesoDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct MesoDetailView: View {
    let discussion: MesoscaleDiscussion

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 🔷 Header
                    Text(discussion.title)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.leading)

                    // 🕓 Published Date
                    Text("Published: \(formattedDate(discussion.published))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()

                    // 📝 Summary
                    Text(discussion.summary)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Divider()

                    // 🔗 Link Button
                    Link(destination: discussion.link) {
                        Label("Read Full Discussion", systemImage: "link")
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
}

#Preview {
    MesoDetailView(discussion: MesoscaleDiscussion(
        id: UUID(),
        title: "Day 1 MD",
        link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
        published: Date(),
        summary: "A SLGT risk of severe thunderstorms exists across the Plains.",
    ))
}
