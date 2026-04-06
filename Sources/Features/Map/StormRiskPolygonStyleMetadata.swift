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
    private static let cigLevelKey = "cigLevel"

    let fillHex: String?
    let strokeHex: String?
    let cigLevel: Int?

    init(fillHex: String?, strokeHex: String?, cigLevel: Int? = nil) {
        self.fillHex = Self.normalized(fillHex)
        self.strokeHex = Self.normalized(strokeHex)
        self.cigLevel = Self.normalized(cigLevel)
    }

    var encoded: String? {
        var parts: [String] = []

        if let fillHex {
            parts.append("\(Self.fillKey)=\(fillHex)")
        }
        if let strokeHex {
            parts.append("\(Self.strokeKey)=\(strokeHex)")
        }
        if let cigLevel {
            parts.append("\(Self.cigLevelKey)=\(cigLevel)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ";")
    }

    static func decode(from subtitle: String?) -> StormRiskPolygonStyleMetadata? {
        guard let subtitle else { return nil }

        var fillHex: String?
        var strokeHex: String?
        var cigLevel: Int?

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
            case cigLevelKey:
                if let value {
                    cigLevel = Int(value)
                }
            default:
                continue
            }
        }

        guard fillHex != nil || strokeHex != nil || cigLevel != nil else { return nil }
        return StormRiskPolygonStyleMetadata(fillHex: fillHex, strokeHex: strokeHex, cigLevel: cigLevel)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func normalized(_ level: Int?) -> Int? {
        guard let level, (1...3).contains(level) else { return nil }
        return level
    }
}
