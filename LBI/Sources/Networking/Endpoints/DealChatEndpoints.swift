import Foundation

/// API endpoints for private deal conversations opened after an offer is
/// accepted. TODO(API): confirm paths/payloads with the backend team.
///
/// Server-side access must be restricted to the two parties of the deal
/// (owner + accepted buyer / bidder / group).
enum DealChatEndpoints {
    /// All deal conversations the current user is a party to.
    static func conversations() -> Endpoint<[DealConversationDTO]> {
        Endpoint(path: "deals", method: .get)
    }

    /// A single conversation, including its latest messages.
    static func conversation(id: String) -> Endpoint<DealConversationDTO> {
        Endpoint(path: "deals/\(id)", method: .get)
    }

    /// Fetch messages newer than a given message id (for polling).
    static func messages(conversationId: String, afterMessageId: String?) -> Endpoint<[DealMessageDTO]> {
        var query: [URLQueryItem] = []
        if let afterMessageId {
            query.append(URLQueryItem(name: "after", value: afterMessageId))
        }
        return Endpoint(path: "deals/\(conversationId)/messages", method: .get, query: query)
    }

    /// Post a new message into the conversation.
    static func sendMessage(conversationId: String, text: String) throws -> Endpoint<DealMessageDTO> {
        try .json(
            path: "deals/\(conversationId)/messages",
            method: .post,
            body: MessageBody(text: text)
        )
    }

    /// Update the deal status (e.g. mark payment pending / completed).
    static func updateStatus(conversationId: String, status: String) throws -> Endpoint<DealConversationDTO> {
        try .json(
            path: "deals/\(conversationId)/status",
            method: .post,
            body: StatusBody(status: status)
        )
    }

    private struct MessageBody: Encodable { let text: String }
    private struct StatusBody: Encodable { let status: String }
}
