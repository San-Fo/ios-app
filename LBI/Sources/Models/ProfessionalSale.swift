import Foundation

/// The role a user holds on the platform, which gates access to the private
/// professional sale (confidential financials + bidding).
enum AccountRole: String, Codable, CaseIterable {
    /// A member of the public — supports businesses, joins takeover groups.
    case retail
    /// A vetted commercial investor / operator who may view confidential
    /// financials, place bids, and access revenue-share loan products.
    case professional
    /// Business owner preview: submitted listings, AI review, bid decision,
    /// and public fallback controls.
    case owner

    var displayName: String {
        switch self {
        case .retail: return "Supporter"
        case .professional: return "Approved commercial investor"
        case .owner: return "Business owner"
        }
    }
}

/// The user's effective account tier: the chosen `AccountRole` combined with
/// whether the verification it requires has actually been approved.
///
/// Drives honest status labels/badges so a verified investor/owner is clearly
/// distinct from one who has only switched mode but not completed verification.
enum AccountTier: Equatable {
    case unverifiedSupporter
    case verifiedSupporter
    case unverifiedInvestor
    case verifiedInvestor
    case unverifiedOwner
    case verifiedOwner

    /// Whether the verification required for this role has been approved.
    var isVerified: Bool {
        switch self {
        case .verifiedSupporter, .verifiedInvestor, .verifiedOwner:
            return true
        case .unverifiedSupporter, .unverifiedInvestor, .unverifiedOwner:
            return false
        }
    }

    /// Short, user-facing label for the tier.
    var displayName: String {
        switch self {
        case .unverifiedSupporter: return "Supporter"
        case .verifiedSupporter: return "Verified supporter"
        case .unverifiedInvestor: return "Commercial investor (unverified)"
        case .verifiedInvestor: return "Approved commercial investor"
        case .unverifiedOwner: return "Business owner (unverified)"
        case .verifiedOwner: return "Verified business owner"
        }
    }
}

/// Where a business-for-sale currently sits in the sale process.
enum SaleStage: String, Codable, CaseIterable {
    /// Submitted by owner; backend AI is evaluating quality and fit.
    case aiReview
    /// Confidential — only registered professionals can view & bid.
    case commercialBidding
    /// Commercial bidding closed; owner decides whether to accept or decline.
    case ownerDecision
    /// The owner rejected professional bids and opened it to the public
    /// (retail supporters / takeover groups) hoping for a better price.
    case openToRetail
    /// A bid has been accepted; sale is being finalised.
    case accepted
    /// The sale has completed.
    case sold

    var displayName: String {
        switch self {
        case .aiReview: return "AI review"
        case .commercialBidding: return "Commercial bidding"
        case .ownerDecision: return "Owner decision"
        case .openToRetail: return "Open to the public"
        case .accepted: return "Offer accepted"
        case .sold: return "Sold"
        }
    }

    /// Whether retail (public) users can currently see/participate in the sale.
    var isVisibleToRetail: Bool {
        switch self {
        case .aiReview, .commercialBidding, .ownerDecision: return false
        case .openToRetail, .accepted, .sold: return true
        }
    }
}

/// Backend AI screening result used to decide whether a submitted sale first
/// enters commercial-investor bidding or should go straight to retail/community.
struct SaleEvaluation: Equatable {
    var score: Int
    var verdict: EvaluationVerdict
    var strengths: [String]
    var risks: [String]
    var summary: String
    /// AI's recommended next action for a commercial investor.
    var recommendedAction: String
    /// AI confidence in the assessment (0–1).
    var confidence: Double

    init(
        score: Int,
        verdict: EvaluationVerdict,
        strengths: [String],
        risks: [String],
        summary: String,
        recommendedAction: String = "",
        confidence: Double = 0.8
    ) {
        self.score = score
        self.verdict = verdict
        self.strengths = strengths
        self.risks = risks
        self.summary = summary
        self.recommendedAction = recommendedAction
        self.confidence = confidence
    }

    /// Qualitative rating derived from the numeric score.
    var rating: EvaluationRating {
        switch score {
        case 85...: return .strong
        case 70..<85: return .promising
        case 50..<70: return .cautious
        default: return .weak
        }
    }

    /// Confidence as a whole-number percentage.
    var confidencePercent: Int { Int((confidence * 100).rounded()) }
}

/// A qualitative bucket for an AI evaluation score, used for badges/colours.
enum EvaluationRating: Equatable {
    case strong
    case promising
    case cautious
    case weak

    var displayName: String {
        switch self {
        case .strong: return "Strong"
        case .promising: return "Promising"
        case .cautious: return "Cautious"
        case .weak: return "Weak"
        }
    }
}

enum EvaluationVerdict: String, Codable {
    case recommendedForCommercialBidding
    case needsManualReview
    case retailOnly

    var displayName: String {
        switch self {
        case .recommendedForCommercialBidding: return "Recommended for commercial bidding"
        case .needsManualReview: return "Needs manual review"
        case .retailOnly: return "Retail/community only"
        }
    }
}

