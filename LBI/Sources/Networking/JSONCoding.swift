import Foundation

/// Centralised JSON coding strategies so DTOs decode/encode consistently with
/// the San Fo backend.
///
/// Backend conventions:
/// - All fields are camelCase (so NO snake_case conversion).
/// - Dates are MongoDB BSON extended JSON, e.g.
///   `{ "$date": { "$numberLong": "1700000000000" } }` where the value is the
///   Unix time in milliseconds as a string. The relaxed form
///   `{ "$date": "2023-11-14T22:13:20Z" }` is also accepted on input.
/// - Money is whole HKD integers.
extension JSONDecoder {
    static let lbiDefault: JSONDecoder = {
        let decoder = JSONDecoder()
        // Backend is camelCase — keep keys as-is.
        decoder.keyDecodingStrategy = .useDefaultKeys
        // Dates arrive as BSON extended JSON, handled by `BSONDate` below.
        return decoder
    }()
}

extension JSONEncoder {
    static let lbiDefault: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }()
}

/// A `Date` wrapper that decodes/encodes MongoDB BSON extended-JSON dates.
///
/// Decoding accepts either:
/// - canonical: `{ "$date": { "$numberLong": "1700000000000" } }`
/// - relaxed:   `{ "$date": "2023-11-14T22:13:20Z" }`
///
/// Encoding always emits the canonical millisecond form, which the backend
/// accepts when we send dates (e.g. `birthDate`).
struct BSONDate: Codable, Equatable, Hashable {
    let date: Date

    init(_ date: Date) { self.date = date }

    private enum OuterKeys: String, CodingKey { case date = "$date" }
    private enum InnerKeys: String, CodingKey { case numberLong = "$numberLong" }

    init(from decoder: Decoder) throws {
        let outer = try decoder.container(keyedBy: OuterKeys.self)

        // Relaxed form: "$date" is an ISO-8601 string.
        if let iso = try? outer.decode(String.self, forKey: .date) {
            if let parsed = BSONDate.isoFormatter.date(from: iso)
                ?? BSONDate.isoFractionalFormatter.date(from: iso) {
                date = parsed
                return
            }
            throw DecodingError.dataCorruptedError(
                forKey: .date, in: outer,
                debugDescription: "Unrecognised ISO-8601 date string: \(iso)"
            )
        }

        // Canonical form: "$date" -> { "$numberLong": "<millis>" }.
        let inner = try outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .date)
        let millisString = try inner.decode(String.self, forKey: .numberLong)
        guard let millis = Double(millisString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .numberLong, in: inner,
                debugDescription: "Expected $numberLong to be a numeric string, got \(millisString)"
            )
        }
        date = Date(timeIntervalSince1970: millis / 1000)
    }

    func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: OuterKeys.self)
        var inner = outer.nestedContainer(keyedBy: InnerKeys.self, forKey: .date)
        let millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
        try inner.encode(String(millis), forKey: .numberLong)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

extension BSONDate {
    /// Convenience for optional decoding sites.
    static func from(_ date: Date?) -> BSONDate? { date.map(BSONDate.init) }
}
