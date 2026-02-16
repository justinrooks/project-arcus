//
//  SkyAwareErrors.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/21/25.
//

import Foundation

// Consolidate all the errors for SkyAware to this
// file. Keeps them from being spread all over the
// app.

enum OtherErrors: Error {
    case nilContext
    case contextFetchError
    case contextSaveError
    case timeoutError
}

enum NwsError: Error, Equatable {
    case invalidUrl
    case parsingError
    case missingData
    case networkError(status: Int)
    case rateLimited(retryAfterSeconds: Int?)
    case serviceUnavailable(retryAfterSeconds: Int?)
}

enum SpcError: Error {
    case missingData
    case missingRssData
    case missingGeoJsonData
    case networkError
    case parsingError
    case invalidUrl
}

enum GeocodeError: Error {
    case noResults
    case noCoordinate
}

//enum DownloaderError: Error {
//    case missingData
//    case networkError
//}
//
//extension DownloaderError: LocalizedError {
//    public var errorDescription: String? {
//        switch self {
//        case .missingData:
//            return "Downloader data is missing."
//        case .networkError:
//            return "Downloader network error."
//        }
//    }
//}

extension SpcError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return "SPC data is missing."
        case .missingRssData:
            return "SPC RSS data is missing."
        case .missingGeoJsonData:
            return "GeoJSON data is missing."
        case .networkError:
            return "SPC data network error."
        case .parsingError:
            return "SPC data parsing error."
        case .invalidUrl:
            return "Url is nil or invalid"
        }
    }
}

extension NwsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "NWS URL is nil or invalid."
        case .parsingError:
            return "NWS data parsing error."
        case .missingData:
            return "NWS response data is missing."
        case .networkError(let status):
            return "NWS network request failed with HTTP status \(status)."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "NWS rate limited (429). Retry after \(retryAfter) seconds."
            }
            return "NWS rate limited (429)."
        case .serviceUnavailable(let retryAfter):
            if let retryAfter {
                return "NWS service unavailable (503). Retry after \(retryAfter) seconds."
            }
            return "NWS service unavailable (503)."
        }
    }
}
