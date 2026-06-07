import Foundation

/// API endpoints for chat conversations (deal + group). The backend exposes a
/// single conversation system; a `deal` conversation is auto-created when an
/// owner accepts a bid, and a `group` conversation backs each takeover group.
enum DealChatEndpoints {
    /// The caller's conversations, newest first.
    static func conversations() -> Endpoint<[ConversationDTO]> {
        Endpoint(path: "me/conversations", method: .get)
    }

    /// A single conversation (participants only).
    static func conversation(id: String) -> Endpoint<ConversationDTO> {
        Endpoint(path: "conversations/\(id)", method: .get)
    }

    /// Messages oldest-first. `after` is a Unix-millis cursor for incremental
    /// polling; `limit` defaults to 50 (max 200).
    static func messages(conversationId: String, afterMillis: Int64?, limit: Int = 50) -> Endpoint<[ChatMessageDTO]> {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let afterMillis {
            query.append(URLQueryItem(name: "after", value: String(afterMillis)))
        }
        return Endpoint(path: "conversations/\(conversationId)/messages", method: .get, query: query)
    }

    /// Post a new message.
    static func sendMessage(conversationId: String, body: String) throws -> Endpoint<ChatMessageDTO> {
        try .json(
            path: "conversations/\(conversationId)/messages",
            method: .post,
            body: MessageBody(body: body)
        )
    }

    private struct MessageBody: Encodable { let body: String }
}
