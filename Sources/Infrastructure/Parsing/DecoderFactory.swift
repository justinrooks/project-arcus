//
//  DecoderFactory.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/18/25.
//

import Foundation

enum DecoderFactory {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let string = try? container.decode(String.self) {
                if let date = ISO8601DateFormatter().date(from: string) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date string: \(string)"
                )
            }

            if let epoch = try? container.decode(Double.self) {
                return normalizeEpochDate(epoch)
            }

            if let epochInt = try? container.decode(Int.self) {
                return normalizeEpochDate(TimeInterval(epochInt))
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date value type."
            )
        }
        return d
    }
    
    static var base: JSONDecoder {
        JSONDecoder()
    }

    private static func normalizeEpochDate(_ epoch: TimeInterval) -> Date {
        let seconds = epoch > 10_000_000_000 ? epoch / 1_000 : epoch
        let referenceDateOffset: TimeInterval = 978_307_200 // 2001-01-01T00:00:00Z
        let normalizedSeconds: TimeInterval

        if seconds > 0 && seconds < referenceDateOffset {
            normalizedSeconds = seconds + referenceDateOffset
        } else {
            normalizedSeconds = seconds
        }

        return Date(timeIntervalSince1970: normalizedSeconds)
    }
}
