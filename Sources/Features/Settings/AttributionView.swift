//
//  AttributionView.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/19/26.
//

import SwiftUI
import WeatherKit
import OSLog

struct AttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openURL) private var openURL
    
    private let logger = Logger.uiHome
    
    // MARK: Local handles
    private var weatherClient: WeatherClient { dependencies.weatherClient }
    
    @State private var attribution: WeatherAttribution?
    @State private var webRoute: WebContentRoute?
    
    var body: some View {
        VStack {
            if let attribution {
                AsyncImage(
                    url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                        image.resizable()
                            .scaledToFit()
                            .frame(height: 10)
                    } placeholder: {
                        ProgressView()
                    }
                Button(attribution.serviceName) {
                    switch WebContentPolicy.decision(for: attribution.legalPageURL) {
                    case .inApp:
                        webRoute = WebContentRoute(
                            url: attribution.legalPageURL,
                            title: "Attribution",
                            sourceName: attribution.serviceName
                        )
                    case .external:
                        openURL(attribution.legalPageURL)
                    case .unsupported:
                        break
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $webRoute) { route in
            WebContentView(route: route)
        }
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
            attribution = await weatherClient.weatherAttribution()
        }
    }
}

#Preview {
    AttributionView()
}
