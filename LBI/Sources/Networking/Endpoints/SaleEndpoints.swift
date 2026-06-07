import Foundation

/// API endpoints for the confidential professional sale + bidding.
/// TODO(API): confirm paths and payloads with the backend team. Access to
/// these endpoints must be gated server-side to verified professional accounts.
enum SaleEndpoints {
    static func sales() -> Endpoint<[ProfessionalSaleDTO]> {
        Endpoint(path: "sales", method: .get)
    }

    static func sale(businessId: String) -> Endpoint<ProfessionalSaleDTO> {
        Endpoint(path: "businesses/\(businessId)/sale", method: .get)
    }

    static func placeBid(saleId: String, amount: Decimal, message: String?) throws -> Endpoint<SaleBidDTO> {
        try .json(
            path: "sales/\(saleId)/bids",
            method: .post,
            body: BidBody(amount: amount, message: message)
        )
    }

    /// Accepting a bid finalises the sale AND opens a private deal conversation,
    /// which the backend returns so the client can navigate straight into it.
    static func acceptBid(saleId: String, bidId: String) -> Endpoint<AcceptOfferResultDTO> {
        Endpoint(path: "sales/\(saleId)/bids/\(bidId)/accept", method: .post)
    }

    static func acceptGroupOffer(saleId: String, offerId: String) -> Endpoint<AcceptOfferResultDTO> {
        Endpoint(path: "sales/\(saleId)/group-offers/\(offerId)/accept", method: .post)
    }

    /// A solo retail buyer accepts the public fallback price; opens a deal chat.
    static func acceptRetailPurchase(saleId: String) -> Endpoint<AcceptOfferResultDTO> {
        Endpoint(path: "sales/\(saleId)/retail-purchase", method: .post)
    }

    static func declineCommercialBids(saleId: String, retailAskingPrice: Decimal, allowOutrightPurchase: Bool, allowGroupTakeover: Bool) throws -> Endpoint<ProfessionalSaleDTO> {
        try .json(
            path: "sales/\(saleId)/decline-commercial-bids",
            method: .post,
            body: RetailFallbackBody(
                retailAskingPrice: retailAskingPrice,
                allowOutrightPurchase: allowOutrightPurchase,
                allowGroupTakeover: allowGroupTakeover
            )
        )
    }

    private struct BidBody: Encodable {
        let amount: Decimal
        let message: String?
    }

    private struct RetailFallbackBody: Encodable {
        let retailAskingPrice: Decimal
        let allowOutrightPurchase: Bool
        let allowGroupTakeover: Bool
    }
}
