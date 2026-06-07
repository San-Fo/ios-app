import Foundation

/// Wire model sent when an owner submits a listing.
/// TODO(API): align with the backend schema; add photo references for upload.
struct ListingSubmissionDTO: Encodable {
    let businessName: String
    let category: String
    let district: String
    let foundedYear: Int?
    let founderStory: String
    let whyItMatters: String
    let monthlyRevenue: Decimal?
    let employees: Int?
    let desiredOutcomes: [String]
    let saleAskingPrice: Decimal?
    let retailFallbackPrice: Decimal?
    let allowRetailOutrightPurchase: Bool
    let allowRetailGroupTakeover: Bool
    let contactEmail: String

    init(_ draft: ListingDraft) {
        businessName = draft.businessName
        category = draft.category.rawValue
        district = draft.district.rawValue
        foundedYear = Int(draft.foundedYear)
        founderStory = draft.founderStory
        whyItMatters = draft.whyItMatters
        monthlyRevenue = Decimal(string: draft.monthlyRevenue)
        employees = Int(draft.employees)
        desiredOutcomes = draft.desiredOutcomes.map(\.rawValue)
        saleAskingPrice = Decimal(string: draft.saleAskingPrice)
        retailFallbackPrice = Decimal(string: draft.retailFallbackPrice)
        allowRetailOutrightPurchase = draft.allowRetailOutrightPurchase
        allowRetailGroupTakeover = draft.allowRetailGroupTakeover
        contactEmail = draft.contactEmail
    }
}

/// Wire model returned after recording an investment/support action.
/// TODO(API): align with the backend schema.
struct InvestmentDTO: Decodable {
    let id: String
    let businessId: String
    let kind: String
    let amount: Decimal
    let date: Date

    func toDomain(businessName: String) -> InvestmentRecord {
        InvestmentRecord(
            id: id,
            businessId: businessId,
            businessName: businessName,
            kind: FundingKind(rawValue: kind) ?? .revenueShare,
            amount: amount,
            date: date
        )
    }
}
