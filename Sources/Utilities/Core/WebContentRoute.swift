//
//  WebContentRoute.swift
//  SkyAware
//

import Foundation

struct WebContentRoute: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let title: String?
    let sourceName: String?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String? = nil,
        sourceName: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.sourceName = sourceName
    }
}

enum WebContentNavigationDecision: Sendable, Equatable {
    case inApp
    case external
    case unsupported
}

enum WebContentPolicy {
    private static let inAppSchemes: Set<String> = ["http", "https"]
    private static let trustedDomains: Set<String> = [
        "weather.gov",
        "spc.noaa.gov",
        "weatherkit.apple.com"
    ]
    private static let externalSchemes: Set<String> = [
        "mailto", "tel", "sms", "maps", "facetime", "facetime-audio", "itms-apps", "itms-appss"
    ]

    static func decision(for url: URL) -> WebContentNavigationDecision {
        guard let scheme = url.scheme?.lowercased(), scheme.isEmpty == false else {
            return .unsupported
        }

        if inAppSchemes.contains(scheme) {
            guard let host = url.host?.lowercased(), host.isEmpty == false else {
                return .unsupported
            }
            return isTrusted(host: host) ? .inApp : .external
        }

        if externalSchemes.contains(scheme) {
            return .external
        }

        return .external
    }

    static func canOpenInApp(_ url: URL) -> Bool {
        decision(for: url) == .inApp
    }

    private static func isTrusted(host: String) -> Bool {
        trustedDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
