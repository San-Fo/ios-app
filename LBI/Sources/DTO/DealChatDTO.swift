import Foundation

/// Wire model for a backend `Conversation` (deal or group chat).
///
/// The backend conversation is intentionally minimal: it carries participants
/// and the linked business, but no agreed amount / counterparty name / status
/// (those live on the sale). The client derives display fields from the
/// associated business/sale when presenting a deal chat.
struct ConversationDTO: Decodable {
    let id: String
    let kind: String                 // "deal" | "group"
    let businessId: String
    let participantIds: [String]?
    let createdAt: BSONDate?

    private enum CodingKeys: String, CodingKey {
        case id, _id = "_id", kind, businessId, participantIds, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? c.decode(String.self, forKey: ._id)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "deal"
        businessId = try c.decodeIfPresent(String.self, forKey: .businessId) ?? ""
        participantIds = try c.decodeIfPresent([String].self, forKey: .participantIds)
        createdAt = try c.decodeIfPresent(BSONDate.self, forKey: .createdAt)
    }

    /// Maps to the app's `DealConversation`. Display fields not present on the
    /// wire model are filled by the caller (which knows the business/sale).
    func toDomain(
        businessName: String,
        dealKind: DealKind,
        agreedAmount: Decimal,
        counterpartyName: String,
        currentUserId: String?,
        messages: [DealMessage]
    ) -> DealConversation {
        DealConversation(
            id: id,
            saleId: businessId,
            businessId: businessId,
            businessName: businessName,
            dealKind: dealKind,
            agreedAmount: agreedAmount,
            counterpartyName: counterpartyName,
            status: .negotiating,
            messages: messages,
            createdAt: createdAt?.date ?? Date()
        )
    }
}

/// Wire model for a backend chat `Message`.
struct ChatMessageDTO: Decodable {
    let id: String
    let conversationId: String
    let senderUserId: String
    let body: String
    let createdAt: BSONDate?

    private enum CodingKeys: String, CodingKey {
        case id, _id = "_id", conversationId, senderUserId, body, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? c.decode(String.self, forKey: ._id)
        conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId) ?? ""
        senderUserId = try c.decodeIfPresent(String.self, forKey: .senderUserId) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        createdAt = try c.decodeIfPresent(BSONDate.self, forKey: .createdAt)
    }

    func toDomain(currentUserId: String?) -> DealMessage {
        DealMessage(
            id: id,
            authorName: senderUserId == currentUserId ? "You" : "Counterparty",
            text: body,
            sentAt: createdAt?.date ?? Date(),
            isCurrentUser: senderUserId == currentUserId,
            isSystem: false
        )
    }
}
