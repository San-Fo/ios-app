import Foundation

/// A business owner's draft listing submission.
struct ListingDraft: Equatable {
    var businessName: String = ""
    var category: BusinessCategory = .restaurant
    var district: District = .central
    var address: String = ""
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
    /// Photos the owner selected for the listing gallery. Stored as JPEG data;
    /// uploaded/hosted by the backend (see `submitListing`).
    var photos: [Data] = []
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
    private let imageUploader: ImageUploader
    init(client: APIClient, imageUploader: ImageUploader) {
        self.client = client
        self.imageUploader = imageUploader
    }

    func submitListing(_ draft: ListingDraft) async throws -> String {
        // Step 1: create the business listing (created `pending`).
        // The backend requires foundingYear, address, latitude and longitude,
        // so supply safe defaults when the owner leaves optional fields blank.
        let currentYear = Calendar.current.component(.year, from: Date())
        let coordinate = draft.district.centroid
        // Photos are hosted via the ImageUploader seam (data URLs for now).
        let galleryUrls = try await imageUploader.upload(draft.photos)
        let create = ListingEndpoints.CreateBusinessBody(
            name: draft.businessName,
            description: draft.founderStory.isEmpty ? draft.whyItMatters : draft.founderStory,
            foundingYear: Int(draft.foundedYear) ?? currentYear,
            categories: [draft.category.serverValue],
            district: draft.district.rawValue,
            address: draft.address.isEmpty ? draft.district.displayName : draft.address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            galleryImageUrls: galleryUrls,
            financialIntent: Self.financialIntent(for: draft)
        )
        let business = try await client.send(try ListingEndpoints.createBusiness(create))

        // Step 2: if the owner is transferring ownership (sell whole/partial or
        // find a successor) and gave a guide price, submit the professional sale
        // so the bidding/fallback flow materialises for the listing.
        if !draft.desiredOutcomes.isDisjoint(with: ListingOutcome.ownershipOutcomes),
           let askingPrice = Decimal(string: draft.saleAskingPrice) {
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
            // The backend has no equity/takeover action, so a community
            // contribution is recorded as a donation. `ActionDTO.toDomain`
            // maps the donation response back to `.partialOwnership` so the
            // displayed kind round-trips consistently.
            body = .donation(amount: amount, tier: nil)
        }
        let dto = try await client.send(try ListingEndpoints.action(businessId: businessId, body: body))
        return dto.toDomain(businessName: businessName)
    }

    /// Derives the backend business financial intent from the draft's outcomes.
    ///
    /// The backend supports three intents (`sale`, `donation`, `revenueShareLoan`)
    /// and a business carries one. With multi-select outcomes we apply a clear
    /// precedence so every selectable outcome maps to a faithful intent:
    /// ownership transfer (sell whole/partial, find successor) → sale;
    /// revenue-share financing → loan; raise capital → community donation.
    private static func financialIntent(for draft: ListingDraft) -> ListingEndpoints.BusinessFinancialIntentBody {
        if !draft.desiredOutcomes.isDisjoint(with: ListingOutcome.ownershipOutcomes) {
            return .sale(targetAmount: Decimal(string: draft.saleAskingPrice) ?? 0)
        }
        if draft.desiredOutcomes.contains(.revenueShare) {
            return .revenueShareLoan(
                targetAmount: (Decimal(string: draft.monthlyRevenue) ?? 0) * 12,
                totalInterestPercentage: 0,
                totalRevenueCutPercentage: 0
            )
        }
        if draft.desiredOutcomes.contains(.raiseCapital) {
            // A community capital raise is recorded as a donation campaign.
            return .donation(tiers: Self.donationTiers(for: draft))
        }
        // No outcome selected: default to a sale with no guide price.
        return .sale(targetAmount: Decimal(string: draft.saleAskingPrice) ?? 0)
    }

    /// Maps the owner's supporter reward tiers to backend donation tiers.
    private static func donationTiers(for draft: ListingDraft) -> [ListingEndpoints.DonationTierBody] {
        draft.shareRewards.map {
            ListingEndpoints.DonationTierBody(name: $0.title, minAmount: 0)
        }
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
