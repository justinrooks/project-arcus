//
//  SettingsDiagnosticsView.swift
//  SkyAware
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct SettingsDiagnosticsView: View {
    @Environment(LocationSession.self) private var locationSession

    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false

    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0

    @AppStorage(
        RemoteNotificationRegistrar.apnsDeviceTokenKey,
        store: UserDefaults.shared
    ) private var apnsDeviceToken: String = ""

    @State private var installationId: String = ""

    private var h3CellDisplay: String {
        guard let h3Cell = locationSession.currentSnapshot?.h3Cell else {
            return "No location hash yet"
        }
        return String(UInt64(bitPattern: h3Cell), radix: 16)
    }

    private var installationIdDisplay: String {
        installationId.isEmpty ? "Not available yet" : installationId
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                sectionCard(title: "Diagnostics", symbol: "stethoscope", accent: .orange) {
                    NavigationLink {
                        BgHealthDiagnosticsView()
                            .navigationTitle("Background Refresh History")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    } label: {
                        settingsNavRow("Background Refresh History", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    NavigationLink {
                        DiagnosticsView()
                            .navigationTitle("Ingestion Diagnostics")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    } label: {
                        settingsNavRow("Ingestion Diagnostics", systemImage: "stethoscope")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    NavigationLink {
                        LogViewerView()
                            .navigationTitle("Log Viewer")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                    } label: {
                        settingsNavRow("Log Viewer", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }

                sectionCard(title: "Location Diagnostics", symbol: "iphone.badge.location", accent: .orange) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Installation ID")
                            .font(.subheadline.weight(.semibold))
                        Text(installationIdDisplay)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("APNs Device Token")
                            .font(.subheadline.weight(.semibold))
                        Text(apnsDeviceToken.isEmpty ? "Not registered yet" : apnsDeviceToken)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current H3 Cell (Res 8)")
                            .font(.subheadline.weight(.semibold))
                        Text(h3CellDisplay)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                sectionCard(title: "Onboarding Debug", symbol: "ladybug", accent: .orange) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Onboarding flow complete", isOn: $onboardingComplete)
                        Text("Marks onboarding as completed so the app skips first-run onboarding screens on launch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    infoRow("Disclaimer Accepted Version", "\(disclaimerVersion)")
                    Button("Reset disclaimer") {
                        UserDefaults.shared?.removeObject(forKey: "onboardingCompleted")
                        UserDefaults.shared?.removeObject(forKey: "disclaimerAcceptedVersion")
                    }
                    .skyAwareGlassButtonStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .task {
            await loadInstallationId()
        }
    }

    private func loadInstallationId() async {
        let value = await InstallationIdentityStore.shared.installationId()
        await MainActor.run {
            installationId = value
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        symbol: String,
        accent: Color = .primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(accent)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func settingsNavRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 4)
        .font(.subheadline.weight(.medium))
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsDiagnosticsView()
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environment(LocationSession.preview)
}
