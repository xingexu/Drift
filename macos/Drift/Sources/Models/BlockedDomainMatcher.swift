import Foundation

/// Matches the destination host, never a domain mentioned in a path or query.
enum BlockedDomainMatcher {
    static func matches(url: String, domain: String) -> Bool {
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let rawHost = parsed.host?.lowercased() else { return false }
        let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let blocked = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !blocked.isEmpty else { return false }
        return host == blocked || host.hasSuffix("." + blocked)
    }
}
