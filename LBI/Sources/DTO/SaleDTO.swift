import Foundation

/// Wire model for the `sale` object folded into a `Business` (backend
/// `BusinessSale`). Confidential `financials` and `bids` may be redacted
/// (`null` / `[]`) by the server depending on the viewer.
struct BusinessSaleDTO: Decodable {
    let stage: String
    let askingPrice: Decimal
    let financials: SaleFinancialsDTO?
    let aiEvaluation: SaleEvaluationDTO?
    let includes: [String]?
    let ownerWillingToStay: Bool?
    let handoverMonths: Int?
    let commercialBiddingEndsAt: BSONDate?
    let retailFallback: RetailFallbackDTO?
    let bids: [SaleBidDTO]?

    /// Maps to the app's `ProfessionalSale`. `businessId`/`businessName` come
    /// from the enclosing business (the backend sale has no id of its own, so
    /// we use the business id as the sale identifier).
    func toDomain(businessId: String, businessName: String) -> ProfessionalSale {
        ProfessionalSale(
            id: businessId,
            businessId: businessId,
            businessName: businessName,
            stage: SaleStage(rawValue: stage) ?? .aiReview,
            askingPrice: askingPrice,
            aiEvaluation: aiEvaluation?.toDomain(),
            commercialBiddingEndsAt: commercialBiddingEndsAt?.date,
            financials: financials?.toDomain() ?? .redacted,
            includes: includes ?? [],
            ownerWillingToStay: ownerWillingToStay ?? false,
            handoverMonths: handoverMonths,
            retailFallbackOffer: retailFallback?.toDomain(),
            bids: (bids ?? []).map { $0.toDomain() },
            groupOffers: Self.groupOffers(from: bids ?? [])
        )
    }

    /// Bids tagged with a `bidderGroupId` are surfaced as group-buy offers so
    /// the owner UI can show them distinctly.
    private static func groupOffers(from bids: [SaleBidDTO]) -> [GroupBuyOffer] {
        bids.compactMap { bid in
            guard let groupId = bid.bidderGroupId else { return nil }
            return GroupBuyOffer(
                id: bid.id,
                groupId: groupId,
                groupName: bid.bidderName ?? "Takeover group",
                memberCount: 0,
                amount: bid.amount,
                message: bid.message,
                date: bid.createdAt?.date ?? Date(),
                status: BidStatus(rawValue: bid.status) ?? .submitted
            )
        }
    }
}

struct SaleEvaluationDTO: Decodable {
    let score: Int
    let verdict: String
    let strengths: [String]?
    let risks: [String]?
    let summary: String?

    func toDomain() -> SaleEvaluation {
        let mappedVerdict = EvaluationVerdict(rawValue: verdict) ?? .needsManualReview
        return SaleEvaluation(
            score: score,
            verdict: mappedVerdict,
            strengths: strengths ?? [],
            risks: risks ?? [],
            summary: summary ?? "",
            // recommendedAction/confidence are not provided by the backend;
            // derive a sensible action from the verdict, leave confidence default.
            recommendedAction: Self.recommendedAction(for: mappedVerdict),
            confidence: 0.8
        )
    }

    private static func recommendedAction(for verdict: EvaluationVerdict) -> String {
        switch verdict {
        case .recommendedForCommercialBidding:
            return "Move to bid — strong commercial candidate."
        case .needsManualReview:
            return "Review the financials and risks before bidding."
        case .retailOnly:
            return "Better suited to a retail or community buyer."
        }
    }
}

/// Backend `retailFallback` (set once the sale reaches `openToRetail`).
struct RetailFallbackDTO: Decodable {
    let askingPrice: Decimal
    let allowOutrightPurchase: Bool?
    let allowGroupTakeover: Bool?
    let ownerNote: String?

    func toDomain() -> RetailFallbackOffer {
        RetailFallbackOffer(
            askingPrice: askingPrice,
            allowOutrightPurchase: allowOutrightPurchase ?? false,
            allowGroupTakeover: allowGroupTakeover ?? false,
            ownerNote: ownerNote ?? ""
        )
    }
}

struct SaleFinancialsDTO: Decodable {
    let annualRevenue: Decimal
    let annualProfit: Decimal
    let monthlyRent: Decimal?
    let leaseYearsRemaining: Int?
    let staffCount: Int
    let inventoryValue: Decimal?
    let notes: String?

    func toDomain() -> SaleFinancials {
        SaleFinancials(
            annualRevenue: annualRevenue,
            annualProfit: annualProfit,
            monthlyRent: monthlyRent,
            leaseYearsRemaining: leaseYearsRemaining,
            staffCount: staffCount,
            inventoryValue: inventoryValue,
            notes: notes ?? ""
        )
    }
}

/// Backend `SaleBid`. `bidderGroupId` is set when the bid was placed on behalf
/// of a takeover group (collective offer).
struct SaleBidDTO: Decodable {
    let id: String
    let bidderUserId: String?
    let bidderName: String?
    let bidderGroupId: String?
    let amount: Decimal
    let message: String?
    let status: String
    let createdAt: BSONDate?

    func toDomain() -> SaleBid {
        SaleBid(
            id: id,
            bidderName: bidderName ?? "Investor",
            bidderCredential: nil,
            amount: amount,
            message: message,
            date: createdAt?.date ?? Date(),
            status: BidStatus(rawValue: status) ?? .submitted,
            isCurrentUser: false
        )
    }
}
