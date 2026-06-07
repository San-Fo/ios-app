import Foundation

/// A supporter-reward tier set by the business owner.
///
/// Supporters collect "support cards" by donating — a voluntary keepsake that
/// shows you helped, NOT a financial share. Collecting at least
/// `cardsRequired` cards unlocks a thank-you perk from the owner.
struct ShareReward: Identifiable, Equatable, Comparable {
    let id: String
    /// Number of support cards a supporter must collect to unlock this perk.
    var cardsRequired: Int
    /// Short title of the perk, e.g. "Founder's thank-you postcard".
    var title: String
    /// Optional longer description of the perk.
    var detail: String?

    init(id: String = UUID().uuidString, cardsRequired: Int, title: String, detail: String? = nil) {
        self.id = id
        self.cardsRequired = cardsRequired
        self.title = title
        self.detail = detail
    }

    static func < (lhs: ShareReward, rhs: ShareReward) -> Bool {
        lhs.cardsRequired < rhs.cardsRequired
    }
}

/// A single line in a use-of-funds breakdown.
struct UseOfFundsItem: Identifiable, Equatable {
    let id: String
    var label: String
    var percentage: Double

    init(id: String = UUID().uuidString, label: String, percentage: Double) {
        self.id = id
        self.label = label
        self.percentage = percentage
    }
}

/// Revenue-share financing terms shown to retail supporters.
struct RevenueShareTerms: Equatable {
    /// Total amount the business wants to raise.
    var fundingTarget: Decimal
    /// Percentage of future revenue shared with supporters.
    var revenueSharePercent: Double
    /// Target return as a multiple of the amount funded (e.g. 1.5x).
    var targetMultiple: Double
    /// Estimated repayment period in months.
    var estimatedMonths: Int
    /// Plain-language description of what the funds are used for.
    var useOfFunds: String
    /// Optional structured breakdown of the use of funds.
    var useOfFundsBreakdown: [UseOfFundsItem]
    /// Minimum investment ticket.
    var minimumInvestment: Decimal?
    /// Maximum investment ticket.
    var maximumInvestment: Decimal?

    init(
        fundingTarget: Decimal,
        revenueSharePercent: Double,
        targetMultiple: Double,
        estimatedMonths: Int,
        useOfFunds: String,
        useOfFundsBreakdown: [UseOfFundsItem] = [],
        minimumInvestment: Decimal? = nil,
        maximumInvestment: Decimal? = nil
    ) {
        self.fundingTarget = fundingTarget
        self.revenueSharePercent = revenueSharePercent
        self.targetMultiple = targetMultiple
        self.estimatedMonths = estimatedMonths
        self.useOfFunds = useOfFunds
        self.useOfFundsBreakdown = useOfFundsBreakdown
        self.minimumInvestment = minimumInvestment
        self.maximumInvestment = maximumInvestment
    }
}

/// Partial ownership investment option.
struct PartialOwnershipOption: Equatable {
    /// Equity percentage available to investors in total.
    var equityOfferedPercent: Double
    /// Pre-money valuation.
    var valuation: Decimal
    /// Minimum ticket size.
    var minimumInvestment: Decimal
    /// Number of existing investors already on the cap table.
    var existingInvestors: Int

    init(
        equityOfferedPercent: Double,
        valuation: Decimal,
        minimumInvestment: Decimal,
        existingInvestors: Int = 0
    ) {
        self.equityOfferedPercent = equityOfferedPercent
        self.valuation = valuation
        self.minimumInvestment = minimumInvestment
        self.existingInvestors = existingInvestors
    }
}

/// Full acquisition option.
struct FullAcquisitionOption: Equatable {
    /// Asking price for the whole business.
    var askingPrice: Decimal
    /// Whether the owner is open to a collective (group) offer.
    var openToGroupOffer: Bool
    /// What's included in the sale.
    var includes: [String]
    /// Whether the property/premises is included.
    var includesProperty: Bool
    /// Years remaining on the lease (if leased).
    var leaseYearsRemaining: Int?
    /// Monthly revenue figure for buyers.
    var monthlyRevenue: Decimal?
    /// Number of staff included.
    var staffCount: Int?
    /// Whether the owner will stay to help with handover.
    var ownerWillingToStay: Bool
    /// Handover period in months.
    var handoverMonths: Int?

    init(
        askingPrice: Decimal,
        openToGroupOffer: Bool,
        includes: [String],
        includesProperty: Bool = false,
        leaseYearsRemaining: Int? = nil,
        monthlyRevenue: Decimal? = nil,
        staffCount: Int? = nil,
        ownerWillingToStay: Bool = false,
        handoverMonths: Int? = nil
    ) {
        self.askingPrice = askingPrice
        self.openToGroupOffer = openToGroupOffer
        self.includes = includes
        self.includesProperty = includesProperty
        self.leaseYearsRemaining = leaseYearsRemaining
        self.monthlyRevenue = monthlyRevenue
        self.staffCount = staffCount
        self.ownerWillingToStay = ownerWillingToStay
        self.handoverMonths = handoverMonths
    }
}
