import Foundation

/// Wire model for a takeover group. TODO(API): align with the backend schema.
struct TakeoverGroupDTO: Decodable {
    let id: String
    let businessId: String
    let businessName: String
    let memberCount: Int
    let targetMembers: Int
    let pooledCommitment: Decimal?
    let status: String?
    let collectiveOfferAmount: Decimal?
    let members: [GroupMemberDTO]?
    let roles: [TakeoverRoleDTO]?
    let channels: [GroupChannelDTO]?
    let founderQAndA: [FounderQADTO]?

    func toDomain() -> TakeoverGroup {
        TakeoverGroup(
            id: id,
            businessId: businessId,
            businessName: businessName,
            memberCount: memberCount,
            targetMembers: targetMembers,
            pooledCommitment: pooledCommitment ?? 0,
            members: (members ?? []).map { $0.toDomain() },
            channels: (channels ?? []).map { $0.toDomain() },
            founderQAndA: (founderQAndA ?? []).map { $0.toDomain() },
            status: status.flatMap(TakeoverStatus.init(rawValue:)) ?? .forming,
            roles: (roles ?? []).map { $0.toDomain() },
            collectiveOfferAmount: collectiveOfferAmount
        )
    }
}

struct GroupMemberDTO: Decodable {
    let id: String
    let name: String
    let role: String
    let committedAmount: Decimal?

    func toDomain() -> GroupMember {
        GroupMember(id: id, name: name, role: GroupRole(rawValue: role) ?? .member, committedAmount: committedAmount)
    }
}

struct TakeoverRoleDTO: Decodable {
    let id: String
    let title: String
    let detail: String
    let isFilled: Bool
    let occupantName: String?

    func toDomain() -> TakeoverRole {
        TakeoverRole(id: id, title: title, detail: detail, isFilled: isFilled, occupantName: occupantName)
    }
}

struct GroupChannelDTO: Decodable {
    let id: String
    let name: String
    let topic: String
    let messages: [GroupMessageDTO]?

    func toDomain() -> GroupChannel {
        GroupChannel(id: id, name: name, topic: topic, messages: (messages ?? []).map { $0.toDomain() })
    }
}

/// Wire model for a group message. TODO(API): align with the backend schema.
struct GroupMessageDTO: Decodable {
    let id: String
    let authorName: String
    let text: String
    let sentAt: Date

    func toDomain() -> GroupMessage {
        GroupMessage(id: id, authorName: authorName, text: text, sentAt: sentAt, isCurrentUser: false)
    }
}

/// Wire model for a founder Q&A entry. TODO(API): align with the backend.
struct FounderQADTO: Decodable {
    let id: String
    let question: String
    let answer: String?
    let askedBy: String

    func toDomain() -> FounderQA {
        FounderQA(id: id, question: question, answer: answer, askedBy: askedBy)
    }
}
