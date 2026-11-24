import Foundation

enum ArcusForgeConfiguration {
    private static let infoDictionaryKey = "ArcusForgeURL"
    private static let invalidHostCharacters = CharacterSet.whitespacesAndNewlines
        .union(.controlCharacters)
        .union(CharacterSet(charactersIn: "/?#@\\"))

    static func configuredBaseURL(bundle: Bundle = .main) -> URL? {
        configuredBaseURL(rawValue: bundle.object(forInfoDictionaryKey: infoDictionaryKey) as? String)
    }

    static func configuredBaseURL(rawValue: String?) -> URL? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: value, encodingInvalidCharacters: false),
              originComponents(for: url) != nil else {
            return nil
        }
        return url
    }

    static func originComponents(for url: URL) -> URLComponents? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty, !host.contains("$("),
              host.rangeOfCharacter(from: invalidHostCharacters) == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/" else {
            return nil
        }
        return components
    }
}
