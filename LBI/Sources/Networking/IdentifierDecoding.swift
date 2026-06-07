import Foundation

/// Helpers for decoding the backend's primary key, which is serialized as
/// `id` in some payloads and `_id` in others (per backend: accept both).
extension KeyedDecodingContainer {
    /// Decodes a required identifier from either `id` or `_id`.
    func decodeIdentifier() throws -> String where Key == IdentifierCodingKey {
        if let id = try decodeIfPresent(String.self, forKey: .id) { return id }
        if let underscored = try decodeIfPresent(String.self, forKey: ._id) { return underscored }
        throw DecodingError.keyNotFound(
            IdentifierCodingKey.id,
            .init(codingPath: codingPath, debugDescription: "Missing both `id` and `_id`")
        )
    }
}

/// Coding keys covering both spellings of the primary key.
enum IdentifierCodingKey: String, CodingKey {
    case id
    case _id = "_id"
}

/// Convenience for decoding just an id from an arbitrary decoder.
func decodeBackendIdentifier(from decoder: Decoder) throws -> String {
    let c = try decoder.container(keyedBy: IdentifierCodingKey.self)
    return try c.decodeIdentifier()
}