/// Confidential financial figures shared with professional buyers.
struct SaleFinancials: Equatable {
    var annualRevenue: Decimal
    var annualProfit: Decimal
    var monthlyRent: Decimal?
    var leaseYearsRemaining: Int?
    var staffCount: Int
    var inventoryValue: Decimal?
    /// Free-form notes (customer base, supplier contracts, etc.).
    var notes: String

    /// Placeholder used when the backend has redacted confidential financials
    /// for the current viewer (non-owner, non-institutional, pre-fallback).
    static let redacted = SaleFinancials(
        annualRevenue: 0,
        annualProfit: 0,
        monthlyRent: nil,
        leaseYearsRemaining: nil,
        staffCount: 0,
        inventoryValue: nil,
        notes: ""
    )
}

/// A confidential, professional-first sale of a whole business.
struct ProfessionalSale: Identifiable, Equatable {
    let id: String
    var businessId: String
    var businessName: String
    var stage: SaleStage
    /// The owner's guide / asking price.
    var askingPrice: Decimal
    /// Backend AI quality assessment for the submitted business.
    var aiEvaluation: SaleEvaluation?
    /// When the commercial investor bidding window closes.
    var commercialBiddingEndsAt: Date?
    /// Confidential financials, shown only to professionals (or when opened to retail).
    var financials: SaleFinancials
    /// What's included in the sale.
    var includes: [String]
    /// Whether the owner will stay on for a handover.
    var ownerWillingToStay: Bool
    var handoverMonths: Int?
    /// Set by owner if they decline commercial bids and open to retail buyers.
    var retailFallbackOffer: RetailFallbackOffer?
    /// Bids placed so far (most recent / highest first when displayed).
    var bids: [SaleBid]
    /// Offers submitted by takeover groups once a retail fallback is open.
    /// The owner may accept one of these even if it is below the asking price.
    var groupOffers: [GroupBuyOffer]

    init(
        id: String,
        businessId: String,
        businessName: String,
        stage: SaleStage,
        askingPrice: Decimal,
        aiEvaluation: SaleEvaluation? = nil,
        commercialBiddingEndsAt: Date? = nil,
        financials: SaleFinancials,
        includes: [String],
        ownerWillingToStay: Bool,
        handoverMonths: Int? = nil,
        retailFallbackOffer: RetailFallbackOffer? = nil,
        bids: [SaleBid],
        groupOffers: [GroupBuyOffer] = []
    ) {
        self.id = id
        self.businessId = businessId
        self.businessName = businessName
        self.stage = stage
        self.askingPrice = askingPrice
        self.aiEvaluation = aiEvaluation
        self.commercialBiddingEndsAt = commercialBiddingEndsAt
        self.financials = financials
        self.includes = includes
        self.ownerWillingToStay = ownerWillingToStay
        self.handoverMonths = handoverMonths
        self.retailFallbackOffer = retailFallbackOffer
        self.bids = bids
        self.groupOffers = groupOffers
    }

    var highestBid: SaleBid? {
        bids.max { $0.amount < $1.amount }
    }

    var acceptedBid: SaleBid? {
        bids.first { $0.status == .accepted }
    }
}

/// An offer submitted by a takeover group against an open retail fallback.
/// May be below the asking price; the owner can still accept it.
struct GroupBuyOffer: Identifiable, Equatable {
    let id: String
    var groupId: String
    var groupName: String
    var memberCount: Int
    var amount: Decimal
    var message: String?
    var date: Date
    var status: BidStatus

    init(
        id: String,
        groupId: String,
        groupName: String,
        memberCount: Int,
        amount: Decimal,
        message: String? = nil,
        date: Date = Date(),
        status: BidStatus = .submitted
    ) {
        self.id = id
        self.groupId = groupId
        self.groupName = groupName
        self.memberCount = memberCount
        self.amount = amount
        self.message = message
        self.date = date
        self.status = status
    }
}

struct RetailFallbackOffer: Equatable {
    var askingPrice: Decimal
    var allowOutrightPurchase: Bool
    var allowGroupTakeover: Bool
    var ownerNote: String
}

/// A single bid placed by a professional buyer.
struct SaleBid: Identifiable, Equatable {
    let id: String
    var bidderName: String
    /// Bidder's track record / one-line credential.
    var bidderCredential: String?
    var amount: Decimal
    var message: String?
    var date: Date
    var status: BidStatus
    /// Whether the current user placed this bid.
    var isCurrentUser: Bool

    init(
        id: String,
        bidderName: String,
        bidderCredential: String? = nil,
        amount: Decimal,
        message: String? = nil,
        date: Date,
        status: BidStatus = .submitted,
        isCurrentUser: Bool = false
    ) {
        self.id = id
        self.bidderName = bidderName
        self.bidderCredential = bidderCredential
        self.amount = amount
        self.message = message
        self.date = date
        self.status = status
        self.isCurrentUser = isCurrentUser
    }
}

enum BidStatus: String, Codable {
    case submitted
    case accepted
    case rejected
    case withdrawn

    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .accepted: return "Accepted"
        case .rejected: return "Declined"
        case .withdrawn: return "Withdrawn"
        }
    }
}
