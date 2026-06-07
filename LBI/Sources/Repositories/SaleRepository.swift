import Foundation

/// Result of accepting any offer: the updated sale and the private deal
/// conversation that was opened with the accepted party.
struct AcceptedOffer: Equatable {
    var sale: ProfessionalSale
    var conversation: DealConversation
}

/// Manages the confidential professional sale + bidding process.
protocol SaleRepository: Sendable {
    /// Sales visible to the current account role.
    func sales() async throws -> [ProfessionalSale]
    /// Fetch the professional sale for a business (nil if none / not permitted).
    func sale(forBusiness businessId: String) async throws -> ProfessionalSale?
    /// A professional places (or updates) a bid.
    func placeBid(saleId: String, amount: Decimal, message: String?) async throws -> SaleBid
    /// The owner accepts a commercial bid; opens a private deal conversation.
    func acceptBid(saleId: String, bidId: String) async throws -> AcceptedOffer
    /// The owner accepts a takeover group's offer (may be below ask); opens a deal conversation.
    func acceptGroupOffer(saleId: String, offerId: String) async throws -> AcceptedOffer
    /// A solo retail buyer accepts the public fallback price; opens a deal conversation.
    func acceptRetailPurchase(saleId: String, buyerName: String) async throws -> AcceptedOffer
    /// The owner rejects commercial bids and opens the sale to retail buyers / takeover groups.
    func declineCommercialBids(saleId: String, retailAskingPrice: Decimal, allowOutrightPurchase: Bool, allowGroupTakeover: Bool) async throws -> ProfessionalSale
}

// MARK: - Live (placeholder)

final class LiveSaleRepository: SaleRepository, @unchecked Sendable {
    private let client: APIClient
    private let currentUserId: () -> String?

    init(client: APIClient, currentUserId: @escaping () -> String? = { nil }) {
        self.client = client
        self.currentUserId = currentUserId
    }

    func sales() async throws -> [ProfessionalSale] {
        try await client.send(SaleEndpoints.sales()).compactMap(saleDomain)
    }

    func sale(forBusiness businessId: String) async throws -> ProfessionalSale? {
        saleDomain(try await client.send(SaleEndpoints.sale(businessId: businessId)))
    }

    func placeBid(saleId: String, amount: Decimal, message: String?) async throws -> SaleBid {
        // `saleId` is the businessId (the sale is folded into the business).
        let business = try await client.send(try SaleEndpoints.placeBid(businessId: saleId, amount: amount, message: message))
        // Return the caller's just-placed bid (highest by recency on the sale).
        guard let sale = saleDomain(business), let mine = sale.bids.last else { throw APIError.unknown }
        return mine
    }

    func acceptBid(saleId: String, bidId: String) async throws -> AcceptedOffer {
        // Accepting returns the updated Business and creates a deal conversation
        // server-side; we then locate that conversation to open the chat.
        let business = try await client.send(SaleEndpoints.acceptBid(businessId: saleId, bidId: bidId))
        guard let sale = saleDomain(business) else { throw APIError.unknown }
        let conversation = try await dealConversation(forBusiness: saleId, sale: sale)
        return AcceptedOffer(sale: sale, conversation: conversation)
    }

    func acceptGroupOffer(saleId: String, offerId: String) async throws -> AcceptedOffer {
        // A group offer is materialised as a normal bid (tagged bidderGroupId),
        // so accepting it uses the same accept-bid endpoint.
        try await acceptBid(saleId: saleId, bidId: offerId)
    }

    func acceptRetailPurchase(saleId: String, buyerName: String) async throws -> AcceptedOffer {
        // NO_BACKEND: no "accept retail purchase" endpoint; a retail buyer records
        // a purchase Action instead, and there is no deal chat for it.
        // TODO(API): add a retail-purchase accept + conversation if needed.
        MockMarker.hit(.noBackend, "Live.acceptRetailPurchase", "no retail-purchase accept endpoint")
        throw APIError.notFound
    }

    func declineCommercialBids(saleId: String, retailAskingPrice: Decimal, allowOutrightPurchase: Bool, allowGroupTakeover: Bool) async throws -> ProfessionalSale {
        let business = try await client.send(try SaleEndpoints.declineCommercialBids(
            businessId: saleId,
            retailAskingPrice: retailAskingPrice,
            allowOutrightPurchase: allowOutrightPurchase,
            allowGroupTakeover: allowGroupTakeover,
            ownerNote: nil
        ))
        guard let sale = saleDomain(business) else { throw APIError.unknown }
        return sale
    }

    // MARK: Helpers

    private func saleDomain(_ business: BusinessDTO) -> ProfessionalSale? {
        business.sale?.toDomain(businessId: business.id, businessName: business.name)
    }

    /// Finds the deal conversation for a business after a bid is accepted.
    private func dealConversation(forBusiness businessId: String, sale: ProfessionalSale) async throws -> DealConversation {
        let convos = try await client.send(DealChatEndpoints.conversations())
        guard let match = convos.first(where: { $0.kind == "deal" && $0.businessId == businessId }) else {
            throw APIError.notFound
        }
        let messages = try await client.send(DealChatEndpoints.messages(conversationId: match.id, afterMillis: nil))
            .map { $0.toDomain(currentUserId: currentUserId()) }
        return match.toDomain(
            businessName: sale.businessName,
            dealKind: .commercialBid,
            agreedAmount: sale.acceptedBid?.amount ?? sale.askingPrice,
            counterpartyName: sale.acceptedBid?.bidderName ?? "Buyer",
            currentUserId: currentUserId(),
            messages: messages
        )
    }
}

// MARK: - Mock

