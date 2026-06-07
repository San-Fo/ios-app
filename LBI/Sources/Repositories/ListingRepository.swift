import Foundation

/// A business owner's draft listing submission.
struct ListingDraft: Equatable {
    var businessName: String = ""
    var category: BusinessCategory = .restaurant
    var district: District = .central
    var foundedYear: String = ""
    var founderStory: String = ""
    var whyItMatters: String = ""
    var monthlyRevenue: String = ""
    var employees: String = ""
    var desiredOutcomes: Set<ListingOutcome> = []
    var saleAskingPrice: String = ""
    var retailFallbackPrice: String = ""
    var allowRetailOutrightPurchase: Bool = true
    var allowRetailGroupTakeover: Bool = true
    var contactEmail: String = ""
    var photoCount: Int = 0
    /// Owner-set supporter reward tiers (own N support cards → unlock a perk).
    var shareRewards: [ShareReward] = []
}

/// Handles owner listing submissions and supporter investment actions.
protocol ListingRepository: Sendable {
    func submitListing(_ draft: ListingDraft) async throws
    func recordInvestment(businessId: String, businessName: String, kind: FundingKind, amount: Decimal) async throws -> InvestmentRecord
}

// MARK: - Live (placeholder)

final class LiveListingRepository: ListingRepository, @unchecked Sendable {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func submitListing(_ draft: ListingDraft) async throws {
        // TODO(API): include multipart photo upload once the backend defines it.
        try await client.send(try ListingEndpoints.submit(draft))
    }

    func recordInvestment(businessId: String, businessName: String, kind: FundingKind, amount: Decimal) async throws -> InvestmentRecord {
        let dto = try await client.send(try ListingEndpoints.invest(businessId: businessId, kind: kind, amount: amount))
        return dto.toDomain(businessName: businessName)
    }
}

// MARK: - Mock

final class MockListingRepository: ListingRepository, @unchecked Sendable {
    func submitListing(_ draft: ListingDraft) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func recordInvestment(businessId: String, businessName: String, kind: FundingKind, amount: Decimal) async throws -> InvestmentRecord {
        try await Task.sleep(nanoseconds: 400_000_000)
        return InvestmentRecord(
            id: UUID().uuidString,
            businessId: businessId,
            businessName: businessName,
            kind: kind,
            amount: amount,
            date: Date()
        )
    }
}
