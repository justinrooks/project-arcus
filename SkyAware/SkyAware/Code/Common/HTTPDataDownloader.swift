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

extension URLSession {
    static let fastFailing: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5 // Fail fast if request is slow
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()
}


extension URLSession: HTTPDataDownloader {
    func httpData(from request: URLRequest) async throws -> Data {
        var attempt = 0
        let maxAttempts = 5
        let backoffTimes: [UInt64] = [0, 10, 15, 20, 25]
        
        while attempt < maxAttempts {
            do {
                let (data, response) = try await self.data(for: request, delegate: nil)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      validStatus.contains(httpResponse.statusCode) else {
                    throw DownloaderError.networkError
                }
                
                return data
            } catch {
                attempt += 1
                
                if attempt < maxAttempts {
                    let waitTime = backoffTimes[attempt]
                    print("Attempt \(attempt) failed, backing off for \(waitTime) seconds...")
                    try? await Task.sleep(for: .seconds(Int(waitTime)))
                } else {
                    throw error
                }
            }
        }
        
        throw DownloaderError.networkError
    }
}
