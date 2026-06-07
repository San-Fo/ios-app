import Foundation

/// Manages takeover groups, their chat, and collective offers.
///
/// Group chat rides on the shared conversation system: the `channelId` passed
/// to the chat methods is the group's `conversationId`.
protocol TakeoverRepository: Sendable {
    func group(forBusiness businessId: String) async throws -> TakeoverGroup?
    func join(groupId: String) async throws
    func sendMessage(groupId: String, channelId: String, text: String) async throws -> GroupMessage
    /// Fetch channel messages sent after `date` (used for polling).
    func newMessages(groupId: String, channelId: String, after date: Date?) async throws -> [GroupMessage]
    func submitCollectiveOffer(groupId: String, amount: Decimal) async throws
    func askFounder(groupId: String, question: String) async throws -> FounderQA
}

// MARK: - Live

final class LiveTakeoverRepository: TakeoverRepository, @unchecked Sendable {
    private let client: APIClient
    private let currentUserId: () -> String?

    init(client: APIClient, currentUserId: @escaping () -> String? = { nil }) {
        self.client = client
        self.currentUserId = currentUserId
    }

    func group(forBusiness businessId: String) async throws -> TakeoverGroup? {
        // The backend returns a list of groups for a business; surface the first.
        try await client.send(TakeoverEndpoints.groups(businessId: businessId))
            .first?
            .toDomain(businessName: "")
    }

    func join(groupId: String) async throws {
        _ = try await client.send(try TakeoverEndpoints.join(groupId: groupId, pledgeAmount: nil))
    }

    func sendMessage(groupId: String, channelId: String, text: String) async throws -> GroupMessage {
        // channelId is the group's conversationId.
        let dto = try await client.send(try DealChatEndpoints.sendMessage(conversationId: channelId, body: text))
        return GroupMessage(
            id: dto.id,
            authorName: "You",
            text: dto.body,
            sentAt: dto.createdAt?.date ?? Date(),
            isCurrentUser: true
        )
    }

    func newMessages(groupId: String, channelId: String, after date: Date?) async throws -> [GroupMessage] {
        let cursor = date.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) }
        let me = currentUserId()
        return try await client.send(DealChatEndpoints.messages(conversationId: channelId, afterMillis: cursor))
            .map { dto in
                GroupMessage(
                    id: dto.id,
                    authorName: dto.senderUserId == me ? "You" : "Member",
                    text: dto.body,
                    sentAt: dto.createdAt?.date ?? Date(),
                    isCurrentUser: dto.senderUserId == me
                )
            }
    }

    func submitCollectiveOffer(groupId: String, amount: Decimal) async throws {
        // The backend sums member pledges itself; `amount` is informational.
        _ = try await client.send(TakeoverEndpoints.submitOffer(groupId: groupId))
    }

    func askFounder(groupId: String, question: String) async throws -> FounderQA {
        // No backend founder-Q&A endpoint; return a local echo so the UI flows.
        // TODO(API): add a founder Q&A endpoint if this feature is kept.
        FounderQA(id: UUID().uuidString, question: question, answer: nil, askedBy: "You")
    }
}

// MARK: - Mock

final class MockTakeoverRepository: TakeoverRepository, @unchecked Sendable {
    private let mutex = Mutex()
    private var groups: [String: TakeoverGroup]

    init() {
        var dict: [String: TakeoverGroup] = [:]
        for group in SampleData.takeoverGroups { dict[group.businessId] = group }
        groups = dict
    }

    func group(forBusiness businessId: String) async throws -> TakeoverGroup? {
        mutex.withLock { groups[businessId] }
    }

    func join(groupId: String) async throws {
        mutex.withLock {
            if let key = groups.first(where: { $0.value.id == groupId })?.key {
                groups[key]?.memberCount += 1
            }
        }
    }

    func sendMessage(groupId: String, channelId: String, text: String) async throws -> GroupMessage {
        let message = GroupMessage(id: UUID().uuidString, authorName: "You", text: text, sentAt: Date(), isCurrentUser: true)
        mutex.withLock {
            if let key = groups.first(where: { $0.value.id == groupId })?.key,
               let channelIndex = groups[key]?.channels.firstIndex(where: { $0.id == channelId }) {
                groups[key]?.channels[channelIndex].messages.append(message)
            }
        }
        return message
    }

    func newMessages(groupId: String, channelId: String, after date: Date?) async throws -> [GroupMessage] {
        mutex.withLock {
            guard let key = groups.first(where: { $0.value.id == groupId })?.key,
                  let channel = groups[key]?.channels.first(where: { $0.id == channelId }) else {
                return []
            }
            guard let date else { return channel.messages }
            return channel.messages.filter { $0.sentAt > date }
        }
    }

    func submitCollectiveOffer(groupId: String, amount: Decimal) async throws {
        // No-op in mock.
    }

    func askFounder(groupId: String, question: String) async throws -> FounderQA {
        let qa = FounderQA(id: UUID().uuidString, question: question, answer: nil, askedBy: "You")
        mutex.withLock {
            if let key = groups.first(where: { $0.value.id == groupId })?.key {
                groups[key]?.founderQAndA.append(qa)
            }
        }
        return qa
    }
}
