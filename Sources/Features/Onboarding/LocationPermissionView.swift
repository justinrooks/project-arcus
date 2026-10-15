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

    var body: some View {
        OnboardingStepShell {
            OnboardingStepHeading(
                symbol: "location.circle.fill",
                title: "Your Location Keeps You Aware"
            )

            Text(locationDescription)
                .font(.body)
                .multilineTextAlignment(.center)

            OnboardingInformationCard(
                symbol: "scope",
                title: "Local risk assessment",
                detail: "See severe-weather information and relevant alerts for your area."
            )

            OnboardingInformationCard(
                symbol: "map",
                title: "Approximate location sharing",
                detail: "For location-based alerts, SkyAware may send a coarse geographic index, county zone, or fire zone to its server. It does not send your precise latitude or longitude for this purpose."
            )

            Text("SkyAware does not sell location data, use it for advertising, or track you across apps or websites.")
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
                }
                .buttonStyle(OnboardingPrimaryActionStyle())
                .disabled(isWorking)

                Button("Skip for Now", action: onSkip)
                    .buttonStyle(OnboardingSecondaryActionStyle())
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
            "SkyAware uses your location to show severe-weather information for your area. You can continue without location access."
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
