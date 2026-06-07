import Foundation

/// Wire model for the backend `Business`. The backend returns one shape for
/// list, search, detail and saved; the `sale` is folded in and confidential
/// fields are redacted server-side per viewer.
///
/// The backend has no authored editorial content (story headline, founder
/// story, memories, reward tiers). Per the backend team, the client derives
/// these: headline/tagline ← `description`, heritage badge ← `foundingYear`,
/// founder name/story ← embedded `owner`. `galleryImageUrls` is a real field.
struct BusinessDTO: Decodable {
    let id: String
    let ownerUserId: String
    let name: String
    let description: String
    let foundingYear: Int?
    let categories: [String]?
    let district: String?
    let location: BusinessLocationDTO?
    let financialIntent: BusinessFinancialIntentDTO?
    let verificationStatus: String?
    let sale: BusinessSaleDTO?
    let galleryImageUrls: [String]?
    let owner: OwnerSummaryDTO?
    let listingStatistics: ListingStatisticsDTO?
    let createdAt: BSONDate?

    /// First category mapped to the app's richer category set (fallback shop).
    private var primaryCategory: BusinessCategory {
        categories?.first.flatMap(BusinessCategory.fromServer) ?? .traditionalShop
    }

    private var mappedDistrict: District {
        district.flatMap(District.init(rawValue:)) ?? .central
    }

    /// The funding/ownership routes derived from the business financial intent
    /// and sale stage (so the UI's funding-kind chips still work).
    private var fundingKinds: Set<FundingKind> {
        var kinds: Set<FundingKind> = []
        switch financialIntent?.kind {
        case .sale: kinds.insert(.fullAcquisition)
        case .revenueShareLoan: kinds.insert(.revenueShare)
        case .donation, .none: break
        }
        if let fallback = sale?.retailFallback, fallback.allowGroupTakeover == true {
            kinds.insert(.takeoverGroup)
        }
        return kinds
    }

    /// Maps the backend sale `verificationStatus` + stage onto the app's
    /// listing status used for badges/progress.
    private var mappedStatus: BusinessStatus {
        if let stage = sale?.stage {
            switch stage {
            case "openToRetail": return .seekingBuyer
            case "accepted": return .underOffer
            case "sold": return .preserved
            case "aiReview", "commercialBidding", "ownerDecision": return .seekingBuyer
            default: break
            }
        }
        switch financialIntent?.kind {
        case .revenueShareLoan: return .raising
        default: return .raising
        }
    }

    // MARK: Domain mapping

    /// The list/card summary model.
    func toSummary() -> Business {
        let target = financialIntent?.targetAmount ?? sale?.askingPrice ?? 0
        return Business(
            id: id,
            name: name,
            category: primaryCategory,
            district: mappedDistrict,
            storyHeadline: description,
            heroImageURL: galleryImageUrls?.first.flatMap(URL.init(string:)),
            status: mappedStatus,
            fundingGoal: target,
            fundingRaised: 0,
            fundingOptions: fundingKinds,
            yearEstablished: foundingYear,
            deadline: nil,
            savedCount: listingStatistics?.likeCount ?? 0,
            viewCount: listingStatistics?.viewCount ?? 0
        )
    }

    /// The full detail model. Editorial content is derived (see type doc).
    func toDetail() -> BusinessDetail {
        // DERIVED: the backend has no authored story/memories/rewards; these are
        // synthesized from `description`/`owner`. Expected on the real path too.
        MockMarker.hit(.derived, "BusinessDTO.toDetail.editorial", "founderStory/whyItMatters/memories/rewards derived")
        return BusinessDetail(
            id: id,
            summary: toSummary(),
            tagline: description,
            founderName: owner?.name ?? "",
            founderStory: owner?.biography ?? description,
            whyItMatters: description,
            communityMemories: [],
            snapshot: BusinessSnapshot(
                foundedYear: foundingYear ?? 0,
                employees: sale?.financials?.staffCount ?? 0,
                monthlyRevenue: nil,
                address: location?.address ?? "",
                highlights: []
            ),
            useOfFunds: "",
            revenueShareTerms: financialIntent?.revenueShareTerms,
            partialOwnership: nil,
            fullAcquisition: nil,
            hasTakeoverGroup: sale?.retailFallback?.allowGroupTakeover ?? false,
            galleryImageURLs: (galleryImageUrls ?? []).compactMap(URL.init(string:)),
            shareRewards: [],
            professionalSale: sale?.toDomain(businessId: id, businessName: name)
        )
    }
}

/// Embedded, redacted owner summary computed by the backend at read time.
struct OwnerSummaryDTO: Decodable {
    let id: String
    let name: String?
    let biography: String?
    let profileImageUrl: String?
}

/// `listingStatistics` on a business.
struct ListingStatisticsDTO: Decodable {
    let viewCount: Int?
    let likeCount: Int?
}

/// `location` on a business: human address + GeoJSON point.
struct BusinessLocationDTO: Decodable {
    let address: String?
    let geo: GeoPointDTO?
}

/// Externally-tagged business financial intent:
/// `{ "sale": { targetAmount } }`,
/// `{ "donation": { tiers[] } }`,
/// `{ "revenueShareLoan": { targetAmount, totalInterestPercentage, totalRevenueCutPercentage } }`.
struct BusinessFinancialIntentDTO: Decodable {
    enum Kind { case sale, donation, revenueShareLoan }

    let kind: Kind
    let targetAmount: Decimal?
    let donationTiers: [DonationTierDTO]?
    let totalInterestPercentage: Double?
    let totalRevenueCutPercentage: Double?

    private enum CodingKeys: String, CodingKey {
        case sale, donation, revenueShareLoan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let sale = try? c.decode(SalePayload.self, forKey: .sale) {
            kind = .sale
            targetAmount = sale.targetAmount
            donationTiers = nil
            totalInterestPercentage = nil
            totalRevenueCutPercentage = nil
        } else if let donation = try? c.decode(DonationPayload.self, forKey: .donation) {
            kind = .donation
            targetAmount = nil
            donationTiers = donation.tiers
            totalInterestPercentage = nil
            totalRevenueCutPercentage = nil
        } else if let loan = try? c.decode(LoanPayload.self, forKey: .revenueShareLoan) {
            kind = .revenueShareLoan
            targetAmount = loan.targetAmount
            donationTiers = nil
            totalInterestPercentage = loan.totalInterestPercentage
            totalRevenueCutPercentage = loan.totalRevenueCutPercentage
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown financialIntent variant")
            )
        }
    }

    /// A revenue-share-loan intent projected onto the app's `RevenueShareTerms`.
    var revenueShareTerms: RevenueShareTerms? {
        guard kind == .revenueShareLoan, let target = targetAmount else { return nil }
        return RevenueShareTerms(
            fundingTarget: target,
            revenueSharePercent: totalRevenueCutPercentage ?? 0,
            targetMultiple: 1 + ((totalInterestPercentage ?? 0) / 100),
            estimatedMonths: 0,
            useOfFunds: "",
            useOfFundsBreakdown: [],
            minimumInvestment: nil,
            maximumInvestment: nil
        )
    }

    private struct SalePayload: Decodable { let targetAmount: Decimal? }
    private struct DonationPayload: Decodable { let tiers: [DonationTierDTO]? }
    private struct LoanPayload: Decodable {
        let targetAmount: Decimal?
        let totalInterestPercentage: Double?
        let totalRevenueCutPercentage: Double?
    }
}

struct DonationTierDTO: Decodable {
    let name: String
    let minAmount: Decimal
}
