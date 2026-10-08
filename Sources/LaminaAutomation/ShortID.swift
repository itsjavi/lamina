import Foundation

/// Ids as results show them: the shortest prefix of the UUID's hex digits that is unique among its neighbors (the
/// documents open, or one document's layers), at least eight long. Requests take that, a longer prefix or the full
/// UUID, with or without hyphens and in any case.
public enum ShortID {
    public static let minimumOutput = 8
    public static let minimumInput = 4

    /// Lowercase hex digits only: `3F2A9C1B-…` becomes `3f2a9c1b…`.
    public static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0 != "-" }
    }

    public static func hex(_ id: UUID) -> String { normalize(id.uuidString) }

    /// Each id's shortest unique prefix among `ids`.
    public static func prefixes(_ ids: some Sequence<UUID>) -> [UUID: String] {
        let all = Array(Set(ids)).map { ($0, hex($0)) }.sorted { $0.1 < $1.1 }
        var result: [UUID: String] = [:]
        for (index, (id, text)) in all.enumerated() {
            // Sorted, an id shares its longest common prefix with a neighbor.
            let shared = [index > 0 ? all[index - 1].1 : nil, index + 1 < all.count ? all[index + 1].1 : nil]
                .compactMap { $0 }.map { commonPrefixLength(text, $0) }.max() ?? 0
            result[id] = String(text.prefix(max(minimumOutput, shared + 1)))
        }
        return result
    }

    /// The one id `query` (already normalized) is a prefix of; nil when none is, `.ambiguous` when several are.
    public static func resolve<T>(_ query: String, among candidates: [(id: UUID, value: T)], noun: String) throws -> T {
        let matches = candidates.filter { hex($0.id).hasPrefix(query) }
        guard let first = matches.first else { throw AutomationError(.notFound, "No \(noun) has the id \(query).") }
        guard matches.count == 1 else {
            throw AutomationError(.ambiguous, "\(matches.count) \(noun)s have ids starting with \(query); give more of the id.")
        }
        return first.value
    }

    private static func commonPrefixLength(_ a: String, _ b: String) -> Int {
        zip(a, b).prefix { $0 == $1 }.count
    }
}
