import Foundation

/// API endpoints for takeover groups. Group chat is the shared conversation
/// system (see `DealChatEndpoints`), keyed by the group's `conversationId`.
enum TakeoverEndpoints {
    /// Groups for a business.
    static func groups(businessId: String) -> Endpoint<[TakeoverGroupDTO]> {
        Endpoint(path: "businesses/\(businessId)/takeover-groups", method: .get)
    }

    /// Create a group on a business.
    static func create(businessId: String, name: String, pledgeAmount: Decimal?) throws -> Endpoint<TakeoverGroupDTO> {
        try .json(
            path: "businesses/\(businessId)/takeover-groups",
            method: .post,
            body: CreateBody(name: name, pledgeAmount: pledgeAmount)
        )
    }

    /// A single group.
    static func group(groupId: String) -> Endpoint<TakeoverGroupDTO> {
        Endpoint(path: "takeover-groups/\(groupId)", method: .get)
    }

    /// Join a group (optionally with a pledge).
    static func join(groupId: String, pledgeAmount: Decimal?) throws -> Endpoint<TakeoverGroupDTO> {
        try .json(
            path: "takeover-groups/\(groupId)/join",
            method: .post,
            body: PledgeBody(pledgeAmount: pledgeAmount)
        )
    }

    /// Leave a group (owner leaving disbands it).
    static func leave(groupId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "takeover-groups/\(groupId)/leave", method: .post)
    }

    /// Update the caller's pledge.
    static func pledge(groupId: String, pledgeAmount: Decimal) throws -> Endpoint<TakeoverGroupDTO> {
        try .json(
            path: "takeover-groups/\(groupId)/pledge",
            method: .put,
            body: PledgeRequiredBody(pledgeAmount: pledgeAmount)
        )
    }

    /// Group owner submits the collective offer (sums pledges into a sale bid).
    static func submitOffer(groupId: String) -> Endpoint<TakeoverGroupDTO> {
        Endpoint(path: "takeover-groups/\(groupId)/submit-offer", method: .post)
    }

    private struct CreateBody: Encodable {
        let name: String
        let pledgeAmount: Decimal?
    }

    private struct PledgeBody: Encodable {
        let pledgeAmount: Decimal?
    }

    private struct PledgeRequiredBody: Encodable {
        let pledgeAmount: Decimal
    }
}
