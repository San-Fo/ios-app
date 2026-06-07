import Foundation

/// API endpoints for the user profile.
///
/// The backend splits profile mutation across several endpoints:
/// - `PATCH /me` for scalar fields (name, bio, language, districts, intents...)
/// - `PUT /me/categories` to replace followed categories
/// - `PUT /me/financial-intents` to replace financial intents
/// - `PUT /me/location` to set the location used for recommendations
/// - `PUT/DELETE /me/saved/{id}` to save/unsave a business (204, no body)
enum ProfileEndpoints {
    /// Current user. (Also used to restore a session.)
    static func me() -> Endpoint<UserProfileDTO> {
        Endpoint(path: "me", method: .get)
    }

    /// Partial scalar update. Returns the updated user.
    static func patch(_ body: UserPatchDTO) throws -> Endpoint<UserProfileDTO> {
        try .json(path: "me", method: .patch, body: body)
    }

    /// Replace followed categories. Returns the updated user.
    static func setCategories(_ categories: [String]) throws -> Endpoint<UserProfileDTO> {
        try .json(path: "me/categories", method: .put, body: categories)
    }

    /// Replace financial intents. Returns the updated user.
    static func setFinancialIntents(_ intents: [String]) throws -> Endpoint<UserProfileDTO> {
        try .json(path: "me/financial-intents", method: .put, body: intents)
    }

    /// Set the user's location. Returns the updated user.
    static func setLocation(latitude: Double, longitude: Double) throws -> Endpoint<UserProfileDTO> {
        try .json(path: "me/location", method: .put, body: LocationBody(latitude: latitude, longitude: longitude))
    }

    /// Save a business (204) — idempotent, cannot be your own listing.
    static func save(businessId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "me/saved/\(businessId)", method: .put)
    }

    /// Unsave a business (204) — idempotent.
    static func unsave(businessId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "me/saved/\(businessId)", method: .delete)
    }

    /// The user's saved businesses (hydrated + redacted).
    static func saved() -> Endpoint<[BusinessDTO]> {
        Endpoint(path: "me/saved", method: .get)
    }

    private struct LocationBody: Encodable {
        let latitude: Double
        let longitude: Double
    }
}

/// Body for `PATCH /me`. Only non-nil fields are sent (the encoder still emits
/// keys with explicit `null`s, so include only what should change by
/// constructing the DTO with just those values).
struct UserPatchDTO: Encodable {
    var name: String?
    var biography: String?
    var address: String?
    var profileImageUrl: String?
    var birthDate: BSONDate?
    var language: String?
    var districts: [String]?
    var financialIntents: [String]?
    var hasCompletedOnboarding: Bool?

    /// Drops nil keys entirely so a partial update never overwrites unrelated
    /// fields with null.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(biography, forKey: .biography)
        try c.encodeIfPresent(address, forKey: .address)
        try c.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try c.encodeIfPresent(birthDate, forKey: .birthDate)
        try c.encodeIfPresent(language, forKey: .language)
        try c.encodeIfPresent(districts, forKey: .districts)
        try c.encodeIfPresent(financialIntents, forKey: .financialIntents)
        try c.encodeIfPresent(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
    }

    private enum CodingKeys: String, CodingKey {
        case name, biography, address, profileImageUrl, birthDate
        case language, districts, financialIntents, hasCompletedOnboarding
    }
}
