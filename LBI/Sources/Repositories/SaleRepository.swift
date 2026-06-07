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
        try await client.send(SaleEndpoints.sales()).map { $0.toDomain() }
    }

    func sale(forBusiness businessId: String) async throws -> ProfessionalSale? {
        try await client.send(SaleEndpoints.sale(businessId: businessId)).toDomain()
    }

    func placeBid(saleId: String, amount: Decimal, message: String?) async throws -> SaleBid {
        let dto = try await client.send(try SaleEndpoints.placeBid(saleId: saleId, amount: amount, message: message))
        return dto.toDomain()
    }

    func acceptBid(saleId: String, bidId: String) async throws -> AcceptedOffer {
        let result = try await client.send(SaleEndpoints.acceptBid(saleId: saleId, bidId: bidId))
            .toDomain(currentUserId: currentUserId())
        return AcceptedOffer(sale: result.sale, conversation: result.conversation)
    }

    func acceptGroupOffer(saleId: String, offerId: String) async throws -> AcceptedOffer {
        let result = try await client.send(SaleEndpoints.acceptGroupOffer(saleId: saleId, offerId: offerId))
            .toDomain(currentUserId: currentUserId())
        return AcceptedOffer(sale: result.sale, conversation: result.conversation)
    }

    func acceptRetailPurchase(saleId: String, buyerName: String) async throws -> AcceptedOffer {
        let result = try await client.send(SaleEndpoints.acceptRetailPurchase(saleId: saleId))
            .toDomain(currentUserId: currentUserId())
        return AcceptedOffer(sale: result.sale, conversation: result.conversation)
    }

    func declineCommercialBids(saleId: String, retailAskingPrice: Decimal, allowOutrightPurchase: Bool, allowGroupTakeover: Bool) async throws -> ProfessionalSale {
        try await client.send(try SaleEndpoints.declineCommercialBids(saleId: saleId, retailAskingPrice: retailAskingPrice, allowOutrightPurchase: allowOutrightPurchase, allowGroupTakeover: allowGroupTakeover)).toDomain()
    }
}

// MARK: - Mock

final class MockSaleRepository: SaleRepository, @unchecked Sendable {
    private var sales: [String: ProfessionalSale]
    private let mutex = Mutex()
    /// When set, accepted offers register a conversation here so the deal chat
    /// is immediately available, mirroring the backend's behaviour.
    private let dealChat: DealChatRepository?

    init(dealChat: DealChatRepository? = nil) {
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
