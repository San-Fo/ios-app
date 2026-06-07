import Foundation

/// API endpoints for the sale lifecycle. The sale is folded into the `Business`
/// document, so every write returns the updated `Business`. Keyed by
/// `businessId` (the backend sale has no separate id).
enum SaleEndpoints {
    /// Verified businesses with an active sale, redacted per viewer.
    static func sales() -> Endpoint<[BusinessDTO]> {
        Endpoint(path: "sales", method: .get)
    }

    /// A single business's sale (returns the full `Business`).
    static func sale(businessId: String) -> Endpoint<BusinessDTO> {
        Endpoint(path: "businesses/\(businessId)/sale", method: .get)
    }

    /// Owner submits the business for acquisition.
    static func submitSale(businessId: String, body: SubmitSaleBody) throws -> Endpoint<BusinessDTO> {
        try .json(path: "businesses/\(businessId)/sale", method: .post, body: body)
    }

    /// Institutional investor places a commercial bid.
    static func placeBid(businessId: String, amount: Decimal, message: String?) throws -> Endpoint<BusinessDTO> {
        try .json(
            path: "businesses/\(businessId)/sale/bids",
            method: .post,
            body: BidBody(amount: amount, message: message)
        )
    }

    /// Owner accepts a bid. The backend also creates a private deal
    /// conversation as a side effect; fetch it via the chat endpoints.
    static func acceptBid(businessId: String, bidId: String) -> Endpoint<BusinessDTO> {
        Endpoint(path: "businesses/\(businessId)/sale/bids/\(bidId)/accept", method: .post)
    }

    /// Owner declines all commercial bids and opens the retail fallback.
    static func declineCommercialBids(
        businessId: String,
        retailAskingPrice: Decimal,
        allowOutrightPurchase: Bool,
        allowGroupTakeover: Bool,
        ownerNote: String?
    ) throws -> Endpoint<BusinessDTO> {
        try .json(
            path: "businesses/\(businessId)/sale/decline-commercial-bids",
            method: .post,
            body: DeclineBody(
                retailAskingPrice: retailAskingPrice,
                allowOutrightPurchase: allowOutrightPurchase,
                allowGroupTakeover: allowGroupTakeover,
                ownerNote: ownerNote
            )
        )
    }

    // MARK: Bodies

    struct SubmitSaleBody: Encodable {
        let askingPrice: Decimal
        let financials: FinancialsBody
        let includes: [String]
        let ownerWillingToStay: Bool
        let handoverMonths: Int?

        struct FinancialsBody: Encodable {
            let annualRevenue: Decimal
            let annualProfit: Decimal
            let monthlyRent: Decimal?
            let leaseYearsRemaining: Int?
            let staffCount: Int
            let inventoryValue: Decimal?
            let notes: String?
        }
    }

    private struct BidBody: Encodable {
        let amount: Decimal
        let message: String?
    }

    private struct DeclineBody: Encodable {
        let retailAskingPrice: Decimal
        let allowOutrightPurchase: Bool
        let allowGroupTakeover: Bool
        let ownerNote: String?
    }
}
