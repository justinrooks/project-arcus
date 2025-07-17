//
//  HTTPDataDownloader.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

let validStatus = 200...299

protocol HTTPDataDownloader: Sendable {
    func httpData(from: URLRequest) async throws -> Data
}

extension URLSession: HTTPDataDownloader {
    func httpData(from request: URLRequest) async throws -> Data {
        let (data, response) = try await self.data(for: request, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse,
              validStatus.contains(httpResponse.statusCode) else {
            throw DownloaderError.networkError
        }

        return data
    }
}
