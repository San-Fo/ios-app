import Foundation

/// Wire model for the backend `User`. Mirrors the server schema exactly
/// (camelCase fields, GeoJSON location, BSON dates), then maps into the app's
/// `UserProfile` domain model.
///
/// The backend models verification/investor state as two enums
/// (`verificationState`, `investorStatus`); the app exposes them as a
/// per-programme verification dictionary plus a derived role.
struct UserProfileDTO: Decodable {
    let id: String
    let appleUserId: String?
    let verificationState: String?      // unverified | verified
    let investorStatus: String?         // unverified | pending | retailVerified | institutionalVerified | rejected
    let name: String?
    let email: String?
    let biography: String?
    let birthDate: BSONDate?
    let address: String?
    let profileImageUrl: String?
    let location: GeoPointDTO?
    let language: String?               // en | zhHant
    let followedCategories: [String]?
    let districts: [String]?
    let financialIntents: [String]?     // purchase | donation | revenueShareLoan
    let savedBusinessIds: [String]?
    let hasCompletedOnboarding: Bool?
    let createdAt: BSONDate?

    /// Passthrough for the auth layer (no dedicated display name on the server).
    var displayName: String? { name }

    func toDomain(fallback user: AuthenticatedUser) -> UserProfile {
        UserProfile(
            id: id,
            displayName: name ?? user.displayName ?? "Friend",
            email: email ?? user.email,
            language: mappedLanguage,
            interests: Set((followedCategories ?? []).compactMap(BusinessCategory.fromServer)),
            districts: Set((districts ?? []).compactMap(District.init(rawValue:))),
            intents: Set((financialIntents ?? []).compactMap(UserIntent.fromServerIntent)),
            savedBusinessIds: Set(savedBusinessIds ?? []),
            joinedGroupIds: [],
            investments: [],
            hasCompletedOnboarding: hasCompletedOnboarding ?? false,
            role: mappedRole,
            verifications: mappedVerifications
        )
    }

    // MARK: Mapping helpers

    /// Backend uses `en` / `zhHant`; the app's `AppLanguage` uses `en` / `zh-Hant`.
    private var mappedLanguage: AppLanguage {
        switch language {
        case "en": return .english
        case "zhHant": return .traditionalChinese
        default: return .english
        }
    }

    /// Derives the app's `AccountRole` from the backend investor status.
    /// (Owner is determined per-business on the backend, not on the user, so a
    /// plain user maps to `.retail`/`.professional`.)
    private var mappedRole: AccountRole {
        switch investorStatus {
        case "institutionalVerified", "retailVerified":
            return .professional
        default:
            return .retail
        }
    }

    /// Projects the backend verification/investor enums onto the app's
    /// per-programme verification map (KYC + pro-investor; KYB lives on the
    /// business, not the user).
    private var mappedVerifications: [VerificationKind: VerificationStatus] {
        var map: [VerificationKind: VerificationStatus] = [:]

        // Identity (KYC) from verificationState.
        switch verificationState {
        case "verified": map[.kyc] = .approved
        default: break
        }

        // Pro-investor accreditation from investorStatus.
        switch investorStatus {
        case "institutionalVerified", "retailVerified": map[.proInvestor] = .approved
        case "pending": map[.proInvestor] = .pending
        case "rejected": map[.proInvestor] = .rejected
        default: break
        }
        return map
    }
}

/// GeoJSON Point wire model: coordinates are `[longitude, latitude]`.
struct GeoPointDTO: Codable, Equatable {
    let type: String
    let coordinates: [Double]

    var longitude: Double? { coordinates.first }
    var latitude: Double? { coordinates.count > 1 ? coordinates[1] : nil }
}

// MARK: - Enum bridging (app <-> backend)

extension BusinessCategory {
    /// Best-effort map from the backend's category enum to the app's richer
    /// category set. Unknown values fall back to `.service`.
    static func fromServer(_ raw: String) -> BusinessCategory? {
        switch raw {
        case "restaurant": return .restaurant
        case "cafe": return .cafe
        case "foodAndBeverage": return .restaurant
        case "retail": return .traditionalShop
        case "services": return .service
        case "artsAndCrafts": return .culture
        case "technology": return .service
        case "wellness": return .wellness
        case "education": return .culture
        case "other": return .service
        default: return BusinessCategory(rawValue: raw)
        }
    }

    /// Map an app category to the backend's category enum value.
    var serverValue: String {
        switch self {
        case .restaurant, .bakery: return "restaurant"
        case .cafe, .teaHouse: return "cafe"
        case .bookstore, .traditionalShop, .familyBusiness: return "retail"
        case .repairShop, .tailoring, .service: return "services"
        case .herbalist, .wellness, .gym, .sports: return "wellness"
        case .culture: return "artsAndCrafts"
        }
    }
}

extension UserIntent {
    /// Map the backend's user financial intent to the app's `UserIntent`.
    static func fromServerIntent(_ raw: String) -> UserIntent? {
        switch raw {
        case "purchase": return .buyBusiness
        case "donation": return .support
        case "revenueShareLoan": return .revenueShare
        default: return nil
        }
    }

    /// Map the app's `UserIntent` to the backend's financial intent value.
    /// `.joinTakeover` has no backend equivalent and is omitted by the caller.
    var serverIntent: String? {
        switch self {
        case .buyBusiness: return "purchase"
        case .support: return "donation"
        case .revenueShare: return "revenueShareLoan"
        case .joinTakeover: return nil
        }
    }
}
