//
//  ArcusSignalConfiguration.swift
//  SkyAware
//
//  Created by Codex on 3/18/26.
//

import Foundation

enum ArcusSignalConfiguration {
    static func baseURL(bundle: Bundle = .main) -> URL {
        guard let url = configuredBaseURL(bundle: bundle) else {
            fatalError("Missing or invalid ARCUS_SIGNAL_URL")
        }

        return url
    }

    static let alertsPath = "/api/v2/alerts"
    static let locationSnapshotsPath = "/api/v1/devices/location-snapshots"
    static let devicePreferencesPath = "/api/v1/devices/preferences"
    static let stormSetupCurrentPath = "/api/v1/storm-setup/current"
    static let stormSetupAdvanedPath = "/api/v1/dev/anvil/profile-analysis"

    private static let infoDictionaryKey = "ArcusSignalURL"

    static func configuredBaseURL(bundle: Bundle = .main) -> URL? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: infoDictionaryKey) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), url.host?.isEmpty == false else {
            return nil
        }
        guard scheme == "https" || scheme == "http" else { return nil }
        return url
    }

    static func url(
        from baseURL: URL,
        path: String,
        queryItems: [URLQueryItem] = []
    ) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}
