//
//  DownloaderError.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/4/25.
//

import Foundation

enum DownloaderError: Error {
    case missingData
    case networkError
}

extension DownloaderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return "Downloader data is missing."
        case .networkError:
            return "Downloader network error."
        }
    }
}
