//
//  WatchDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct WatchDetailView: View {
    let watch: Watch

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 🔷 Header
                    Text(watch.title)
                        .font(.title)
                        .bold()
                        .multilineTextAlignment(.leading)

                    // 🕓 Published Date
                    Text("Published: \(formattedDate(watch.published))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()

                    // 📝 Summary
                    Text(watch.summary)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Divider()

                    // 🔗 Link Button
                    Link(destination: watch.link) {
                        Label("Read Full Watch Description", systemImage: "link")
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
            .navigationTitle("Watch Detail")
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
    WatchDetailView(watch: Watch(
        id: UUID(),
        title: "Day 1 Watch",
        link: URL(string: "https://spc.noaa.gov/products/outlook/day1otlk.html")!,
        published: Date(),
        summary: "A SLGT risk of severe thunderstorms exists across the Plains.",
    ))
}
