import Foundation

/// Wire model for the backend `TakeoverGroup`.
///
/// The backend group is leaner than the app's domain model: it has members
/// with pledges, a single linked chat `conversationId`, and an optional
/// collective offer — but no nested channels, roles, founder Q&A, or target
/// member count. The client synthesizes a single "discussion" channel from the
/// `conversationId` and derives the rest.
struct TakeoverGroupDTO: Decodable {
    let id: String
    let businessId: String
    let name: String
    let createdByUserId: String
    let members: [GroupMemberDTO]?
    let conversationId: String
    let collectiveOffer: CollectiveOfferDTO?
    let createdAt: BSONDate?

    /// - Parameter businessName: resolved by the caller (the group has no name
    ///   of the business, only its id).
    func toDomain(businessName: String) -> TakeoverGroup {
        let mappedMembers = (members ?? []).map { $0.toDomain() }
        let pooled = mappedMembers.compactMap(\.committedAmount).reduce(0, +)
        return TakeoverGroup(
            id: id,
            businessId: businessId,
            businessName: businessName.isEmpty ? name : businessName,
            memberCount: mappedMembers.count,
            targetMembers: max(mappedMembers.count, 1),
            pooledCommitment: pooled,
            members: mappedMembers,
            // The backend exposes one chat per group via `conversationId`; we
            // present it as a single discussion channel.
            channels: [
                GroupChannel(id: conversationId, name: "discussion", topic: name, messages: [])
            ],
            founderQAndA: [],
            status: .forming,
            roles: [],
            collectiveOfferAmount: collectiveOffer?.totalAmount
        )
    }
}

/// Backend group member: `{ userId, role, pledgeAmount, joinedAt }`.
struct GroupMemberDTO: Decodable {
    let userId: String
    let role: String
    let pledgeAmount: Decimal?
    let joinedAt: BSONDate?

    func toDomain() -> GroupMember {
        GroupMember(
            id: userId,
            name: role == "owner" ? "Group lead" : "Member",
            role: role == "owner" ? .lead : .member,
            committedAmount: pledgeAmount
        )
    }
}

/// Backend collective offer summary on a group.
struct CollectiveOfferDTO: Decodable {
    let totalAmount: Decimal
    let status: String?
    let submittedBidId: String?
    let submittedAt: BSONDate?
}
