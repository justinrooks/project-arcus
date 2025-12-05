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

enum NwsError: Error {
    case invalidUrl
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
