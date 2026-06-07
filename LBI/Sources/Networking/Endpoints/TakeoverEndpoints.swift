import Foundation

/// API endpoints for takeover groups.
/// TODO(API): confirm paths and payloads with the backend team.
enum TakeoverEndpoints {
    static func group(businessId: String) -> Endpoint<TakeoverGroupDTO> {
        Endpoint(path: "businesses/\(businessId)/takeover-group", method: .get)
    }

    static func join(groupId: String) -> Endpoint<EmptyResponse> {
        Endpoint(path: "takeover-groups/\(groupId)/members", method: .post)
    }

    static func sendMessage(groupId: String, channelId: String, text: String) throws -> Endpoint<GroupMessageDTO> {
        try .json(
            path: "takeover-groups/\(groupId)/channels/\(channelId)/messages",
            method: .post,
            body: ["text": text]
        )
    }

    static func messages(groupId: String, channelId: String, afterMessageId: String?) -> Endpoint<[GroupMessageDTO]> {
        var query: [URLQueryItem] = []
        if let afterMessageId {
            query.append(URLQueryItem(name: "after", value: afterMessageId))
        }
        return Endpoint(
            path: "takeover-groups/\(groupId)/channels/\(channelId)/messages",
            method: .get,
            query: query
        )
    }

    static func submitOffer(groupId: String, amount: Decimal) throws -> Endpoint<EmptyResponse> {
        try .json(
            path: "takeover-groups/\(groupId)/offers",
            method: .post,
            body: ["amount": amount]
        )
    }

    static func askFounder(groupId: String, question: String) throws -> Endpoint<FounderQADTO> {
        try .json(
            path: "takeover-groups/\(groupId)/questions",
            method: .post,
            body: ["question": question]
        )
    }
}
