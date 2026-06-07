import Foundation

/// Core domain model for a business listing (summary form used in lists).
struct Business: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var category: BusinessCategory
    var district: District
    var storyHeadline: String
    var heroImageURL: URL?
    var status: BusinessStatus
    var fundingGoal: Decimal
    var fundingRaised: Decimal
    var fundingOptions: Set<FundingKind>
    /// Year the business was established (for the heritage-year badge).
    var yearEstablished: Int?
    /// Optional funding/at-risk deadline, used for urgent countdowns.
    var deadline: Date?
    /// Social proof.
    var savedCount: Int
    var viewCount: Int

    init(
        id: String,
        name: String,
        category: BusinessCategory,
        district: District,
        storyHeadline: String,
        heroImageURL: URL?,
        status: BusinessStatus,
        fundingGoal: Decimal,
        fundingRaised: Decimal,
        fundingOptions: Set<FundingKind>,
        yearEstablished: Int? = nil,
        deadline: Date? = nil,
        savedCount: Int = 0,
        viewCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.district = district
        self.storyHeadline = storyHeadline
        self.heroImageURL = heroImageURL
        self.status = status
        self.fundingGoal = fundingGoal
        self.fundingRaised = fundingRaised
        self.fundingOptions = fundingOptions
        self.yearEstablished = yearEstablished
        self.deadline = deadline
        self.savedCount = savedCount
        self.viewCount = viewCount
    }

    /// Raised / goal, clamped to 0...1 for progress bars.
    var fundingProgress: Double {
        guard fundingGoal > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: fundingRaised).doubleValue
            / NSDecimalNumber(decimal: fundingGoal).doubleValue)
    }

    /// Whole days remaining until the deadline (nil if none / past).
    var daysRemaining: Int? {
        guard let deadline else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return days >= 0 ? days : nil
    }
}

/// Which financing/ownership routes a business offers.
enum FundingKind: String, CaseIterable, Codable, Identifiable {
    case revenueShare
    case partialOwnership
    case fullAcquisition
    case takeoverGroup

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .revenueShare: return "Revenue Share"
        case .partialOwnership: return "Partial Ownership"
        case .fullAcquisition: return "Full Acquisition"
        case .takeoverGroup: return "Takeover Group"
        }
    }

    var systemImage: String {
        switch self {
        case .revenueShare: return "percent"
        case .partialOwnership: return "chart.pie.fill"
        case .fullAcquisition: return "key.fill"
        case .takeoverGroup: return "person.3.fill"
        }
    }
}

/// Full business detail, including story, snapshot and options.
struct BusinessDetail: Identifiable, Equatable {
    let id: String
    var summary: Business
    /// Short, evocative tagline shown under the name.
    var tagline: String
    var founderName: String
    var founderStory: String
    var whyItMatters: String
    var communityMemories: [CommunityMemory]
    var snapshot: BusinessSnapshot
    var useOfFunds: String
    var revenueShareTerms: RevenueShareTerms?
    var partialOwnership: PartialOwnershipOption?
    var fullAcquisition: FullAcquisitionOption?
    var hasTakeoverGroup: Bool
    var galleryImageURLs: [URL]
    /// Owner-set supporter reward tiers (own N cards → unlock a perk).
    var shareRewards: [ShareReward]
    /// A confidential professional-first sale, when the owner offers the
    /// whole business for sale to vetted professional buyers.
    var professionalSale: ProfessionalSale?

    init(
        id: String,
        summary: Business,
        tagline: String = "",
        founderName: String,
        founderStory: String,
        whyItMatters: String,
        communityMemories: [CommunityMemory],
        snapshot: BusinessSnapshot,
        useOfFunds: String,
        revenueShareTerms: RevenueShareTerms? = nil,
        partialOwnership: PartialOwnershipOption? = nil,
        fullAcquisition: FullAcquisitionOption? = nil,
        hasTakeoverGroup: Bool,
        galleryImageURLs: [URL],
        shareRewards: [ShareReward] = [],
        professionalSale: ProfessionalSale? = nil
    ) {
        self.id = id
        self.summary = summary
        self.tagline = tagline
        self.founderName = founderName
        self.founderStory = founderStory
        self.whyItMatters = whyItMatters
        self.communityMemories = communityMemories
        self.snapshot = snapshot
        self.useOfFunds = useOfFunds
        self.revenueShareTerms = revenueShareTerms
        self.partialOwnership = partialOwnership
        self.fullAcquisition = fullAcquisition
        self.hasTakeoverGroup = hasTakeoverGroup
        self.galleryImageURLs = galleryImageURLs
        self.shareRewards = shareRewards.sorted()
        self.professionalSale = professionalSale
    }
}

/// A short remembered moment contributed by the community.
struct CommunityMemory: Identifiable, Equatable {
    let id: String
    var author: String
    var text: String
    var yearsAgo: Int?
    /// Author's initials for the avatar.
    var authorInitials: String?
    /// The author's relationship to the business (e.g. "Regular since 1990").
    var relationship: String?

    init(
        id: String,
        author: String,
        text: String,
        yearsAgo: Int? = nil,
        authorInitials: String? = nil,
        relationship: String? = nil
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.yearsAgo = yearsAgo
        self.authorInitials = authorInitials ?? String(author.prefix(1))
        self.relationship = relationship
    }
}

/// Key facts about the business.
struct BusinessSnapshot: Equatable {
    var foundedYear: Int
    var employees: Int
    var monthlyRevenue: Decimal?
    var address: String
    var highlights: [String]
}