/// ⚠️ MOCK — in-memory sales/bids/AI evaluations from `SampleData`. No backend.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockSaleRepository: SaleRepository, @unchecked Sendable {
    private var sales: [String: ProfessionalSale]
    private let mutex = Mutex()
    /// When set, accepted offers register a conversation here so the deal chat
    /// is immediately available, mirroring the backend's behaviour.
    private let dealChat: DealChatRepository?

    init(dealChat: DealChatRepository? = nil) {
        MockMarker.hit(.mock, "MockSaleRepository", "sales/bids/AI from SampleData")
        var dict: [String: ProfessionalSale] = [:]
        for sale in SampleData.professionalSales { dict[sale.businessId] = sale }
        sales = dict
        self.dealChat = dealChat
    }

    func sales() async throws -> [ProfessionalSale] {
        mutex.withLock { sales.values.sorted { $0.businessName < $1.businessName } }
    }

    func sale(forBusiness businessId: String) async throws -> ProfessionalSale? {
        mutex.withLock { sales[businessId] }
    }

    func placeBid(saleId: String, amount: Decimal, message: String?) async throws -> SaleBid {
        let bid = SaleBid(
            id: UUID().uuidString,
            bidderName: "You",
            bidderCredential: "Approved commercial investor",
            amount: amount,
            message: message,
            date: Date(),
            status: .submitted,
            isCurrentUser: true
        )
        mutex.withLock {
            if let key = sales.first(where: { $0.value.id == saleId })?.key {
                sales[key]?.bids.append(bid)
            }
        }
        return bid
    }

    func acceptBid(saleId: String, bidId: String) async throws -> AcceptedOffer {
        let result: (ProfessionalSale, SaleBid) = try mutex.withLock {
            guard let key = sales.first(where: { $0.value.id == saleId })?.key,
                  var sale = sales[key],
                  let bid = sale.bids.first(where: { $0.id == bidId }) else {
                throw APIError.notFound
            }
            sale.stage = .accepted
            sale.bids = sale.bids.map { existing in
                var existing = existing
                existing.status = existing.id == bidId ? .accepted : .rejected
                return existing
            }
            sales[key] = sale
            return (sale, bid)
        }

        let conversation = Self.makeConversation(
            sale: result.0,
            dealKind: .commercialBid,
            amount: result.1.amount,
            counterparty: result.1.bidderName
        )
        dealChat?.register(conversation)
        return AcceptedOffer(sale: result.0, conversation: conversation)
    }

    func acceptGroupOffer(saleId: String, offerId: String) async throws -> AcceptedOffer {
        let result: (ProfessionalSale, GroupBuyOffer) = try mutex.withLock {
            guard let key = sales.first(where: { $0.value.id == saleId })?.key,
                  var sale = sales[key],
                  let offer = sale.groupOffers.first(where: { $0.id == offerId }) else {
                throw APIError.notFound
            }
            sale.stage = .accepted
            sale.groupOffers = sale.groupOffers.map { existing in
                var existing = existing
                existing.status = existing.id == offerId ? .accepted : .rejected
                return existing
            }
            sales[key] = sale
            return (sale, offer)
        }

        let conversation = Self.makeConversation(
            sale: result.0,
            dealKind: .groupTakeover,
            amount: result.1.amount,
            counterparty: result.1.groupName
        )
        dealChat?.register(conversation)
        return AcceptedOffer(sale: result.0, conversation: conversation)
    }

    func acceptRetailPurchase(saleId: String, buyerName: String) async throws -> AcceptedOffer {
        let result: (ProfessionalSale, Decimal) = try mutex.withLock {
            guard let key = sales.first(where: { $0.value.id == saleId })?.key,
                  var sale = sales[key] else {
                throw APIError.notFound
            }
            let amount = sale.retailFallbackOffer?.askingPrice ?? sale.askingPrice
            sale.stage = .accepted
            sales[key] = sale
            return (sale, amount)
        }

        let conversation = Self.makeConversation(
            sale: result.0,
            dealKind: .soloBuyer,
            amount: result.1,
            counterparty: buyerName
        )
        dealChat?.register(conversation)
        return AcceptedOffer(sale: result.0, conversation: conversation)
    }

    func declineCommercialBids(saleId: String, retailAskingPrice: Decimal, allowOutrightPurchase: Bool, allowGroupTakeover: Bool) async throws -> ProfessionalSale {
        try mutex.withLock {
        guard let key = sales.first(where: { $0.value.id == saleId })?.key else {
            throw APIError.notFound
        }
        guard var sale = sales[key] else { throw APIError.notFound }
        sale.stage = .openToRetail
        sale.retailFallbackOffer = RetailFallbackOffer(
            askingPrice: retailAskingPrice,
            allowOutrightPurchase: allowOutrightPurchase,
            allowGroupTakeover: allowGroupTakeover,
            ownerNote: "Commercial bids were declined. The owner has opened a public fallback price."
        )
        sale.bids = sale.bids.map { bid in
            var bid = bid
            if bid.status == .submitted { bid.status = .rejected }
            return bid
        }
        sales[key] = sale
        return sale
        }
    }

    private static func makeConversation(
        sale: ProfessionalSale,
        dealKind: DealKind,
        amount: Decimal,
        counterparty: String
    ) -> DealConversation {
        DealConversation(
            id: UUID().uuidString,
            saleId: sale.id,
            businessId: sale.businessId,
            businessName: sale.businessName,
            dealKind: dealKind,
            agreedAmount: amount,
            counterpartyName: counterparty,
            status: .negotiating,
            messages: [
                DealMessage(
                    id: UUID().uuidString,
                    authorName: "System",
                    text: "Offer accepted at \(Money.hkd(amount)). This private channel is for \(sale.businessName) — discuss handover, due diligence and payment here.",
                    sentAt: Date(),
                    isCurrentUser: false,
                    isSystem: true
                )
            ]
        )
    }
}
