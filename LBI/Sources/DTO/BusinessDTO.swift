import Foundation

/// Wire model for a business summary.
///
/// TODO(API): replace these fields with the real backend schema. Keep the
/// `toDomain()` mapping as the single translation point so the UI never depends
/// on the wire format.
struct BusinessDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let district: String
    let storyHeadline: String
    let heroImageURL: String?
    let status: String
    let fundingGoal: Decimal
    let fundingRaised: Decimal
    let fundingOptions: [String]
    let yearEstablished: Int?
    let deadline: Date?
    let savedCount: Int?
    let viewCount: Int?

    func toDomain() -> Business {
        Business(
            id: id,
            name: name,
            category: BusinessCategory(rawValue: category) ?? .traditionalShop,
            district: District(rawValue: district) ?? .central,
            storyHeadline: storyHeadline,
            heroImageURL: heroImageURL.flatMap(URL.init(string:)),
            status: BusinessStatus(rawValue: status) ?? .raising,
            fundingGoal: fundingGoal,
            fundingRaised: fundingRaised,
            fundingOptions: Set(fundingOptions.compactMap(FundingKind.init(rawValue:))),
            yearEstablished: yearEstablished,
            deadline: deadline,
            savedCount: savedCount ?? 0,
            viewCount: viewCount ?? 0
        )
    }
}

/// Wire model for a community memory.
struct CommunityMemoryDTO: Decodable {
    let id: String
    let author: String
    let text: String
    let yearsAgo: Int?
    let authorInitials: String?
    let relationship: String?

    func toDomain() -> CommunityMemory {
        CommunityMemory(id: id, author: author, text: text, yearsAgo: yearsAgo, authorInitials: authorInitials, relationship: relationship)
    }
}

/// Wire model for a business snapshot.
struct BusinessSnapshotDTO: Decodable {
    let foundedYear: Int
    let employees: Int
    let monthlyRevenue: Decimal?
    let address: String
    let highlights: [String]

    func toDomain() -> BusinessSnapshot {
        BusinessSnapshot(foundedYear: foundedYear, employees: employees, monthlyRevenue: monthlyRevenue, address: address, highlights: highlights)
    }
}

/// Wire model for revenue-share terms.
struct RevenueShareTermsDTO: Decodable {
    let fundingTarget: Decimal
    let revenueSharePercent: Double
    let targetMultiple: Double
    let estimatedMonths: Int
    let useOfFunds: String
    let useOfFundsBreakdown: [UseOfFundsItemDTO]?
    let minimumInvestment: Decimal?
    let maximumInvestment: Decimal?

    func toDomain() -> RevenueShareTerms {
        RevenueShareTerms(
            fundingTarget: fundingTarget,
            revenueSharePercent: revenueSharePercent,
            targetMultiple: targetMultiple,
            estimatedMonths: estimatedMonths,
            useOfFunds: useOfFunds,
            useOfFundsBreakdown: (useOfFundsBreakdown ?? []).map { $0.toDomain() },
            minimumInvestment: minimumInvestment,
            maximumInvestment: maximumInvestment
        )
    }
}

struct UseOfFundsItemDTO: Decodable {
    let label: String
    let percentage: Double
    func toDomain() -> UseOfFundsItem { UseOfFundsItem(label: label, percentage: percentage) }
}

/// Wire model for partial ownership.
struct PartialOwnershipDTO: Decodable {
    let equityOfferedPercent: Double
    let valuation: Decimal
    let minimumInvestment: Decimal
    let existingInvestors: Int?

    func toDomain() -> PartialOwnershipOption {
        PartialOwnershipOption(equityOfferedPercent: equityOfferedPercent, valuation: valuation, minimumInvestment: minimumInvestment, existingInvestors: existingInvestors ?? 0)
    }
}

/// Wire model for full acquisition.
struct FullAcquisitionDTO: Decodable {
    let askingPrice: Decimal
    let openToGroupOffer: Bool
    let includes: [String]
    let includesProperty: Bool?
    let leaseYearsRemaining: Int?
    let monthlyRevenue: Decimal?
    let staffCount: Int?
    let ownerWillingToStay: Bool?
    let handoverMonths: Int?

    func toDomain() -> FullAcquisitionOption {
        FullAcquisitionOption(
            askingPrice: askingPrice,
            openToGroupOffer: openToGroupOffer,
            includes: includes,
            includesProperty: includesProperty ?? false,
            leaseYearsRemaining: leaseYearsRemaining,
            monthlyRevenue: monthlyRevenue,
            staffCount: staffCount,
            ownerWillingToStay: ownerWillingToStay ?? false,
            handoverMonths: handoverMonths
        )
    }
}

/// Wire model for full business detail.
/// TODO(API): align with the backend; this maps every section to the domain.
struct BusinessDetailDTO: Decodable {
    let id: String
    let summary: BusinessDTO
    let tagline: String?
    let founderName: String
    let founderStory: String
    let whyItMatters: String
    let communityMemories: [CommunityMemoryDTO]?
    let snapshot: BusinessSnapshotDTO?
    let useOfFunds: String
    let revenueShareTerms: RevenueShareTermsDTO?
    let partialOwnership: PartialOwnershipDTO?
    let fullAcquisition: FullAcquisitionDTO?
    let hasTakeoverGroup: Bool
    let galleryImageURLs: [String]?
    let shareRewards: [ShareRewardDTO]?
    let professionalSale: ProfessionalSaleDTO?

    func toDomain() -> BusinessDetail {
        BusinessDetail(
            id: id,
            summary: summary.toDomain(),
            tagline: tagline ?? summary.storyHeadline,
            founderName: founderName,
            founderStory: founderStory,
            whyItMatters: whyItMatters,
            communityMemories: (communityMemories ?? []).map { $0.toDomain() },
            snapshot: snapshot?.toDomain() ?? BusinessSnapshot(foundedYear: summary.yearEstablished ?? 0, employees: 0, monthlyRevenue: nil, address: "", highlights: []),
            useOfFunds: useOfFunds,
            revenueShareTerms: revenueShareTerms?.toDomain(),
            partialOwnership: partialOwnership?.toDomain(),
            fullAcquisition: fullAcquisition?.toDomain(),
            hasTakeoverGroup: hasTakeoverGroup,
            galleryImageURLs: (galleryImageURLs ?? []).compactMap(URL.init(string:)),
            shareRewards: (shareRewards ?? []).map { $0.toDomain() },
            professionalSale: professionalSale?.toDomain()
        )
    }
}

/// Wire model for an owner-set supporter reward tier.
/// TODO(API): align with the backend schema.
struct ShareRewardDTO: Decodable {
    let id: String
    let cardsRequired: Int
    let title: String
    let detail: String?

    func toDomain() -> ShareReward {
        ShareReward(id: id, cardsRequired: cardsRequired, title: title, detail: detail)
    }
}
