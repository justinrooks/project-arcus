//
//  StormRiskPolygonStyleMetadata.swift
//  SkyAware
//
//  Created by Codex on 2/16/26.
//

import Foundation

/// Compact metadata container for SPC-provided polygon style values.
/// Stored in MKPolygon.subtitle to keep map rendering independent from model types.
struct StormRiskPolygonStyleMetadata: Sendable {
    private static let fillKey = "spcFill"
    private static let strokeKey = "spcStroke"

    let fillHex: String?
    let strokeHex: String?

    init(fillHex: String?, strokeHex: String?) {
        self.fillHex = Self.normalized(fillHex)
        self.strokeHex = Self.normalized(strokeHex)
    }

    var encoded: String? {
        var parts: [String] = []

        if let fillHex {
            parts.append("\(Self.fillKey)=\(fillHex)")
        }
        if let strokeHex {
            parts.append("\(Self.strokeKey)=\(strokeHex)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ";")
    }

    static func decode(from subtitle: String?) -> StormRiskPolygonStyleMetadata? {
        guard let subtitle else { return nil }

        var fillHex: String?
        var strokeHex: String?

        for pair in subtitle.split(separator: ";") {
            let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard keyValue.count == 2 else { continue }

            let key = String(keyValue[0])
            let value = normalized(String(keyValue[1]))

            switch key {
            case fillKey:
                fillHex = value
            case strokeKey:
                strokeHex = value
            default:
                continue
            }
        }

        guard fillHex != nil || strokeHex != nil else { return nil }
        return StormRiskPolygonStyleMetadata(fillHex: fillHex, strokeHex: strokeHex)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
