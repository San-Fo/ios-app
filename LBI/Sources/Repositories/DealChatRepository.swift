import Foundation

/// Manages private, server-backed deal conversations between an owner and the
/// party whose offer they accepted.
protocol DealChatRepository: Sendable {
    /// All conversations the current user is part of.
    func conversations() async throws -> [DealConversation]
    /// Fetch one conversation (with its messages).
    func conversation(id: String) async throws -> DealConversation?
    /// Fetch messages newer than `afterMessageId` (used for polling).
    func newMessages(conversationId: String, afterMessageId: String?) async throws -> [DealMessage]
    /// Send a message into a conversation.
    func sendMessage(conversationId: String, text: String) async throws -> DealMessage
    /// Update the deal status.
    func updateStatus(conversationId: String, status: DealStatus) async throws -> DealConversation
    /// Register a conversation locally (mock convenience after accepting offers).
    func register(_ conversation: DealConversation)
}

// MARK: - Live

final class LiveDealChatRepository: DealChatRepository, @unchecked Sendable {
    private let client: APIClient
    private let currentUserId: () -> String?

    init(client: APIClient, currentUserId: @escaping () -> String? = { nil }) {
        self.client = client
        self.currentUserId = currentUserId
    }

    func conversations() async throws -> [DealConversation] {
        try await client.send(DealChatEndpoints.conversations())
            .map { $0.toDomain(currentUserId: currentUserId()) }
    }

    func conversation(id: String) async throws -> DealConversation? {
        try await client.send(DealChatEndpoints.conversation(id: id))
            .toDomain(currentUserId: currentUserId())
    }

    func newMessages(conversationId: String, afterMessageId: String?) async throws -> [DealMessage] {
        try await client.send(DealChatEndpoints.messages(conversationId: conversationId, afterMessageId: afterMessageId))
            .map { $0.toDomain(currentUserId: currentUserId()) }
    }

    func sendMessage(conversationId: String, text: String) async throws -> DealMessage {
        try await client.send(try DealChatEndpoints.sendMessage(conversationId: conversationId, text: text))
            .toDomain(currentUserId: currentUserId())
    }

    func updateStatus(conversationId: String, status: DealStatus) async throws -> DealConversation {
        try await client.send(try DealChatEndpoints.updateStatus(conversationId: conversationId, status: status.rawValue))
            .toDomain(currentUserId: currentUserId())
    }

    func register(_ conversation: DealConversation) {
        // No-op: the live backend is the source of truth.
    }
}

// MARK: - Mock

/// In-memory mock that simulates a server-backed conversation, including an
/// occasional reply from the counterparty so polling has something to surface.
final class MockDealChatRepository: DealChatRepository, @unchecked Sendable {
    private let mutex = Mutex()
    private var conversations: [String: DealConversation] = [:]

    func conversations() async throws -> [DealConversation] {
        mutex.withLock { conversations.values.sorted { $0.createdAt > $1.createdAt } }
    }

    func conversation(id: String) async throws -> DealConversation? {
        mutex.withLock { conversations[id] }
    }

    func newMessages(conversationId: String, afterMessageId: String?) async throws -> [DealMessage] {
        mutex.withLock {
            guard let messages = conversations[conversationId]?.messages else { return [] }
            guard let afterMessageId else { return messages }
            guard let index = messages.firstIndex(where: { $0.id == afterMessageId }) else { return [] }
            return Array(messages.suffix(from: messages.index(after: index)))
        }
    }

    func sendMessage(conversationId: String, text: String) async throws -> DealMessage {
        let message = DealMessage(
            id: UUID().uuidString,
            authorName: "You",
            text: text,
            sentAt: Date(),
            isCurrentUser: true
        )
        let counterparty: String? = mutex.withLock {
            conversations[conversationId]?.messages.append(message)
            return conversations[conversationId]?.counterpartyName
        }

        // Simulate the other party acknowledging, as a stand-in for the server.
        if let counterparty {
            let reply = DealMessage(
                id: UUID().uuidString,
                authorName: counterparty,
                text: Self.autoReply(to: text),
                sentAt: Date().addingTimeInterval(1),
                isCurrentUser: false
            )
            mutex.withLock {
                conversations[conversationId]?.messages.append(reply)
            }
        }
        return message
    }

    func updateStatus(conversationId: String, status: DealStatus) async throws -> DealConversation {
        try mutex.withLock {
            guard var convo = conversations[conversationId] else { throw APIError.notFound }
            convo.status = status
            convo.messages.append(
                DealMessage(
                    id: UUID().uuidString,
                    authorName: "System",
                    text: "Deal status updated to \(status.displayName).",
                    sentAt: Date(),
                    isCurrentUser: false,
                    isSystem: true
                )
            )
            conversations[conversationId] = convo
            return convo
        }
    }

    func register(_ conversation: DealConversation) {
        mutex.withLock { conversations[conversation.id] = conversation }
    }

    private static func autoReply(to text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("payment") || lowered.contains("pay") {
            return "Understood. Let's confirm the payment milestones and escrow details here."
        }
        if lowered.contains("handover") || lowered.contains("transition") {
            return "Agreed. We can align on the handover timeline and what's included."
        }
        return "Thanks for the message — noted. Let's continue working through the details."
    }
}
