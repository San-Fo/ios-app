import Foundation

/// Manages takeover groups, channels, messages and collective offers.
protocol TakeoverRepository: Sendable {
    func group(forBusiness businessId: String) async throws -> TakeoverGroup?
    func join(groupId: String) async throws
    func sendMessage(groupId: String, channelId: String, text: String) async throws -> GroupMessage
    /// Fetch channel messages newer than `afterMessageId` (used for polling).
    func newMessages(groupId: String, channelId: String, afterMessageId: String?) async throws -> [GroupMessage]
    func submitCollectiveOffer(groupId: String, amount: Decimal) async throws
    func askFounder(groupId: String, question: String) async throws -> FounderQA
}

// MARK: - Live (placeholder)

final class LiveTakeoverRepository: TakeoverRepository, @unchecked Sendable {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func group(forBusiness businessId: String) async throws -> TakeoverGroup? {
        // TODO(API): map TakeoverGroupDTO → domain once the backend is ready.
        try await client.send(TakeoverEndpoints.group(businessId: businessId)).toDomain()
    }

    func join(groupId: String) async throws {
        try await client.send(TakeoverEndpoints.join(groupId: groupId))
    }

    func sendMessage(groupId: String, channelId: String, text: String) async throws -> GroupMessage {
        // TODO(API): return mapped message from the backend response.
        let dto = try await client.send(try TakeoverEndpoints.sendMessage(groupId: groupId, channelId: channelId, text: text))
        return dto.toDomain()
    }

    func newMessages(groupId: String, channelId: String, afterMessageId: String?) async throws -> [GroupMessage] {
        try await client.send(TakeoverEndpoints.messages(groupId: groupId, channelId: channelId, afterMessageId: afterMessageId))
            .map { $0.toDomain() }
    }

    func submitCollectiveOffer(groupId: String, amount: Decimal) async throws {
        try await client.send(try TakeoverEndpoints.submitOffer(groupId: groupId, amount: amount))
    }

    func askFounder(groupId: String, question: String) async throws -> FounderQA {
        let dto = try await client.send(try TakeoverEndpoints.askFounder(groupId: groupId, question: question))
        return dto.toDomain()
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

    func newMessages(groupId: String, channelId: String, afterMessageId: String?) async throws -> [GroupMessage] {
        mutex.withLock {
            guard let key = groups.first(where: { $0.value.id == groupId })?.key,
                  let channel = groups[key]?.channels.first(where: { $0.id == channelId }) else {
                return []
            }
            guard let afterMessageId else { return channel.messages }
            guard let index = channel.messages.firstIndex(where: { $0.id == afterMessageId }) else { return [] }
            return Array(channel.messages.suffix(from: channel.messages.index(after: index)))
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
