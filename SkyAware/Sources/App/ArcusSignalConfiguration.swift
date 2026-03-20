//
//  ArcusSignalConfiguration.swift
//  SkyAware
//
//  Created by Codex on 3/18/26.
//

import Foundation

enum ArcusSignalConfiguration {
    static let defaultBaseURL = URL(string: "https://skyaware.bennettbunker.com")!
    static let alertsPath = "/api/v1/alerts"
    static let locationSnapshotsPath = "/api/v1/devices/location-snapshots"

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

    static func resolvedBaseURL(bundle: Bundle = .main) -> URL {
        configuredBaseURL(bundle: bundle) ?? defaultBaseURL
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
