import Foundation

/// A private, backend-backed conversation opened once an owner accepts an
/// offer — from a commercial bidder, a solo retail buyer, or a takeover group.
///
/// The conversation is where both sides discuss handover, due diligence and
/// payment. It is fully server-backed: messages are sent to and fetched from
/// the backend so all participants stay in sync.
struct DealConversation: Identifiable, Equatable, Hashable {
    let id: String
    var saleId: String
    var businessId: String
    var businessName: String
    /// How the accepted offer originated.
    var dealKind: DealKind
    /// The agreed price for the deal.
    var agreedAmount: Decimal
    /// Display name of the counterparty (buyer / bidder / group).
    var counterpartyName: String
    var status: DealStatus
    var messages: [DealMessage]
    var createdAt: Date

    init(
        id: String,
        saleId: String,
        businessId: String,
        businessName: String,
        dealKind: DealKind,
        agreedAmount: Decimal,
        counterpartyName: String,
        status: DealStatus = .negotiating,
        messages: [DealMessage] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.saleId = saleId
        self.businessId = businessId
        self.businessName = businessName
        self.dealKind = dealKind
        self.agreedAmount = agreedAmount
        self.counterpartyName = counterpartyName
        self.status = status
        self.messages = messages
        self.createdAt = createdAt
    }
}

/// How an accepted deal originated.
enum DealKind: String, Codable, Hashable {
    case commercialBid
    case soloBuyer
    case groupTakeover

    var displayName: String {
        switch self {
        case .commercialBid: return "Commercial acquisition"
        case .soloBuyer: return "Retail buyer"
        case .groupTakeover: return "Group takeover"
        }
    }

    var icon: String {
        switch self {
        case .commercialBid: return "briefcase.fill"
        case .soloBuyer: return "person.fill"
        case .groupTakeover: return "person.3.fill"
        }
    }
}

/// Lifecycle of a deal conversation.
enum DealStatus: String, Codable, Hashable {
    case negotiating
    case paymentPending
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .negotiating: return "Negotiating"
        case .paymentPending: return "Payment pending"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

/// A single message in a deal conversation.
struct DealMessage: Identifiable, Equatable, Hashable {
    let id: String
    var authorName: String
    var text: String
    var sentAt: Date
    var isCurrentUser: Bool
    /// Optional system/event note (e.g. "Offer accepted", "Payment marked sent").
    var isSystem: Bool

    init(
        id: String,
        authorName: String,
        text: String,
        sentAt: Date,
        isCurrentUser: Bool,
        isSystem: Bool = false
    ) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.sentAt = sentAt
        self.isCurrentUser = isCurrentUser
        self.isSystem = isSystem
    }
}
