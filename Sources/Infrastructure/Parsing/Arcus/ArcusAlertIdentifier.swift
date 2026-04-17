//
//  ArcusAlertIdentifier.swift
//  SkyAware
//
//  Created by Codex on 4/17/26.
//

import Foundation

enum ArcusAlertIdentifier {
    static func canonical(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let uuid = UUID(uuidString: trimmed) else {
            return trimmed
        }

        // TODO(server): Replace this client-side UUID string canonicalization once
        // Arcus Signal and APNs guarantee one explicit series-id format end-to-end.
        return uuid.uuidString
    }

    static func canonical(_ uuid: UUID) -> String {
        uuid.uuidString
    }
}
