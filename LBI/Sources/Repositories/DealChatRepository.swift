import Foundation

/// Manages server-backed chat conversations (deal + group).
///
/// Polling uses a timestamp cursor (`after:`) because the backend's
/// `/conversations/{id}/messages` takes a `after=<unixMillis>` parameter.
protocol DealChatRepository: Sendable {
    /// All conversations the current user is part of.
    func conversations() async throws -> [DealConversation]
    /// Fetch one conversation (with its messages).
    func conversation(id: String) async throws -> DealConversation?
    /// Fetch messages sent strictly after `date` (nil = all). Used for polling.
    func newMessages(conversationId: String, after date: Date?) async throws -> [DealMessage]
    /// Send a message into a conversation.
    func sendMessage(conversationId: String, text: String) async throws -> DealMessage
    /// Update the deal status (client-side only; the backend has no status).
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
        let dtos = try await client.send(DealChatEndpoints.conversations())
        // The list view only needs lightweight rows; messages are loaded when a
        // conversation is opened.
        return dtos.map { dto in
            dto.toDomain(
                businessName: "",
                dealKind: dto.kind == "group" ? .groupTakeover : .commercialBid,
                agreedAmount: 0,
                counterpartyName: "Counterparty",
                currentUserId: currentUserId(),
                messages: []
            )
        }
    }

    func conversation(id: String) async throws -> DealConversation? {
        let dto = try await client.send(DealChatEndpoints.conversation(id: id))
        let messages = try await client.send(DealChatEndpoints.messages(conversationId: id, afterMillis: nil))
            .map { $0.toDomain(currentUserId: currentUserId()) }
        return dto.toDomain(
            businessName: "",
            dealKind: dto.kind == "group" ? .groupTakeover : .commercialBid,
            agreedAmount: 0,
            counterpartyName: "Counterparty",
            currentUserId: currentUserId(),
            messages: messages
        )
    }

    func newMessages(conversationId: String, after date: Date?) async throws -> [DealMessage] {
        let cursor = date.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) }
        return try await client.send(DealChatEndpoints.messages(conversationId: conversationId, afterMillis: cursor))
            .map { $0.toDomain(currentUserId: currentUserId()) }
    }

    func sendMessage(conversationId: String, text: String) async throws -> DealMessage {
        try await client.send(try DealChatEndpoints.sendMessage(conversationId: conversationId, body: text))
            .toDomain(currentUserId: currentUserId())
    }

    func updateStatus(conversationId: String, status: DealStatus) async throws -> DealConversation {
        // NO_BACKEND: the backend has no deal-status concept; re-fetch instead.
        // TODO(API): add a status endpoint if deal lifecycle state is needed.
        MockMarker.hit(.noBackend, "Live.dealUpdateStatus", "no deal status endpoint")
        guard let convo = try await conversation(id: conversationId) else { throw APIError.notFound }
        return convo
    }

    func register(_ conversation: DealConversation) {
        // No-op: the live backend is the source of truth.
    }
}

// MARK: - Mock

/// ⚠️ MOCK — in-memory conversations with a canned auto-reply from the
/// "counterparty". No real second participant, no server.
/// Active only when `APIConfiguration.useMockData == true`.
final class MockDealChatRepository: DealChatRepository, @unchecked Sendable {
    private let mutex = Mutex()
    private var conversations: [String: DealConversation] = [:]

    func conversations() async throws -> [DealConversation] {
        mutex.withLock { conversations.values.sorted { $0.createdAt > $1.createdAt } }
    }

    func conversation(id: String) async throws -> DealConversation? {
        mutex.withLock { conversations[id] }
    }

    func newMessages(conversationId: String, after date: Date?) async throws -> [DealMessage] {
        mutex.withLock {
            guard let messages = conversations[conversationId]?.messages else { return [] }
            guard let date else { return messages }
            return messages.filter { $0.sentAt > date }
        }
    }

    func sendMessage(conversationId: String, text: String) async throws -> DealMessage {
        MockMarker.hit(.mock, "MockDealChatRepository.sendMessage", "canned counterparty auto-reply")
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
