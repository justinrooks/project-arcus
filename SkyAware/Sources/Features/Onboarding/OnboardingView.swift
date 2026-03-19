//
//  OnboardingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import CoreLocation
import OSLog
import SwiftUI
import UserNotifications

@MainActor
struct OnboardingView: View {
    @Environment(\.dependencies) private var deps

    private let logger = Logger.appMain
    private let currentDisclaimerVersion = 1
    let locationMgr: LocationManager

    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false

    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0

    @State private var currentPage = 0
    @State private var locationStepState: PermissionStepState = .idle
    @State private var notificationStepState: PermissionStepState = .idle

    private var sync: any SpcSyncing { deps.spcSync }

    private var isArcusSignalPushEnabled: Bool {
        ArcusSignalConfiguration.configuredBaseURL() != nil
    }

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomeView {
                withAnimation {
                    currentPage = 1
                }
            }
            .tag(0)

            DisclaimerView {
                disclaimerVersion = currentDisclaimerVersion
                withAnimation {
                    currentPage = 2
                }
            }
            .tag(1)

            LocationPermissionView(
                isWorking: locationStepState.isWorking,
                statusMessage: locationStepState.statusMessage,
                onEnable: requestLocationPermission,
                onSkip: advanceToNotificationPage
            )
            .tag(2)

            NotificationPermissionView(
                isWorking: notificationStepState.isWorking,
                statusMessage: notificationStepState.statusMessage,
                onEnable: requestNotificationPermission,
                onSkip: completeOnboarding
            )
            .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(.skyAwareBackground)
    }

    private func requestLocationPermission() {
        guard !locationStepState.isWorking else { return }

        Task { @MainActor in
            locationStepState = .working("Waiting for your location choice...")
            _ = await resolveLocationAuthorization()
            locationStepState = .idle
            advanceToNotificationPage()
        }
    }

    private func requestNotificationPermission() {
        guard !notificationStepState.isWorking else { return }

        Task { @MainActor in
            await finalizeNotificationOnboarding()
        }
    }

    @MainActor
    private func resolveLocationAuthorization(timeout: Double = 30) async -> CLAuthorizationStatus {
        let currentStatus = locationMgr.authStatus
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        locationMgr.checkLocationAuthorization(isActive: true)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let status = locationMgr.authStatus
            if status != .notDetermined {
                return status
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        logger.notice("Timed out waiting for onboarding location permission response")
        return locationMgr.authStatus
    }

    @MainActor
    private func finalizeNotificationOnboarding() async {
        notificationStepState = .working("Requesting notification access...")
        let status = await RemoteNotificationRegistrar.shared.requestAuthorizationAndRegister()

        guard status.isRemoteRegistrationEligible else {
            notificationStepState = .idle
            completeOnboarding()
            return
        }

        guard isArcusSignalPushEnabled else {
            notificationStepState = .idle
            completeOnboarding()
            return
        }

        notificationStepState = .working("Finalizing device registration...")
        guard await RemoteNotificationRegistrar.shared.waitForDeviceToken() != nil else {
            logger.notice("Continuing onboarding without APNs token; token not received before timeout")
            notificationStepState = .idle
            completeOnboarding()
            return
        }

        let hasSnapshot = await deps.locationProvider.snapshot() != nil
        let canCaptureFreshSnapshot = locationMgr.authStatus.isAuthorizedForOnboardingLocation
        if hasSnapshot || canCaptureFreshSnapshot {
            notificationStepState = .working(
                hasSnapshot
                    ? "Sending your first location snapshot..."
                    : "Capturing your first location snapshot..."
            )
            let pushedSnapshot = await deps.locationProvider.pushLatestSnapshotWhenAvailable(timeout: 12)
            if !pushedSnapshot {
                logger.notice("Continuing onboarding without an uploaded location snapshot; none became available")
            }
        }

        notificationStepState = .idle
        completeOnboarding()
    }

    @MainActor
    private func advanceToNotificationPage() {
        withAnimation {
            currentPage = 3
        }
    }

    @MainActor
    private func completeOnboarding() {
        onboardingComplete = true
        Task {
            await sync.sync()
        }
    }
}

private enum PermissionStepState: Equatable {
    case idle
    case working(String)

    var isWorking: Bool {
        if case .working = self {
            return true
        }
        return false
    }

    var statusMessage: String? {
        switch self {
        case .idle:
            return nil
        case .working(let message):
            return message
        }
    }
}

private extension CLAuthorizationStatus {
    var isAuthorizedForOnboardingLocation: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
}

private extension UNAuthorizationStatus {
    var isRemoteRegistrationEligible: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}

#Preview {
    let provider = LocationProvider()
    let sink: LocationSink = { [provider] update in await provider.send(update: update) }
    let locationMgr = LocationManager(onUpdate: sink)
    
    OnboardingView(locationMgr: locationMgr)
}
