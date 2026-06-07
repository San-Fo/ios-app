import Foundation

/// Wire model for a professional sale. TODO(API): align with the backend.
struct ProfessionalSaleDTO: Decodable {
    let id: String
    let businessId: String
    let businessName: String
    let stage: String
    let askingPrice: Decimal
    let aiEvaluation: SaleEvaluationDTO?
    let commercialBiddingEndsAt: Date?
    let financials: SaleFinancialsDTO
    let includes: [String]?
    let ownerWillingToStay: Bool?
    let handoverMonths: Int?
    let retailFallbackOffer: RetailFallbackOfferDTO?
    let bids: [SaleBidDTO]?
    let groupOffers: [GroupBuyOfferDTO]?

    func toDomain() -> ProfessionalSale {
        ProfessionalSale(
            id: id,
            businessId: businessId,
            businessName: businessName,
            stage: SaleStage(rawValue: stage) ?? .aiReview,
            askingPrice: askingPrice,
            aiEvaluation: aiEvaluation?.toDomain(),
            commercialBiddingEndsAt: commercialBiddingEndsAt,
            financials: financials.toDomain(),
            includes: includes ?? [],
            ownerWillingToStay: ownerWillingToStay ?? false,
            handoverMonths: handoverMonths,
            retailFallbackOffer: retailFallbackOffer?.toDomain(),
            bids: (bids ?? []).map { $0.toDomain() },
            groupOffers: (groupOffers ?? []).map { $0.toDomain() }
        )
    }
}

/// Result of accepting any offer: the updated sale plus the deal conversation
/// the backend opened between the owner and the accepted party.
struct AcceptOfferResultDTO: Decodable {
    let sale: ProfessionalSaleDTO
    let conversation: DealConversationDTO

    func toDomain(currentUserId: String?) -> (sale: ProfessionalSale, conversation: DealConversation) {
        (sale.toDomain(), conversation.toDomain(currentUserId: currentUserId))
    }
}

struct GroupBuyOfferDTO: Decodable {
    let id: String
    let groupId: String
    let groupName: String
    let memberCount: Int
    let amount: Decimal
    let message: String?
    let date: Date
    let status: String

    func toDomain() -> GroupBuyOffer {
        GroupBuyOffer(
            id: id,
            groupId: groupId,
            groupName: groupName,
            memberCount: memberCount,
            amount: amount,
            message: message,
            date: date,
            status: BidStatus(rawValue: status) ?? .submitted
        )
    }
}

struct SaleEvaluationDTO: Decodable {
    let score: Int
    let verdict: String
    let strengths: [String]?
    let risks: [String]?
    let summary: String?
    let recommendedAction: String?
    let confidence: Double?

    func toDomain() -> SaleEvaluation {
        SaleEvaluation(
            score: score,
            verdict: EvaluationVerdict(rawValue: verdict) ?? .needsManualReview,
            strengths: strengths ?? [],
            risks: risks ?? [],
            summary: summary ?? "",
            recommendedAction: recommendedAction ?? "",
            confidence: confidence ?? 0.8
        )
    }
}

struct RetailFallbackOfferDTO: Decodable {
    let askingPrice: Decimal
    let allowOutrightPurchase: Bool?
    let allowGroupTakeover: Bool?
    let ownerNote: String?

    func toDomain() -> RetailFallbackOffer {
        RetailFallbackOffer(
            askingPrice: askingPrice,
            allowOutrightPurchase: allowOutrightPurchase ?? true,
            allowGroupTakeover: allowGroupTakeover ?? true,
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

struct SaleBidDTO: Decodable {
    let id: String
    let bidderName: String
    let bidderCredential: String?
    let amount: Decimal
    let message: String?
    let date: Date
    let status: String

    func toDomain() -> SaleBid {
        SaleBid(
            id: id,
            bidderName: bidderName,
            bidderCredential: bidderCredential,
            amount: amount,
            message: message,
            date: date,
            status: BidStatus(rawValue: status) ?? .submitted,
            isCurrentUser: false
        )
    }
}
