//
//  LocationPermissionView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import CoreLocation
import SwiftUI

struct LocationPermissionView: View {
    let isWorking: Bool
    let statusMessage: String?
    var authorizationStatus: CLAuthorizationStatus? = nil
    let onEnable: () -> Void
    let onSkip: () -> Void

    @ScaledMetric(relativeTo: .largeTitle)
    private var symbolSize: CGFloat = 80

    var body: some View {
        OnboardingStepShell {
            Image(systemName: "location.fill")
                .font(.system(size: symbolSize))
                .foregroundColor(.skyAwareAccent)

            Text("Location Access")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(locationDescription)
                .font(.body)
                .multilineTextAlignment(.center)

            Text("To support timely location-based alerts, SkyAware may share an approximate location with the alert service, such as your county, fire zone, or a coarse geographic index.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("SkyAware does not sell your data, use it for advertising, or track you across apps or websites.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            VStack(spacing: 12) {
                if let statusMessage {
                    ProgressView(statusMessage)
                        .font(.subheadline)
                        .tint(.skyAwareAccent)
                }

                Button(action: onEnable) {
                    Text(primaryActionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: SkyAwareRadius.chip)
                                .fill(Color.skyAwareAccent)
                        )
                }
                .disabled(isWorking)

                Button("Skip for Now", action: onSkip)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .disabled(isWorking)
            }
        }
    }
}

private extension LocationPermissionView {
    var locationDescription: String {
        switch authorizationStatus {
        case .denied:
            "Location access is off. Open Settings to enable location for SkyAware."
        case .restricted:
            "Location access is unavailable because of system restrictions. Settings may not be able to change this."
        default:
            "SkyAware uses your location to determine relevant severe-weather risk and nearby weather events for your area."
        }
    }

    var primaryActionTitle: String {
        switch authorizationStatus {
        case .denied:
            "Open Settings"
        case .restricted:
            "Continue without Location"
        default:
            "Enable Location"
        }
    }
}

enum LocationPermissionRecoveryAction: Equatable {
    case openSettings
    case requestAuthorization
    case unavailable
    case none

    static func resolve(authorizationStatus: CLAuthorizationStatus) -> Self {
        switch authorizationStatus {
        case .notDetermined:
            .requestAuthorization
        case .denied:
            .openSettings
        case .restricted:
            .unavailable
        case .authorizedAlways, .authorizedWhenInUse:
            .none
        @unknown default:
            .unavailable
        }
    }

    static func perform(
        authorizationStatus: CLAuthorizationStatus,
        openSettings: () -> Void,
        requestAuthorization: () -> Void
    ) {
        switch resolve(authorizationStatus: authorizationStatus) {
        case .openSettings:
            openSettings()
        case .requestAuthorization:
            requestAuthorization()
        case .unavailable, .none:
            break
        }
    }
}

#Preview {
    LocationPermissionView(
        isWorking: false,
        statusMessage: nil,
        onEnable: {},
        onSkip: {}
    )
}

private struct LocationPermissionViewAX5Preview: PreviewProvider {
    static var previews: some View {
        LocationPermissionView(
            isWorking: false,
            statusMessage: nil,
            onEnable: {},
            onSkip: {}
        )
        .previewDevice("iPhone SE (3rd generation)")
        .environment(\.dynamicTypeSize, .accessibility5)
    }
}
