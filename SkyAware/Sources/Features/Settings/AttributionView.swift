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
    
    private let logger = Logger.uiHome
    
    // MARK: Local handles
    private var weatherClient: WeatherClient { dependencies.weatherClient }
    
    @State private var attribution: WeatherAttribution?
    
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
                Text(.init("[\(attribution.serviceName)](\(attribution.legalPageURL))"))
                    .font(.caption2)
//                      .fontWeight(.semibold)
//                      .textCase(.uppercase)
                      .foregroundStyle(.secondary)
            }
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
