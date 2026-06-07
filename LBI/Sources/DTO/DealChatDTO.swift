import Foundation

/// Wire model for a deal conversation. TODO(API): align with the backend.
struct DealConversationDTO: Decodable {
    let id: String
    let saleId: String
    let businessId: String
    let businessName: String
    let dealKind: String
    let agreedAmount: Decimal
    let counterpartyName: String
    let status: String?
    let messages: [DealMessageDTO]?
    let createdAt: Date?

    func toDomain(currentUserId: String?) -> DealConversation {
        DealConversation(
            id: id,
            saleId: saleId,
            businessId: businessId,
            businessName: businessName,
            dealKind: DealKind(rawValue: dealKind) ?? .commercialBid,
            agreedAmount: agreedAmount,
            counterpartyName: counterpartyName,
            status: DealStatus(rawValue: status ?? "") ?? .negotiating,
            messages: (messages ?? []).map { $0.toDomain(currentUserId: currentUserId) },
            createdAt: createdAt ?? Date()
        )
    }
}

struct DealMessageDTO: Decodable {
    let id: String
    let authorId: String?
    let authorName: String
    let text: String
    let sentAt: Date
    let isSystem: Bool?

    func toDomain(currentUserId: String?) -> DealMessage {
        DealMessage(
            id: id,
            authorName: authorName,
            text: text,
            sentAt: sentAt,
            isCurrentUser: authorId != nil && authorId == currentUserId,
            isSystem: isSystem ?? false
        )
    }
}
