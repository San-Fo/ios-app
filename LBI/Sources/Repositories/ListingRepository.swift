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
    /// Creates the listing (status `pending`) and returns the new business id.
    /// The caller then prompts KYB for that id to verify and publish it.
    func submitListing(_ draft: ListingDraft) async throws -> String
    func recordInvestment(businessId: String, businessName: String, kind: FundingKind, amount: Decimal) async throws -> InvestmentRecord
}

// MARK: - Live (placeholder)

final class LiveListingRepository: ListingRepository, @unchecked Sendable {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func submitListing(_ draft: ListingDraft) async throws -> String {
        // Step 1: create the business listing (created `pending`).
        let create = ListingEndpoints.CreateBusinessBody(
            name: draft.businessName,
            description: draft.founderStory.isEmpty ? draft.whyItMatters : draft.founderStory,
            foundingYear: Int(draft.foundedYear),
            categories: [draft.category.serverValue],
            district: draft.district.rawValue,
            address: nil,
            latitude: nil,
            longitude: nil,
            financialIntent: Self.financialIntent(for: draft)
        )
        let business = try await client.send(try ListingEndpoints.createBusiness(create))

        // Step 2: if the owner is selling the whole business, submit the sale.
        if draft.desiredOutcomes.contains(.sellWhole), let askingPrice = Decimal(string: draft.saleAskingPrice) {
            let financials = SaleEndpoints.SubmitSaleBody.FinancialsBody(
                annualRevenue: (Decimal(string: draft.monthlyRevenue) ?? 0) * 12,
                annualProfit: 0,
                monthlyRent: nil,
                leaseYearsRemaining: nil,
                staffCount: Int(draft.employees) ?? 0,
                inventoryValue: nil,
                notes: nil
            )
            let saleBody = SaleEndpoints.SubmitSaleBody(
                askingPrice: askingPrice,
                financials: financials,
                includes: [],
                ownerWillingToStay: false,
                handoverMonths: nil
            )
            _ = try await client.send(try SaleEndpoints.submitSale(businessId: business.id, body: saleBody))
        }
        // TODO(API): photo upload once the backend defines it.
        return business.id
    }

    func recordInvestment(businessId: String, businessName: String, kind: FundingKind, amount: Decimal) async throws -> InvestmentRecord {
        let body: ListingEndpoints.ActionBody
        switch kind {
        case .fullAcquisition:
            body = .purchase
        case .revenueShare:
            body = .revenueShareLoan(amount: amount)
        case .partialOwnership, .takeoverGroup:
            // Map remaining kinds to a donation-style contribution.
            body = .donation(amount: amount, tier: nil)
        }
        let dto = try await client.send(try ListingEndpoints.action(businessId: businessId, body: body))
        return dto.toDomain(businessName: businessName)
    }

    /// Derives the backend business financial intent from the draft's outcomes.
    private static func financialIntent(for draft: ListingDraft) -> ListingEndpoints.BusinessFinancialIntentBody {
        if draft.desiredOutcomes.contains(.sellWhole) || draft.desiredOutcomes.contains(.sellPartial) {
            return .sale(targetAmount: Decimal(string: draft.saleAskingPrice) ?? 0)
        }
        if draft.desiredOutcomes.contains(.revenueShare) {
            return .revenueShareLoan(
                targetAmount: (Decimal(string: draft.monthlyRevenue) ?? 0) * 12,
                totalInterestPercentage: 0,
                totalRevenueCutPercentage: 0
            )
        }
        return .sale(targetAmount: Decimal(string: draft.saleAskingPrice) ?? 0)
    }
}

// MARK: - Mock

/// ⚠️ MOCK — listing submission and actions are no-ops that fake success.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockListingRepository: ListingRepository, @unchecked Sendable {
    func submitListing(_ draft: ListingDraft) async throws -> String {
        MockMarker.hit(.mock, "MockListingRepository.submitListing", "fakes success; nothing persisted")
        try await Task.sleep(nanoseconds: 400_000_000)
        // Return a synthetic business id so the KYB step can proceed in demos.
        return "mock-business-\(UUID().uuidString.prefix(8))"
    }

    func recordInvestment(businessId: String, businessName: String, kind: FundingKind, amount: Decimal) async throws -> InvestmentRecord {
        MockMarker.hit(.mock, "MockListingRepository.recordInvestment", "fakes an action; no payment")
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
