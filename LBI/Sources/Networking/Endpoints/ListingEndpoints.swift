import Foundation

/// API endpoints for creating listings and recording financing actions.
enum ListingEndpoints {
    /// Create a business listing (created `pending`, verified separately).
    static func createBusiness(_ body: CreateBusinessBody) throws -> Endpoint<BusinessDTO> {
        try .json(path: "businesses", method: .post, body: body)
    }

    /// Record a financing action on a business. The body is the externally
    /// tagged action kind (purchase / donation / revenueShareLoan).
    static func action(businessId: String, body: ActionBody) throws -> Endpoint<ActionDTO> {
        try .json(path: "businesses/\(businessId)/actions", method: .post, body: body)
    }

    /// Body for `POST /businesses`.
    struct CreateBusinessBody: Encodable {
        let name: String
        let description: String
        let foundingYear: Int?
        let categories: [String]
        let district: String
        let address: String?
        let latitude: Double?
        let longitude: Double?
        let financialIntent: BusinessFinancialIntentBody
    }

    /// Externally-tagged business financial intent for creation.
    enum BusinessFinancialIntentBody: Encodable {
        case sale(targetAmount: Decimal)
        case donation(tiers: [DonationTierBody])
        case revenueShareLoan(targetAmount: Decimal, totalInterestPercentage: Double, totalRevenueCutPercentage: Double)

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .sale(targetAmount):
                try c.encode(SalePayload(targetAmount: targetAmount), forKey: .sale)
            case let .donation(tiers):
                try c.encode(DonationPayload(tiers: tiers), forKey: .donation)
            case let .revenueShareLoan(target, interest, cut):
                try c.encode(
                    LoanPayload(targetAmount: target, totalInterestPercentage: interest, totalRevenueCutPercentage: cut),
                    forKey: .revenueShareLoan
                )
            }
        }

        private enum CodingKeys: String, CodingKey { case sale, donation, revenueShareLoan }
        private struct SalePayload: Encodable { let targetAmount: Decimal }
        private struct DonationPayload: Encodable { let tiers: [DonationTierBody] }
        private struct LoanPayload: Encodable {
            let targetAmount: Decimal
            let totalInterestPercentage: Double
            let totalRevenueCutPercentage: Double
        }
    }

    struct DonationTierBody: Encodable {
        let name: String
        let minAmount: Decimal
    }

    /// Externally-tagged action kind for `POST /businesses/{id}/actions`.
    /// The action **request** body is internally tagged with a `kind` field
    /// (verified against the live server): `{"kind":"purchase"}`,
    /// `{"kind":"donation","amount":..,"tier":..}`,
    /// `{"kind":"revenueShareLoan","amount":..}`. (Note: the action *response*
    /// serializes `kind` differently — see `ActionDTO`.)
    enum ActionBody: Encodable {
        case purchase
        case donation(amount: Decimal, tier: String?)
        case revenueShareLoan(amount: Decimal)

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .purchase:
                try c.encode("purchase", forKey: .kind)
            case let .donation(amount, tier):
                try c.encode("donation", forKey: .kind)
                try c.encode(amount, forKey: .amount)
                try c.encodeIfPresent(tier, forKey: .tier)
            case let .revenueShareLoan(amount):
                try c.encode("revenueShareLoan", forKey: .kind)
                try c.encode(amount, forKey: .amount)
            }
        }

        private enum CodingKeys: String, CodingKey { case kind, amount, tier }
    }
}
